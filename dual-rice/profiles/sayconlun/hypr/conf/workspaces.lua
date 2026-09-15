-- 1 main    drafting AND gaming - Steam and games are sent here (conf/rules.lua)
-- 2 and up  no rule: each opens on whichever monitor is focused, and
--           disappears from the bar again once it is empty
--
-- To keep a workspace on one monitor, add `monitor = "<name>"` to its rule.
-- `monitor` only applies when a workspace is CREATED - existing ones stay put
-- through a reload; move them with
--   hyprctl dispatch 'hl.dsp.workspace.move({ workspace = 1, monitor = "DP-1" })'
hl.workspace_rule({ workspace = "1", default_name = "main", layout_opts = { orientation = "left" } })
