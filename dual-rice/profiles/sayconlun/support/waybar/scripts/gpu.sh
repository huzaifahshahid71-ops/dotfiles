#!/usr/bin/env bash
# GPU usage for waybar, with temperature and VRAM in the tooltip, as JSON.
# Reads the card's own device directory: /sys/class/hwmon/hwmonN is
# renumbered every boot, but device/hwmon/* always belongs to this card.
dev=""
for d in /sys/class/drm/card*/device; do
    [[ -r "$d/gpu_busy_percent" ]] && { dev="$d"; break; }
done
[[ -n "$dev" ]] || { echo '{"text":""}'; exit 0; }

busy=$(<"$dev/gpu_busy_percent")
temp=0
for t in "$dev"/hwmon/hwmon*/temp1_input; do
    [[ -r "$t" ]] && temp=$(( $(<"$t") / 1000 ))
    break
done
used=$(( $(<"$dev/mem_info_vram_used") / 1048576 ))
total=$(( $(<"$dev/mem_info_vram_total") / 1048576 ))
class=ok; (( temp >= 90 )) && class=hot

printf '{"text":"󰢮 %s%%","tooltip":"GPU %s%%  ·  %s°C\\nVRAM %s / %s MiB","class":"%s"}\n' \
    "$busy" "$busy" "$temp" "$used" "$total" "$class"
