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
  resetMeterOnJoin = true, -- clear Blizzard's damage meter when joining a group
  combatBanner = true, -- big fading text in the middle on combat start and end
  flightTimes = true, -- measure and keep flight times (Flights.lua)
  flightBar = true, -- bar during a flight with a known or estimated time
  flightBarUnknown = true, -- also for an unknown time (counting up)
  flightLanding = true, -- "Landing" in the middle a few seconds before arrival
  flightBarPos = false, -- { point, relativePoint, x, y } after Shift + drag
  flights = {}, -- flights[faction][fromNodeID][toNodeID] = seconds
  flightNames = {}, -- flight point names by node ID
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
  ns.Warnings.Update(true)
  ns.Buffs.Update()
  ns.Refresh()
end

function ns.SetAllRows(value)
  for _, section in ipairs(ns.Data.GetCatalog()) do
    for _, row in ipairs(section.rows) do
      charDB.rows[row.id] = value and true or false
    end
  end
  ns.Tracking.Update()
  ns.Warnings.Update(true)
  ns.UpdateFishingAlert()
  ns.Buffs.Update()
  ns.Refresh()
end

function ns.ResetRows()
  charDB.rows = {}
  rowDefaults = nil
  ns.Tracking.Update()
  ns.Warnings.Update(true)
  ns.UpdateFishingAlert()
  ns.Buffs.Update()
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

function ns.IsInFight()
  return inFight
end

function ns.SetInFight(value)
  inFight = value
  ns.UpdateFishingAlert()
end

-- Blizzard's damage meter is cleared once per group the player joins (the
-- same call as its own "reset all sessions" menu entry). The game sends no
-- GROUP_JOINED on a login or /reload inside a group, so those keep the numbers.
-- GROUP_FORMED and GROUP_JOINED can both come for one group: its partyGUID
-- makes that one reset; without a readable GUID, one per JOIN_SAME_GROUP seconds.
local JOIN_SAME_GROUP = 2
local meterGroup, meterResetAt

function ns.GetResetMeterOnJoin()
  return db and db.resetMeterOnJoin and true or false
end

function ns.SetResetMeterOnJoin(value)
  db.resetMeterOnJoin = value and true or false
end

function ns.GetFlightTimes()
  return db and db.flightTimes and true or false
end

function ns.SetFlightTimes(value)
  ns.Flights.SetEnabled(value)
end

function ns.GetFlightBar()
  return db and db.flightBar and true or false
end

function ns.SetFlightBar(value)
  ns.Flights.SetBar(value)
end

function ns.GetFlightLanding()
  return db and db.flightLanding and true or false
end

function ns.SetFlightLanding(value)
  db.flightLanding = value and true or false
end

function ns.GetFlightBarUnknown()
  return db and db.flightBarUnknown and true or false
end

function ns.SetFlightBarUnknown(value)
  ns.Flights.SetBarUnknown(value)
end

function ns.GetCombatBanner()
  return db and db.combatBanner and true or false
end

function ns.SetCombatBanner(value)
  db.combatBanner = value and true or false
end

