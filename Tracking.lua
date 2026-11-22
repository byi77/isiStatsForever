local _, ns = ...
local L = ns.L
local Data = ns.Data
local U = ns.Util
local call, num, str, isSecret = U.call, U.num, U.str, U.isSecret

-- A text in the middle of the screen for as long as herbalism or mining is
-- learned and no gathering tracking is on. The game runs one tracking at a
-- time, so with both professions either one is enough.
local Tracking = {}
ns.Tracking = Tracking

-- Skill lines and the tracking spells, as in Blizzard's Minimap.lua.
local GATHERING = {
  { skill = 182, spells = { [2383] = true, [8387] = true } }, -- herbalism / Find Herbs
  { skill = 186, spells = { [2580] = true, [8388] = true } }, -- mining / Find Minerals
}
-- Before the text appears: switching casts a spell, and the list is empty for
-- a moment after login and loading screens. It goes away at once.
local CHECK_DELAY = 3

-- Events after which the state can differ.
Tracking.EVENTS = {
  MINIMAP_UPDATE_TRACKING = true,
  SPELLS_CHANGED = true,
  SKILL_LINES_CHANGED = true,
  LOADING_SCREEN_DISABLED = true,
  PLAYER_ENTERING_WORLD = true,
  PLAYER_REGEN_ENABLED = true,
  PLAYER_ALIVE = true,
  PLAYER_UNGHOST = true,
}

local checkRun = 0

-- "none": no gathering profession. "on". "off", plus the names of the
-- trackings that could be on. "unknown": the game does not say (no guessing).
function Tracking.State()
  local wanted, learned = {}, false
  for _, gathering in ipairs(GATHERING) do
    if Data.GetSkill(gathering.skill) then
      learned = true
      for spellID in pairs(gathering.spells) do
        wanted[spellID] = true
      end
    end
  end
  if not learned then
    return "none"
  end

  local api = type(C_Minimap) == "table" and C_Minimap or {}
  local count = num(call(api.GetNumTrackingTypes))
  if not count then
    return "unknown"
  end
  local names = {}
  for index = 1, count do
    local info = call(api.GetTrackingInfo, index)
    if isSecret(info) then
      return "unknown"
    end
    if type(info) == "table" then
      local spellID, active = info.spellID, info.active
      if isSecret(spellID) or isSecret(active) then
        return "unknown"
      end
      if spellID and wanted[spellID] then
        if active then
          return "on"
        end
        names[#names + 1] = str(info.name)
      end
    end
  end
  if #names == 0 then
    return "unknown" -- the list is not loaded yet
  end
  return "off", table.concat(names, " / ")
end

-- Shows or hides the text for the state right now. "unknown" leaves it as it
-- is: a loading screen or a hidden value says nothing about the tracking.
function Tracking.Update()
  local state, names = Tracking.State()
  if state == "on" or state == "none" or not ns.IsRowEnabled("warn_tracking") then
    ns.UI.SetAlert("tracking", nil)
  elseif state == "off" then
    ns.UI.SetAlert("tracking", string.format(L.WARN_TRACKING_FMT, names))
  end
end

function Tracking.Schedule()
  if Tracking.State() == "on" then
    ns.UI.SetAlert("tracking", nil) -- no delay when it is switched on
  end
  if type(C_Timer) ~= "table" or not C_Timer.After then
    return
  end
  checkRun = checkRun + 1
  local run = checkRun
  C_Timer.After(CHECK_DELAY, function()
    if run == checkRun then
      Tracking.Update()
    end
  end)
end
