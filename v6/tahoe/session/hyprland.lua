-- ZEPHYRUS v6.0 Tahoe — STAGED STANDALONE LOGIN CONFIG.
--
-- NOT A LIVE PROFILE.  Does not load hyprliquid or existing rice services.
-- Test independently in a separate, recoverable physical login session
-- ONLY after explicit approval, verified display manager and fallback.
--
-- Isolated: no imports from ~/.config/hypr or other rice paths.
hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = 1.25,
})

hl.config({
    general = {
        layout = "dwindle",
        gaps_in = 7,
        gaps_out = 16,
        border_size = 1,
        resize_on_border = true,
    },
    decoration = {
        rounding = 22,
        blur = { enabled = true, size = 4, passes = 1 },
        shadow = { enabled = true, range = 10, render_power = 3 },
    },
    animations = { enabled = true },
    misc = {
        disable_hyprland_logo = false,
        force_default_wallpaper = 1,
    },
})

-- Manual fallback: Super+Enter opens terminal. Exit only this Tahoe
-- compositor with Super+Shift+E (returns to the login manager).
hl.bind("SUPER + RETURN", hl.dsp.exec_cmd("foot"))
hl.bind("SUPER + T", hl.dsp.exec_cmd("foot"))
hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("SUPER + SHIFT + E", hl.dsp.exit())
hl.bind("SUPER + V", hl.dsp.window.float({ action = "toggle" }))

-- Floating-first is a separate tested policy milestone. Do not use
-- blanket float rules on the first standalone boot: dialogs, portal
-- prompts and games must be audited with a reliable terminal fallback.

hl.on("hyprland.start", function()
    hl.exec_cmd("foot")
end)
