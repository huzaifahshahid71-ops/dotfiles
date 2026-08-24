
-- HUZAIFAH-DESKTOP-SWITCHER
hl.unbind("SUPER + SHIFT + D")
hl.bind(
    "SUPER + SHIFT + D",
    hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/desktop-switch"),
    { description = "Desktop: Switch profile" }
)
