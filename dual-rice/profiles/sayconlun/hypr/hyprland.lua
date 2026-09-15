-- ─── New Rice · Hyprland ─────────────────────────────────────────────────────
--
-- Lua config (Hyprland 0.55+). hyprlang's hyprland.conf is gone: 0.57 drops it.
--
-- Monitors and look live in THIS file on purpose: rice-settings' engines
-- (rice-monitor-ctl.py, rice-look-ctl.py) read their baseline from here and
-- write overrides into conf.d/. So keep each monitor on ONE hl.monitor line and
-- the look block below as one `key = value,` per line. Everything else is in conf/.
--
-- Check before reloading:
--   Hyprland --verify-config --config ~/.config/hypr/hyprland.lua
--
-- `hyprctl keyword` does not exist for a Lua config - live changes go through
-- `hyprctl eval '<lua>'`, and `hyprctl dispatch` takes hl.dsp.* (see conf/binds.lua).

-- Helpers shared with conf/ and the scripts that `hyprctl eval` into this config.
require("conf.lib")

-- Where the GENERATED files live: colors.lua and conf.d/. Not "next to this
-- file": Hyprland resolves the config's symlink before it sets package.path, so
-- require() finds conf/ in the repo, while matugen and the settings tools write
-- into ~/.config/hypr. Literal ~/.config, like matugen's paths. RICE_HYPR_DIR
-- moves both sides at once - that is how a nested test instance gets its own.
rice.dir = os.getenv("RICE_HYPR_DIR") or (os.getenv("HOME") .. "/.config/hypr")

-- Palette, generated from the wallpaper by matugen (see ~/.local/share/desktop-profiles/sayconlun/support/matugen).
-- Missing on a fresh install until `rice-wallpaper theme` has run once; the
-- fallback keeps borders visible meanwhile.
local ok, c = pcall(dofile, rice.dir .. "/colors.lua")
if not ok then
    c = {
        primary = "rgb(7dcfff)", onprimary = "rgb(00344a)", tertiary = "rgb(bb9af7)",
        divider = "rgb(3b4261)", raised = "rgb(2f334d)", text = "rgb(c8d3f5)",
    }
end
rice.colors = c

require("conf.env")

-- ---------------------------------------------------------------- monitors --
-- Every output starts at its preferred mode, placed automatically (the
-- catch-all below). To pin one, add a line per monitor (`hyprctl monitors all`
-- lists the names) - or use `rice-settings displays` (Super+Shift+D), which
-- writes conf.d/ instead. Keep each rule on ONE line:
--   hl.monitor({ output = "DP-1", mode = "2560x1440@165", position = "0x0", scale = 1 })
--   hl.monitor({ output = "HDMI-A-1", mode = "3840x2160@60", position = "2560x0", scale = 1.5 })
--   hl.monitor({ output = "DP-2", mode = "2560x1440@180", position = "0x0", scale = 1, vrr = 2 })
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

-- -------------------------------------------------------------------- look --
-- Gradients are tables here: the hyprlang form "rgb(a) rgb(b) 45deg" is
-- rejected as an invalid colour.
hl.config({
    general = {
        gaps_in = 2,
        gaps_out = 8,
        border_size = 2,
        col = {
            active_border = { colors = { c.primary, c.tertiary }, angle = 45 },
            inactive_border = c.divider,
        },
        layout = "dwindle",
        allow_tearing = true,          -- games; paired with `immediate` in conf/rules.lua
        resize_on_border = true,
    },

    decoration = {
        rounding = 4,
        active_opacity = 1.0,
        inactive_opacity = 0.9,

        shadow = {
            enabled = true,
            range = 5,
            render_power = 2,
            color = "rgba(00000099)",
        },

        blur = {
            enabled = true,
            size = 6,
            passes = 3,
            new_optimizations = true,
            xray = true,
            noise = 0.02,
            contrast = 1.0,
            brightness = 0.9,
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        force_split = 2,
        preserve_split = true,
        default_split_ratio = 1.0,     -- even splits: cava | music, editor | terminal
    },

    -- Window groups (tabbed tiles). Tabs are FILLED so
    -- their contrast does not depend on the wallpaper behind them (bare titles
    -- measured 1.54:1 against a pale sky). rice-theme-reload pushes new colours live.
    group = {
        col = {
            border_active = { colors = { c.primary, c.tertiary }, angle = 45 },
            border_inactive = c.divider,
        },
        groupbar = {
            font_size = 11,
            height = 20,
            gradients = true,
            indicator_height = 0,
            col = {
                active = c.primary,
                inactive = c.raised,
            },
            text_color = c.onprimary,
            text_color_inactive = c.text,
        },
    },

    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        force_default_wallpaper = 0,
        enable_swallow = true,
        swallow_regex = "^(kitty|konsole|foot)$",
        animate_manual_resizes = false,
        focus_on_activate = true,
        -- If the lock screen (Quickshell's WlSessionLock) ever dies while locked,
        -- the session stays locked but another locker may take over - from a TTY:
        --   hyprctl --instance 0 dispatch 'hl.dsp.exec_cmd("hyprlock")'
        allow_session_lock_restore = true,
    },
})

-- flafy's easing curves
hl.curve("expoOut",   { type = "bezier", points = { {0.19, 1.0}, {0.22, 1.0} } })
hl.curve("easeInOut", { type = "bezier", points = { {0.5, 0},    {0.5, 1}    } })

hl.animation({ leaf = "windows",    enabled = true, speed = 4, bezier = "expoOut" })
hl.animation({ leaf = "windowsIn",  enabled = true, speed = 4, bezier = "expoOut", style = "popin 80%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 4, bezier = "expoOut", style = "popin 80%" })
hl.animation({ leaf = "layers",     enabled = true, speed = 3, bezier = "expoOut", style = "popin 90%" })
hl.animation({ leaf = "border",     enabled = true, speed = 6, bezier = "easeInOut" })
hl.animation({ leaf = "fade",       enabled = true, speed = 4, bezier = "expoOut" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "expoOut", style = "slide" })

-- Frosted shell surfaces. ignore_alpha makes the blur pass skip transparent
-- pixels, so the gaps between waybar's islands stay clear instead of reading
-- as one dimmed band (blur brightness 0.9 dims whatever it covers).
hl.layer_rule({
    name = "waybar-glass",
    match = { namespace = "^(waybar)$" },
    blur = true,
    ignore_alpha = 0.3,
})

hl.layer_rule({
    name = "rofi-glass",
    match = { namespace = "^(rofi)$" },
    blur = true,
    ignore_alpha = 0.3,
})

-- The Quickshell cards (OSD, notifications, control centre, settings hub,
-- keybind menu).
-- Not rice-wallpaper: its backdrop is opaque, so blur would only cost frames.
hl.layer_rule({
    name = "quickshell-glass",
    match = { namespace = "^(rice-osd|rice-notifications|rice-notifcenter|rice-controlcenter|rice-settings|rice-binds)$" },
    blur = true,
    ignore_alpha = 0.3,
})

-- ----------------------------------------------------------------- the rest --
require("conf.input")
require("conf.workspaces")
require("conf.rules")
require("conf.binds")
require("conf.autostart")

-- Overrides written by rice-settings and the keybind menu. Last, so they win;
-- generated, so not in git. Delete one and `hyprctl reload` to fall back to the
-- values above. Loaded in name order (00-, 05-, 10-, ...), from rice.dir - a
-- wildcard with no match at all is a config error, hence conf.d/00-defaults.lua.
require(rice.dir .. "/conf.d/*.lua")
