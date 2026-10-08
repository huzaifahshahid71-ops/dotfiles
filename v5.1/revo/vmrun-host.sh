#!/usr/bin/env bash
set -euo pipefail

SHARE="${VMRUN_SHARE:-$HOME/VMs/vm-share}"
QUEUE="$SHARE/.vmrun"
TIMEOUT="${VMRUN_TIMEOUT:-120}"

usage() {
    cat <<'EOF'
Usage:
  vmrun 'command to execute inside the VM'
  vmrun --ping

Environment:
  VMRUN_SHARE    host path of the 9P share (default: ~/VMs/vm-share)
  VMRUN_TIMEOUT  seconds to wait for a result (default: 120)
EOF
}

if [[ $# -eq 0 ]]; then
    usage
    exit 2
fi

if [[ "${1:-}" == "--ping" ]]; then
    command='printf "VM bridge alive: "; hostname; printf "user: "; whoami'
else
    command="$*"
fi

[[ -d "$SHARE" ]] || {
    printf 'vmrun: shared directory not found: %s\n' "$SHARE" >&2
    exit 3
}

mkdir -p "$QUEUE"

id="$(date +%s%N)-$$-${RANDOM:-0}"
stem="$QUEUE/$id"
cmdtmp="$stem.cmd.tmp"
cmdfile="$stem.cmd"
outfile="$stem.out"
rcfile="$stem.rc"

cleanup() {
    rm -f "$cmdtmp" "$cmdfile" "$outfile" "$rcfile" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

printf '%s' "$command" | base64 -w0 > "$cmdtmp"
mv -f "$cmdtmp" "$cmdfile"

deadline=$((SECONDS + TIMEOUT))
while [[ ! -f "$rcfile" ]]; do
    if (( SECONDS >= deadline )); then
        printf 'vmrun: timed out after %ss; is vmrun-agent running in the VM?\n' "$TIMEOUT" >&2
        exit 124
    fi
    sleep 0.05
done

[[ -f "$outfile" ]] && cat "$outfile"
rc="$(cat "$rcfile" 2>/dev/null || printf '1')"

if [[ "$rc" =~ ^[0-9]+$ ]]; then
    exit "$rc"
fi

exit 1
