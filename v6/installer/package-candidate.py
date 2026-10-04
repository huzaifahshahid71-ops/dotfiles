#!/usr/bin/env python3
"""Package the lightweight preview; deliberately refuses a production filename."""
import argparse
import hashlib
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.output.name != "sumi-setup-v6-candidate1.zip":
        parser.error("Use sumi-setup-v6-candidate1.zip; this is not the production release")
    with zipfile.ZipFile(args.output, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in sorted(ROOT.rglob("*")):
            if path.is_file() and not path.is_symlink() and "__pycache__" not in path.parts and path.suffix != ".pyc":
                info = zipfile.ZipInfo("sumi-setup/" + path.relative_to(ROOT).as_posix())
                info.external_attr = (0o100755 if path.suffix == ".sh" else 0o100644) << 16
                info.compress_type = zipfile.ZIP_DEFLATED
                archive.writestr(info, path.read_bytes())
    with args.output.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
    print(args.output, args.output.stat().st_size, digest)


if __name__ == "__main__":
    main()