local function resetMeterOnJoin(partyGUID)
  local meter = type(C_DamageMeter) == "table" and C_DamageMeter or nil
  local reset = meter and meter.ResetAllCombatSessions
  if not db.resetMeterOnJoin or type(reset) ~= "function" then
    return
  end
  local group, now = ns.Util.str(partyGUID), ns.Util.num(ns.Util.call(GetTime))
  if group then
    if group == meterGroup then
      return
    end
  elseif meterGroup == nil and meterResetAt and now and now - meterResetAt < JOIN_SAME_GROUP then
    return
  end
  meterGroup, meterResetAt = group, now
  if pcall(reset) then
    print("|cff1e90ffisiStatsForever|r: " .. L.METER_RESET_DONE)
  end
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
ns.Print = out

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
  -- Through call() and plain checks: a secret value must not be concatenated.
  local level = ns.Util.num(ns.Util.call(UnitLevel, "player"))
  local class = ns.Util.str(ns.Util.call(UnitClass, "player"))
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
local BUFF_EVENTS = {
  UNIT_AURA = true,
  UNIT_LEVEL = true,
  PLAYER_LEVEL_UP = true,
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
    ns.Flights.Init(db)
    IsiStatsCharDB = IsiStatsCharDB or {}
    charDB = IsiStatsCharDB
    charDB.rows = charDB.rows or {}
    charDB.swings = nil -- left over from test builds that counted swings
    ns.LevelTime.Init(charDB)
    ns.Session.Init(charDB)
    ns.Buffs.Init(charDB)
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
    for e in pairs(ns.Flights.EVENTS) do
      pcall(self.RegisterEvent, self, e)
    end
    for e in pairs(ns.Session.EVENTS) do
      pcall(self.RegisterEvent, self, e)
    end
    for e in pairs(ns.Warnings.EVENTS) do
      if e ~= "UNIT_AURA" then -- registered for the player only, above
        pcall(self.RegisterEvent, self, e)
      end
    end
    for e, unit in pairs(ns.Warnings.UNIT_EVENTS) do
      pcall(self.RegisterUnitEvent, self, e, unit)
    end
    ns.Data.Prime()
    pcall(self.RegisterEvent, self, "LOADING_SCREEN_ENABLED")
    pcall(self.RegisterEvent, self, "GROUP_JOINED")
    pcall(self.RegisterEvent, self, "GROUP_FORMED")
    pcall(self.RegisterEvent, self, "ITEM_DATA_LOAD_RESULT")
    ns.Buffs.SetLoading(false)
    ns.Tracking.Schedule()
    ns.SetInFight(inCombat()) -- a reload during a fight
    ns.Warnings.Update() -- after the fight flag
    if db.combatMode ~= "always" then
      ns.ApplyCombatVisibility()
    elseif db.shown and not db.dock then
      ns.Show()
    end
    -- Played time for "time on this level"; the shown time ticks on.
    ns.LevelTime.Request()
    ns.LevelTime.Start()
    if type(C_Timer) == "table" and C_Timer.NewTicker then
      C_Timer.NewTicker(30, function()
        ns.RequestRefresh()
        ns.Warnings.Update() -- poisons and imbues run out without an event
      end)
    end
  else
    if event == "GROUP_JOINED" or event == "GROUP_FORMED" then
      resetMeterOnJoin(arg2)
      return
    elseif event == "ITEM_DATA_LOAD_RESULT" then
      ns.Warnings.OnItemLoaded(arg1)
      return
    end
    if event == "TIME_PLAYED_MSG" then
      ns.LevelTime.OnTimePlayed(arg1, arg2)
    elseif event == "PLAYER_LEVEL_UP" then
      ns.LevelTime.OnLevelUp()
    elseif event == "PLAYER_XP_UPDATE" then
      ns.LevelTime.OnXPUpdate()
    end
    if ns.Flights.EVENTS[event] then
      ns.Flights.OnEvent(event)
    end
    if ns.Session.EVENTS[event] then
      ns.Session.OnEvent(event, arg1)
    end
    if PRIME_EVENTS[event] then
      ns.Data.Prime()
    end
    if ns.Tracking.EVENTS[event] then
      ns.Tracking.Schedule()
    end
    if event == "LOADING_SCREEN_ENABLED" then
      ns.Buffs.SetLoading(true)
    elseif event == "LOADING_SCREEN_DISABLED" or event == "PLAYER_ENTERING_WORLD" then
      ns.Buffs.SetLoading(false)
    elseif BUFF_EVENTS[event] then
      ns.Buffs.Update()
    end
    if event == "PLAYER_EQUIPMENT_CHANGED" then
      ns.UpdateFishingAlert()
    end
    if event == "PLAYER_REGEN_DISABLED" then
      ns.SetInFight(true)
      if db.combatBanner then
        ns.UI.ShowCombatBanner(L.COMBAT_START, "bad")
      end
    elseif event == "PLAYER_REGEN_ENABLED" then
      ns.SetInFight(false)
      if db.combatBanner then
        ns.UI.ShowCombatBanner(L.COMBAT_END, "good")
      end
    end
    if ns.Warnings.EVENTS[event] or ns.Warnings.UNIT_EVENTS[event] then
      ns.Warnings.Update() -- after SetInFight
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
    local flights, flightNames, master = db.flights, db.flightNames, db.lastFlightMaster -- and the flight times
    IsiStatsDB = {}
    db = IsiStatsDB
    for k, v in pairs(DEFAULTS) do
      db[k] = type(v) == "table" and {} or v
    end
    db.errors = errors
    db.chatHistory = chatHistory
    db.flights, db.flightNames, db.lastFlightMaster = flights, flightNames, master
    ns.ErrorLog.Install(db)
    ns.Flights.Init(db)
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
  elseif cmd == "session" and arg == "reset" then
    ns.Session.Reset()
    ns.RequestRefresh()
    out(L.SESSION_RESET)
  elseif cmd == "flights" then
    if arg == "clear" then
      ns.Flights.Clear()
      out(L.FLIGHT_CLEARED)
    else
      ns.Flights.Print(out)
    end
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
