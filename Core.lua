local addonName, ns = ...
local L = ns.L

local DEFAULTS = {
  dock = false, -- follow the character frame (off: own window, the player docks it in the settings)
  shown = true, -- free window open (only when not docked)
  scale = 1,
  alpha = 100, -- background opacity in percent
  showHeaders = false, -- section headers (hidden by default)
  flashChanges = true, -- fade a value in when it changes
  combatMode = "always", -- "always" | "hide" (hidden in combat) | "only" (shown only in combat)
  locked = false, -- no moving / resizing
  chatHistoryArrows = true, -- Up / Down in the chat input walk the sent lines
  chatHistory = {}, -- sent chat lines, oldest first (ChatHistory.lua)
  errors = {}, -- own Lua errors (ErrorLog.lua)
  pos = nil, -- { point, relativePoint, x, y }
  collapsed = {},
}

local db
local charDB -- per character: rows[id] = true/false where the user chose
local rowDefaults

-- ---------------------------------------------------------------- row visibility

function ns.IsRowEnabled(id)
  local chosen = charDB and charDB.rows and charDB.rows[id]
  if chosen ~= nil then
    return chosen
  end
  rowDefaults = rowDefaults or ns.Data.GetDefaults()
  return rowDefaults[id] == true
end

function ns.SetRowEnabled(id, value)
  charDB.rows[id] = value and true or false
  if id == "warn_tracking" then
    ns.Tracking.Update()
  elseif id == "warn_fishing_combat" then
    ns.UpdateFishingAlert()
  end
  ns.Refresh()
end

function ns.SetAllRows(value)
  for _, section in ipairs(ns.Data.GetCatalog()) do
    for _, row in ipairs(section.rows) do
      charDB.rows[row.id] = value and true or false
    end
  end
  ns.Tracking.Update()
  ns.UpdateFishingAlert()
  ns.Refresh()
end

function ns.ResetRows()
  charDB.rows = {}
  rowDefaults = nil
  ns.Tracking.Update()
  ns.UpdateFishingAlert()
  ns.Refresh()
end

function ns.GetAlpha()
  return db and db.alpha or 100
end

function ns.SetAlpha(percent)
  db.alpha = math.floor(math.max(0, math.min(100, percent)) + 0.5)
  ns.UI.SetBackgroundAlpha(db.alpha / 100)
  if ns.Options then
    ns.Options.Sync()
  end
end

function ns.GetFlashChanges()
  return db and db.flashChanges and true or false
end

function ns.SetFlashChanges(value)
  db.flashChanges = value and true or false
  ns.UI.SetFlashEnabled(db.flashChanges)
end

function ns.GetShowHeaders()
  return db and db.showHeaders and true or false
end

function ns.SetShowHeaders(value)
  db.showHeaders = value and true or false
  ns.Refresh()
end

-- Drops saved choices for rows that no longer exist (e.g. the removed
-- "vs. target" section or the main-hand skill row).
function ns.PruneRows()
  local valid = {}
  for _, section in ipairs(ns.Data.GetCatalog()) do
    for _, row in ipairs(section.rows) do
      valid[row.id] = true
    end
  end
  for id in pairs(charDB.rows) do
    if not valid[id] then
      charDB.rows[id] = nil
    end
  end
end

-- Fishing pole in combat (also with the window closed): the text stays until
-- the pole is taken off, also after the fight, and the sound comes at once and
-- then every FISHING_SOUND_GAP seconds until the fight is over or the pole is
-- off. It does not start outside combat, fishing needs the pole.
local FISHING_SOUND_GAP = 2
-- Own flag: InCombatLockdown() is still false during PLAYER_REGEN_DISABLED.
local inFight = false
local fishingSoundOn, fishingSoundRun = false, 0

local function fishingWarningWanted()
  return ns.IsRowEnabled("warn_fishing_combat") and ns.Skills.hasFishingPole()
end

local function stopFishingSound()
  fishingSoundOn = false
  fishingSoundRun = fishingSoundRun + 1 -- pending timers do nothing
end

local function fishingSound(run)
  if run ~= fishingSoundRun then
    return
  end
  if not inFight or not fishingWarningWanted() then
    stopFishingSound()
    return
  end
  ns.UI.PlayAlertSound()
  if type(C_Timer) == "table" and C_Timer.After then
    C_Timer.After(FISHING_SOUND_GAP, function()
      fishingSound(run)
    end)
  end
end

