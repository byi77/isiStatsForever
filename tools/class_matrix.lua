---@diagnostic disable: undefined-global
-- Runs in standalone Lua (io, os, loadfile), not in the WoW client.
-- Class matrix: loads the real addon once per class (typical gear, power
-- type and weapon skills) and checks what the window shows - with the class
-- defaults and with every value switched on. Exit 1 on any failure.
-- Usage: lua tools/class_matrix.lua <addon dir> [deDE|enUS]
local dir = arg[1] or "."
local clientLocale = arg[2] or "deDE"

local SKILL_NAMES = {
  [43] = "Schwerter",
  [44] = "Äxte",
  [45] = "Bogen",
  [46] = "Schusswaffen",
  [54] = "Streitkolben",
  [55] = "Zweihandschwerter",
  [95] = "Verteidigung",
  [136] = "Stäbe",
  [160] = "Zweihandstreitkolben",
  [162] = "Unbewaffnet",
  [172] = "Zweihandäxte",
  [173] = "Dolche",
  [176] = "Wurfwaffen",
  [226] = "Armbrüste",
  [228] = "Zauberstäbe",
  [229] = "Stangenwaffen",
}

-- Item subclasses (weapon class 2) and the shield (armor class 4, subclass 6).
local AXE_2H, BOW, MACE, SWORD, SWORD_2H, STAFF, DAGGER, THROWN, WAND = 1, 2, 4, 7, 8, 10, 15, 16, 19
local SHIELD = "shield"

-- main/off/ranged gear, mana user, known skill lines, expected default rows.
local CLASSES = {
  WARRIOR = {
    gear = { SWORD, SHIELD, THROWN },
    mana = false,
    skills = { 43, 44, 54, 55, 173, 176, 45, 162, 95 },
    mainStat = 1,
    attack = "melee",
  },
  PALADIN = {
    gear = { SWORD_2H },
    mana = true,
    skills = { 43, 55, 54, 160, 162, 95 },
    mainStat = 1,
    attack = "melee",
  },
  ROGUE = {
    gear = { SWORD, DAGGER, THROWN },
    mana = false,
    skills = { 43, 173, 54, 176, 45, 162, 95 },
    mainStat = 2,
    attack = "melee",
  },
  HUNTER = {
    gear = { AXE_2H, nil, BOW },
    mana = true,
    skills = { 44, 172, 45, 46, 173, 229, 162, 95 },
    mainStat = 2,
    attack = "ranged",
  },
  SHAMAN = {
    gear = { MACE, SHIELD },
    mana = true,
    skills = { 54, 136, 173, 162, 95 },
    mainStat = 4,
    attack = "spell",
  },
  DRUID = { gear = { STAFF }, mana = true, skills = { 136, 54, 173, 162, 95 }, mainStat = 4, attack = "spell" },
  PRIEST = {
    gear = { MACE, nil, WAND },
    mana = true,
    skills = { 54, 136, 173, 228, 162, 95 },
    mainStat = 4,
    attack = "spell",
  },
  MAGE = {
    gear = { STAFF, nil, WAND },
    mana = true,
    skills = { 136, 43, 173, 228, 162, 95 },
    mainStat = 4,
    attack = "spell",
  },
  WARLOCK = {
    gear = { DAGGER, nil, WAND },
    mana = true,
    skills = { 173, 43, 136, 228, 162, 95 },
    mainStat = 4,
    attack = "spell",
  },
}
local ORDER = { "WARRIOR", "PALADIN", "ROGUE", "HUNTER", "SHAMAN", "DRUID", "PRIEST", "MAGE", "WARLOCK" }

local SUBCLASS_SKILL = {
  [AXE_2H] = 172,
  [BOW] = 45,
  [MACE] = 54,
  [SWORD] = 43,
  [SWORD_2H] = 55,
  [STAFF] = 136,
  [DAGGER] = 173,
  [THROWN] = 176,
  [WAND] = 228,
}
-- Every weapon type (item subclass) and its skill line.
local ALL_SUBCLASS_SKILL = {
  [0] = 44,
  [1] = 172,
  [2] = 45,
  [3] = 46,
  [4] = 54,
  [5] = 160,
  [6] = 229,
  [7] = 43,
  [8] = 55,
  [10] = 136,
  [13] = 162,
  [15] = 173,
  [16] = 176,
  [18] = 226,
  [19] = 228,
}
local RANGED_SUBCLASS = { [2] = true, [3] = true, [16] = true, [18] = true, [19] = true }

-- Weapon types each class can use in WoW Forever. Source: the WhatsTraining
-- addon's weapon skill table, which treats Forever as Classic Era
-- ("Forever shares Era's weapon masters"). Wands are not trained at a weapon
-- master and so are not in that table; they are the priest, mage and warlock
-- ranged weapon.
local USABLE = {
  WARRIOR = { 0, 1, 4, 5, 6, 7, 8, 10, 2, 3, 15, 16, 18, 13 },
  PALADIN = { 0, 1, 4, 5, 6, 7, 8 },
  HUNTER = { 0, 1, 6, 7, 8, 10, 2, 3, 15, 16, 18, 13 },
  ROGUE = { 4, 7, 2, 3, 15, 16, 18, 13 },
  PRIEST = { 4, 10, 15, 19 },
  SHAMAN = { 0, 4, 10, 15, 13 },
  DRUID = { 4, 5, 6, 10, 15, 13 },
  MAGE = { 7, 10, 15, 19 },
  WARLOCK = { 7, 10, 15, 19 },
}

