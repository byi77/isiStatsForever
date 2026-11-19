local dir = arg[1]
-- Client language to simulate (second argument): deDE (default) or enUS.
local clientLocale = arg[2] or "deDE"
local ns = assert(loadfile(dir .. "/tools/wow_stub.lua"))(dir, clientLocale)
assert(ns.UI.GetFrame():IsShown(), "fresh install: own window, open")
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

-- Fishing pole: red row at the very top, raid warning with sound at combat start.
GetInventoryItemID = function(_, slot)
  return slot == 16 and 6256 or nil
end
local savedItemInfo = C_Item
C_Item = {
  GetItemInfoInstant = function()
    return 6256, "Angel", "", "", 0, 2, 20
  end,
}
local fishSections = ns.Data.Collect()
check(fishSections[1].key == "warn" and fishSections[1].rows[1].key == "warn_fishing", "fishing pole row at the top")
local warned, played, warnCount = nil, nil, 0
RaidWarningFrame = {}
RaidNotice_AddMessage = function(_, text)
  warned = text
  warnCount = warnCount + 1
end
SOUNDKIT = { RAID_WARNING = 8959 }
PlaySound = function(id)
  played = id
end
StubFrames[1].scripts.OnEvent(StubFrames[1], "PLAYER_REGEN_DISABLED")
check(warned == ns.L.WARN_FISHING_COMBAT and played == 8959, "raid warning with sound when combat starts")
check(warnCount == 5, "raid warning comes 5 times")
ns.SetRowEnabled("warn_fishing", false)
ns.SetRowEnabled("warn_fishing_combat", false)
warned = nil
StubFrames[1].scripts.OnEvent(StubFrames[1], "PLAYER_REGEN_DISABLED")
check(warned == nil and ns.Data.Collect()[1].key ~= "warn", "fishing warnings switchable")
ns.ResetRows()
GetInventoryItemID, C_Item = nil, savedItemInfo
check(ns.Data.Collect()[1].key ~= "warn", "no warning without a fishing pole")
RaidWarningFrame, RaidNotice_AddMessage, SOUNDKIT, PlaySound = nil, nil, nil, nil

