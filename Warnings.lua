local _, ns = ...
local L = ns.L
local U = ns.Util
local call, num, isSecret = U.call, U.num, U.isSecret

-- Class and gear warnings: texts in the middle of the screen that stay while
-- their cause lasts, like the missing Well-Rested warning (red, sound once).
local Warnings = {}
ns.Warnings = Warnings

-- ---------------------------------------------------------------- game data

-- Item, spell and aura IDs: game data 1.60.1.71037 (ItemSparse, SpellReagents,
-- SpellName); APIs as Blizzard's own UI uses them (DurabilityFrame,
-- PetHappiness, StanceBar).
local SOUL_SHARD = 6265
local SHARDS_LOW = 5
local AMMO_LOW = 200
-- Warlock spells with the soul shard as reagent: until one is known the shards
-- are of no use.
local SHARD_SPELLS = {
  691, -- Summon Felhunter
  693, -- Create Soulstone
  697, -- Summon Voidwalker
  698, -- Ritual of Summoning
  712, -- Summon Succubus
  713, -- Summon Incubus
  1098, -- Subjugate Demon
  2362, -- Create Spellstone
  5699, -- Create Healthstone
  6201, -- Create Healthstone
  6202, -- Create Healthstone
  6353, -- Soul Fire
  6366, -- Create Firestone
  8722, -- Summon Succubus
  8994, -- Banish
  11725, -- Subjugate Demon
  11726, -- Subjugate Demon
  11729, -- Create Healthstone
  11730, -- Create Healthstone
  12746, -- Summon Voidwalker
  12890, -- Deep Slumber
  17727, -- Create Spellstone
  17728, -- Create Spellstone
  17877, -- Shadowburn
  17924, -- Soul Fire
  17951, -- Create Firestone
  17952, -- Create Firestone
  17953, -- Create Firestone
  18867, -- Shadowburn
  18868, -- Shadowburn
  18869, -- Shadowburn
  18870, -- Shadowburn
  18871, -- Shadowburn
  20752, -- Create Soulstone
  20755, -- Create Soulstone
  20756, -- Create Soulstone
  20757, -- Create Soulstone
  27565, -- Banish
  28023, -- Create Healthstone
  427733, -- Summon Felguard
  437169, -- Portal of Summoning
  437311, -- Portal of Summoning
  1322007, -- Summon Voidwalker
}
local BATTLE_SHOUT = { 6673, 5242, 6192, 11549, 11550, 11551, 25289 }
local DAZE_ASPECTS = { 5118, 13159 } -- Aspect of the Cheetah, Aspect of the Pack
local CALL_PET = { 883 }
local DEFENSIVE_STANCE = { [71] = true }
local AMMO_WEAPONS = { [2] = true, [3] = true, [18] = true } -- bow, gun, crossbow
local SLOT_AMMO = 0
local ALERT_SLOTS = 11 -- INVENTORY_ALERT_STATUS_SLOTS in DurabilityFrame.lua
local PET_HAPPY = 3 -- 1 mad, 2 content, 3 happy (PetHappiness.lua)
local POISONS = { 2842 } -- the rogue's Poisons skill spell
local ROCKBITER = { 8017, 8018, 8019, 10399, 16314, 16315, 16316 } -- the shaman's first imbue
local RIGHTEOUS_FURY = { 25780, 407627 }
local REAGENT_LOW = 5
local BAGS_LOW = 2 -- free slots in the normal bags
local SKILL_GAP = 10 -- weapon skill text only when more than this below the maximum (user decision 2026-11-27)
local BAG_FIRST, BAG_LAST = 0, 4 -- backpack and the four bag slots
-- Professions and secondary skills (skill line IDs): alchemy, blacksmithing,
-- enchanting, engineering, herbalism, leatherworking, mining, skinning,
-- tailoring, cooking, first aid, fishing.
local PROFESSIONS = { 171, 164, 333, 202, 182, 165, 186, 393, 197, 185, 129, 356 }
-- Rank caps below the last rank -> the level the next rank needs at the
-- trainer (classic rules: Journeyman 10, Expert 20, Artisan 35).
local PROFESSION_TRAIN_LEVEL = { [75] = 10, [150] = 20, [225] = 35 }