-- After combat, gear and settings changes.
function ns.UpdateFishingAlert()
  if not fishingWarningWanted() then
    ns.UI.SetAlert("fishing", nil)
    stopFishingSound()
  elseif not inFight then
    stopFishingSound() -- the text stays
  elseif not fishingSoundOn then
    ns.UI.SetAlert("fishing", L.WARN_FISHING_COMBAT, true)
    fishingSoundOn = true
    fishingSoundRun = fishingSoundRun + 1
    fishingSound(fishingSoundRun)
  end
end

function ns.SetInFight(value)
  inFight = value
  ns.UpdateFishingAlert()
end

function ns.IsLocked()
  return db and db.locked and true or false
end

function ns.SetLocked(value)
  db.locked = value and true or false
  if ns.Options then
    ns.Options.Sync()
  end
end

local function inCombat()
  return type(InCombatLockdown) == "function" and InCombatLockdown() and true or false
end

-- Whether the window should be visible from dock state, open state and the
-- combat mode. Explicit /isistats show/hide still works in every mode.
local function wantedVisible()
  local mode = db.combatMode
  if mode == "only" then
    return inCombat()
  end
  if mode == "hide" and inCombat() then
    return false
  end
  local cf = _G.CharacterFrame
  if db.dock then
    return cf ~= nil and cf:IsShown()
  end
  return db.shown == true
end

function ns.ApplyCombatVisibility()
  local frame = ns.UI.GetFrame()
  if not frame then
    return
  end
  if wantedVisible() then
    ns.ApplyPosition()
    frame:Show()
  else
    frame:Hide()
  end
end

function ns.GetCombatMode()
  return db and db.combatMode or "always"
end

function ns.SetCombatMode(mode)
  if mode ~= "hide" and mode ~= "only" then
    mode = "always"
  end
  db.combatMode = mode
  ns.ApplyCombatVisibility()
  if ns.Options then
    ns.Options.Sync()
  end
end

function ns.IsDocked()
  return db and db.dock and true or false
end

local function out(msg)
  print("|cff1e90ffisiStatsForever|r: " .. tostring(msg))
end

local function characterFrame()
  return _G.CharacterFrame
end

local function isDockedNow()
  local cf = characterFrame()
  return db.dock and cf and cf:IsShown()
end

-- ---------------------------------------------------------------- position

function ns.ApplyPosition()
  local frame = ns.UI.GetFrame()
  if not frame then
    return
  end
  frame:SetScale(db.scale or 1)
  ns.UI.SetBackgroundAlpha((db.alpha or 100) / 100)
  frame:ClearAllPoints()
  if isDockedNow() then
    frame:SetPoint("TOPLEFT", characterFrame(), "TOPRIGHT", 2, 0)
  elseif db.pos then
    local p = db.pos
    frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
  else
    frame:SetPoint("CENTER", UIParent, "CENTER", 300, 0)
  end
end

function ns.IsAnchoredToCharacter()
  return isDockedNow() and true or false
end

function ns.OnScaleChanged(scale, savePosition)
  db.scale = math.floor(scale * 100 + 0.5) / 100
  if savePosition then
    ns.SavePosition()
  end
end

function ns.SavePosition()
  local frame = ns.UI.GetFrame()
  local point, _, relativePoint, x, y = frame:GetPoint(1)
  if point then
    db.pos = { point, relativePoint, x, y }
  end
end

function ns.OnDragStart()
  if db.dock then
    db.dock = false
    db.shown = true
  end
end

function ns.ToggleDock()
  db.dock = not db.dock
  if db.dock then
    out(L.CMD_DOCKED)
    local cf = characterFrame()
    if cf and not cf:IsShown() then
      ns.UI.GetFrame():Hide()
    end
  else
    db.shown = true
    out(L.CMD_FREE)
  end
  ns.ApplyPosition()
  if ns.Options then
    ns.Options.Sync()
  end
end

-- ---------------------------------------------------------------- show / refresh

local pending = false

function ns.Refresh()
  pending = false
  local frame = ns.UI.GetFrame()
  if not frame or not frame:IsShown() then
    return
  end
  local level = UnitLevel("player")
  local class = UnitClass("player")
  if frame.subtitle then
    frame.subtitle:SetText((class or "") .. (level and (" " .. level) or ""))
  end
  ns.UI.SetFlashEnabled(db.flashChanges)
  ns.UI.Render(ns.Data.Collect(), db.collapsed, db.showHeaders)
end

function ns.RequestRefresh()
  local frame = ns.UI.GetFrame()
  if pending or not frame or not frame:IsShown() then
    return
  end
  pending = true
  C_Timer.After(0.15, ns.Refresh)
