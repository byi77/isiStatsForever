local _, ns = ...
local L = ns.L
local Data = ns.Data
local U = ns.Util
local call = U.call
local isSecret = U.isSecret
local show = U.show
local num = U.num
local positive = U.positive
local str = U.str
local pct = U.pct
local signed = U.signed
local buffColor = U.buffColor
local SKILL_STEP = U.SKILL_STEP
local missChance = U.missChance
local glancing = U.glancing
local signedPct = U.signedPct
local armorReduction = U.armorReduction
local K = ns.Skills
local SKILL = K.SKILL
local WEAPON_SKILL_ORDER = K.WEAPON_SKILL_ORDER
local SLOT_MAIN = K.SLOT_MAIN
local SLOT_OFF = K.SLOT_OFF
local SLOT_RANGED = K.SLOT_RANGED
local itemTypeInSlot = K.itemTypeInSlot
local skillForSlot = K.skillForSlot
local hasShield = K.hasShield
local scanClassicWeaponSkills = K.scanClassicWeaponSkills

-- Collects the shown values as sections of rows (see Catalog.lua for the ids).
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

  -- The defense skill itself is listed with the weapon skills (current / max);
  -- here only the values derived from it.
  local def = skills[SKILL.DEFENSE]
  local attackerSkill = level and level * 5
  if def then
    local total = def.rank + def.mod
    local tip = attackerSkill and string.format(L.DEFENSE_TIP, attackerSkill) or nil
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
  local showDefense = enabled("d_def") and skills[SKILL.DEFENSE] ~= nil
  if not showEquipped and not showOther and not showDefense then
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
    -- current / max stays at the right edge; the +/- values go in front.
    local value = max and string.format("%d / %d", s.rank, max) or tostring(s.rank)
    if s.mod ~= 0 then
      value = signed(s.mod) .. " " .. value
    end
    local color = (max and s.rank < max) and "warn" or nil
    local tip = isEquipped and L.EQUIPPED or nil
    if foe and not foe.unknownDefense then
      value = signedPct((total - foe.defense) * SKILL_STEP) .. "  " .. value
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

  if not found and (showEquipped or showOther) then
    rows[#rows + 1] = { label = L.NONE_KNOWN, value = "", labelColor = "dim" }
  end

  -- Defense below the weapons, as current / max like the game's skill panel.
  if showDefense then
    local def = skills[SKILL.DEFENSE]
    local max = def.max and def.max > 0 and def.max or nil
    local value = max and string.format("%d / %d", def.rank, max) or tostring(def.rank)
    if def.mod ~= 0 then
      value = signed(def.mod) .. " " .. value
    end
    rows[#rows + 1] = {
      key = "d_def",
      label = L.DEFENSE,
      value = value,
      color = (max and def.rank < max) and "warn" or nil,
      tip = level and string.format(L.DEFENSE_TIP, level * 5) or nil,
    }
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

  -- Classic API fallback for the defense skill.
  if not skills[SKILL.DEFENSE] then
    local defBase, defMod = call(UnitDefense, "player")
    defBase, defMod = num(defBase), num(defMod) or 0
    if defBase and defBase > 0 then
      skills[SKILL.DEFENSE] = { name = DEFENSE or L.DEFENSE, rank = defBase, mod = defMod }
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