-- Reagents: per spell family { spell, reagent item } by rank, lowest level
-- first; only the highest known rank's reagent counts. Situational spells
-- (Slow Fall, Levitate, Water Walking / Breathing, Divine Intervention) are
-- left out: their reagents are rarely carried. Generated from SpellReagents,
-- SpellLevels and SkillLineAbility 1.60.1.71037.
local REAGENTS = {
  ROGUE = {
    { { 1856, 5140 }, { 1857, 5140 } }, -- Vanish
    { { 2094, 5530 } }, -- Blind
  },
  MAGE = {
    { { 1297659, 17031 } }, -- Teleport: Dalaran
    { { 3565, 17031 } }, -- Teleport: Darnassus
    { { 3562, 17031 } }, -- Teleport: Ironforge
    { { 3567, 17031 } }, -- Teleport: Orgrimmar
    { { 3561, 17031 } }, -- Teleport: Stormwind
    { { 3566, 17031 } }, -- Teleport: Thunder Bluff
    { { 3563, 17031 } }, -- Teleport: Undercity
    { { 11419, 17032 } }, -- Portal: Darnassus
    { { 11416, 17032 } }, -- Portal: Ironforge
    { { 11417, 17032 } }, -- Portal: Orgrimmar
    { { 10059, 17032 } }, -- Portal: Stormwind
    { { 11420, 17032 } }, -- Portal: Thunder Bluff
    { { 11418, 17032 } }, -- Portal: Undercity
    { { 23028, 17020 } }, -- Arcane Brilliance
  },
  PRIEST = {
    { { 21562, 17028 }, { 21564, 17029 } }, -- Prayer of Fortitude
    { { 27683, 17029 } }, -- Prayer of Shadow Protection
    { { 27681, 17029 } }, -- Prayer of Spirit
  },
  DRUID = {
    { { 20484, 17034 }, { 20739, 17035 }, { 20742, 17036 }, { 20747, 17037 }, { 20748, 17038 } }, -- Rebirth
    { { 21849, 17021 }, { 21850, 17026 } }, -- Gift of the Wild
  },
  PALADIN = {
    { { 25898, 21177 } }, -- Greater Blessing of Kings
    { { 25782, 21177 }, { 25916, 21177 } }, -- Greater Blessing of Might
    { { 25894, 21177 }, { 25918, 21177 } }, -- Greater Blessing of Wisdom
  },
  SHAMAN = {
    { { 20608, 17030 }, { 21169, 17030 } }, -- Reincarnation
  },
}