end

function ns.ToggleSection(key)
  db.collapsed[key] = not db.collapsed[key] or nil
  ns.Refresh()
end

function ns.Show()
  if not isDockedNow() then
    db.shown = true
  end
  ns.ApplyPosition()
  ns.UI.GetFrame():Show()
end

function ns.Hide()
  db.shown = false
  ns.UI.GetFrame():Hide()
end

function ns.Toggle()
  if ns.UI.GetFrame():IsShown() then
    ns.Hide()
  else
    ns.Show()
  end
end

function IsiStats_OnAddonCompartmentClick()
  ns.Toggle()
end

-- ---------------------------------------------------------------- character frame

local function hookCharacterFrame()
  local cf = characterFrame()
  if not cf or cf.isiStatsForeverHooked then
    return
  end
  cf.isiStatsForeverHooked = true
  cf:HookScript("OnShow", function()
    if db.dock then
      ns.ApplyCombatVisibility()
    end
  end)
  cf:HookScript("OnHide", function()
    if db.dock then
      ns.ApplyCombatVisibility()
    end
  end)
end

-- ---------------------------------------------------------------- events

local REFRESH_EVENTS = {
  "PLAYER_EQUIPMENT_CHANGED",
  "PLAYER_LEVEL_UP",
  "SKILL_LINES_CHANGED",
  "CHARACTER_POINTS_CHANGED",
  "UPDATE_SHAPESHIFT_FORM",
  "COMBAT_RATING_UPDATE",
  "PLAYER_TARGET_CHANGED",
  "PLAYER_XP_UPDATE",
  "TIME_PLAYED_MSG",
  "UPDATE_EXHAUSTION",
  "PLAYER_REGEN_DISABLED",
  "PLAYER_REGEN_ENABLED",
  "UNIT_LEVEL",
}
-- The game hides hit, expertise and glancing in combat: read them on these
-- events, also while the window is hidden (e.g. "show only in combat").
local PRIME_EVENTS = {
  PLAYER_EQUIPMENT_CHANGED = true,
  PLAYER_LEVEL_UP = true,
  SKILL_LINES_CHANGED = true,
  CHARACTER_POINTS_CHANGED = true,
  COMBAT_RATING_UPDATE = true,
  PLAYER_REGEN_ENABLED = true,
}
local UNIT_EVENTS = {
  "UNIT_STATS",
  "UNIT_AURA",
  "UNIT_ATTACK_POWER",
  "UNIT_RANGED_ATTACK_POWER",
  "UNIT_DAMAGE",
  "UNIT_RANGEDDAMAGE",
  "UNIT_ATTACK_SPEED",
  "UNIT_RESISTANCES",
  "UNIT_MAXHEALTH",
  "UNIT_MAXPOWER",
  "UNIT_DEFENSE",
}

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, arg1, arg2)
  if event == "ADDON_LOADED" then
    if arg1 ~= addonName then
      return
    end
    IsiStatsDB = IsiStatsDB or {}
    db = IsiStatsDB
    for k, v in pairs(DEFAULTS) do
      if db[k] == nil then
        db[k] = type(v) == "table" and {} or v
      end
    end
    ns.ErrorLog.Install(db)
    IsiStatsCharDB = IsiStatsCharDB or {}
    charDB = IsiStatsCharDB
    charDB.rows = charDB.rows or {}
    charDB.swings = nil -- left over from test builds that counted swings
    ns.LevelTime.Init(charDB)
    ns.PruneRows()
    self:UnregisterEvent("ADDON_LOADED")
  elseif event == "PLAYER_LOGIN" then
    ns.UI.Create()
    ns.Options.Register()
    hookCharacterFrame()
    ns.ChatHistory.Setup(db)
    for _, e in ipairs(REFRESH_EVENTS) do
      pcall(self.RegisterEvent, self, e)
    end
    for _, e in ipairs(UNIT_EVENTS) do
      pcall(self.RegisterUnitEvent, self, e, "player")
    end
    for e in pairs(ns.Tracking.EVENTS) do
      pcall(self.RegisterEvent, self, e)
    end
    ns.Data.Prime()
    ns.Buffs.Read()
    ns.Tracking.Schedule()
    ns.SetInFight(inCombat()) -- a reload during a fight
    if db.combatMode ~= "always" then
      ns.ApplyCombatVisibility()
    elseif db.shown and not db.dock then
      ns.Show()
    end
    -- Played time for "time on this level"; the shown time ticks on.
    ns.LevelTime.Request()
    ns.LevelTime.Start()
    if type(C_Timer) == "table" and C_Timer.NewTicker then
      C_Timer.NewTicker(30, ns.RequestRefresh)
    end
  else
    if event == "TIME_PLAYED_MSG" then
      ns.LevelTime.OnTimePlayed(arg1, arg2)
    elseif event == "PLAYER_LEVEL_UP" then
      ns.LevelTime.OnLevelUp()
    elseif event == "PLAYER_XP_UPDATE" then
      ns.LevelTime.OnXPUpdate()
    end
    if PRIME_EVENTS[event] then
      ns.Data.Prime()
    end
    if ns.Tracking.EVENTS[event] then
      ns.Tracking.Schedule()
    end
    if event == "UNIT_AURA" or event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_ENABLED" then
      ns.Buffs.Read()
    end
    if event == "PLAYER_EQUIPMENT_CHANGED" then
      ns.UpdateFishingAlert()
    end
    if event == "PLAYER_REGEN_DISABLED" then
      ns.SetInFight(true)
    elseif event == "PLAYER_REGEN_ENABLED" then
      ns.SetInFight(false)
    end
    if (event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED") and db.combatMode ~= "always" then
      ns.ApplyCombatVisibility()
    end
    ns.RequestRefresh()
  end
end)

