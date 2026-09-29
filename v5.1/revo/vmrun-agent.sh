#!/usr/bin/env bash
set -euo pipefail

QUEUE="${VMRUN_QUEUE:-$HOME/hostshare/.vmrun}"
SELF="$HOME/.local/bin/vmrun-agent"
SERVICE="$HOME/.config/systemd/user/vmrun-agent.service"

install_agent() {
    install -Dm755 "$0" "$SELF"
    mkdir -p "$QUEUE" "$(dirname "$SERVICE")"

    cat > "$SERVICE" <<EOF
[Unit]
Description=Host-to-VM command bridge over 9P
After=default.target

[Service]
Type=simple
ExecStart=/usr/bin/bash $SELF
Restart=always
RestartSec=1
Environment=PATH=$HOME/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/bin:/bin

[Install]
WantedBy=default.target
EOF

    # Capture the current graphical-session environment when available.
    systemctl --user import-environment \
        WAYLAND_DISPLAY \
        HYPRLAND_INSTANCE_SIGNATURE \
        XDG_CURRENT_DESKTOP \
        XDG_RUNTIME_DIR \
        DBUS_SESSION_BUS_ADDRESS \
        >/dev/null 2>&1 || true

    systemctl --user daemon-reload
    systemctl --user enable --now vmrun-agent.service

    printf 'vmrun agent installed and running\n'
    printf 'queue: %s\n' "$QUEUE"
}

if [[ "${1:-}" == "--install" ]]; then
    install_agent
    exit 0
fi

mkdir -p "$QUEUE"

cleanup_stale() {
    find "$QUEUE" -maxdepth 1 -type f \
        \( -name '*.run' -o -name '*.tmp' \) \
        -mmin +10 -delete 2>/dev/null || true
}

run_job() {
    local cmdfile="$1"
    local stem="${cmdfile%.cmd}"
    local runfile="$stem.run"
    local outfile="$stem.out"
    local rcfile="$stem.rc"
    local tmpout="$stem.out.tmp"
    local tmprc="$stem.rc.tmp"
    local command rc

    mv "$cmdfile" "$runfile" 2>/dev/null || return 0

    command="$(base64 -d < "$runfile" 2>/dev/null || true)"
    if [[ -z "$command" ]]; then
        printf 'vmrun-agent: empty or invalid command payload\n' > "$tmpout"
        printf '2\n' > "$tmprc"
    else
        set +e
        bash -lc "$command" > "$tmpout" 2>&1
        rc=$?
        set -e
        printf '%s\n' "$rc" > "$tmprc"
    fi

    mv -f "$tmpout" "$outfile"
    mv -f "$tmprc" "$rcfile"
    rm -f "$runfile"
}

cleanup_stale

while true; do
    found=0

    for cmdfile in "$QUEUE"/*.cmd; do
        [[ -e "$cmdfile" ]] || continue
        found=1
        run_job "$cmdfile"
    done

    if (( found == 0 )); then
        sleep 0.08
    fi
done
