local _, ns = ...
local L = ns.L

-- Collects the player's stats as a list of sections:
-- { key, title, rows = { { label, value, color, labelColor, tip } } }
-- Every API call is guarded: WoW Forever is a modern client with a classic
-- ruleset, so some classic APIs are missing and some modern ones return
-- secret values. A missing value simply hides its row.

local Data = {}
ns.Data = Data

-- ---------------------------------------------------------------- helpers

local function dropFirst(ok, ...)
  if not ok then
    return nil
  end
  return ...
end

local function call(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  return dropFirst(pcall(fn, ...))
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

local function hasShield()
  local classID, subclassID = itemTypeInSlot(SLOT_OFF)
  return classID == ARMOR_CLASS_ID and subclassID == SHIELD_SUBCLASS_ID
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

-- ---------------------------------------------------------------- row catalog

-- Every value has a stable ID; the settings page lists them by section and
-- the collector only emits the enabled ones (ns.IsRowEnabled).
function Data.GetCatalog()
  local function stat(i)
    return str(_G["SPELL_STAT" .. i .. "_NAME"]) or ("Stat " .. i)
  end
  local function resist(i)
    return str(_G["RESISTANCE" .. i .. "_NAME"]) or ("Resist " .. i)
  end
  return {
    {
      key = "base",
      title = L.BASE,
      rows = {
        { id = "stat1", label = stat(1) },
        { id = "stat2", label = stat(2) },
        { id = "stat3", label = stat(3) },
        { id = "stat4", label = stat(4) },
        { id = "stat5", label = stat(5) },
        { id = "health", label = L.HEALTH },
        { id = "mana", label = L.MANA },
      },
    },
    {
      key = "melee",
      title = L.MELEE,
      rows = {
        { id = "m_ap", label = L.ATTACK_POWER },
        { id = "m_dmg", label = L.DAMAGE },
        { id = "m_speed", label = L.SPEED },
        { id = "m_dps", label = L.DPS },
        { id = "m_crit", label = L.CRIT },
        { id = "m_hit", label = L.HIT },
        { id = "m_skill_mh", label = L.SKILL_MH },
        { id = "m_skill_oh", label = L.SKILL_OH },
        { id = "m_miss", label = L.MISS_VS_BOSS },
      },
    },
    {
      key = "ranged",
      title = L.RANGED,
      rows = {
        { id = "r_ap", label = L.ATTACK_POWER },
        { id = "r_dmg", label = L.DAMAGE },
        { id = "r_speed", label = L.SPEED },
        { id = "r_dps", label = L.DPS },
        { id = "r_crit", label = L.CRIT },
        { id = "r_hit", label = L.HIT },
        { id = "r_skill", label = L.SKILL_RANGED },
      },
    },
    {
      key = "spell",
      title = L.SPELL,
      rows = {
        { id = "s_dmg", label = L.SPELL_DAMAGE },
        { id = "s_heal", label = L.HEALING },
        { id = "s_crit", label = L.SPELL_CRIT },
        { id = "s_hit", label = L.SPELL_HIT },
        { id = "s_mp5", label = L.MP5 },
      },
    },
    {
      key = "defense",
      title = L.DEFENSE_SECTION,
      rows = {
        { id = "d_def", label = L.DEFENSE },
        { id = "d_missed", label = L.MISSED_BY },
        { id = "d_critred", label = L.CRIT_REDUCTION },
        { id = "d_armor", label = L.ARMOR },
        { id = "d_armordr", label = L.ARMOR_DR },
        { id = "d_dodge", label = L.DODGE },
        { id = "d_parry", label = L.PARRY },
        { id = "d_block", label = L.BLOCK },
        { id = "d_blockval", label = L.BLOCK_VALUE },
      },
    },
    {
      key = "skills",
      title = L.WEAPON_SKILLS,
      rows = {
        { id = "w_equipped", label = L.SKILLS_EQUIPPED },
        { id = "w_other", label = L.SKILLS_OTHER },
        { id = "w_vs", label = L.OPT_W_VS },
      },
    },
    {
      key = "target",
      title = L.TARGET_SECTION,
      rows = {
        { id = "t_info", label = L.OPT_T_INFO },
        { id = "t_hit", label = L.T_HIT },
        { id = "t_crit", label = L.T_CRIT },
        { id = "t_glance", label = L.T_GLANCE },
        { id = "t_boss", label = L.OPT_T_BOSS },
      },
    },
    {
      key = "resist",
      title = L.RESISTANCES,
      rows = {
        { id = "res2", label = resist(2) },
        { id = "res3", label = resist(3) },
        { id = "res4", label = resist(4) },
        { id = "res5", label = resist(5) },
        { id = "res6", label = resist(6) },
      },
    },
  }
end

-- Class defaults: main stat, the class's attack value, defense and the
-- skills of the equipped weapons. Everything else starts off.
local CLASS_DEFAULTS = {
  WARRIOR = { "stat1", "m_ap" },
  PALADIN = { "stat1", "m_ap" },
  ROGUE = { "stat2", "m_ap" },
  HUNTER = { "stat2", "r_ap" },
  SHAMAN = { "stat4", "s_dmg" },
  DRUID = { "stat4", "s_dmg" },
  PRIEST = { "stat4", "s_dmg" },
  MAGE = { "stat4", "s_dmg" },
  WARLOCK = { "stat4", "s_dmg" },
}
local COMMON_DEFAULTS = { "d_def", "w_equipped", "w_vs" }

function Data.GetDefaults()
  local defaults = {}
  local _, classToken = call(UnitClass, "player")
  for _, id in ipairs(CLASS_DEFAULTS[classToken] or { "stat1", "m_ap" }) do
    defaults[id] = true
  end
  for _, id in ipairs(COMMON_DEFAULTS) do
    defaults[id] = true
  end
  return defaults
end

-- ---------------------------------------------------------------- sections

local function enabled(id)
  return ns.IsRowEnabled == nil or ns.IsRowEnabled(id)
end

local function addRow(rows, id, label, value, color, tip, labelColor)
  if value == nil or not enabled(id) then
    return
  end
  rows[#rows + 1] = { label = label, value = value, color = color, tip = tip, labelColor = labelColor }
end

local function skillValueText(s)
  local total = s.rank + s.mod
  if s.mod ~= 0 then
    return string.format("%d |cff8a96a8(%d%s)|r", total, s.rank, signed(s.mod))
  end
  return tostring(total)
end

local function baseSection()
  local rows = {}
  for i = 1, 5 do
    local base, stat, pos, neg = call(UnitStat, "player", i)
    stat, base, pos, neg = num(stat), num(base), num(pos) or 0, num(neg) or 0
    if stat then
      local name = str(_G["SPELL_STAT" .. i .. "_NAME"]) or ("Stat " .. i)
      local tip = base and string.format(L.STAT_TIP, base, pos + neg) or nil
      addRow(rows, "stat" .. i, name, tostring(stat), buffColor(pos, neg), tip)
    end
  end
  local hp = num(call(UnitHealthMax, "player"))
  addRow(rows, "health", L.HEALTH, hp and tostring(hp))
  local mana = num(call(UnitPowerMax, "player", 0))
  if mana and mana > 0 then
    addRow(rows, "mana", L.MANA, tostring(mana))
  end
  return { key = "base", title = L.BASE, rows = rows }
end

local function meleeSection(level, skills, hit)
  local rows = {}
  local base, pos, neg = call(UnitAttackPower, "player")
  base, pos, neg = num(base), num(pos) or 0, num(neg) or 0
  if base then
    addRow(rows, "m_ap", L.ATTACK_POWER, tostring(base + pos + neg), buffColor(pos, neg))
  end

  local minD, maxD, minOff, maxOff = call(UnitDamage, "player")
  minD, maxD, minOff, maxOff = num(minD), num(maxD), num(minOff), num(maxOff)
  local speedMain, speedOff = call(UnitAttackSpeed, "player")
  speedMain, speedOff = num(speedMain), num(speedOff)
  local dualWield = speedOff and speedOff > 0 and minOff and maxOff and maxOff > 0

  if minD and maxD then
    local text = string.format("%d - %d", minD, maxD)
    if dualWield then
      text = text .. string.format(" |cff8a96a8/|r %d - %d", minOff, maxOff)
    end
    addRow(rows, "m_dmg", L.DAMAGE, text)
  end
  if speedMain and speedMain > 0 then
    local text = string.format("%.2f", speedMain)
    if dualWield then
      text = text .. string.format(" |cff8a96a8/|r %.2f", speedOff)
    end
    addRow(rows, "m_speed", L.SPEED, text)
    if minD and maxD then
      local dps = (minD + maxD) / 2 / speedMain
      if dualWield then
        dps = dps + (minOff + maxOff) / 2 / speedOff
      end
      addRow(rows, "m_dps", L.DPS, string.format("%.1f", dps))
    end
  end

  local crit = num(call(GetCritChance))
  addRow(rows, "m_crit", L.CRIT, crit and pct(crit))
  addRow(rows, "m_hit", L.HIT, pct(hit))

  -- Weapon skill of the equipped weapons.
  local mainSkillID = skillForSlot(SLOT_MAIN) or (not itemTypeInSlot(SLOT_MAIN) and SKILL.UNARMED) or nil
  local offSkillID = dualWield and skillForSlot(SLOT_OFF) or nil
  local mainSkill = mainSkillID and skills[mainSkillID]
  local offSkill = offSkillID and skills[offSkillID]

  -- Classic API fallback: UnitAttackBothHands gives base and modifier.
  local mhBase, mhMod, ohBase, ohMod = call(UnitAttackBothHands, "player")
  mhBase, mhMod, ohBase, ohMod = num(mhBase), num(mhMod) or 0, num(ohBase), num(ohMod) or 0
  if not mainSkill and mhBase and mhBase > 0 then
    mainSkill = { name = "", rank = mhBase, mod = mhMod }
  end
  if dualWield and not offSkill and ohBase and ohBase > 0 then
    offSkill = { name = "", rank = ohBase, mod = ohMod }
  end

  if mainSkill then
    local tip = mainSkill.name ~= "" and mainSkill.name or nil
    addRow(rows, "m_skill_mh", L.SKILL_MH, skillValueText(mainSkill), "accent", tip)
  end
  if offSkill then
    local tip = offSkill.name ~= "" and offSkill.name or nil
    addRow(rows, "m_skill_oh", L.SKILL_OH, skillValueText(offSkill), "accent", tip)
  end

  if mainSkill and level then
    local targetLevel = level + 3
    local targetDefense = targetLevel * 5
    local miss, missDW = missChance(mainSkill.rank + mainSkill.mod, targetDefense, hit)
    local tip = string.format(L.MISS_TIP, targetLevel, targetDefense)
    if dualWield then
      tip = tip .. "\n" .. string.format(L.MISS_DW, missDW)
    end
    local label = string.format(L.MISS_VS, targetLevel)
    addRow(rows, "m_miss", label, string.format("%.1f%%", miss), miss > 9 and "warn" or nil, tip)
  end

  return { key = "melee", title = L.MELEE, rows = rows }
end

local function rangedSection(skills, hit)
  if not itemTypeInSlot(SLOT_RANGED) then
    return nil
  end
  local rows = {}
  local skillID = skillForSlot(SLOT_RANGED)
  local isWand = skillID == SKILL.WANDS

  if not isWand then
    local base, pos, neg = call(UnitRangedAttackPower, "player")
    base, pos, neg = num(base), num(pos) or 0, num(neg) or 0
    if base then
      addRow(rows, "r_ap", L.ATTACK_POWER, tostring(base + pos + neg), buffColor(pos, neg))
    end
  end

  local speed, minD, maxD = call(UnitRangedDamage, "player")
  speed, minD, maxD = num(speed), num(minD), num(maxD)
  if minD and maxD and maxD > 0 then
    addRow(rows, "r_dmg", L.DAMAGE, string.format("%d - %d", minD, maxD))
  end
  if speed and speed > 0 then
    addRow(rows, "r_speed", L.SPEED, string.format("%.2f", speed))
    if minD and maxD and maxD > 0 then
      addRow(rows, "r_dps", L.DPS, string.format("%.1f", (minD + maxD) / 2 / speed))
    end
  end

  if not isWand then
    local crit = num(call(GetRangedCritChance))
    addRow(rows, "r_crit", L.CRIT, crit and pct(crit))
    addRow(rows, "r_hit", L.HIT, pct(hit))
  end

  local s = skillID and skills[skillID]
  if not s then
    local base, mod = call(UnitRangedAttack, "player")
    base, mod = num(base), num(mod) or 0
    if base and base > 0 then
      s = { name = "", rank = base, mod = mod }
    end
  end
  if s then
    addRow(rows, "r_skill", L.SKILL_RANGED, skillValueText(s), "accent", s.name ~= "" and s.name or nil)
  end

  return { key = "ranged", title = L.RANGED, rows = rows }
end

local SCHOOLS = { 2, 3, 4, 5, 6, 7 } -- holy, fire, nature, frost, shadow, arcane

local function spellSection()
  local mana = num(call(UnitPowerMax, "player", 0))
  if not mana or mana <= 0 then
    return nil
  end
  local rows = {}

  local best, tipLines = nil, {}
  for _, school in ipairs(SCHOOLS) do
    local v = num(call(GetSpellBonusDamage, school))
    if v then
      best = math.max(best or 0, v)
      local name = str(_G["DAMAGE_SCHOOL" .. school]) or ("School " .. school)
      tipLines[#tipLines + 1] = string.format(L.SCHOOL_TIP, name, v)
    end
  end
  local schoolTip = #tipLines > 0 and table.concat(tipLines, "\n") or nil
  addRow(rows, "s_dmg", L.SPELL_DAMAGE, best and tostring(best), nil, schoolTip)

  local heal = num(call(GetSpellBonusHealing))
  addRow(rows, "s_heal", L.HEALING, heal and tostring(heal))

  local crit
  for _, school in ipairs(SCHOOLS) do
    local v = num(call(GetSpellCritChance, school))
    if v then
      crit = math.max(crit or 0, v)
    end
  end
  addRow(rows, "s_crit", L.SPELL_CRIT, crit and pct(crit))

  local spellHit = num(call(GetSpellHitModifier))
  addRow(rows, "s_hit", L.SPELL_HIT, spellHit and pct(spellHit))

  local regenBase, regenCasting = call(GetManaRegen)
  regenBase, regenCasting = num(regenBase), num(regenCasting)
  if regenBase then
    local tip = string.format(L.MP5_TIP, regenBase * 5, (regenCasting or 0) * 5)
    addRow(rows, "s_mp5", L.MP5, string.format("%d", regenBase * 5), nil, tip)
  end

  return { key = "spell", title = L.SPELL, rows = rows }
end

local function defenseSection(level, skills)
  local rows = {}

  local def = skills[SKILL.DEFENSE]
  local defBase, defMod = call(UnitDefense, "player")
  defBase, defMod = num(defBase), num(defMod) or 0
  if not def and defBase and defBase > 0 then
    def = { name = DEFENSE or L.DEFENSE, rank = defBase, mod = defMod }
  end

  local attackerSkill = level and level * 5
  if def then
    local total = def.rank + def.mod
    local tip = attackerSkill and string.format(L.DEFENSE_TIP, attackerSkill) or nil
    addRow(rows, "d_def", L.DEFENSE, skillValueText(def), "accent", tip)
    if attackerSkill then
      local diff = total - attackerSkill
      addRow(rows, "d_missed", L.MISSED_BY, pct(math.max(0, 5 + diff * 0.04)), nil, tip)
      if diff > 0 then
        addRow(rows, "d_critred", L.CRIT_REDUCTION, pct(diff * 0.04), "good", tip)
      end
    end
  end

  local _, armor = call(UnitArmor, "player")
  armor = num(armor)
  if armor then
    addRow(rows, "d_armor", L.ARMOR, tostring(armor))
    if level then
      local dr = armorReduction(armor, level)
      local drBoss = armorReduction(armor, level + 3)
      local tip = string.format(L.ARMOR_DR_TIP, level, dr, level + 3, drBoss)
      addRow(rows, "d_armordr", L.ARMOR_DR, string.format("%.1f%%", dr), nil, tip)
    end
  end

  local dodge = num(call(GetDodgeChance))
  addRow(rows, "d_dodge", L.DODGE, dodge and pct(dodge))
  local parry = num(call(GetParryChance))
  if parry and parry > 0 then
    addRow(rows, "d_parry", L.PARRY, pct(parry))
  end
  if hasShield() then
    local block = num(call(GetBlockChance))
    addRow(rows, "d_block", L.BLOCK, block and pct(block))
    local blockValue = num(call(GetShieldBlock))
    if blockValue and blockValue > 0 then
      addRow(rows, "d_blockval", L.BLOCK_VALUE, tostring(blockValue))
    end
  end

  return { key = "defense", title = L.DEFENSE_SECTION, rows = rows }
end

-- ---------------------------------------------------------------- vs. target

local RAID_BOSS_LEVEL = 63

-- The current attackable target as { name, levelText, level, defense };
-- without one, an enemy of your own level (like the game's skill panel).
local function currentTarget(playerLevel)
  local exists = call(UnitExists, "target")
  local hostile = exists and call(UnitCanAttack, "player", "target")
  if exists == true and hostile == true then
    local name = str(call(UnitName, "target")) or L.TARGET
    local level = num(call(UnitLevel, "target"))
    local classification = str(call(UnitClassification, "target"))
    if classification == "worldboss" then
      return { name = name, levelText = "??", level = RAID_BOSS_LEVEL, defense = RAID_BOSS_LEVEL * 5 }
    end
    if level == -1 then
      local guess = playerLevel + 10
      return { name = name, levelText = "??", level = guess, defense = guess * 5 }
    end
    if level and level > 0 then
      return { name = name, levelText = tostring(level), level = level, defense = level * 5 }
    end
  end
  return { name = L.SAME_LEVEL, levelText = tostring(playerLevel), level = playerLevel, defense = playerLevel * 5 }
end

local RANGED_SKILLS = {
  [SKILL.BOWS] = true,
  [SKILL.GUNS] = true,
  [SKILL.CROSSBOWS] = true,
  [SKILL.THROWN] = true,
  [SKILL.WANDS] = true,
}

-- Tooltip for a weapon row: the full comparison against the target.
local function versusTip(foe, total, melee, playerLevel)
  local delta = (total - foe.defense) * SKILL_STEP
  local lines = {
    string.format("%s - " .. L.T_LEVEL_FMT, foe.name, foe.levelText, foe.defense),
    L.T_HIT .. ": " .. signedPct(delta),
    L.T_CRIT .. ": " .. signedPct(delta),
  }
  if melee and foe.level > playerLevel then
    local chance, reduction = glancing(total, foe.defense, playerLevel)
    lines[#lines + 1] = L.T_GLANCE .. ": " .. string.format(L.T_GLANCE_FMT, chance, reduction)
  end
  return table.concat(lines, "\n")
end

local function weaponSkillSection(skills, classicList, level)
  local showEquipped, showOther = enabled("w_equipped"), enabled("w_other")
  if not showEquipped and not showOther then
    return nil
  end
  local rows = {}
  local foe = level and enabled("w_vs") and currentTarget(level) or nil
  if foe then
    rows[1] = {
      label = foe.name,
      value = string.format(L.T_LEVEL_FMT, foe.levelText, foe.defense),
      labelColor = "heading",
      color = "dim",
      tip = L.W_VS_TIP,
    }
  end
  local equipped = {}
  for _, slot in ipairs({ SLOT_MAIN, SLOT_OFF, SLOT_RANGED }) do
    local id = skillForSlot(slot)
    if id then
      equipped[id] = true
    end
  end
  if not itemTypeInSlot(SLOT_MAIN) then
    equipped[SKILL.UNARMED] = true
  end

  local function add(s, isEquipped, id)
    if (isEquipped and not showEquipped) or (not isEquipped and not showOther) then
      return
    end
    local total = s.rank + s.mod
    local max = s.max and s.max > 0 and s.max or nil
    local value = max and string.format("%d / %d", s.rank, max) or tostring(s.rank)
    if s.mod ~= 0 then
      value = value .. " " .. signed(s.mod)
    end
    local color = (max and s.rank < max) and "warn" or nil
    local tip = isEquipped and L.EQUIPPED or nil
    if foe then
      value = value .. "  " .. signedPct((total - foe.defense) * SKILL_STEP)
      local vs = versusTip(foe, total, not RANGED_SKILLS[id], level)
      tip = tip and (tip .. "\n\n" .. vs) or vs
    end
    rows[#rows + 1] = {
      label = s.name,
      value = value,
      color = color,
      tip = tip,
      labelColor = isEquipped and "accent" or nil,
    }
  end

  local found = false
  for _, id in ipairs(WEAPON_SKILL_ORDER) do
    local s = skills[id]
    if s then
      found = true
      add(s, equipped[id], id)
    end
  end

  if not found and classicList then
    for _, s in ipairs(classicList) do
      if s.name ~= DEFENSE and s.rank > 0 then
        found = true
        add(s, false)
      end
    end
  end

  if not found then
    rows[1] = { label = L.NONE_KNOWN, value = "", labelColor = "dim" }
  end
  return { key = "skills", title = L.WEAPON_SKILLS, rows = rows }
end

-- Skills of the equipped weapons: { name, total, melee }, one per skill line.
local function equippedWeapons(skills)
  local list, seen = {}, {}
  local function add(id, melee)
    local s = id and skills[id]
    if s and not seen[id] then
      seen[id] = true
      list[#list + 1] = { name = s.name, total = s.rank + s.mod, melee = melee }
    end
  end
  add(skillForSlot(SLOT_MAIN) or (not itemTypeInSlot(SLOT_MAIN) and SKILL.UNARMED) or nil, true)
  add(skillForSlot(SLOT_OFF), true)
  add(skillForSlot(SLOT_RANGED), false)
  return list
end

local function addVersus(rows, weapons, foe, playerLevel)
  if enabled("t_info") then
    rows[#rows + 1] = {
      label = foe.name,
      value = string.format(L.T_LEVEL_FMT, foe.levelText, foe.defense),
      labelColor = "heading",
      color = "dim",
    }
  end
  local showHit, showCrit, showGlance = enabled("t_hit"), enabled("t_crit"), enabled("t_glance")
  if not (showHit or showCrit or showGlance) then
    return
  end
  for _, w in ipairs(weapons) do
    local delta = (w.total - foe.defense) * SKILL_STEP
    rows[#rows + 1] = { label = w.name, value = tostring(w.total), labelColor = "accent", color = "accent" }
    if showHit then
      rows[#rows + 1] = { label = "   " .. L.T_HIT, value = signedPct(delta), tip = L.T_HIT_TIP }
    end
    if showCrit then
      rows[#rows + 1] = { label = "   " .. L.T_CRIT, value = signedPct(delta), tip = L.T_CRIT_TIP }
    end
    if showGlance and w.melee and foe.level > playerLevel then
      local chance, reduction = glancing(w.total, foe.defense, playerLevel)
      rows[#rows + 1] = {
        label = "   " .. L.T_GLANCE,
        value = string.format(L.T_GLANCE_FMT, chance, reduction),
        color = chance >= 40 and "warn" or nil,
        tip = L.T_GLANCE_TIP,
      }
    end
  end
end

local function targetSection(level, skills)
  if not level then
    return nil
  end
  local weapons = equippedWeapons(skills)
  if #weapons == 0 then
    return nil
  end
  local rows = {}
  addVersus(rows, weapons, currentTarget(level), level)
  if enabled("t_boss") then
    local boss = { name = L.RAID_BOSS, levelText = "??", level = RAID_BOSS_LEVEL, defense = RAID_BOSS_LEVEL * 5 }
    addVersus(rows, weapons, boss, level)
  end
  return { key = "target", title = L.TARGET_SECTION, rows = rows }
end

local function resistanceSection()
  local rows = {}
  for i = 2, 6 do
    local _, total = call(UnitResistance, "player", i)
    total = num(total)
    if total then
      local name = str(_G["RESISTANCE" .. i .. "_NAME"]) or ("Resist " .. i)
      addRow(rows, "res" .. i, name, tostring(total), total == 0 and "dim" or nil)
    end
  end
  return { key = "resist", title = L.RESISTANCES, rows = rows }
end

-- ---------------------------------------------------------------- public

function Data.Collect()
  local level = num(call(UnitLevel, "player"))
  local hit = num(call(GetHitModifier)) or 0

  local skills = {}
  for _, id in ipairs(WEAPON_SKILL_ORDER) do
    skills[id] = Data.GetSkill(id)
  end
  skills[SKILL.DEFENSE] = Data.GetSkill(SKILL.DEFENSE)

  local classicList
  if not next(skills) then
    classicList = scanClassicWeaponSkills()
    if classicList then
      for _, s in ipairs(classicList) do
        if s.name == DEFENSE then
          skills[SKILL.DEFENSE] = s
        end
      end
    end
  end

  local sections = {}
  local function push(section)
    if section and #section.rows > 0 then
      sections[#sections + 1] = section
    end
  end
  push(baseSection())
  push(meleeSection(level, skills, hit))
  push(rangedSection(skills, hit))
  push(spellSection())
  push(defenseSection(level, skills))
  push(weaponSkillSection(skills, classicList, level))
  push(targetSection(level, skills))
  push(resistanceSection())

  if #sections == 0 then
    sections[1] =
      { key = "empty", title = "isiStats", rows = { { label = L.ALL_HIDDEN, value = "", labelColor = "dim" } } }
  end
  return sections
end

-- /isistats debug: raw skill info so field names can be checked in game.
function Data.DebugDump(print)
  local hasSkillInfo = type(C_SkillInfo) == "table"
  print(
    "C_SkillInfo:",
    type(C_SkillInfo),
    "GetSkillLineInfoByID:",
    hasSkillInfo and type(C_SkillInfo.GetSkillLineInfoByID)
  )
  print(
    "GetSkillLineInfo:",
    type(GetSkillLineInfo),
    "UnitDefense:",
    type(UnitDefense),
    "UnitAttackBothHands:",
    type(UnitAttackBothHands),
    "GetHitModifier:",
    type(GetHitModifier)
  )
  print("Settings:", type(Settings), "InterfaceOptions_AddCategory:", type(InterfaceOptions_AddCategory))
  local api = hasSkillInfo and C_SkillInfo.GetSkillLineInfoByID
  for _, id in ipairs({ SKILL.DEFENSE, skillForSlot(SLOT_MAIN) or SKILL.UNARMED }) do
    local info = api and call(api, id)
    if type(info) == "table" then
      local parts = {}
      for k, v in pairs(info) do
        parts[#parts + 1] = tostring(k) .. "=" .. tostring(v)
      end
      print("skill " .. id .. ": " .. table.concat(parts, ", "))
    else
      print("skill " .. id .. ": " .. tostring(info))
    end
  end
end
