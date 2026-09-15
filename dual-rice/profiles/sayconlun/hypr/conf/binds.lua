-- Keybinds. The keybind menu (Super+/, rice-binds-ctl.py) reads THIS file as
-- its baseline, so keep its shape: one bind per line, inside a `-- --- name --`
-- section, as
--   bind / bindr (repeats) / bindl (works while locked) / bindrl / bindm (mouse)
-- then the key string and ONE dispatcher. Rebinds made in the menu are saved to
-- conf.d/30-binds.lua and applied over these; this file is never rewritten.

local bind, bindr, bindl, bindrl, bindm = rice.bind, rice.bindr, rice.bindl, rice.bindrl, rice.bindm
local exec, dsp = hl.dsp.exec_cmd, hl.dsp

-- Your apps: point term, files and browser at whatever you use.
local bin     = "~/.local/share/desktop-profiles/sayconlun/support/bin"          -- not on the session PATH - always spell it out
local term    = "kitty"
local files   = "thunar"
local browser = "firefox"

-- ------------------------------------------------------------------- apps --
bind("SUPER + RETURN",         exec("steam"))
bind("SUPER + T",              exec(term))
bind("CTRL + ALT + DELETE",    exec(term .. " --class taskmgr -e btop"))
bind("SUPER + SPACE",          exec("rofi -show drun -theme ~/.local/share/desktop-profiles/sayconlun/support/rofi/launcher.rasi"))
bind("SUPER + SHIFT + SPACE",  exec("rofi -show filebrowser -theme ~/.local/share/desktop-profiles/sayconlun/support/rofi/launcher.rasi"))
bind("CTRL + SHIFT + SPACE",   exec("rofi -show filebrowser -theme ~/.local/share/desktop-profiles/sayconlun/support/rofi/launcher.rasi"))
bind("SUPER + E",              exec(files))
bind("SUPER + B",              exec(browser))
bind("SUPER + Q",              dsp.window.close())
bind("SUPER + SHIFT + Q",      dsp.exit())
bind("SUPER + G",              dsp.window.float())
bind("SUPER + S",              dsp.window.fullscreen())
bind("SUPER + A",              dsp.layout("togglesplit"))

-- ------------------------------------------------------------------ shell --
bind("SUPER + C",              exec(bin .. "/rice-clipboard"))
bind("SUPER + N",              exec("qs -c lumina ipc call notifications toggle"))   -- notification centre
bind("SUPER + X",              exec(bin .. "/rice-power"))
bind("SUPER + ESCAPE",         exec("loginctl lock-session"))           -- hypridle locks (Quickshell, else hyprlock)
bind("SUPER + SHIFT + W",      exec("qs -c lumina ipc call wallpaper toggle"))       -- carousel
bind("SUPER + slash",          exec("qs -c lumina ipc call binds toggle"))           -- cheatsheet + rebinding
bind("SUPER + comma",          exec("qs -c lumina ipc call settings toggle"))        -- settings hub
bind("SUPER + D",              exec("qs -c lumina ipc call dashboard toggle"))       -- dashboard
bind("SUPER + SHIFT + S",      exec("qs -c lumina ipc call capture menu"))           -- screenshot / record
bind("SUPER + ALT + W",        exec(bin .. "/rice-wallpaper next"))
bind("SUPER + CTRL + W",       exec(bin .. "/rice-wallhaven"))
bind("SUPER + SHIFT + D",      exec("qs -c multi-rice-switcher"))
bind("SUPER + CTRL + D",       exec(bin .. "/rice-settings displays"))
bind("SUPER + SHIFT + A",      exec(bin .. "/rice-settings look"))      -- SUPER + A alone is togglesplit
bind("SUPER + SHIFT + B",      exec("pkill -USR1 -x waybar"))           -- hide/show the bar
bind("SUPER + SHIFT + V",      exec("qs -c lumina ipc call visualiser toggle"))      -- desktop visualiser

bind("Print",                  exec([[grim -g "$(slurp)" - | wl-copy -t image/png]]))
bind("SHIFT + Print",          exec([[grim - | wl-copy -t image/png]]))
bind("SUPER + Print",          exec([[grim -g "$(slurp)" ~/Pictures/shot-$(date +%s).png]]))
bind("CTRL + Print",           exec([[grim -g "$(slurp)" - | satty -f -]]))
bind("F8",                     exec(bin .. "/gsr-replay-save"))         -- save the last 3 min of the replay buffer

-- ---------------------------------------------------- reading back / focus --
bind("SUPER + P",              exec(bin .. "/read-aloud.sh --toggle"))
bind("SUPER + bracketleft",    exec(bin .. "/read-aloud.sh --back"))
bind("SUPER + bracketright",   exec(bin .. "/read-aloud.sh --forward"))
bind("SUPER + SHIFT + R",      exec(bin .. "/read-aloud.sh --selection"))
bind("SUPER + SHIFT + P",      exec(bin .. "/read-aloud.sh --stop"))
bind("SUPER + F",              exec(bin .. "/hypr-focus.sh"))

