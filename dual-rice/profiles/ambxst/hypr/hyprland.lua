-- Ambxst isolated profile
local home = os.getenv("HOME")
local generated = home .. "/.local/share/ambxst/hyprland.lua"

-- On normal boots Ambxst's generated Lua exists and applies the full rice.
-- On a fresh restore, start Ambxst directly once so axctl can generate it.
local f = io.open(generated, "r")
if f then
    f:close()
    loadfile(generated)()
else
    hl.on("hyprland.start", function()
        hl.exec_cmd(home .. "/.local/bin/ambxst")
    end)
end

-- Keep the laptop's captured display scale independent of Ambxst defaults.
hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = 1.25
})

-- Huzaifah triple-rice switcher.
hl.bind(
    "SUPER + SHIFT + D",
    hl.dsp.exec_cmd(home .. "/.local/bin/desktop-switch"),
    { description = "Switch desktop profile" }
)
