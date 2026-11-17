local dir = arg[1]
-- Client language to simulate (second argument): deDE (default) or enUS.
local clientLocale = arg[2] or "deDE"
local ns = assert(loadfile(dir .. "/tools/wow_stub.lua"))(dir, clientLocale)
CharacterFrame:Show()
CharacterFrame:Hide()
SlashCmdList.ISISTATS("alpha 40")
SlashCmdList.ISISTATS("alpha 0")
SlashCmdList.ISISTATS("")
SlashCmdList.ISISTATS("config")
SlashCmdList.ISISTATS("free")
SlashCmdList.ISISTATS("dock")
SlashCmdList.ISISTATS("scale 1.2")
SlashCmdList.ISISTATS("reset")
ns.Options.Sync()
ns.SetRowEnabled("m_dps", true)
ns.SetAllRows(false)
ns.ResetRows()
ns.SetShowHeaders(true)
ns.SetShowHeaders(false)
ns.SetAlpha(55)

-- Asserts (exit 1 on the first failure).
local failures = 0
local function check(cond, msg)
  if not cond then
    failures = failures + 1
    print("FAIL " .. msg)
  end
end

-- Warrior class defaults: strength, melee AP, defense, equipped skills + vs. target.
for _, id in ipairs({ "stat1", "m_ap", "m_dmg", "d_def", "w_equipped", "w_vs" }) do
  check(ns.IsRowEnabled(id), "default on: " .. id)
end
for _, id in ipairs({ "stat4", "s_dmg", "r_ap", "w_other", "m_dps" }) do
  check(not ns.IsRowEnabled(id), "default off: " .. id)
end
check(IsiStatsDB.showHeaders == false, "headers hidden by default")
check(IsiStatsDB.alpha == 55, "alpha saved")
check(IsiStatsDB.scale == 1, "scale reset to 1")

-- Saved choices for rows that no longer exist are dropped.
IsiStatsCharDB.rows.t_info = true
IsiStatsCharDB.rows.m_skill_mh = false
ns.PruneRows()
check(IsiStatsCharDB.rows.t_info == nil and IsiStatsCharDB.rows.m_skill_mh == nil, "stale row settings pruned")

-- A user choice survives and wins over the class default.
ns.SetRowEnabled("stat1", false)
check(not ns.IsRowEnabled("stat1"), "user choice wins over default")
ns.ResetRows()
check(ns.IsRowEnabled("stat1"), "class default back after reset")

-- Collected sections: values the defaults switch on are there.
local function findRow(sections, label)
  for _, s in ipairs(sections) do
    for _, r in ipairs(s.rows) do
      if r.label == label then
        return r
      end
    end
  end
end
local sections = ns.Data.Collect()
check(
  findRow(sections, ns.L.ATTACK_POWER) and findRow(sections, ns.L.ATTACK_POWER).value == "1100",
  "attack power 1100"
)
check(findRow(sections, ns.L.DEFENSE) ~= nil, "defense row")

-- No guessing: a hostile level ?? target (not a world boss) gets no defense.
UnitExists = function()
  return true
end
UnitCanAttack = function()
  return true
end
UnitName = function()
  return "Elite"
end
UnitClassification = function()
  return "elite"
end
UnitLevel = function(unit)
  return unit == "target" and -1 or 60
end
local target = findRow(ns.Data.Collect(), "Elite")
check(target and target.value == ns.L.T_LEVEL_UNKNOWN, "level ?? target shows unknown defense")

-- Error log: own errors are captured and de-duplicated, others are not
-- (debugstack is stubbed to point into isiStatsForever, so the filter is the message
-- for the foreign case).
debugstack = function()
  return "Interface/AddOns/OtherAddon/x.lua:1"
end
geterrorhandler()("Interface/AddOns/OtherAddon/x.lua:1: boom")
check(#IsiStatsDB.errors == 0, "foreign error not logged")
geterrorhandler()("Interface/AddOns/isiStatsForever/Data.lua:42: attempt to index nil")
geterrorhandler()("Interface/AddOns/isiStatsForever/Data.lua:42: attempt to index nil")
check(#IsiStatsDB.errors == 1 and IsiStatsDB.errors[1].count == 2, "own error logged once, counted twice")
SlashCmdList.ISISTATS("errors")
SlashCmdList.ISISTATS("reset")
check(#IsiStatsDB.errors == 1, "error log survives reset")
SlashCmdList.ISISTATS("errors clear")
check(#IsiStatsDB.errors == 0, "error log cleared")

-- Fade-in: a changed value plays the animation, an unchanged one does not.
UnitLevel = function()
  return 60
end
UnitExists = function()
  return false
end
ns.Show()
check(ns.UI.GetFrame():IsShown(), "window shown for the fade-in test")
ns.Refresh()
local before = flashPlays
ns.Refresh()
check(flashPlays == before, "no fade-in without a change")
UnitAttackPower = function()
  return 900, 250, 0
end
ns.Refresh()
check(flashPlays > before, "fade-in when attack power changes")
ns.SetFlashChanges(false)
before = flashPlays
UnitAttackPower = function()
  return 900, 300, 0
end
ns.Refresh()
check(flashPlays == before, "no fade-in when switched off")

-- Language follows the client: German strings only on a deDE client.
if clientLocale == "deDE" then
  check(ns.L.MELEE == "Nahkampf", "deDE client shows German")
else
  check(ns.L.MELEE == "Melee", clientLocale .. " client shows English")
  -- UTF-8 umlauts/eszett all start with byte 195 (0xC3); English text has none.
  for key, value in pairs(ns.L) do
    for i = 1, #value do
      if value:byte(i) == 195 then
        check(false, "non-ASCII (German) text in English locale: " .. key)
        break
      end
    end
  end
end

-- Combat visibility: fired through the real event handler.
local ev = StubFrames[1]
local frame = ns.UI.GetFrame()
local combat = false
InCombatLockdown = function()
  return combat
end
SlashCmdList.ISISTATS("free")
ns.Show()
ns.SetCombatMode("hide")
combat = true
ev.scripts.OnEvent(ev, "PLAYER_REGEN_DISABLED")
check(not frame:IsShown(), "hide in combat: hidden when combat starts")
combat = false
ev.scripts.OnEvent(ev, "PLAYER_REGEN_ENABLED")
check(frame:IsShown(), "hide in combat: back after combat")
ns.SetCombatMode("only")
check(not frame:IsShown(), "only in combat: hidden out of combat")
combat = true
ev.scripts.OnEvent(ev, "PLAYER_REGEN_DISABLED")
check(frame:IsShown(), "only in combat: shown when combat starts")
combat = false
ev.scripts.OnEvent(ev, "PLAYER_REGEN_ENABLED")
check(not frame:IsShown(), "only in combat: hidden after combat")
ns.SetCombatMode("always")
check(IsiStatsDB.combatMode == "always", "combat mode back to always")

-- Lock
SlashCmdList.ISISTATS("lock")
check(IsiStatsDB.locked == true and ns.IsLocked(), "lock")
SlashCmdList.ISISTATS("unlock")
check(IsiStatsDB.locked == false, "unlock")

if failures > 0 then
  print(("load test: %d failure(s)"):format(failures))
  os.exit(1)
end
print("load test (" .. clientLocale .. "): all checks passed")