local RANGED_SKILL = { [45] = true, [46] = true, [176] = true, [226] = true, [228] = true }

local failures = 0
local function check(cond, msg)
  if not cond then
    failures = failures + 1
    print("  FAIL " .. msg)
  end
end

local function setupFor(token, spec, gearOverride, skillsOverride)
  local gear = gearOverride or spec.gear
  local skillList = skillsOverride or spec.skills
  return function()
    UnitClass = function()
      return token, token
    end
    SPELL_STAT1_NAME, SPELL_STAT2_NAME, SPELL_STAT3_NAME = "Stärke", "Beweglichkeit", "Ausdauer"
    SPELL_STAT4_NAME, SPELL_STAT5_NAME = "Intelligenz", "Willenskraft"
    UnitPowerMax = function()
      return spec.mana and 2500 or 0
    end
    local known = {}
    for _, id in ipairs(skillList) do
      known[id] = true
    end
    C_SkillInfo = {
      GetSkillLineInfoByID = function(id)
        if known[id] then
          return { name = SKILL_NAMES[id], rank = 280, maxRank = 300, modifier = 0 }
        end
      end,
    }
    GetInventoryItemID = function(_, slot)
      local item = gear[slot - 15] -- 16 main, 17 off, 18 ranged
      return item and (slot * 100) or nil
    end
    C_Item = {
      GetItemInfoInstant = function(itemID)
        local item = gear[itemID / 100 - 15]
        if item == SHIELD then
          return itemID, nil, nil, nil, nil, 4, 6
        end
        return itemID, nil, nil, nil, nil, 2, item
      end,
    }
    UnitRangedDamage = function()
      return 2.8, 60, 110
    end
    UnitRangedAttackPower = function()
      return 400, 0, 0
    end
    GetRangedCritChance = function()
      return 4
    end
    GetSpellBonusDamage = function()
      return 150
    end
    GetSpellCritChance = function()
      return 6
    end
    GetBlockChance = function()
      return 5
    end
    GetShieldBlock = function()
      return 30
    end
    GetParryChance = function()
      return (token == "WARRIOR" or token == "PALADIN" or token == "ROGUE" or token == "HUNTER") and 5 or 0
    end
    -- hostile target two levels above: glancing applies to melee only
    UnitExists = function()
      return true
    end
    UnitCanAttack = function()
      return true
    end
    UnitName = function()
      return "Testgegner"
    end
    UnitClassification = function()
      return "normal"
    end
    UnitLevel = function(unit)
      return unit == "target" and 62 or 60
    end
  end
end

