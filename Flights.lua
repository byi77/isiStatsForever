local _, ns = ...
local L = ns.L
local U = ns.Util
local call, num, str, isSecret = U.call, U.num, U.str, U.isSecret

-- Flight times, measured by this game install: taking a flight at a flight
-- master notes where from and where to (the game's flight point IDs), the
-- flight starts when the character is on the taxi and ends when it is off it
-- again. Only whole flights are kept: an early landing, a summon, a battleground
-- or dungeon finder port, a loading screen or a /reload on the way drops the
-- measurement. Saved account-wide per faction in
-- IsiStatsDB.flights[faction][fromID][toID] = seconds (the last flight counts),
-- the names in IsiStatsDB.flightNames[nodeID]. Nothing comes from elsewhere.
--
-- A route never flown as a whole but made of hops whose times are all saved
-- gets an estimate: the sum of those saved times (user decision 2026-11-27),
-- always marked with "~" and never saved as a measured time.
--
-- Shown: the time in the flight map tooltip of every flight point, and while on
-- the taxi a bar (UI.lua): filling for a known or estimated time, counting up
-- for an unknown one (own setting).
local Flights = {}
ns.Flights = Flights

local START_WINDOW = 10 -- s: the taxi has to start this soon after the click
local MIN_SECONDS = 5 -- shorter: not a real flight

local db
local pending -- { from, to, at, estimate } from the click
local flight -- { from, to, start, estimate } while on the taxi
local opened -- { bySlot, current } of the open flight map (read when it opens)
local hookedButtons = setmetatable({}, { __mode = "k" })

Flights.EVENTS = {
  TAXIMAP_OPENED = true,
  PLAYER_CONTROL_LOST = true,
  PLAYER_CONTROL_GAINED = true,
  PLAYER_LEAVING_WORLD = true,
  LFG_PROPOSAL_SUCCEEDED = true,
}

local function onTaxi()
  local v = call(UnitOnTaxi, "player")
  return not isSecret(v) and v == true
end

local function faction()
  return str(call(UnitFactionGroup, "player"))
end

-- The flight map's nodes by slot: { id, name }, and the one the character is at.
local function nodesBySlot()
  local mapID = num(call(GetTaxiMapID))
  local api = type(C_TaxiMap) == "table" and C_TaxiMap or {}
  local list = mapID and call(api.GetAllTaxiNodes, mapID)
  local bySlot, current = {}, nil
  if type(list) ~= "table" or isSecret(list) then
    return bySlot, current
  end
  local state = type(Enum) == "table" and Enum.FlightPathState or {}
  for _, info in ipairs(list) do
    local id, slot = type(info) == "table" and num(info.nodeID), type(info) == "table" and num(info.slotIndex)
    if id and slot then
      local node = { id = id, name = str(info.name) }
      bySlot[slot] = node
      if state.Current ~= nil and info.state == state.Current then
        current = node
      end
    end
  end
  return bySlot, current
end

local function mapNodes()
  local bySlot, current = nodesBySlot()
  if not current and opened then
    return opened.bySlot, opened.current -- the map may be closed already
  end
  return bySlot, current
end

local function remember(node)
  if node and node.name then
    db.flightNames[node.id] = node.name
  end
end

function Flights.Name(id)
  return db and db.flightNames[id] or ("#" .. tostring(id))
end

function Flights.Get(fromID, toID)
  local list = db and db.flights[faction() or ""]
  return list and list[fromID] and list[fromID][toID] or nil
end

local function clock(seconds)
  seconds = math.floor(seconds + 0.5)
  return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end
Flights.Clock = clock

-- Estimate for the route to `slot` from its hops (the game's own route): the
-- shortest chain of saved times from start to destination along the hops.
-- nil when the game has no hops for it or a part has no saved time.
function Flights.Estimate(slot, bySlot, current)
  local hops = num(call(GetNumRoutes, slot))
  local target = bySlot[slot]
  if not (hops and hops >= 2 and current and target) then
    return nil
  end
  local chain = { current.id }
  for hop = 2, hops do
    local hopSlot = num(call(TaxiGetNodeSlot, slot, hop, true))
    local node = hopSlot and bySlot[hopSlot]
    if not node then
      return nil
    end
    chain[#chain + 1] = node.id
  end
  chain[#chain + 1] = target.id
  local best = { [1] = 0 }
  for j = 2, #chain do
    for i = 1, j - 1 do
      local t = best[i] and Flights.Get(chain[i], chain[j])
      if t and (not best[j] or best[i] + t < best[j]) then
        best[j] = best[i] + t
      end
    end
  end
  return best[#chain]
end

-- Known time or estimate for a flight point of the open map.
local function timeFor(slot)
  local bySlot, current = mapNodes()
  local target = bySlot[slot]
  if not (current and target) or current.id == target.id then
    return nil
  end
  local known = Flights.Get(current.id, target.id)
  if known then
    return known, false
  end
  local estimate = Flights.Estimate(slot, bySlot, current)
  if estimate then
    return estimate, true
  end
  return nil, nil
end

-- ---------------------------------------------------------------- flight map tooltip

local function addTooltipLine(slot)
  if not (db and db.flightTimes) or type(GameTooltip) ~= "table" or not slot then
    return
  end
  local seconds, estimated = timeFor(slot)
  if estimated == nil and seconds == nil then
    local bySlot, current = mapNodes()
    if not (current and bySlot[slot]) or current.id == bySlot[slot].id then
      return -- the point the character is at, or not a flight point of this map
    end
    GameTooltip:AddLine(L.FLIGHT_TIP_UNKNOWN, 0.6, 0.6, 0.6)
  elseif estimated then
    GameTooltip:AddLine(string.format(L.FLIGHT_TIP_ESTIMATE_FMT, clock(seconds)), 1, 1, 1)
  else
    GameTooltip:AddLine(string.format(L.FLIGHT_TIP_FMT, clock(seconds)), 1, 1, 1)
  end
  GameTooltip:Show()
end

-- Classic taxi frame: TaxiButton<slot>.
local function onTaxiButtonEnter(button)
  addTooltipLine(num(call(button.GetID, button)))
end

-- Flight map pins carry their node data.
local function onPinEnter(pin)
  local data = type(pin.taxiNodeData) == "table" and pin.taxiNodeData or nil
  addTooltipLine(data and num(data.slotIndex))
end

local function hookButton(button, fn)
  if type(button) == "table" and not hookedButtons[button] and button.HookScript then
    hookedButtons[button] = true
    button:HookScript("OnEnter", fn)
  end
end

function Flights.HookMap()
  for slot in pairs(opened and opened.bySlot or {}) do
    hookButton(_G["TaxiButton" .. slot], onTaxiButtonEnter)
  end
  local map = _G.FlightMapFrame
  local pool = type(map) == "table" and type(map.pinPools) == "table" and map.pinPools.FlightMap_FlightPointPinTemplate
  if type(pool) == "table" and pool.EnumerateActive then
    for pin in pool:EnumerateActive() do
      hookButton(pin, onPinEnter)
    end
  end
end

-- ---------------------------------------------------------------- flights

-- After TakeTaxiNode(slot): the click on a flight point.
function Flights.OnTakeTaxi(slot)
  slot = num(slot)
  if not (db and db.flightTimes and slot) then
    return
  end
  local bySlot, current = mapNodes()
  local target = bySlot[slot]
  if not (current and target) or current.id == target.id then
    pending = nil
    return
  end
  remember(current)
  remember(target)
  pending = { from = current.id, to = target.id, at = GetTime() }
  local known = Flights.Get(current.id, target.id)
  if known then
    ns.Print(string.format(L.FLIGHT_KNOWN_FMT, Flights.Name(target.id), clock(known)))
  else
    pending.estimate = Flights.Estimate(slot, bySlot, current)
  end
end

local function showBar()
  if not (flight and db.flightBar) then
    ns.UI.HideFlightBar()
    return
  end
  local name = string.format(L.FLIGHT_ROUTE_FMT, Flights.Name(flight.from), Flights.Name(flight.to))
  local known = Flights.Get(flight.from, flight.to)
  if known then
    ns.UI.ShowFlightBar(name, known, flight.start, "known")
  elseif flight.estimate then
    ns.UI.ShowFlightBar(name, flight.estimate, flight.start, "estimate")
  elseif db.flightBarUnknown then
    ns.UI.ShowFlightBar(name, nil, flight.start, "unknown")
  else
    ns.UI.HideFlightBar()
  end
end

function Flights.OnEvent(event)
  if event == "TAXIMAP_OPENED" then
    local bySlot, current = nodesBySlot()
    opened = { bySlot = bySlot, current = current }
    -- pins are placed after the event
    if type(C_Timer) == "table" and C_Timer.After then
      C_Timer.After(0, Flights.HookMap)
    end
    Flights.HookMap()
  elseif event == "PLAYER_CONTROL_LOST" then
    if pending and GetTime() - pending.at <= START_WINDOW and onTaxi() then
      flight = { from = pending.from, to = pending.to, start = GetTime(), estimate = pending.estimate }
      showBar()
    end
    pending = nil
  elseif event == "PLAYER_CONTROL_GAINED" then
    local done = flight
    if not done or onTaxi() then
      return
    end
    flight = nil
    ns.UI.HideFlightBar()
    local seconds = math.floor(GetTime() - done.start + 0.5)
    local side = faction()
    if not (db and db.flightTimes and side) or seconds < MIN_SECONDS then
      return
    end
    db.flights[side] = db.flights[side] or {}
    local list = db.flights[side]
    list[done.from] = list[done.from] or {}
    list[done.from][done.to] = seconds
    ns.Print(string.format(L.FLIGHT_SAVED_FMT, Flights.Name(done.from), Flights.Name(done.to), clock(seconds)))
  elseif event == "PLAYER_LEAVING_WORLD" or event == "LFG_PROPOSAL_SUCCEEDED" then
    Flights.Abort()
  end
end

-- An early landing, a summon or a port: not the whole route.
function Flights.Abort()
  pending, flight = nil, nil
  ns.UI.HideFlightBar()
end

function Flights.Count()
  local n = 0
  for _, list in pairs(db and db.flights or {}) do
    for _, targets in pairs(list) do
      for _ in pairs(targets) do
        n = n + 1
      end
    end
  end
  return n
end

-- /isistats flights: the saved times of this faction, by start.
function Flights.Print(out)
  local side = faction()
  local list = side and db.flights[side]
  local lines = {}
  for fromID, targets in pairs(list or {}) do
    for toID, seconds in pairs(targets) do
      lines[#lines + 1] = string.format("%s -> %s: %s", Flights.Name(fromID), Flights.Name(toID), clock(seconds))
    end
  end
  table.sort(lines)
  if #lines == 0 then
    out(L.FLIGHT_NONE)
    return
  end
  out(string.format(L.FLIGHT_LIST_FMT, #lines))
  for _, line in ipairs(lines) do
    out(line)
  end
end

function Flights.Clear()
  db.flights, db.flightNames = {}, {}
end

function Flights.Init(saved)
  db = saved
  db.flights = type(db.flights) == "table" and db.flights or {}
  db.flightNames = type(db.flightNames) == "table" and db.flightNames or {}
  if type(hooksecurefunc) == "function" then
    if type(TakeTaxiNode) == "function" then
      hooksecurefunc("TakeTaxiNode", Flights.OnTakeTaxi)
    end
    if type(TaxiRequestEarlyLanding) == "function" then
      hooksecurefunc("TaxiRequestEarlyLanding", Flights.Abort)
    end
    if type(C_SummonInfo) == "table" and type(C_SummonInfo.ConfirmSummon) == "function" then
      hooksecurefunc(C_SummonInfo, "ConfirmSummon", Flights.Abort)
    end
    if type(AcceptBattlefieldPort) == "function" then
      hooksecurefunc("AcceptBattlefieldPort", function(_, accept)
        if accept then
          Flights.Abort()
        end
      end)
    end
  end
  -- a /reload on the way: no start time, so no measurement
  pending, flight = nil, nil
end

function Flights.SetEnabled(value)
  db.flightTimes = value and true or false
  if not db.flightTimes then
    Flights.Abort()
  end
end

function Flights.SetBar(value)
  db.flightBar = value and true or false
  showBar()
end

function Flights.SetBarUnknown(value)
  db.flightBarUnknown = value and true or false
  showBar()
end
