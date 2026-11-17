local _, ns = ...

-- Played time on the current level (from the game's /played query) and the
-- estimated time to the next level from the XP rate on this level.
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

local levelSeconds -- played seconds on this level at `receivedAt`
local receivedAt -- GetTime() of the answer
local muted = {}

local function now()
  return type(GetTime) == "function" and GetTime() or 0
end

local function chatFrames()
  local frames = {}
  local count = type(NUM_CHAT_WINDOWS) == "number" and NUM_CHAT_WINDOWS or 10
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

-- Estimated seconds to the next level from the XP rate on this level, or nil
-- when there is not enough data (no XP yet or under a minute).
function LevelTime.Estimate(currentXP, remainingXP)
  local seconds = LevelTime.Seconds()
  if not seconds or seconds < MIN_SECONDS_FOR_ESTIMATE or not currentXP or currentXP <= 0 then
    return nil
  end
  return remainingXP / (currentXP / seconds)
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
