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
local SKILL_IDLE_CAP = 300 -- s: a longer gap between two skill-ups counts as this
local SKILL_SAMPLES = 10 -- recent skill-ups the pace is taken from
local MIN_SKILL_UPS = 3 -- fewer: no estimate
local GOLD_RATE_MIN = 600 -- s of session before gold per hour is shown
local KILL_SAMPLES = 20 -- recent kills the average is taken from
local MIN_KILLS = 3 -- fewer: no estimate

local charDB
local killAt -- GetTime() of a kill message still waiting for its XP gain
local lastGain, lastGainAt -- an XP gain still waiting for a kill message
local killGains = {}
-- Weapon skill-ups of this session (not saved): id -> { rank, at, ups = { { dt, gain } } }
local skillSeen = {}
local merchantCost -- repair costs at the open vendor, nil without one

Session.EVENTS = {
  PLAYER_ENTERING_WORLD = true,
  PLAYER_MONEY = true,
  CHAT_MSG_COMBAT_XP_GAIN = true,
  SKILL_LINES_CHANGED = true,
  PLAYER_REGEN_ENABLED = true, -- skill ranks may be hidden in combat: catch up
  PLAYER_DEAD = true,
  MERCHANT_SHOW = true, -- dispatched by Core before its repair line
  MERCHANT_CLOSED = true,
  UPDATE_INVENTORY_DURABILITY = true,
}

local function money()
  local v = call(GetMoney)
  return not isSecret(v) and num(v) or nil
end

function Session.Reset()
  charDB.session = { start = time(), money = money(), xp = 0, kills = 0, killXP = 0, deaths = 0, repairs = 0 }
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
    s.killXP = (s.killXP or 0) + gain
    killAt = nil
  else
    lastGain, lastGainAt = gain, t
  end
end

-- Weapon skill ranks now: a higher rank than before is a skill-up, with the
-- active time since the previous one (capped like the XP rate).
function Session.OnSkillsChanged()
  local t = type(GetTime) == "function" and GetTime() or 0
  for _, id in ipairs(ns.Skills.WEAPON_SKILL_ORDER) do
    local s = ns.Data.GetSkill(id)
    local seen = skillSeen[id]
    if s and seen and s.rank > seen.rank then
      local ups = seen.ups
      ups[#ups + 1] = { math.min(math.max(0, t - seen.at), SKILL_IDLE_CAP), s.rank - seen.rank }
      if #ups > SKILL_SAMPLES then
        table.remove(ups, 1)
      end
      seen.rank, seen.at = s.rank, t
    elseif s and (not seen or s.rank < seen.rank) then
      skillSeen[id] = { rank = s.rank, at = t, ups = {} }
    end
  end
end

-- Seconds until the skill reaches max at the pace of its recent skill-ups, or nil.
function Session.SkillEta(id, rank, max)
  local seen = skillSeen[id]
  if not (seen and max and rank < max) or #seen.ups < MIN_SKILL_UPS then
    return nil
  end
  local dt, gain = 0, 0
  for _, u in ipairs(seen.ups) do
    dt, gain = dt + u[1], gain + u[2]
  end
  return dt > 0 and gain > 0 and (max - rank) * dt / gain or nil
end

-- Repair costs at the open vendor, or nil.
local function repairCost()
  if not merchantCost and call(CanMerchantRepair) ~= true then
    return nil
  end
  local cost = call(GetRepairAllCost)
  return not isSecret(cost) and num(cost) or nil
end

function Session.OnEvent(event, isInitialLogin)
  local s = charDB and charDB.session
  if event == "PLAYER_DEAD" and s then
    s.deaths = (s.deaths or 0) + 1
  elseif event == "MERCHANT_SHOW" then
    merchantCost = repairCost()
  elseif event == "MERCHANT_CLOSED" then
    merchantCost = nil
  elseif event == "UPDATE_INVENTORY_DURABILITY" and merchantCost and s then
    -- repaired at the vendor: the costs went down by what was paid
    local now = repairCost()
    if now and now < merchantCost then
      s.repairs = (s.repairs or 0) + merchantCost - now
    end
    merchantCost = now or merchantCost
  elseif event == "SKILL_LINES_CHANGED" or event == "PLAYER_REGEN_ENABLED" then
    Session.OnSkillsChanged()
  elseif event == "PLAYER_ENTERING_WORLD" then
    if isInitialLogin == true then
      Session.Reset()
    elseif s and s.money == nil then
      s.money = money()
    end
    Session.OnSkillsChanged()
  elseif event == "CHAT_MSG_COMBAT_XP_GAIN" and s then
    s.kills = s.kills + 1
    local t = GetTime()
    if lastGain and t - lastGainAt <= PAIR_WINDOW then
      addKillGain(lastGain)
      s.killXP = (s.killXP or 0) + lastGain
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
    killXP = s.killXP or 0,
    deaths = s.deaths or 0,
    repairs = s.repairs or 0,
  }
end

-- Gold won or spent per hour (copper), once the session is GOLD_RATE_MIN old.
function Session.GoldPerHour(v)
  if not (v and v.gold) or v.seconds < GOLD_RATE_MIN then
    return nil
  end
  return math.floor(v.gold * 3600 / v.seconds + 0.5)
end

-- "+1g 23s 4c" / "-56s"; unsigned: no "+".
function Session.FormatMoney(copper, unsigned)
  local sign = copper < 0 and "-" or (unsigned and "" or "+")
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
