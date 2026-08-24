#!/usr/bin/env python3
"""Resolve an exact dependency closure from the installed pacman database.

Unlike pactree text parsing, this resolves virtual dependencies (provides) back
to the actual installed package that satisfies them. It is intended for the
Huzaifah Triple-Rice offline AppImage builder.
"""

from __future__ import annotations

import argparse
import re
import sys
from collections import defaultdict, deque
from pathlib import Path

LOCAL_DB = Path("/var/lib/pacman/local")


def parse_desc(path: Path) -> dict[str, list[str]]:
    fields: dict[str, list[str]] = defaultdict(list)
    current: str | None = None
    for raw in path.read_text(errors="replace").splitlines():
        line = raw.rstrip("\n")
        if line.startswith("%") and line.endswith("%") and len(line) > 2:
            current = line.strip("%")
            continue
        if not line:
            current = None
            continue
        if current is not None:
            fields[current].append(line)
    return dict(fields)


def dep_name(spec: str) -> str:
    # Arch dependency/version syntax: foo>=1, libfoo.so=1-64, etc.
    return re.split(r"[<>=]", spec, maxsplit=1)[0].strip()


def load_packages():
    packages: dict[str, dict[str, object]] = {}
    providers: dict[str, list[str]] = defaultdict(list)

    for desc in LOCAL_DB.glob("*/desc"):
        try:
            fields = parse_desc(desc)
        except OSError:
            continue
        if not fields.get("NAME"):
            continue

        name = fields["NAME"][0]
        version = fields.get("VERSION", [""])[0]
        depends = fields.get("DEPENDS", [])
        provides = fields.get("PROVIDES", [])

        packages[name] = {
            "version": version,
            "depends": depends,
            "provides": provides,
        }
        providers[name].append(name)
        for provided in provides:
            key = dep_name(provided)
            if key:
                providers[key].append(name)

    return packages, providers


def resolve_provider(
    dependency: str,
    packages: dict[str, dict[str, object]],
    providers: dict[str, list[str]],
) -> str | None:
    key = dep_name(dependency)
    if key in packages:
        return key

    candidates = providers.get(key, [])
    if len(candidates) == 1:
        return candidates[0]
    if candidates:
        # Every candidate is installed; prefer deterministic lexical order.
        return sorted(candidates)[0]
    return None


def resolve(targets: list[str]) -> tuple[list[str], list[str]]:
    packages, providers = load_packages()
    missing_targets = [t for t in targets if t not in packages]
    if missing_targets:
        return [], [f"target:{x}" for x in missing_targets]

    closure: set[str] = set()
    unresolved: set[str] = set()
    queue: deque[str] = deque(targets)

    while queue:
        pkg = queue.popleft()
        if pkg in closure:
            continue
        closure.add(pkg)

        for dependency in packages[pkg]["depends"]:  # type: ignore[index]
            provider = resolve_provider(str(dependency), packages, providers)
            if provider is None:
                unresolved.add(f"{pkg}:{dependency}")
                continue
            if provider not in closure:
                queue.append(provider)

    return sorted(closure), sorted(unresolved)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("targets", nargs="*")
    parser.add_argument(
        "--targets-file",
        type=Path,
        help="newline-separated target package names",
    )
    args = parser.parse_args()

    targets = list(args.targets)
    if args.targets_file:
        targets.extend(
            line.strip()
            for line in args.targets_file.read_text().splitlines()
            if line.strip() and not line.lstrip().startswith("#")
        )

    targets = sorted(set(targets))
    if not targets:
        print("ERROR: no target packages supplied", file=sys.stderr)
        return 2

    closure, unresolved = resolve(targets)
    if unresolved:
        print("ERROR: could not resolve the installed dependency closure:", file=sys.stderr)
        for item in unresolved:
            print(f"  {item}", file=sys.stderr)
        return 1

    for pkg in closure:
        print(pkg)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