-- Self buffs checked out of combat: a group is missing when one of its "know"
-- spells is known and none of its "auras" is on. label: a locale key for the
-- group, else the name of the highest known spell. Same sources as REAGENTS
-- plus SpellName (auras: every spell of these names).
local SELF_BUFFS = {
  MAGE = {
    { -- Frost Armor / Ice Armor / Mage Armor
      know = { 168, 7300, 7301, 7302, 6117, 7320, 22782, 10219, 22783, 10220 },
      auras = {
        168,
        506,
        1200,
        6117,
        7300,
        7301,
        7302,
        7320,
        10219,
        10220,
        12544,
        12556,
        15784,
        18100,
        22782,
        22783,
        1283419,
      },
    },
    { -- Arcane Intellect / Arcane Brilliance
      know = { 1459, 1460, 1461, 10156, 10157, 23028 },
      auras = { 1459, 1460, 1461, 10156, 10157, 13326, 16876, 23028, 364161 },
    },
  },
  PRIEST = {
    { -- Inner Fire
      know = { 588, 7128, 602, 1006, 10951, 10952 },
      auras = { 588, 602, 624, 1006, 1254, 7128, 10951, 10952 },
    },
    { -- Power Word: Fortitude / Prayer of Fortitude
      know = { 1243, 1244, 1245, 2791, 10937, 21562, 10938, 21564 },
      auras = { 1243, 1244, 1245, 2791, 10937, 10938, 10939, 10940, 13864, 21562, 21564, 23947, 23948, 450086 },
    },
  },
  DRUID = {
    { -- Mark of the Wild / Gift of the Wild
      know = { 1126, 5232, 6756, 5234, 8907, 9884, 21849, 9885, 21850 },
      auras = {
        1126,
        5232,
        5234,
        5286,
        5287,
        6756,
        8907,
        8908,
        9884,
        9885,
        16878,
        21849,
        21850,
        24752,
        364163,
        1291335,
        1310503,
      },
    },
  },
  PALADIN = {
    { -- the auras (Devotion, Retribution, Concentration, resistances, Sanctity)
      label = "WARN_LABEL_AURA",
      know = {
        465,
        10290,
        7294,
        643,
        19746,
        10298,
        19876,
        10291,
        19888,
        10299,
        19891,
        1032,
        19895,
        19897,
        10300,
        19899,
        10292,
        19896,
        10301,
        19898,
        10293,
        19900,
      },
      auras = {
        465,
        643,
        1032,
        1876,
        7294,
        8258,
        8990,
        10290,
        10291,
        10292,
        10293,
        10298,
        10299,
        10300,
        10301,
        13008,
        17232,
        19746,
        19876,
        19888,
        19891,
        19895,
        19896,
        19897,
        19898,
        19899,
        19900,
        20218,
        420998,
        449669,
        463620,
        463621,
        1232703,
        1233344,
      },
    },
    { -- the blessings, also the greater ones
      label = "WARN_LABEL_BLESSING",
      know = {
        19740,
        19834,
        19742,
        20217,
        19835,
        19850,
        19836,
        19852,
        19837,
        19853,
        19838,
        25782,
        19854,
        25894,
        25290,
        25291,
        25898,
        25916,
        25918,
      },
      auras = {
        19740,
        19742,
        19834,
        19835,
        19836,
        19837,
        19838,
        19850,
        19852,
        19853,
        19854,
        20217,
        25290,
        25291,
        25782,
        25894,
        25898,
        25916,
        25918,
        26650,
        1213408,
      },
    },
  },
  SHAMAN = {
    { -- Lightning Shield
      know = { 324, 325, 905, 945, 8134, 10431, 10432 },
      auras = {
        324,
        325,
        905,
        945,
        8134,
        8788,
        10431,
        10432,
        12550,
        13585,
        15507,
        19514,
        20545,
        23551,
        23552,
        25020,
        26363,
        26364,
        26365,
        26366,
        26367,
        26369,
        26370,
        26545,
        27635,
        28820,
        28821,
        432143,
        432144,
        432145,
        432146,
        432147,
        432148,
        432149,
        466739,
        470743,
        470744,
        470745,
        470746,
        470748,
        470749,
        470753,
        1213479,
        1270462,
      },
    },
  },
}

-- ---------------------------------------------------------------- readers

-- Each returns its value, or nil when the game does not say.

local function knowsAny(spells)
  local book = type(C_SpellBook) == "table" and C_SpellBook or {}
  if type(book.IsSpellKnown) ~= "function" then
    return nil
  end
  for _, spellID in ipairs(spells) do
    local known = call(book.IsSpellKnown, spellID)
    if isSecret(known) then
      return nil
    elseif known then
      return true
    end
  end
  return false
end

