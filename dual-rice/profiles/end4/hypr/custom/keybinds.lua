hl.bind("CTRL+SUPER+ALT+Slash", hl.dsp.exec_cmd("xdg-open ~/.config/hypr/custom/keybinds.lua"), {description = "Edit user keybinds"} )

-- HUZAIFAH-MULTI-RICE-SWITCHER
hl.unbind("SUPER + SHIFT + D")
hl.bind(
    "SUPER + SHIFT + D",
    hl.dsp.exec_cmd("qs -c multi-rice-switcher"),
    { description = "Desktop: Open Multi-Rice switcher" }
)

-- HUZAIFAH-REFRESH-SWITCHER
hl.unbind("SUPER + SHIFT + R")
hl.bind(
    "SUPER + SHIFT + R",
    hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/refresh-switch"),
    { description = "Display: Switch refresh rate" }
)
