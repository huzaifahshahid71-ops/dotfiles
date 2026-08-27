-- Optional per-user keybind overrides (managed by DMS). Loaded after default binds.

-- HUZAIFAH-MULTI-RICE-SWITCHER
hl.bind("SUPER + SHIFT + D", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/desktop-switch"))

-- Keyboard has no Print key: use the familiar screenshot shortcut.
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd("dms screenshot"))

-- Bare Super opens the DMS application launcher.
hl.bind("SUPER + SUPER_L", hl.dsp.exec_cmd("dms ipc call spotlight toggle"), { release = true })