-- A hidden aura reads as nil in combat: nil is "missing" only when readable.
local function auraHidden(spellID)
  local ask = type(C_Secrets) == "table" and C_Secrets.ShouldSpellAuraBeSecret or nil
  local hidden = call(ask, spellID)
  if isSecret(hidden) then
    return true
  elseif hidden ~= nil then
    return hidden == true
  end
  return type(InCombatLockdown) == "function" and InCombatLockdown() and true or false
end

local function hasAura(spells)
  local getAura = type(C_UnitAuras) == "table" and C_UnitAuras.GetPlayerAuraBySpellID or nil
  if type(getAura) ~= "function" then
    return nil
  end
  local unknown = false
  for _, spellID in ipairs(spells) do
    local aura = call(getAura, spellID)
    if isSecret(aura) then
      unknown = true
    elseif type(aura) == "table" then
      return true
    elseif auraHidden(spellID) then
      unknown = true
    end
  end
  if unknown then
    return nil
  end
  return false
end

local function itemCount(itemID)
  local item = type(C_Item) == "table" and C_Item or {}
  return num(call(item.GetItemCount, itemID))
end

-- The spell ID of the active stance, 0 for none.
local function stanceSpell()
  local form = num(call(GetShapeshiftForm))
  if form == 0 then
    return 0
  elseif not form then
    return nil
  end
  local _, _, _, spellID = call(GetShapeshiftFormInfo, form)
  return num(spellID)
end

-- The highest known spell of a list, nil for none or unknown.
local function bestKnown(spells)
  local book = type(C_SpellBook) == "table" and C_SpellBook or {}
  local best
  for _, spellID in ipairs(spells) do
    local known = call(book.IsSpellKnown, spellID)
    if isSecret(known) then
      return nil
    elseif known then
      best = spellID
    end
  end
  return best
end

local function spellName(spellID)
  local getName = type(C_Spell) == "table" and C_Spell.GetSpellName or nil
  return U.str(call(getName, spellID)) or ("#" .. spellID)
end

-- Item names the game is still loading: ITEM_DATA_LOAD_RESULT for one of
-- them updates the text (the event fires for every item the client loads).
local requested = {}

local function itemName(itemID)
  local item = type(C_Item) == "table" and C_Item or {}
  local name = U.str(call(item.GetItemNameByID, itemID))
  if not name then
    requested[itemID] = true
    call(item.RequestLoadItemDataByID, itemID)
  end
  return name or ("#" .. itemID)
end

-- A weapon (not a shield, off-hand item or fishing pole) in the slot, and
-- whether it has a temporary enchant (poison, imbue). nil when the game does
-- not say.
local FISHING_POLE = 20
local function weaponWithoutEnchant(slot, weaponSlot)
  local classID, subclassID = ns.Skills.itemTypeInSlot(slot)
  if classID ~= 2 or subclassID == FISHING_POLE then
    return false
  end
  local item = type(C_Item) == "table" and C_Item or {}
  local enchants = call(item.GetWeaponEnchantInfo, weaponSlot)
  if type(enchants) ~= "table" or isSecret(enchants) then
    return nil
  end
  for _, enchant in pairs(enchants) do
    if type(enchant) == "table" then
      local has = enchant.hasEnchant
      if isSecret(has) then
        return nil
      elseif has == true then
        return false
      end
    end
  end
  return true
end

