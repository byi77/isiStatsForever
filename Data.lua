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

-- Class defaults: main stat, the class's attack value and weapon damage
-- (spell damage for casters), defense and the skills of the equipped weapons. Everything else starts off.
local CLASS_DEFAULTS = {
  WARRIOR = { "stat1", "m_ap", "m_dmg" },
  PALADIN = { "stat1", "m_ap", "m_dmg" },
  ROGUE = { "stat2", "m_ap", "m_dmg" },
  HUNTER = { "stat2", "r_ap", "r_dmg" },
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
  rows[#rows + 1] = { key = id, label = label, value = value, color = color, tip = tip, labelColor = labelColor }
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
    local base, rawStat, pos, neg = call(UnitStat, "player", i)
    local stat
    stat, base, pos, neg = num(rawStat), num(base), num(pos) or 0, num(neg) or 0
    local name = str(_G["SPELL_STAT" .. i .. "_NAME"]) or ("Stat " .. i)
    if stat then
      local tip = base and string.format(L.STAT_TIP, base, pos + neg) or nil
      addRow(rows, "stat" .. i, name, tostring(stat), buffColor(pos, neg), tip)
    elseif isSecret(rawStat) then
      addRow(rows, "stat" .. i, name, show(rawStat, "%d"))
    end
  end
  addRow(rows, "health", L.HEALTH, show(call(UnitHealthMax, "player"), "%d"))
  local rawMana = call(UnitPowerMax, "player", 0)
  if positive("mana", rawMana) then
    addRow(rows, "mana", L.MANA, show(rawMana, "%d"))
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

  addRow(rows, "m_crit", L.CRIT, show(call(GetCritChance), "%.2f%%"))
  addRow(rows, "m_hit", L.HIT, hit and pct(hit) or show(call(GetHitModifier), "%.2f%%"))

  -- Main-hand weapon skill for the miss chance (the skills themselves are
  -- listed under weapon skills).
  local mainSkillID = skillForSlot(SLOT_MAIN) or (not itemTypeInSlot(SLOT_MAIN) and SKILL.UNARMED) or nil
  local mainSkill = mainSkillID and skills[mainSkillID]

  -- Classic API fallback: UnitAttackBothHands gives base and modifier.
  local mhBase, mhMod = call(UnitAttackBothHands, "player")
  mhBase, mhMod = num(mhBase), num(mhMod) or 0
  if not mainSkill and mhBase and mhBase > 0 then
    mainSkill = { name = "", rank = mhBase, mod = mhMod }
  end

  if mainSkill and level and hit then
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

local function rangedSection(hit)
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
    addRow(rows, "r_crit", L.CRIT, show(call(GetRangedCritChance), "%.2f%%"))
    addRow(rows, "r_hit", L.HIT, hit and pct(hit) or show(call(GetHitModifier), "%.2f%%"))
  end

  return { key = "ranged", title = L.RANGED, rows = rows }
end

local SCHOOLS = { 2, 3, 4, 5, 6, 7 } -- holy, fire, nature, frost, shadow, arcane

local function spellSection()
  if not positive("mana", call(UnitPowerMax, "player", 0)) then
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

  addRow(rows, "s_heal", L.HEALING, show(call(GetSpellBonusHealing), "%d"))

  -- Highest school crit; while hidden (no comparing) the first school's value.
  local crit, secretCrit
  for _, school in ipairs(SCHOOLS) do
    local raw = call(GetSpellCritChance, school)
    local v = num(raw)
    if v then
      crit = math.max(crit or 0, v)
    elseif secretCrit == nil and isSecret(raw) then
      secretCrit = raw
    end
  end
  addRow(rows, "s_crit", L.SPELL_CRIT, crit and pct(crit) or show(secretCrit, "%.2f%%"))

  addRow(rows, "s_hit", L.SPELL_HIT, show(call(GetSpellHitModifier), "%.2f%%"))

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

  local _, rawArmor = call(UnitArmor, "player")
  local armor = num(rawArmor)
  if not armor and isSecret(rawArmor) then
    addRow(rows, "d_armor", L.ARMOR, show(rawArmor, "%d"))
  end
  if armor then
    addRow(rows, "d_armor", L.ARMOR, tostring(armor))
    if level then
      local dr = armorReduction(armor, level)
      local drBoss = armorReduction(armor, level + 3)
      local tip = string.format(L.ARMOR_DR_TIP, level, dr, level + 3, drBoss)
      addRow(rows, "d_armordr", L.ARMOR_DR, string.format("%.1f%%", dr), nil, tip)
    end
  end

  addRow(rows, "d_dodge", L.DODGE, show(call(GetDodgeChance), "%.2f%%"))
  local rawParry = call(GetParryChance)
  if positive("parry", rawParry) then
    addRow(rows, "d_parry", L.PARRY, show(rawParry, "%.2f%%"))
  end
  if hasShield() then
    addRow(rows, "d_block", L.BLOCK, show(call(GetBlockChance), "%.2f%%"))
    local rawBlockValue = call(GetShieldBlock)
    if positive("blockValue", rawBlockValue) then
      addRow(rows, "d_blockval", L.BLOCK_VALUE, show(rawBlockValue, "%d"))
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
  if isSecret(exists) then
    return { unknown = true }
  end
  local hostile = exists and call(UnitCanAttack, "player", "target")
  if isSecret(hostile) then
    return { unknown = true }
  end
  if exists == true and hostile == true then
    local name = str(call(UnitName, "target")) or L.TARGET
    local rawLevel = call(UnitLevel, "target")
    if isSecret(rawLevel) then
      return { unknown = true }
    end
    local level = num(rawLevel)
    local classification = str(call(UnitClassification, "target"))
    if classification == "worldboss" then
      return { name = name, levelText = "??", level = RAID_BOSS_LEVEL, defense = RAID_BOSS_LEVEL * 5 }
    end
    if level == -1 then
      -- Level ?? (not a world boss): its defense is unknown; nothing is
      -- computed against it (no guessing).
      return { name = name, levelText = "??", unknownDefense = true }
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
  local foeHidden = foe and foe.unknown
  if foeHidden then
    foe = nil
  end
  if foe then
    rows[1] = {
      key = "w_vs_target",
      label = foe.name,
      value = foe.unknownDefense and L.T_LEVEL_UNKNOWN or string.format(L.T_LEVEL_FMT, foe.levelText, foe.defense),
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
    if foe and not foe.unknownDefense then
      value = value .. "  " .. signedPct((total - foe.defense) * SKILL_STEP)
      local vs = versusTip(foe, total, not RANGED_SKILLS[id], level)
      tip = tip and (tip .. "\n\n" .. vs) or vs
    end
    rows[#rows + 1] = {
      key = "w:" .. s.name,
      partial = foeHidden or nil,
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
    rows[#rows + 1] = { label = L.NONE_KNOWN, value = "", labelColor = "dim" }
  end
  return { key = "skills", title = L.WEAPON_SKILLS, rows = rows }
end

local function resistanceSection()
  local rows = {}
  for i = 2, 6 do
    local _, rawTotal = call(UnitResistance, "player", i)
    local total = num(rawTotal)
    local name = str(_G["RESISTANCE" .. i .. "_NAME"]) or ("Resist " .. i)
    if total then
      addRow(rows, "res" .. i, name, tostring(total), total == 0 and "dim" or nil)
    elseif isSecret(rawTotal) then
      addRow(rows, "res" .. i, name, show(rawTotal, "%d"))
    end
  end
  return { key = "resist", title = L.RESISTANCES, rows = rows }
end

-- ---------------------------------------------------------------- public

function Data.Collect()
  local level = num(call(UnitLevel, "player"))
  local hit = num(call(GetHitModifier))
  if hit == nil and type(GetHitModifier) ~= "function" then
    hit = 0
  end

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
  push(rangedSection(hit))
  push(spellSection())
  push(defenseSection(level, skills))
  push(weaponSkillSection(skills, classicList, level))
  push(resistanceSection())

  if #sections == 0 then
    sections[1] =
      { key = "empty", title = "isiStats", rows = { { label = L.ALL_HIDDEN, value = "", labelColor = "dim" } } }
  end
  return Data.ApplyCombatCache(sections)
end

-- ---------------------------------------------------------------- combat cache

-- In combat the client hides some values (secret values). Out of combat the
-- full result is kept; in combat every row or section that is missing (or
-- only partly known) is filled with its last value from before the fight,
-- greyed out. Rows are matched by their key.
local lastSnapshot

local function stripColors(text)
  return (tostring(text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function staleCopy(row)
  return {
    key = row.key,
    label = row.label,
    value = stripColors(row.value),
    labelColor = "dim",
    color = "dim",
    tip = L.STALE_TIP .. (row.tip and ("\n\n" .. row.tip) or ""),
    stale = true,
  }
end

local function mergeRows(current, previous)
  local byKey, prevKeys = {}, {}
  for _, r in ipairs(previous) do
    if r.key then
      prevKeys[r.key] = true
    end
  end
  for _, r in ipairs(current) do
    if r.key and not r.partial then
      byKey[r.key] = r
    end
  end
  local out, used = {}, {}
  for _, p in ipairs(previous) do
    local c = p.key and byKey[p.key]
    if c then
      out[#out + 1] = c
      used[c] = true
    elseif p.key then
      out[#out + 1] = staleCopy(p)
    end
  end
  for _, r in ipairs(current) do
    if not used[r] and not (r.partial and r.key and prevKeys[r.key]) and not (r.key == nil and #out > 0) then
      out[#out + 1] = r
    end
  end
  return out
end

function Data.ApplyCombatCache(sections)
  local inCombat = type(InCombatLockdown) == "function" and InCombatLockdown()
  if not inCombat then
    lastSnapshot = sections
    return sections
  end
  if not lastSnapshot then
    return sections
  end
  local currentByKey = {}
  for _, s in ipairs(sections) do
    currentByKey[s.key] = s
  end
  local out, used = {}, {}
  for _, prev in ipairs(lastSnapshot) do
    local cur = currentByKey[prev.key]
    if cur then
      out[#out + 1] = { key = cur.key, title = cur.title, rows = mergeRows(cur.rows, prev.rows) }
      used[prev.key] = true
    elseif prev.key ~= "empty" then
      out[#out + 1] = { key = prev.key, title = prev.title, rows = mergeRows({}, prev.rows) }
    end
  end
  for _, s in ipairs(sections) do
    if not used[s.key] and s.key ~= "empty" then
      out[#out + 1] = s
    end
  end
  return out
end

-- Names of the API functions that returned secret values so far.
function Data.SecretApiNames()
  local names = {}
  for k, v in pairs(_G) do
    if type(v) == "function" and secretFns[v] then
      names[#names + 1] = k
    elseif type(v) == "table" and type(k) == "string" and k:match("^C_") then
      for k2, v2 in pairs(v) do
        if type(v2) == "function" and secretFns[v2] then
          names[#names + 1] = k .. "." .. tostring(k2)
        end
      end
    end
  end
  table.sort(names)
  return names
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
  local secret = Data.SecretApiNames()
  print("secret in combat:", #secret > 0 and table.concat(secret, ", ") or "-")
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
