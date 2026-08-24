hl.bind("CTRL+SUPER+ALT+Slash", hl.dsp.exec_cmd("xdg-open ~/.config/hypr/custom/keybinds.lua"), {description = "Edit user keybinds"} )

-- HUZAIFAH-DESKTOP-SWITCHER
hl.unbind("SUPER + SHIFT + D")
hl.bind(
    "SUPER + SHIFT + D",
    hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/desktop-switch"),
    { description = "Desktop: Switch profile" }
)
