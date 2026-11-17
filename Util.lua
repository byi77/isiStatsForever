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

-- ---------------------------------------------------------------- formulas (classic)

-- Miss chance of a special attack against a target with `defense`,
-- classic rules: +0.1% per point of difference, +0.2% once the gap is
-- larger than 10, and 1% of hit is lost against such targets.
-- The WoW Forever skill panel rates every point between weapon skill and
-- target defense at 0.04% (hit and crit), at any gap; that panel is the
-- reference here.
local SKILL_STEP = 0.04

local function missChance(skill, defense, hit)
  local miss = 5 + (defense - skill) * SKILL_STEP
  return math.max(0, miss - hit), math.max(0, miss + 19 - hit)
end

-- Glancing blows (classic): chance from the defense gap to the capped skill,
-- damage from the gap to the real skill. Matches the game panel
-- (skill 203 vs. 315: 100% glancing, 89% less damage).
local function glancing(skill, defense, playerLevel)
  local cappedSkill = math.min(skill, playerLevel * 5)
  local chance = math.max(0, math.min(100, 10 + (defense - cappedSkill) * 2))
  local diff = defense - skill
  local low = math.max(0.01, math.min(0.91, 1.3 - 0.05 * diff))
  local high = math.max(0.2, math.min(0.99, 1.2 - 0.03 * diff))
  local reduction = (1 - (low + high) / 2) * 100
  return chance, math.floor(reduction)
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
  glancing = glancing,
  signedPct = signedPct,
  armorReduction = armorReduction,
}