local function selfBuffsCheck(classToken)
  return function()
    local missing = {}
    for _, group in ipairs(SELF_BUFFS[classToken]) do
      local best = bestKnown(group.know)
      if best then
        local on = hasAura(group.auras)
        if on == nil then
          return nil
        elseif not on then
          missing[#missing + 1] = group.label and L[group.label] or spellName(best)
        end
      end
    end
    return #missing > 0 and string.format(L.WARN_BUFFS_MISSING_FMT, table.concat(missing, ", "))
  end
end

-- ---------------------------------------------------------------- the list

-- One entry per warning; settings row, default (on for every class, user
-- decision 2026-11-22) and event handling follow.
--   key      alert key; the setting is "warn_" .. key - never rename it
--   class    optional class token, others neither get the row nor the text
--   classes  optional set of class tokens, instead of class
--   combat   true: only while in a fight
--   calm     true: only out of combat (buffs are prepared before the pull)
--   alive    true: not while dead or a ghost
--   delay    seconds the cause must last before the text appears (default 3;
--            the bags and auras are empty for a moment after loading screens)
--   silent   true: no warning sound when it appears
--   color    palette key of the text (default "bad")
--   notice   seconds: shown once for this long while the cause lasts, then
--            hidden until the cause is gone and comes again (user decision
--            2026-11-27 for the weapon skill text: once per fight, briefly)
--   renotice true: a notice comes again when its text changes (bags: 2 free,
--            1 free, full; user decision 2026-11-27: 5 s)
--   check()  text to show, false for none, nil when the game does not say
Warnings.LIST = {
  {
    key = "shards",
    class = "WARLOCK",
    check = function()
      local knows = knowsAny(SHARD_SPELLS)
      if not knows then
        return knows
      end
      local count = itemCount(SOUL_SHARD)
      return count and count <= SHARDS_LOW and string.format(L.WARN_SHARDS_FMT, count)
    end,
  },
  {
    key = "ammo",
    class = "HUNTER",
    check = function()
      local classID, subclassID = ns.Skills.itemTypeInSlot(ns.Skills.SLOT_RANGED)
      if classID ~= 2 or not AMMO_WEAPONS[subclassID] then
        return false
      end
      local count = num(call(GetInventoryItemCount, "player", SLOT_AMMO))
      return count and count <= AMMO_LOW and string.format(L.WARN_AMMO_FMT, count)
    end,
  },
  {
    key = "aspect",
    class = "HUNTER",
    combat = true,
    delay = 0,
    check = function()
      local on = hasAura(DAZE_ASPECTS)
      return on and L.WARN_ASPECT_TEXT or on
    end,
  },
  {
    key = "pet_happy",
    class = "HUNTER",
    check = function()
      -- HasPetUI and GetPetHappiness can still report a dismissed pet; the
      -- game only shows the mood on the pet frame, i.e. while the pet is out.
      local _, isHunterPet = call(HasPetUI)
      local out, dead = call(UnitExists, "pet"), call(UnitIsDead, "pet")
      if isSecret(isHunterPet) or isSecret(out) or isSecret(dead) then
        return nil
      elseif not isHunterPet or not out or dead then
        return false
      end
      local api = type(C_PetInfo) == "table" and C_PetInfo or {}
      local happiness = num(call(api.GetPetHappiness))
      if not happiness then
        return nil
      end
      if happiness >= PET_HAPPY then
        return false
      end
      return happiness <= 1 and L.WARN_PET_MAD or L.WARN_PET_CONTENT
    end,
  },
  {
    key = "pet_missing",
    class = "HUNTER",
    combat = true,
    delay = 0,
    check = function()
      local knows = knowsAny(CALL_PET)
      if not knows then
        return knows
      end
      local exists, dead = call(UnitExists, "pet"), call(UnitIsDead, "pet")
      if isSecret(exists) or isSecret(dead) then
        return nil
      elseif not exists then
        return L.WARN_PET_MISSING
      end
      return dead and L.WARN_PET_DEAD or false
    end,
  },
  {
    key = "battle_shout",
    class = "WARRIOR",
    combat = true,
    check = function()
      local knows = knowsAny(BATTLE_SHOUT)
      if not knows then
        return knows
      end
      local on = hasAura(BATTLE_SHOUT)
      if on == nil then
        return nil
      end
      return not on and L.WARN_BATTLE_SHOUT
    end,
  },
  {
    key = "def_shield",
    class = "WARRIOR",
    check = function()
      local spellID = stanceSpell()
      if not spellID then
        return nil
      end
      return DEFENSIVE_STANCE[spellID] and not ns.Skills.hasShield() and L.WARN_DEF_SHIELD
    end,
  },
  {
    key = "poison",
    class = "ROGUE",
    alive = true,
    check = function()
      local knows = knowsAny(POISONS)
      if not knows then
        return knows
      end
      local main = weaponWithoutEnchant(ns.Skills.SLOT_MAIN, 0)
      local off = weaponWithoutEnchant(ns.Skills.SLOT_OFF, 1)
      if main == nil or off == nil then
        return nil
      end
      return (main or off) and L.WARN_POISON
    end,
  },
  {
    key = "imbue",
    class = "SHAMAN",
    combat = true,
    alive = true,
    check = function()
      local knows = knowsAny(ROCKBITER)
      if not knows then
        return knows
      end
      local main = weaponWithoutEnchant(ns.Skills.SLOT_MAIN, 0)
      if main == nil then
        return nil
      end
      return main and L.WARN_IMBUE
    end,
  },
  { key = "mage_buffs", class = "MAGE", calm = true, alive = true, check = selfBuffsCheck("MAGE") },
  { key = "priest_buffs", class = "PRIEST", calm = true, alive = true, check = selfBuffsCheck("PRIEST") },
  { key = "druid_buffs", class = "DRUID", calm = true, alive = true, check = selfBuffsCheck("DRUID") },
  { key = "paladin_buffs", class = "PALADIN", calm = true, alive = true, check = selfBuffsCheck("PALADIN") },
  { key = "shaman_buffs", class = "SHAMAN", calm = true, alive = true, check = selfBuffsCheck("SHAMAN") },
  {
    key = "righteous_fury",
    class = "PALADIN",
    alive = true,
    check = function()
      if not bestKnown(RIGHTEOUS_FURY) or not ns.Skills.hasShield() then
        return false
      end
      local on = hasAura(RIGHTEOUS_FURY)
      if on == nil then
        return nil
      end
      return not on and string.format(L.WARN_BUFFS_MISSING_FMT, spellName(RIGHTEOUS_FURY[1]))
    end,
  },
  {
    key = "reagents",
    classes = { ROGUE = true, MAGE = true, PRIEST = true, DRUID = true, PALADIN = true, SHAMAN = true },
    check = function()
      local _, classToken = call(UnitClass, "player")
      local families = not isSecret(classToken) and REAGENTS[classToken]
      if not families then
        return false
      end
      local book = type(C_SpellBook) == "table" and C_SpellBook or {}
      local needed, order = {}, {}
      for _, family in ipairs(families) do
        local item
        for _, rank in ipairs(family) do
          local known = call(book.IsSpellKnown, rank[1])
          if isSecret(known) then
            return nil
          elseif known then
            item = rank[2]
          end
        end
        if item and not needed[item] then
          needed[item] = true
          order[#order + 1] = item
        end
      end
      local low = {}
      for _, item in ipairs(order) do
        local count = itemCount(item)
        if not count then
          return nil
        elseif count <= REAGENT_LOW then
          low[#low + 1] = itemName(item) .. " " .. count
        end
      end
      return #low > 0 and string.format(L.WARN_REAGENTS_FMT, table.concat(low, ", "))
    end,
  },
  {
    key = "bags",
    notice = 5,
    renotice = true,
    check = function()
      local api = type(C_Container) == "table" and C_Container or {}
      local free, known = 0, false
      for bag = BAG_FIRST, BAG_LAST do
        local slots = num(call(api.GetContainerNumSlots, bag))
        if slots and slots > 0 then
          local count, family = call(api.GetContainerNumFreeSlots, bag)
          count, family = num(count), num(family)
          if not count then
            return nil
          end
          if (family or 0) == 0 then -- profession bags take only their own goods
            free, known = free + count, true
          end
        end
      end
      if not known then
        return nil
      end
      return free <= BAGS_LOW
        and (free == 0 and L.WARN_BAGS_FULL or free == 1 and L.WARN_BAGS_ONE or string.format(L.WARN_BAGS_FMT, free))
    end,
  },
  {
    key = "talents",
    calm = true,
    check = function()
      local api = type(C_ClassTalents) == "table" and C_ClassTalents.HasUnspentTalentPoints
      local has, classPoints, specPoints = call(api)
      if type(has) ~= "boolean" or isSecret(has) then
        return nil
      end
      if not has then
        return false
      end
      local count = (num(classPoints) or 0) + (num(specPoints) or 0)
      if count == 1 then
        return L.WARN_TALENTS_ONE
      end
      return count > 0 and string.format(L.WARN_TALENTS_FMT, count) or L.WARN_TALENTS_TEXT
    end,
  },
  {
    key = "skillup",
    combat = true,
    delay = 0,
    silent = true,
    color = "warn",
    notice = 5,
    check = function()
      local Skills = ns.Skills
      local seen, parts = {}, {}
      for _, slot in ipairs({ Skills.SLOT_MAIN, Skills.SLOT_OFF, Skills.SLOT_RANGED }) do
        local id = Skills.skillForSlot(slot)
        if id and not seen[id] then
          seen[id] = true
          local s = ns.Data.GetSkill(id)
          if not s or not s.max then
            return nil
          end
          if s.max - s.rank > SKILL_GAP then
            parts[#parts + 1] = string.format("%s %d/%d", s.name, s.rank, s.max)
          end
        end
      end
      return #parts > 0 and string.format(L.WARN_SKILLUP_FMT, table.concat(parts, ", "))
    end,
  },
  {
    key = "profession",
    calm = true,
    check = function()
      local level = num(call(UnitLevel, "player"))
      if not level then
        return nil
      end
      local full = {}
      for _, id in ipairs(PROFESSIONS) do
        local s = ns.Data.GetSkill(id)
        local need = s and s.max and PROFESSION_TRAIN_LEVEL[s.max]
        if need and s.rank >= s.max and level >= need then
          full[#full + 1] = string.format("%s %d/%d", s.name, s.rank, s.max)
        end
      end
      return #full > 0 and string.format(L.WARN_PROFESSION_FMT, table.concat(full, ", "))
    end,
  },
  {
    key = "durability",
    check = function()
      local worst = 0
      for index = 1, ALERT_SLOTS do
        local status = num(call(GetInventoryAlertStatus, index))
        if status and status > worst then
          worst = status
        end
      end
      if type(GetInventoryAlertStatus) ~= "function" then
        return nil
      end
      return worst >= 2 and L.WARN_GEAR_BROKEN or worst == 1 and L.WARN_GEAR_LOW
    end,
  },
}

-- Events after which a warning can change (UNIT_AURA comes from Core's
-- player-only registration). UNIT_EVENTS: event -> unit.
Warnings.EVENTS = {
  BAG_UPDATE_DELAYED = true,
  SPELLS_CHANGED = true,
  LOADING_SCREEN_DISABLED = true,
  PLAYER_ENTERING_WORLD = true,
  PLAYER_EQUIPMENT_CHANGED = true,
  PLAYER_REGEN_DISABLED = true,
  PLAYER_REGEN_ENABLED = true,
  UPDATE_SHAPESHIFT_FORM = true,
  UPDATE_SHAPESHIFT_FORMS = true,
  UPDATE_INVENTORY_ALERTS = true,
  PET_UI_UPDATE = true,
  UNIT_AURA = true,
  WEAPON_ENCHANT_CHANGED = true,
  TRAIT_CONFIG_UPDATED = true,
  PLAYER_LEVEL_UP = true,
  CHARACTER_POINTS_CHANGED = true,
  SKILL_LINES_CHANGED = true,
}
Warnings.UNIT_EVENTS = {
  UNIT_PET = "player",
  UNIT_HAPPINESS = "pet",
  UNIT_INVENTORY_CHANGED = "player",
}

local DEFAULT_DELAY = 3

function Warnings.OptionId(warning)
  return "warn_" .. warning.key
end

local function forClass(warning, classToken)
  if warning.classes then
    return warning.classes[classToken] == true
  end
  return not warning.class or warning.class == classToken
end

-- For the settings list: an unknown class lists everything.
function Warnings.AppliesTo(warning, classToken)
  return classToken == nil or forClass(warning, classToken)
end

local function playerClass()
  local _, classToken = call(UnitClass, "player")
  if isSecret(classToken) then
    return nil
  end
  return classToken
end

-- What the warning says right now: text, false or nil (unknown).
function Warnings.Check(warning, classToken)
  if not forClass(warning, classToken) then
    return false
  end
  if (warning.combat and not ns.IsInFight()) or (warning.calm and ns.IsInFight()) then
    return false
  end
  if warning.alive then
    local dead = call(UnitIsDeadOrGhost, "player")
    if isSecret(dead) then
      return nil
    elseif dead then
      return false
    end
  end
  return warning.check()
end

local pending = {} -- key -> run of the timer that may show it
local noticeEnd = {} -- key -> GetTime() when a `notice` warning is hidden again
local noticeText = {} -- key -> the text that notice was shown with
local runs = 0

local function clock()
  return type(GetTime) == "function" and GetTime() or 0
end

-- Shows a warning's text; a `notice` warning only for its seconds (again for a
-- new text with `renotice`), then hidden while the cause lasts.
local function show(warning, text)
  local key = warning.key
  if warning.notice then
    local t = clock()
    if not noticeEnd[key] or (warning.renotice and noticeText[key] ~= text) then
      noticeEnd[key], noticeText[key] = t + warning.notice, text
      if type(C_Timer) == "table" and C_Timer.After then
        C_Timer.After(warning.notice, function()
          Warnings.Update()
        end)
      end
    elseif t >= noticeEnd[key] then
      ns.UI.SetAlert(key, nil)
      return
    end
  end
  ns.UI.SetAlert(key, text, warning.silent, warning.color or "bad")
end

-- ITEM_DATA_LOAD_RESULT (registered by Core): only for a name asked for.
function Warnings.OnItemLoaded(itemID)
  if not isSecret(itemID) and requested[itemID] then
    requested[itemID] = nil
    Warnings.Update()
  end
end

-- now: show without the delay (settings switched).
function Warnings.Update(now)
  local classToken = playerClass()
  for _, warning in ipairs(Warnings.LIST) do
    local key = warning.key
    local result = false
    if ns.IsRowEnabled(Warnings.OptionId(warning)) then
      result = Warnings.Check(warning, classToken)
    end
    if result == nil then -- unknown: leave it as it is (a brief one still goes)
      pending[key] = nil
      if warning.notice and noticeEnd[key] and clock() >= noticeEnd[key] then
        ns.UI.SetAlert(key, nil)
      end
    elseif not result then
      pending[key] = nil
      noticeEnd[key], noticeText[key] = nil, nil
      ns.UI.SetAlert(key, nil)
    elseif ns.UI.GetAlert(key) or noticeEnd[key] or now or (warning.delay or DEFAULT_DELAY) == 0 then
      pending[key] = nil
      show(warning, result)
    elseif not pending[key] and type(C_Timer) == "table" and C_Timer.After then
      runs = runs + 1
      local run = runs
      pending[key] = run
      C_Timer.After(warning.delay or DEFAULT_DELAY, function()
        if pending[key] ~= run then
          return
        end
        pending[key] = nil
        local text = ns.IsRowEnabled(Warnings.OptionId(warning)) and Warnings.Check(warning, playerClass())
        if text then
          show(warning, text)
        end
      end)
    end
  end
end
