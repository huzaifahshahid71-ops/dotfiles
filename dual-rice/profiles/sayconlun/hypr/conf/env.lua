hl.env("PATH", os.getenv("HOME") .. "/.local/share/desktop-profiles/sayconlun/support/bin:" .. (os.getenv("PATH") or ""))
-- Qt goes through qt6ct. NOT "kde": that platform theme ships with
-- plasma-integration, which is not installed, and Qt silently falls back to an
-- unthemed default (light chrome around a dark Dolphin view).
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("NIXOS_OZONE_WL", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE", "24")
