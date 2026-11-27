local _, ns = ...
local L = ns.L
local U = ns.Util
local call, num, str, isSecret = U.call, U.num, U.str, U.isSecret

-- Flight times, measured by this game install: taking a flight at a flight
-- master notes where from and where to (the game's flight point IDs), the
-- flight starts when the character is on the taxi and ends when it is off it
-- again. Only whole flights are kept: an early landing, a loading screen or a
-- /reload on the way drops the measurement. Saved account-wide per faction in
-- IsiStatsDB.flights[faction][fromID][toID] = seconds (the last flight counts),
-- the names in IsiStatsDB.flightNames[nodeID]. Nothing comes from elsewhere.
local Flights = {}
ns.Flights = Flights

local START_WINDOW = 10 -- s: the taxi has to start this soon after the click
local MIN_SECONDS = 5 -- shorter: not a real flight

local db
local pending -- { from, to, at } from the click
local flight -- { from, to, start } while on the taxi
local opened -- nodesBySlot() of the open flight map (read when it opens)

Flights.EVENTS = {
  TAXIMAP_OPENED = true,
  PLAYER_CONTROL_LOST = true,
  PLAYER_CONTROL_GAINED = true,
  PLAYER_LEAVING_WORLD = true,
}

local function onTaxi()
  local v = call(UnitOnTaxi, "player")
  return not isSecret(v) and v == true
end

local function faction()
  return str(call(UnitFactionGroup, "player"))
end

-- The flight map's nodes by slot: { nodeID, name, current }.
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

local function remember(node)
  if node.name then
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
  return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end
Flights.Clock = clock

-- After TakeTaxiNode(slot): the click on a flight point.
function Flights.OnTakeTaxi(slot)
  if not (db and db.flightTimes) then
    return
  end
  local bySlot, current = nodesBySlot()
  if not (current and bySlot[num(slot) or -1]) and opened then
    bySlot, current = opened.bySlot, opened.current -- the map may be closed already
  end
  local target = bySlot[num(slot) or -1]
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
  end
end

function Flights.OnEvent(event)
  if event == "TAXIMAP_OPENED" then
    local bySlot, current = nodesBySlot()
    opened = { bySlot = bySlot, current = current }
  elseif event == "PLAYER_CONTROL_LOST" then
    if pending and GetTime() - pending.at <= START_WINDOW and onTaxi() then
      flight = { from = pending.from, to = pending.to, start = GetTime() }
    end
    pending = nil
  elseif event == "PLAYER_CONTROL_GAINED" then
    local done = flight
    if not done or onTaxi() then
      return
    end
    flight = nil
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
  elseif event == "PLAYER_LEAVING_WORLD" then
    pending, flight = nil, nil
  end
end

-- An early landing is not the whole route.
function Flights.Abort()
  pending, flight = nil, nil
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
  end
  -- a /reload on the way: no start time, so no measurement
  pending, flight = nil, nil
end

function Flights.SetEnabled(value)
  db.flightTimes = value and true or false
  if not db.flightTimes then
    pending, flight = nil, nil
  end
end
