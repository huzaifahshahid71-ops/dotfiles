-- The shell layer, one tool per job:
--   rice-wallpaper restore   starts awww-daemon, shows the last wallpaper and
--                            derives the palette from it (matugen)
--   waybar                   bar
--   qs -c lumina               Quickshell: notifications, OSD, control centre, clock,
--                            visualiser, overlays
--   hyprpolkitagent          polkit password dialogs
--   hypridle -> hyprlock     idle and lock
--
-- hyprland.start fires once per session, never on `hyprctl reload`.
-- RICE_NO_AUTOSTART=1 skips it all - for trying the config in a nested Hyprland
-- without a second bar and shell.
if os.getenv("RICE_NO_AUTOSTART") then
    return
end

hl.on("hyprland.start", function()
    hl.exec_cmd("~/.local/share/desktop-profiles/sayconlun/support/bin/rice-wallpaper restore")
    hl.exec_cmd("waybar -c ~/.local/share/desktop-profiles/sayconlun/support/waybar/config.jsonc -s ~/.local/share/desktop-profiles/sayconlun/support/waybar/style.css")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("wl-paste --type text  --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("qs -c lumina -n -d")
end)
