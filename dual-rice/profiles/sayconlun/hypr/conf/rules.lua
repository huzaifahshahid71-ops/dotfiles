-- Window rules. `match` takes RE2 regexes; every other field is an effect.
-- --verify-config names an unknown field, EXCEPT that it accepts any value for
-- `group`.

hl.window_rule({
    name = "suppress-maximize",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name = "taskmgr-float",
    match = { class = "^(taskmgr)$" },
    float = true,
    center = true,
    size = { 1200, 800 },
})

hl.window_rule({
    name = "float-utilities",
    match = { class = [[^(pavucontrol|org\.pulseaudio\.pavucontrol|nm-connection-editor|hyprpolkitagent|com\.gabm\.satty|org\.kde\.kcalc)$]] },
    float = true,
})

hl.window_rule({
    name = "pip-always-on-top",
    match = { title = "^(Picture-in-Picture)$" },
    float = true,
    pin = true,
})

hl.window_rule({
    name = "media-idle-inhibit",
    match = { class = "^(firefox|chromium|mpv)$" },
    idle_inhibit = "focus",
})

hl.window_rule({
    name = "video-players-float",
    match = { class = "^(vlc|mpv)$" },
    float = true,
})

-- ------------------------------------------------------------------ games --
hl.window_rule({
    name = "steam-to-main",
    match = { class = "^(steam|Steam)$" },
    workspace = "1",
})

-- Steam titles, wine/proton .exe windows, Lutris, emulators, Moonlight.
hl.window_rule({
    name = "games-to-main",
    match = { class = [[^(steam_app_.*|.*\.exe|lutris|net\.lutris\.Lutris|moonlight|ryujinx)$]] },
    workspace = "1",
    fullscreen = true,
    immediate = true,
    idle_inhibit = "always",
})
