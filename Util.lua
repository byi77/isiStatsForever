local _, ns = ...

-- Shared helpers: guarded API calls, secret-value handling, formatting and
-- the skill/defense formulas (sources in CLAUDE.md).

ns.Data = ns.Data or {}

-- ---------------------------------------------------------------- helpers

local function dropFirst(ok, ...)
  if not ok then
    return nil
  end
  return ...
end

-- API functions that returned a secret value (in combat the client hides
-- some values from addons); listed by /isistats debug.
local secretFns = {}

local function noteSecrets(fn, ...)
  if type(issecretvalue) == "function" then
    for i = 1, select("#", ...) do
      if issecretvalue((select(i, ...))) then
        secretFns[fn] = true
        break
      end
    end
  end
  return ...
end

local function call(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  return noteSecrets(fn, dropFirst(pcall(fn, ...)))
end

local function isSecret(v)
  return type(issecretvalue) == "function" and issecretvalue(v) or false
end

-- Display text for a single API value. A secret value (in combat) cannot be
-- compared or used in arithmetic, but string.format turns it into a secret
-- string that a FontString can still show - the same way isiLive's stats box
-- shows stats in restricted content. Returns nil for anything else.
local function show(raw, fmt)
  if raw == nil then
    return nil
  end
  if isSecret(raw) then
    local ok, text = pcall(string.format, fmt, raw)
    return ok and text or nil
  end
  if type(raw) ~= "number" then
    return nil
  end
  return string.format(fmt, raw)
end

local function num(v)
  if v == nil then
    return nil
  end
  if type(issecretvalue) == "function" and issecretvalue(v) then
    return nil
  end
  if type(v) ~= "number" then
    return nil
  end
  return v
end

-- "Is there any?" for values whose row only shows when > 0 (mana, parry,
-- block value). A hidden value cannot be compared, so the last plain answer
-- from outside combat decides.
local known = {}

local function positive(key, raw)
  local v = num(raw)
  if v then
    known[key] = v > 0
    return known[key]
  end
  return isSecret(raw) and known[key] == true
end

local function str(v)
  if v == nil then
    return nil
  end
  if type(issecretvalue) == "function" and issecretvalue(v) then
    return nil
  end
  if type(v) ~= "string" or v == "" then
    return nil
  end
  return v
end

local function pct(v)
  return string.format("%.2f%%", v)
end

local function signed(v)
  if v > 0 then
    return "|cff73d973+" .. v .. "|r"
  elseif v < 0 then
    return "|cffff6b61" .. v .. "|r"
  end
  return ""
end

local function buffColor(pos, neg)
  if neg and neg < 0 then
    return "bad"
  elseif pos and pos > 0 then
    return "good"
  end
  return nil
end

-- ---------------------------------------------------------------- formulas (from the game)

-- The WoW Forever skill panel (SkillsFrame.lua) rates every point between
-- weapon skill and target defense at 0.04% for hit, dodge, parry and crit.
local SKILL_STEP = 0.04
-- The game's tooltips, against your level and against a raid boss:
-- miss CR_*_HIT_CAP_TOOLTIP, dodge and parry CR_EXPERTISE_TOOLTIP.
local SAME_LEVEL = { miss = 5, dodge = 5, parry = 5 }
local RAID_BOSS = { miss = 8, dodge = 6.5, parry = 16.5 }
local BOSS_GAP = 15 -- three levels: the gap the boss values already contain
local DUAL_WIELD_MISS = 19

local function clamp(v)
  return math.max(0, math.min(100, v))
end

local function baseChance(kind, skill, defense, boss)
  local gap = defense - skill
  if boss then
    return RAID_BOSS[kind] + (gap - BOSS_GAP) * SKILL_STEP
  end
  return SAME_LEVEL[kind] + gap * SKILL_STEP
end

local function missChance(skill, defense, hit, boss, dual)
  return clamp(baseChance("miss", skill, defense, boss) + (dual and DUAL_WIELD_MISS or 0) - hit)
end

-- Dodge and parry of the target; expertise (percent) lowers each of them.
local function avoidChance(skill, defense, expertise, boss)
  return clamp(baseChance("dodge", skill, defense, boss) - expertise),
    clamp(baseChance("parry", skill, defense, boss) - expertise)
end

-- Glancing blows from the game itself, as in the skill panel: chance and
-- damage penalty in percent. The game hides them in combat, so the answers
-- from outside combat are kept per skill and defense.
local knownGlancing = {}

local function glancing(skill, defense)
  local key = skill .. ":" .. defense
  local chance = num(call(GetGlancingBlowChance, skill, defense))
  local penalty = num(call(GetGlancingBlowPenalty, skill, defense))
  if chance and penalty then
    knownGlancing[key] = { chance * 100, penalty * 100 }
  end
  local cached = knownGlancing[key]
  if cached then
    return cached[1], cached[2]
  end
  return nil
end

local function signedPct(v)
  local text = string.format("%+.2f%%", v)
  if v < 0 then
    return "|cffff6b61" .. text .. "|r"
  elseif v > 0 then
    return "|cff73d973" .. text .. "|r"
  end
  return text
end

-- Number of chat windows. Constants.ChatFrameConstants.MaxChatWindows is the
-- client constant; NUM_CHAT_WINDOWS only exists as a Blizzard_DeprecatedChatInfo
-- shim (cvar loadDeprecationFallbacks). Neither present: nil, nothing guessed.
local function chatWindowCount()
  local constants = type(Constants) == "table" and Constants.ChatFrameConstants
  local count = type(constants) == "table" and num(constants.MaxChatWindows)
  if count and count > 0 then
    return count
  end
  count = num(NUM_CHAT_WINDOWS)
  return count and count > 0 and count or nil
end

local function armorReduction(armor, attackerLevel)
  local dr = armor / (armor + 400 + 85 * attackerLevel)
  return math.min(0.75, math.max(0, dr)) * 100
end

ns.Util = {
  secretFns = secretFns,
  call = call,
  isSecret = isSecret,
  show = show,
  num = num,
  positive = positive,
  str = str,
  pct = pct,
  signed = signed,
  buffColor = buffColor,
  SKILL_STEP = SKILL_STEP,
  missChance = missChance,
  avoidChance = avoidChance,
  glancing = glancing,
  signedPct = signedPct,
  armorReduction = armorReduction,
  chatWindowCount = chatWindowCount,
}