local function index(sections)
  local bySection, labels = {}, {}
  for _, s in ipairs(sections) do
    bySection[s.key] = {}
    for _, r in ipairs(s.rows) do
      bySection[s.key][r.label] = r
      labels[#labels + 1] = r.label
    end
  end
  return bySection, labels
end

for _, token in ipairs(ORDER) do
  local spec = CLASSES[token]
  local ns = assert(loadfile(dir .. "/tools/wow_stub.lua"))(dir, clientLocale, setupFor(token, spec))
  local L = ns.L
  local statName = { "Stärke", "Beweglichkeit", "Ausdauer", "Intelligenz", "Willenskraft" }

  -- 1) class defaults
  local by, labels = index(ns.Data.Collect())
  print(token .. ": " .. table.concat(labels, " | "))
  for i = 1, 5 do
    local shown = by.base and by.base[statName[i]] ~= nil
    check(shown == (i == spec.mainStat), ("%s: %s %s"):format(token, statName[i], shown and "shown" or "hidden"))
  end
  if spec.attack == "melee" then
    check(by.melee and by.melee[L.ATTACK_POWER], token .. ": melee attack power")
    check(by.melee and by.melee[L.DAMAGE], token .. ": melee weapon damage")
    check(not by.ranged, token .. ": no ranged rows by default")
  elseif spec.attack == "ranged" then
    check(by.ranged and by.ranged[L.ATTACK_POWER], token .. ": ranged attack power")
    check(by.ranged and by.ranged[L.DAMAGE], token .. ": ranged weapon damage")
    check(not by.melee, token .. ": no melee rows by default")
  else
    check(by.spell and by.spell[L.SPELL_DAMAGE], token .. ": spell damage")
    check(not by.melee and not by.ranged, token .. ": no melee/ranged rows by default")
  end
  check(by.skills and by.skills[L.DEFENSE], token .. ": defense (current / max) below the weapon skills")
  check(not (by.defense and by.defense[L.DEFENSE]), token .. ": defense not twice")

  -- equipped weapon skills (and only those), with the vs.-target tooltip
  local equipped = {}
  for slot = 1, 3 do
    local item = spec.gear[slot]
    if item and item ~= SHIELD then
      equipped[SUBCLASS_SKILL[item]] = true
    end
  end
  for _, id in ipairs(spec.skills) do
    if id ~= 95 and id ~= 162 then
      local row = by.skills and by.skills[SKILL_NAMES[id]]
      check(
        (row ~= nil) == (equipped[id] == true),
        ("%s: skill %s %s"):format(token, SKILL_NAMES[id], row and "shown" or "hidden")
      )
      if row and equipped[id] then
        local glance = row.tip and row.tip:find(L.T_GLANCE, 1, true) ~= nil
        check(glance == not RANGED_SKILL[id], ("%s: glancing tooltip for %s"):format(token, SKILL_NAMES[id]))
      end
    end
  end

  -- 2) every value switched on
  ns.SetAllRows(true)
  by = index(ns.Data.Collect())
  local hasRanged = spec.gear[3] ~= nil
  check((by.ranged ~= nil) == hasRanged, token .. ": ranged section only with a ranged weapon")
  if hasRanged then
    local isWand = spec.gear[3] == WAND
    check((by.ranged[L.ATTACK_POWER] ~= nil) == not isWand, token .. ": ranged AP only for non-wands")
    check((by.ranged[L.CRIT] ~= nil) == not isWand, token .. ": ranged crit only for non-wands")
    check(by.ranged[L.DAMAGE] ~= nil, token .. ": ranged damage")
  end
  check((by.spell ~= nil) == spec.mana, token .. ": spell section only for mana users")
  check((by.base[L.MANA] ~= nil) == spec.mana, token .. ": mana row only for mana users")
  local shield = spec.gear[2] == SHIELD
  check((by.defense[L.BLOCK] ~= nil) == shield, token .. ": block only with a shield")
  local parry = token == "WARRIOR" or token == "PALADIN" or token == "ROGUE" or token == "HUNTER"
  check((by.defense[L.PARRY] ~= nil) == parry, token .. ": parry only when the class can parry")
  -- all known weapon skills listed (defense and unarmed rules aside)
  for _, id in ipairs(spec.skills) do
    if id ~= 95 then
      check(by.skills[SKILL_NAMES[id]] ~= nil, ("%s: all skills on lists %s"):format(token, SKILL_NAMES[id]))
    end
  end
end

-- Every usable weapon type, one at a time: the slot content decides the
-- shown skill (marked as equipped, with its vs.-target value; glancing in
-- the tooltip only for melee weapons).
for _, token in ipairs(ORDER) do
  local spec = CLASSES[token]
  local skills = { 95, 162 }
  for _, sub in ipairs(USABLE[token]) do
    skills[#skills + 1] = ALL_SUBCLASS_SKILL[sub]
  end
  local names = {}
  for _, sub in ipairs(USABLE[token]) do
    local skillID = ALL_SUBCLASS_SKILL[sub]
    local ranged = RANGED_SUBCLASS[sub] == true
    local gear = ranged and { nil, nil, sub } or { sub }
    local ns = assert(loadfile(dir .. "/tools/wow_stub.lua"))(dir, clientLocale, setupFor(token, spec, gear, skills))
    local L = ns.L
    local by = index(ns.Data.Collect())
    local name = SKILL_NAMES[skillID]
    local row = by.skills and by.skills[name]
    check(row ~= nil, ("%s with %s: skill row shown"):format(token, name))
    if row then
      check(row.tip and row.tip:find(L.EQUIPPED, 1, true), ("%s with %s: marked equipped"):format(token, name))
      check(row.pct and row.pct:find("^%d+%%$"), ("%s with %s: percentage in its column"):format(token, name))
      check(row.value:match("^%d+ / %d+$"), ("%s with %s: current / max alone in the right column"):format(token, name))
      check(row.progress and row.progress > 0 and row.progress <= 1, ("%s with %s: progress bar"):format(token, name))
      check(
        row.tip and row.tip:find(string.format(L.TO_CAP_FMT, 20, 300), 1, true),
        ("%s with %s: distance to cap"):format(token, name)
      )
      local glance = row.tip and row.tip:find(L.T_GLANCE, 1, true) ~= nil
      check(glance == not ranged, ("%s with %s: glancing only for melee"):format(token, name))
    end
    -- only equipped skills: this weapon, plus unarmed when the main hand is empty
    for label in pairs(by.skills or {}) do
      local expected = label == name
        or label == "Testgegner"
        or label == L.DEFENSE
        or (ranged and label == "Unbewaffnet")
      check(expected, ("%s with %s: unexpected skill row %s"):format(token, name, label))
    end
    names[#names + 1] = name
  end
  print(("%s weapons (%d): %s"):format(token, #names, table.concat(names, ", ")))
end

if failures > 0 then
  print(("class matrix: %d failure(s)"):format(failures))
  os.exit(1)
end
print("class matrix (" .. clientLocale .. "): all 9 classes and all usable weapon types passed")
