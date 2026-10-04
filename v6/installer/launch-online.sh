#!/bin/sh
set -eu
setup_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec python3 "$setup_dir/app.py" "$@"
