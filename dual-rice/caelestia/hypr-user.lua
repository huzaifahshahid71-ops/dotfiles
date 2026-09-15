
-- HUZAIFAH-DESKTOP-SWITCHER
hl.unbind("SUPER + SHIFT + D")
hl.bind(
    "SUPER + SHIFT + D",
    hl.dsp.exec_cmd("qs -c multi-rice-switcher"),
    { description = "Desktop: Switch profile" }
)

-- HUZAIFAH-REFRESH-SWITCHER
hl.unbind("SUPER + SHIFT + R")
hl.bind(
    "SUPER + SHIFT + R",
    hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/refresh-switch"),
    { description = "Display: Switch refresh rate" }
)
