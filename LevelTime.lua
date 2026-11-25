local _, ns = ...

-- Played time on the current level (from the game's /played query) and the
-- estimated time to the next level.
--
-- The estimate uses the XP rate over the last WINDOW seconds of *active* play:
-- every XP gain advances an active clock by the time since the previous gain,
-- capped at IDLE_CAP, so hours spent idle (auction house, crafting, AFK) count
-- as a few minutes only and a fresh farming session shows its real pace after
-- a few kills. While nothing is gained the rate stays frozen at the last value.
-- The gains are kept per character (IsiStatsCharDB.xpRate), across level-ups
-- and relogs. Until the window has enough data, the average over this level
-- (XP on this level / played time on this level) is the fallback.
--
-- The game answers RequestTimePlayed() with TIME_PLAYED_MSG, which the chat
-- windows normally print. For the one automatic query at login the chat
-- windows stop listening to that event until the answer is in (no global
-- function is replaced, so nothing is tainted); a /played typed by the
-- player prints as usual.

local LevelTime = {}
ns.LevelTime = LevelTime

local MIN_SECONDS_FOR_ESTIMATE = 60 -- below this the XP rate is too noisy
local RESTORE_AFTER = 10 -- seconds; chat listens again even without an answer
local IDLE_CAP = 300 -- seconds; a longer gap between two XP gains counts as this
local WINDOW = 1800 -- seconds of active play the rate is taken from
local MIN_GAINS = 3 -- gains in the window before it replaces the level average
local MIN_ACTIVE = 300 -- seconds of active play in the window, same purpose

local levelSeconds -- played seconds on this level at `receivedAt`
local receivedAt -- GetTime() of the answer
local muted = {}

local rate -- IsiStatsCharDB.xpRate: { active = clock, gains = { { t, dt, xp } } }
local lastXP, lastMax -- UnitXP / UnitXPMax at the previous update
local lastGainAt -- GetTime() of the previous gain (or of the session start)

local function now()
  return type(GetTime) == "function" and GetTime() or 0
end

local function chatFrames()
  local frames = {}
  local count = ns.Util.chatWindowCount() or 0
  for i = 1, count do
    local frame = _G["ChatFrame" .. i]
    if type(frame) == "table" and frame.IsEventRegistered then
      frames[#frames + 1] = frame
    end
  end
  return frames
end

local function unmuteChat()
  for _, frame in ipairs(muted) do
    pcall(frame.RegisterEvent, frame, "TIME_PLAYED_MSG")
  end
  muted = {}
end

-- Asks the game for the played time without a chat line.
function LevelTime.Request()
  if type(RequestTimePlayed) ~= "function" then
    return
  end
  for _, frame in ipairs(chatFrames()) do
    local ok, registered = pcall(frame.IsEventRegistered, frame, "TIME_PLAYED_MSG")
    if ok and registered then
      pcall(frame.UnregisterEvent, frame, "TIME_PLAYED_MSG")
      muted[#muted + 1] = frame
    end
  end
  pcall(RequestTimePlayed)
  if type(C_Timer) == "table" and C_Timer.After then
    C_Timer.After(RESTORE_AFTER, unmuteChat)
  end
end

-- TIME_PLAYED_MSG: total, thisLevel (seconds).
function LevelTime.OnTimePlayed(_, thisLevel)
  if type(thisLevel) == "number" and not (type(issecretvalue) == "function" and issecretvalue(thisLevel)) then
    levelSeconds = thisLevel
    receivedAt = now()
  end
  if #muted > 0 and type(C_Timer) == "table" and C_Timer.After then
    C_Timer.After(0, unmuteChat) -- after every frame has seen this event
  end
end

-- A new level starts at zero.
function LevelTime.OnLevelUp()
  if levelSeconds then
    levelSeconds = 0
    receivedAt = now()
  end
end

-- Seconds played on this level, or nil until the game has answered.
function LevelTime.Seconds()
  if not levelSeconds then
    return nil
  end
  return levelSeconds + math.max(0, now() - receivedAt)
end

local function playerXP()
  local U = ns.Util
  return U.num(U.call(UnitXP, "player")), U.num(U.call(UnitXPMax, "player"))
end

-- ADDON_LOADED: the saved gains of this character.
function LevelTime.Init(charDB)
  if type(charDB.xpRate) ~= "table" or type(charDB.xpRate.gains) ~= "table" then
    charDB.xpRate = { active = 0, gains = {} }
  end
  rate = charDB.xpRate
  rate.active = type(rate.active) == "number" and rate.active or 0
end

-- PLAYER_LOGIN: the XP the next gain is measured from; the time up to the
-- first gain of the session counts like any other gap (capped).
function LevelTime.Start()
  lastXP, lastMax = playerXP()
  lastGainAt = now()
end

-- Drops gains that left the window.
local function trim()
  local gains, keep = rate.gains, {}
  for _, g in ipairs(gains) do
    if g[1] > rate.active - WINDOW then
      keep[#keep + 1] = g
    end
  end
  rate.gains = keep
end

-- PLAYER_XP_UPDATE: records the gain since the previous update. A lower XP
-- value than before means a level-up in between (the rest of the old level
-- plus the XP on the new one).
function LevelTime.OnXPUpdate()
  if not rate then
    return
  end
  local xp, max = playerXP()
  if not xp or not max or max <= 0 then
    return
  end
  local gain
  if lastXP then
    if xp > lastXP then
      gain = xp - lastXP
    elseif xp < lastXP and lastMax and lastMax > lastXP then
      gain = lastMax - lastXP + xp
    end
  end
  lastXP, lastMax = xp, max
  if not gain then
    return
  end
  local t = now()
  local dt = math.min(math.max(0, t - (lastGainAt or t)), IDLE_CAP)
  lastGainAt = t
  rate.active = rate.active + dt
  rate.gains[#rate.gains + 1] = { rate.active, dt, gain }
  trim()
end

-- XP per second over the window of active play, or nil while it has too few
-- gains or too little time in it.
function LevelTime.Rate()
  if not rate or #rate.gains < MIN_GAINS then
    return nil
  end
  local xp, span = 0, 0
  for _, g in ipairs(rate.gains) do
    span = span + g[2]
    xp = xp + g[3]
  end
  if span < MIN_ACTIVE or xp <= 0 then
    return nil
  end
  return xp / span
end

-- Estimated seconds to the next level and where the rate came from ("window"
-- or "level"), or nil when there is not enough data for either.
function LevelTime.Estimate(currentXP, remainingXP)
  local perSecond = LevelTime.Rate()
  if perSecond then
    return remainingXP / perSecond, "window"
  end
  local seconds = LevelTime.Seconds()
  if not seconds or seconds < MIN_SECONDS_FOR_ESTIMATE or not currentXP or currentXP <= 0 then
    return nil
  end
  return remainingXP / (currentXP / seconds), "level"
end

-- "2d 3h", "1h 23m", "45m" (days with the locale's day letter).
function LevelTime.Format(seconds)
  local L = ns.L
  seconds = math.floor(seconds + 0.5)
  local days = math.floor(seconds / 86400)
  local hours = math.floor(seconds % 86400 / 3600)
  local minutes = math.floor(seconds % 3600 / 60)
  if days > 0 then
    return string.format(L.DUR_DAYS_FMT, days, hours)
  elseif hours > 0 then
    return string.format("%dh %dm", hours, minutes)
  end
  return string.format("%dm", math.max(minutes, seconds > 0 and 1 or 0))
end