-- ------------------------------------------------------- windows (vim keys) --
bind("SUPER + H",              dsp.focus({ direction = "left" }))
bind("SUPER + J",              dsp.focus({ direction = "down" }))
bind("SUPER + K",              dsp.focus({ direction = "up" }))
bind("SUPER + L",              dsp.focus({ direction = "right" }))
bind("SUPER + left",           dsp.focus({ direction = "left" }))
bind("SUPER + down",           dsp.focus({ direction = "down" }))
bind("SUPER + up",             dsp.focus({ direction = "up" }))
bind("SUPER + right",          dsp.focus({ direction = "right" }))

bind("SUPER + CTRL + H",       dsp.window.swap({ direction = "left" }))
bind("SUPER + CTRL + J",       dsp.window.swap({ direction = "down" }))
bind("SUPER + CTRL + K",       dsp.window.swap({ direction = "up" }))
bind("SUPER + CTRL + L",       dsp.window.swap({ direction = "right" }))

bindr("SUPER + SHIFT + H",     dsp.window.resize({ x = -80, y = 0, relative = true }))
bindr("SUPER + SHIFT + J",     dsp.window.resize({ x = 0, y = 80, relative = true }))
bindr("SUPER + SHIFT + K",     dsp.window.resize({ x = 0, y = -80, relative = true }))
bindr("SUPER + SHIFT + L",     dsp.window.resize({ x = 80, y = 0, relative = true }))

bindm("SUPER + mouse:272",     dsp.window.drag())
bindm("SUPER + mouse:273",     dsp.window.resize())

-- ------------------------------------------------------------- workspaces --
bind("SUPER + 1",              dsp.focus({ workspace = 1 }))
bind("SUPER + 2",              dsp.focus({ workspace = 2 }))
bind("SUPER + 3",              dsp.focus({ workspace = 3 }))
bind("SUPER + 4",              dsp.focus({ workspace = 4 }))
bind("SUPER + 5",              dsp.focus({ workspace = 5 }))
bind("SUPER + 6",              dsp.focus({ workspace = 6 }))
bind("SUPER + 7",              dsp.focus({ workspace = 7 }))
bind("SUPER + 8",              dsp.focus({ workspace = 8 }))
bind("SUPER + 9",              dsp.focus({ workspace = 9 }))
bind("SUPER + 0",              dsp.focus({ workspace = 10 }))
bind("SUPER + M",              dsp.focus({ workspace = "previous" }))

bind("SUPER + SHIFT + 1",      dsp.window.move({ workspace = 1 }))
bind("SUPER + SHIFT + 2",      dsp.window.move({ workspace = 2 }))
bind("SUPER + SHIFT + 3",      dsp.window.move({ workspace = 3 }))
bind("SUPER + SHIFT + 4",      dsp.window.move({ workspace = 4 }))
bind("SUPER + SHIFT + 5",      dsp.window.move({ workspace = 5 }))
bind("SUPER + SHIFT + 6",      dsp.window.move({ workspace = 6 }))
bind("SUPER + SHIFT + 7",      dsp.window.move({ workspace = 7 }))
bind("SUPER + SHIFT + 8",      dsp.window.move({ workspace = 8 }))
bind("SUPER + SHIFT + 9",      dsp.window.move({ workspace = 9 }))
bind("SUPER + SHIFT + 0",      dsp.window.move({ workspace = 10 }))

bind("SUPER + TAB",            dsp.window.cycle_next())
bind("SUPER + mouse_down",     dsp.focus({ workspace = "e+1" }))
bind("SUPER + mouse_up",       dsp.focus({ workspace = "e-1" }))

-- ------------------------------------------------------ media keys (+ OSD) --
-- Plain commands: the Quickshell OSD (Osd.qml) watches PipeWire and the
-- players itself, so nothing here has to ask for it to appear.
bindrl("XF86AudioRaiseVolume",  exec("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"))
bindrl("XF86AudioLowerVolume",  exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"))
bindl("XF86AudioMute",          exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
bindl("XF86AudioMicMute",       exec("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"))
bindl("XF86AudioPlay",          exec("playerctl play-pause"))
bindl("XF86AudioNext",          exec("playerctl next"))
bindl("XF86AudioPrev",          exec("playerctl previous"))
bindrl("XF86MonBrightnessUp",   exec("brightnessctl set 5%+"))
bindrl("XF86MonBrightnessDown", exec("brightnessctl set 5%-"))

-- Rebinds made in the keybind menu live in conf.d/30-binds.lua, not here.
--
-- The menu enters this submap while it waits for a new combo: with nothing
-- bound in it, every key reaches the menu instead of firing its usual action.
-- Escape always leaves it - from Hyprland's side, so it works even if the
-- shell has died.
hl.define_submap("rice-capture", function()
    hl.bind("escape", dsp.submap("reset"))
end)
