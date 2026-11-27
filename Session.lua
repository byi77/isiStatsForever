local _, ns = ...
local U = ns.Util
local call, num, isSecret = U.call, U.num, U.isSecret

-- Session values since the login (kept across /reload, started again on a
-- real login or by /isistats session reset): played time, XP, gold and kills
-- that gave XP. Also the XP of the recent kills, for "kills to the next level".
--
-- A kill is a CHAT_MSG_COMBAT_XP_GAIN event (its text is not read: it may be
-- secret in combat); the XP of that kill is the gain of the PLAYER_XP_UPDATE
-- that comes with it, whichever of the two arrives first.
local Session = {}
ns.Session = Session

local PAIR_WINDOW = 1 -- s: a kill message and an XP gain this close belong together
local KILL_SAMPLES = 20 -- recent kills the average is taken from
local MIN_KILLS = 3 -- fewer: no estimate

local charDB
local killAt -- GetTime() of a kill message still waiting for its XP gain
local lastGain, lastGainAt -- an XP gain still waiting for a kill message
local killGains = {}

Session.EVENTS = {
  PLAYER_ENTERING_WORLD = true,
  PLAYER_MONEY = true,
  CHAT_MSG_COMBAT_XP_GAIN = true,
}

local function money()
  local v = call(GetMoney)
  return not isSecret(v) and num(v) or nil
end

function Session.Reset()
  charDB.session = { start = time(), money = money(), xp = 0, kills = 0 }
  killGains = {}
  killAt, lastGain, lastGainAt = nil, nil, nil
end

function Session.Init(saved)
  charDB = saved
  if type(charDB.session) ~= "table" then
    Session.Reset()
  end
end

local function addKillGain(gain)
  killGains[#killGains + 1] = gain
  if #killGains > KILL_SAMPLES then
    table.remove(killGains, 1)
  end
end

-- From LevelTime.OnXPUpdate: one plain XP gain.
function Session.OnXPGain(gain)
  local s = charDB and charDB.session
  if not s then
    return
  end
  s.xp = s.xp + gain
  local t = GetTime()
  if killAt and t - killAt <= PAIR_WINDOW then
    addKillGain(gain)
    killAt = nil
  else
    lastGain, lastGainAt = gain, t
  end
end

function Session.OnEvent(event, isInitialLogin)
  local s = charDB and charDB.session
  if event == "PLAYER_ENTERING_WORLD" then
    if isInitialLogin == true then
      Session.Reset()
    elseif s and s.money == nil then
      s.money = money()
    end
  elseif event == "CHAT_MSG_COMBAT_XP_GAIN" and s then
    s.kills = s.kills + 1
    local t = GetTime()
    if lastGain and t - lastGainAt <= PAIR_WINDOW then
      addKillGain(lastGain)
      lastGain = nil
    else
      killAt = t
    end
  end
end

-- Kills still needed for remainingXP from the recent kills' average, or nil.
function Session.KillsToLevel(remainingXP)
  if #killGains < MIN_KILLS or not remainingXP then
    return nil
  end
  local sum = 0
  for _, g in ipairs(killGains) do
    sum = sum + g
  end
  local average = sum / #killGains
  return average > 0 and math.ceil(remainingXP / average) or nil, average
end

-- { seconds, xp, gold (copper, may be negative), kills } or nil.
function Session.Values()
  local s = charDB and charDB.session
  if not s then
    return nil
  end
  local now = money()
  return {
    seconds = math.max(0, time() - (s.start or time())),
    xp = s.xp or 0,
    gold = now and s.money and (now - s.money) or nil,
    kills = s.kills or 0,
  }
end

-- "+1g 23s 4c" / "-56s"
function Session.FormatMoney(copper)
  local sign = copper < 0 and "-" or "+"
  copper = math.abs(copper)
  local g, s, c = math.floor(copper / 10000), math.floor(copper % 10000 / 100), copper % 100
  local parts = {}
  if g > 0 then
    parts[#parts + 1] = g .. "|cffffd700g|r"
  end
  if s > 0 or g > 0 then
    parts[#parts + 1] = s .. "|cffc7c7cfs|r"
  end
  parts[#parts + 1] = c .. "|cffeda55fc|r"
  return sign .. table.concat(parts, " ")
end
