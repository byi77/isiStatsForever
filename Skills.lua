local _, ns = ...
local Data = ns.Data
local U = ns.Util
local call, num, str = U.call, U.num, U.str

-- Skill lines, weapon slots and the equipped weapon types.
-- ---------------------------------------------------------------- skills

-- Skill line IDs (same in every client language).
local SKILL = {
  SWORDS = 43,
  AXES = 44,
  BOWS = 45,
  GUNS = 46,
  MACES = 54,
  SWORDS_2H = 55,
  DEFENSE = 95,
  STAVES = 136,
  MACES_2H = 160,
  UNARMED = 162,
  AXES_2H = 172,
  DAGGERS = 173,
  THROWN = 176,
  CROSSBOWS = 226,
  WANDS = 228,
  POLEARMS = 229,
  FIST = 473,
}
Data.SKILL = SKILL

local WEAPON_SKILL_ORDER = {
  SKILL.SWORDS,
  SKILL.SWORDS_2H,
  SKILL.AXES,
  SKILL.AXES_2H,
  SKILL.MACES,
  SKILL.MACES_2H,
  SKILL.POLEARMS,
  SKILL.STAVES,
  SKILL.DAGGERS,
  SKILL.FIST,
  SKILL.UNARMED,
  SKILL.BOWS,
  SKILL.GUNS,
  SKILL.CROSSBOWS,
  SKILL.THROWN,
  SKILL.WANDS,
}

-- Weapon item subclass -> skill line.
local SUBCLASS_SKILL = {
  [0] = SKILL.AXES,
  [1] = SKILL.AXES_2H,
  [2] = SKILL.BOWS,
  [3] = SKILL.GUNS,
  [4] = SKILL.MACES,
  [5] = SKILL.MACES_2H,
  [6] = SKILL.POLEARMS,
  [7] = SKILL.SWORDS,
  [8] = SKILL.SWORDS_2H,
  [10] = SKILL.STAVES,
  [13] = SKILL.FIST,
  [15] = SKILL.DAGGERS,
  [16] = SKILL.THROWN,
  [18] = SKILL.CROSSBOWS,
  [19] = SKILL.WANDS,
}

local WEAPON_CLASS_ID = 2
local ARMOR_CLASS_ID = 4
local SHIELD_SUBCLASS_ID = 6
local SLOT_MAIN, SLOT_OFF, SLOT_RANGED = 16, 17, 18

-- One skill by ID: { name, rank, max, mod } or nil when unknown.
function Data.GetSkill(id)
  local api = type(C_SkillInfo) == "table" and C_SkillInfo.GetSkillLineInfoByID
  local info = api and call(api, id)
  if type(info) ~= "table" then
    return nil
  end
  local rank = num(info.rank) or num(info.skillLineRank)
  if not rank or rank <= 0 then
    return nil
  end
  local mod = (num(info.modifier) or num(info.skillLineModifier) or 0) + (num(info.tempPoints) or 0)
  return {
    name = str(info.name) or str(info.skillLineDisplayName) or ("#" .. id),
    rank = rank,
    max = num(info.maxRank) or num(info.skillLineMaxRank),
    mod = mod,
  }
end

-- Fallback for clients with the classic skill list but without
-- C_SkillInfo: everything under the header that holds "Defense".
local function scanClassicWeaponSkills()
  if type(GetNumSkillLines) ~= "function" or type(GetSkillLineInfo) ~= "function" then
    return nil
  end
  local count = num(call(GetNumSkillLines)) or 0
  local groups, current = {}, nil
  for i = 1, count do
    local name, isHeader, _, rank, temp, mod, maxRank = call(GetSkillLineInfo, i)
    if isHeader then
      current = { skills = {} }
      groups[#groups + 1] = current
    elseif current and str(name) then
      current.skills[#current.skills + 1] = {
        name = name,
        rank = num(rank) or 0,
        max = num(maxRank),
        mod = (num(mod) or 0) + (num(temp) or 0),
      }
      if name == DEFENSE then
        current.hasDefense = true
      end
    end
  end
  for _, g in ipairs(groups) do
    if g.hasDefense then
      return g.skills
    end
  end
  return nil
end

local function itemTypeInSlot(slot)
  local itemID = num(call(GetInventoryItemID, "player", slot))
  if not itemID then
    return nil
  end
  local getInfo = (type(C_Item) == "table" and C_Item.GetItemInfoInstant) or GetItemInfoInstant
  local _, _, _, _, _, classID, subclassID = call(getInfo, itemID)
  return num(classID), num(subclassID)
end

local function skillForSlot(slot)
  local classID, subclassID = itemTypeInSlot(slot)
  if classID ~= WEAPON_CLASS_ID then
    return nil
  end
  return SUBCLASS_SKILL[subclassID]
end

-- Fishing pole: weapon class 2, subclass 20, in the main hand.
local FISHING_POLE_SUBCLASS_ID = 20

local function hasFishingPole()
  local classID, subclassID = itemTypeInSlot(SLOT_MAIN)
  return classID == WEAPON_CLASS_ID and subclassID == FISHING_POLE_SUBCLASS_ID
end

local function hasShield()
  local classID, subclassID = itemTypeInSlot(SLOT_OFF)
  return classID == ARMOR_CLASS_ID and subclassID == SHIELD_SUBCLASS_ID
end

ns.Skills = {
  SKILL = SKILL,
  WEAPON_SKILL_ORDER = WEAPON_SKILL_ORDER,
  SUBCLASS_SKILL = SUBCLASS_SKILL,
  SLOT_MAIN = SLOT_MAIN,
  SLOT_OFF = SLOT_OFF,
  SLOT_RANGED = SLOT_RANGED,
  itemTypeInSlot = itemTypeInSlot,
  skillForSlot = skillForSlot,
  hasShield = hasShield,
  hasFishingPole = hasFishingPole,
  scanClassicWeaponSkills = scanClassicWeaponSkills,
}