-- Chat history: sent lines are saved, a repeat moves to the end, and the
-- saved lines go back into the edit box history (oldest first) on login.
check(IsiStatsDB.chatHistoryArrows == true, "chat history arrows on by default")
local box = ChatFrame1EditBox
box:AddHistoryLine("/w Freund hi")
box:AddHistoryLine("hallo")
box:AddHistoryLine("/w Freund hi")
local saved = IsiStatsDB.chatHistory
check(#saved == 2 and saved[1] == "hallo" and saved[2] == "/w Freund hi", "chat lines saved, repeat moved to the end")
check(box.altArrow == false, "Up / Down walk the history without Alt")
-- /console: the game sends it without a history line; the typed text counts.
box:Fire("OnEditFocusGained")
box:SetText("/console gxRestart", true)
box:SetText("", false) -- the game clears the box while sending
box:Fire("OnEnterPressed")
check(
  saved[#saved] == "/console gxRestart" and box.history[#box.history] == "/console gxRestart",
  "/console saved from the typed text"
)
-- A line the game already added is not added twice.
box:Fire("OnEditFocusGained")
box:SetText("hallo", true)
box:AddHistoryLine("hallo")
local historyCount = #box.history
box:Fire("OnEnterPressed")
check(#box.history == historyCount, "no double line when the game added it")
-- Text deleted by hand before Enter is not saved.
box:Fire("OnEditFocusGained")
box:SetText("/console x", true)
box:SetText("", true)
box:Fire("OnEnterPressed")
check(saved[#saved] ~= "/console x", "deleted text is not saved")
-- Up / Down walk the saved list themselves (newest first), Down past the
-- newest gives an empty line.
box:Fire("OnEditFocusGained")
local n = #IsiStatsDB.chatHistory
local clock = 0
GetTime = function()
  clock = clock + 1
  return clock
end
box:FireKey("OnArrowPressed", "UP")
check(box.text == IsiStatsDB.chatHistory[n], "Up shows the newest line")
box:FireKey("OnArrowPressed", "UP")
check(box.text == IsiStatsDB.chatHistory[n - 1], "Up again shows the one before")
box:FireKey("OnArrowPressed", "DOWN")
check(box.text == IsiStatsDB.chatHistory[n], "Down goes back")
box:FireKey("OnArrowPressed", "DOWN")
check(box.text == "", "Down past the newest line empties the box")
GetTime = function()
  return 5
end
box:FireKey("OnArrowPressed", "UP")
box:FireKey("OnArrowPressed", "UP")
check(box.text == IsiStatsDB.chatHistory[n], "one key press reported twice steps once")
GetTime = nil
box:Fire("OnEditFocusGained")
ns.ChatHistory.SetArrows(false)
check(box.altArrow == true, "arrow keys switchable")
local savedCount = #IsiStatsDB.chatHistory
box:AddHistoryLine("geheim")
check(#IsiStatsDB.chatHistory == savedCount, "nothing saved with the setting off")
ns.ChatHistory.SetArrows(true)
SlashCmdList.ISISTATS("chat clear")
check(#IsiStatsDB.chatHistory == 0, "chat history cleared")

-- XP to the next level, in thousands, at the very top; gone at max level.
UnitXP = function()
  return 5000
end
UnitXPMax = function()
  return 17400
end
GetMaxPlayerLevel = function()
  return 60
end
UnitLevel = function()
  return 41
end
local xpSections = ns.Data.Collect()
local xpRow = xpSections[1] and xpSections[1].rows[1]
check(xpSections[1].key == "xp" and xpRow and xpRow.value == "12.4k", "XP row first, 12.4k to go")
check(xpRow and xpRow.label == string.format(ns.L.XP_NEXT_FMT, 42), "XP row names the next level")
-- The login query mutes the chat windows for TIME_PLAYED_MSG and lets them
-- listen again once the answer is in (no global function replaced).
local chatListens = true
ChatFrame1 = {
  IsEventRegistered = function(_, event)
    return event == "TIME_PLAYED_MSG" and chatListens
  end,
  UnregisterEvent = function()
    chatListens = false
  end,
  RegisterEvent = function()
    chatListens = true
  end,
}
local pendingTimers, asked = {}, false
local realAfter = C_Timer.After
C_Timer.After = function(_, fn)
  pendingTimers[#pendingTimers + 1] = fn
end
RequestTimePlayed = function()
  asked = true
end
ns.LevelTime.Request()
check(asked and not chatListens, "played-time query sent with the chat muted")
ns.LevelTime.OnTimePlayed(100000, 3600)
for _, fn in ipairs(pendingTimers) do
  fn()
end
check(chatListens, "chat listens again after the answer")
C_Timer.After = realAfter
ChatFrame1, RequestTimePlayed = nil, nil

-- Time on this level from TIME_PLAYED_MSG (through the real event handler)
-- and the estimate from the XP rate: 5000 XP in 1h, 12400 to go -> ~2h 28m.
local clock = 1000
GetTime = function()
  return clock
end
local evFrame = StubFrames[1]
evFrame.scripts.OnEvent(evFrame, "TIME_PLAYED_MSG", 100000, 3600)
local function xpRowByKey(key)
  for _, r in ipairs(ns.Data.Collect()[1].rows) do
    if r.key == key then
      return r
    end
  end
end
check(xpRowByKey("xp_time") and xpRowByKey("xp_time").value == "1h 0m", "time on this level 1h 0m")
check(xpRowByKey("xp_eta") and xpRowByKey("xp_eta").value == "~2h 28m", "estimate ~2h 28m")
clock = clock + 1800
check(xpRowByKey("xp_time").value == "1h 30m", "time on this level keeps counting")
evFrame.scripts.OnEvent(evFrame, "PLAYER_LEVEL_UP", 42)
check(xpRowByKey("xp_time").value == "0m", "level up restarts the level time")
check(xpRowByKey("xp_eta").value == "-", "no estimate without data")
UnitLevel = function()
  return 60
end
check(ns.Data.Collect()[1].key ~= "xp", "no XP row at max level")
UnitXP, UnitXPMax, GetMaxPlayerLevel = nil, nil, nil

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

-- Debug output is kept for reading from the SavedVariables file.
SlashCmdList.ISISTATS("debug")
check(type(IsiStatsDB.lastDebug) == "table" and #IsiStatsDB.lastDebug.lines > 3, "debug dump saved")

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