-- ---------------------------------------------------------------- slash

SLASH_ISISTATS1 = "/isistats"
SLASH_ISISTATS2 = "/istats"
SlashCmdList.ISISTATS = function(msg)
  local cmd, arg = strtrim(msg or ""):lower():match("^(%S*)%s*(.-)$")
  if cmd == "" then
    ns.Toggle()
  elseif cmd == "show" then
    ns.Show()
  elseif cmd == "hide" then
    ns.Hide()
  elseif cmd == "config" or cmd == "options" or cmd == "settings" then
    ns.Options.Open()
  elseif cmd == "dock" then
    if not db.dock then
      ns.ToggleDock()
    end
  elseif cmd == "free" or cmd == "undock" then
    if db.dock then
      ns.ToggleDock()
    end
    ns.Show()
  elseif cmd == "alpha" then
    local v = tonumber(arg)
    if v and v >= 0 and v <= 100 then
      ns.SetAlpha(v)
    end
    out(string.format(L.CMD_ALPHA, db.alpha))
  elseif cmd == "scale" then
    local v = tonumber(arg)
    if v and v >= 0.5 and v <= 2 then
      db.scale = v
      ns.ApplyPosition()
    end
    out(string.format(L.CMD_SCALE, db.scale))
  elseif cmd == "reset" then
    local errors = db.errors -- the error log survives a settings reset
    local chatHistory = db.chatHistory -- so do the sent chat lines
    IsiStatsDB = {}
    db = IsiStatsDB
    for k, v in pairs(DEFAULTS) do
      db[k] = type(v) == "table" and {} or v
    end
    db.errors = errors
    db.chatHistory = chatHistory
    ns.ErrorLog.Install(db)
    ns.ChatHistory.Setup(db)
    ns.ApplyPosition()
    ns.ResetRows()
    ns.Options.Sync()
    out(L.CMD_RESET)
  elseif cmd == "lock" or cmd == "unlock" then
    ns.SetLocked(cmd == "lock")
    out(cmd == "lock" and L.CMD_LOCKED or L.CMD_UNLOCKED)
  elseif cmd == "chat" and arg == "clear" then
    ns.ChatHistory.Clear()
    out(L.CHAT_CLEARED)
  elseif cmd == "errors" then
    if arg == "clear" then
      ns.ErrorLog.Clear()
      out(L.ERR_CLEARED)
    else
      ns.ErrorLog.Print(out)
    end
  elseif cmd == "debug" then
    -- Printed and kept in IsiStatsDB.lastDebug, so it can be read from the
    -- SavedVariables file after a /reload (no copying from the chat).
    local lines = {}
    ns.Data.DebugDump(function(...)
      local parts = {}
      for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring((select(i, ...)))
      end
      local line = table.concat(parts, " ")
      lines[#lines + 1] = line
      print("|cff1e90ffisiStatsForever|r " .. line)
    end)
    db.lastDebug = { time = type(date) == "function" and date("%Y-%m-%d %H:%M:%S") or "", lines = lines }
    out(L.DEBUG_SAVED)
  else
    out(L.CMD_HELP)
  end
end
