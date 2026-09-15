-- The `rice` table: state and helpers that outlive a single config file.
--
-- `hyprctl eval` runs in the same Lua state as the config, so the scripts call
-- these instead of rebuilding Hyprland calls in bash:
--   rice.rebind(...)       rice-binds-ctl.py (the keybind menu)
--   rice.focus(on)         hypr-focus.sh (writing mode)
-- A `hyprctl reload` rebuilds all of it from the config files.

rice = rice or {}

-- ------------------------------------------------------------------ binds --
-- Every bind made through these is remembered under the key string it was
-- COMMITTED with (as written in conf/binds.lua), so a rebind can find it again
-- however often it has moved. A key string used twice keeps both, in order.
rice.binds = {}

local function binder(opts)
    return function(keys, action)
        local entry = { action = action, opts = opts, keys = keys }
        entry.handle = hl.bind(keys, action, opts)
        local list = rice.binds[keys] or {}
        list[#list + 1] = entry
        rice.binds[keys] = list
    end
end

rice.bind   = binder(nil)
rice.bindr  = binder({ repeating = true })                 -- repeats while held
rice.bindl  = binder({ locked = true })                    -- works on the lock screen
rice.bindrl = binder({ repeating = true, locked = true })
rice.bindm  = binder({ mouse = true })                     -- drag with a mouse button

-- changes: { { committed_keys, n, new_keys }, ... } where n picks between binds
-- that share committed keys (1 for the usual case). All are removed before any
-- is bound again: in a swap one bind's new keys are the other's old ones.
function rice.rebind(changes)
    local todo = {}
    for _, ch in ipairs(changes) do
        local entry = (rice.binds[ch[1]] or {})[ch[2] or 1]
        if not entry then
            error("rice.rebind: no bind committed as \"" .. tostring(ch[1]) .. "\"")
        end
        todo[#todo + 1] = { entry = entry, keys = ch[3] }
    end
    for _, t in ipairs(todo) do
        t.entry.handle:remove()
    end
    for _, t in ipairs(todo) do
        t.entry.handle = hl.bind(t.keys, t.entry.action, t.entry.opts)
        t.entry.keys = t.keys
    end
end

-- ------------------------------------------------------------- focus mode --
-- Entering saves the LIVE gaps/border/rounding and leaving puts exactly those
-- back, so whatever rice-settings set survives the round trip. After a reload
-- there is nothing saved, and nothing to restore: the config values are back.
function rice.focus(on)
    if on then
        rice.focus_saved = rice.focus_saved or {
            gaps_out = hl.get_config("general.gaps_out"),
            gaps_in = hl.get_config("general.gaps_in"),
            border_size = hl.get_config("general.border_size"),
            rounding = hl.get_config("decoration.rounding"),
        }
        hl.config({
            general = { gaps_out = 140, gaps_in = 0, border_size = 0 },
            decoration = { rounding = 0 },
        })
    elseif rice.focus_saved then
        local s = rice.focus_saved
        hl.config({
            general = { gaps_out = s.gaps_out, gaps_in = s.gaps_in, border_size = s.border_size },
            decoration = { rounding = s.rounding },
        })
        rice.focus_saved = nil
    end
end
