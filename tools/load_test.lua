local dir = arg[1]
-- Client language to simulate (second argument): deDE (default) or enUS.
local clientLocale = arg[2] or "deDE"
local ns = assert(loadfile(dir .. "/tools/wow_stub.lua"))(dir, clientLocale)
assert(ns.UI.GetFrame():IsShown(), "fresh install: own window, open")
assert(ns.UI.GetFrame().version, "version text in the title bar")
C_AddOns = {
  GetAddOnMetadata = function(name, key)
    return name == "isiStatsForever" and key == "Version" and "1.2.3" or nil
  end,
}
assert(ns.ErrorLog.Version() == "1.2.3", "version from the TOC")
C_AddOns = nil
assert(ns.ErrorLog.Version() == "?", "no metadata API: unknown")
CharacterFrame:Show()
CharacterFrame:Hide()
SlashCmdList.ISISTATS("alpha 40")
SlashCmdList.ISISTATS("alpha 0")
SlashCmdList.ISISTATS("")
SlashCmdList.ISISTATS("config")
SlashCmdList.ISISTATS("free")
SlashCmdList.ISISTATS("dock")
SlashCmdList.ISISTATS("scale 1.2")
SlashCmdList.ISISTATS("reset")
ns.Options.Sync()
ns.SetRowEnabled("m_dps", true)
ns.SetAllRows(false)
ns.ResetRows()
ns.SetShowHeaders(true)
ns.SetShowHeaders(false)
ns.SetAlpha(55)

-- Asserts (exit 1 on the first failure).
local failures = 0
local function check(cond, msg)
  if not cond then
    failures = failures + 1
    print("FAIL " .. msg)
  end
end

-- Warrior class defaults: strength, melee AP, defense, equipped skills + vs. target.
for _, id in ipairs({ "stat1", "m_ap", "m_dmg", "d_def", "w_equipped", "w_vs" }) do
  check(ns.IsRowEnabled(id), "default on: " .. id)
end
for _, id in ipairs({ "stat4", "s_dmg", "r_ap", "w_other", "m_dps" }) do
  check(not ns.IsRowEnabled(id), "default off: " .. id)
end
check(IsiStatsDB.showHeaders == false, "headers hidden by default")
check(IsiStatsDB.alpha == 55, "alpha saved")
check(IsiStatsDB.scale == 1, "scale reset to 1")

-- Saved choices for rows that no longer exist are dropped.
IsiStatsCharDB.rows.t_info = true
IsiStatsCharDB.rows.m_skill_mh = false
ns.PruneRows()
check(IsiStatsCharDB.rows.t_info == nil and IsiStatsCharDB.rows.m_skill_mh == nil, "stale row settings pruned")

-- A user choice survives and wins over the class default.
ns.SetRowEnabled("stat1", false)
check(not ns.IsRowEnabled("stat1"), "user choice wins over default")
ns.ResetRows()
check(ns.IsRowEnabled("stat1"), "class default back after reset")

-- Collected sections: values the defaults switch on are there.
local function findRow(sections, label)
  for _, s in ipairs(sections) do
    for _, r in ipairs(s.rows) do
      if r.label == label then
        return r
      end
    end
  end
end
local sections = ns.Data.Collect()
check(
  findRow(sections, ns.L.ATTACK_POWER) and findRow(sections, ns.L.ATTACK_POWER).value == "1100",
  "attack power 1100"
)
check(findRow(sections, ns.L.DEFENSE) ~= nil, "defense row")

-- Fishing pole: red row at the very top, lasting text with sound from combat start.
GetInventoryItemID = function(_, slot)
  return slot == 16 and 6256 or nil
end
local savedItemInfo = C_Item
C_Item = {
  GetItemInfoInstant = function()
    return 6256, "Angel", "", "", 0, 2, 20
  end,
}
local fishSections = ns.Data.Collect()
check(fishSections[1].key == "warn" and fishSections[1].rows[1].key == "warn_fishing", "fishing pole row at the top")
local played, soundCount = nil, 0
SOUNDKIT = { RAID_WARNING = 8959 }
PlaySound = function(id)
  played = id
  soundCount = soundCount + 1
end
-- The first alert creates the frame: record what it draws and where it sits.
local alertLines, alertAnchor, alertVisible = {}, nil, false
local createFrame = CreateFrame
RaidWarningFrame = createFrame("Frame")
CreateFrame = function(...)
  local frame = createFrame(...)
  local createString = frame.CreateFontString
  frame.CreateFontString = function(self, name, layer, font)
    local fs = createString(self, name, layer, font)
    if font == "GameFontNormalHuge" then
      local line = {}
      alertLines[#alertLines + 1] = line
      fs.SetText = function(_, text)
        line.text = text
      end
      local show, hide = self.Show, self.Hide
      if #alertLines == 1 then
        self.Show = function(me)
          show(me)
          alertVisible = true
        end
        self.Hide = function(me)
          hide(me)
          alertVisible = false
        end
      end
    end
    return fs
  end
  frame.SetPoint = function(_, point, relative, relativePoint)
    if relative and relative == RaidWarningFrame then
      alertAnchor = point .. ">" .. relativePoint
    end
  end
  return frame
end
local function fireCore(event)
  StubFrames[1].scripts.OnEvent(StubFrames[1], event)
end
-- The fishing sound repeats: run its timers by hand.
local afterNow, soundTimers = C_Timer.After, {}
C_Timer.After = function(delay, fn)
  if delay == 2 then
    soundTimers[#soundTimers + 1] = fn
  else
    afterNow(delay, fn)
  end
end
local function twoSeconds()
  local due = soundTimers
  soundTimers = {}
  for _, fn in ipairs(due) do
    fn()
  end
end
check(ns.UI.GetAlert("fishing") == nil, "pole outside combat: no screen text")
fireCore("PLAYER_REGEN_DISABLED")
CreateFrame = createFrame
check(ns.UI.GetAlert("fishing") == ns.L.WARN_FISHING_COMBAT and played == 8959, "text with sound when combat starts")
check(alertVisible and alertLines[1].text == ns.L.WARN_FISHING_COMBAT, "fishing text drawn")
check(alertAnchor == "BOTTOM>TOP", "screen texts sit above the raid warnings")
check(soundCount == 1, "sound at once when combat starts")
for i = 2, 8 do
  twoSeconds()
  check(soundCount == i, "sound every 2 seconds while in combat")
end
fireCore("PLAYER_EQUIPMENT_CHANGED")
twoSeconds()
check(soundCount == 9, "other gear during the fight: still one series")
fireCore("PLAYER_REGEN_ENABLED")
check(alertVisible, "fishing text stays after the fight")
twoSeconds()
check(soundCount == 9, "fight over: sound stops")
fireCore("PLAYER_EQUIPMENT_CHANGED")
check(alertVisible, "fishing text stays when other gear changes")
fireCore("PLAYER_REGEN_DISABLED")
check(soundCount == 10, "next combat with the text still up: sound again")
fireCore("PLAYER_REGEN_ENABLED")
soundCount = 1
ns.UI.SetAlert("tracking", "Radar")
check(soundCount == 2, "second text: its own sound")
ns.UI.SetAlert("tracking", "Radar")
check(soundCount == 2, "same text again: no sound")
check(alertLines[1].text == ns.L.WARN_FISHING_COMBAT and alertLines[2].text == "Radar", "both texts stacked")

local poleInfo = C_Item
C_Item = {
  GetItemInfoInstant = function()
    return 1, "Schwert", "", "", 0, 2, 7
  end,
}
fireCore("PLAYER_EQUIPMENT_CHANGED")
check(ns.UI.GetAlert("fishing") == nil, "pole taken off: text gone")
check(alertVisible and alertLines[1].text == "Radar" and alertLines[2].text == "", "other text moves down")
ns.UI.SetAlert("tracking", nil)
check(not alertVisible, "no text left: nothing on screen")
check(soundCount == 2, "taking texts away is silent")
fireCore("PLAYER_REGEN_DISABLED")
check(ns.UI.GetAlert("fishing") == nil, "combat with a weapon: no text")

C_Item = poleInfo
soundCount = 0
fireCore("PLAYER_EQUIPMENT_CHANGED")
check(ns.UI.GetAlert("fishing") ~= nil and soundCount == 1, "pole equipped during a fight: text and sound")
local swordInfo = {
  GetItemInfoInstant = function()
    return 1, "Schwert", "", "", 0, 2, 7
  end,
}
C_Item = swordInfo
fireCore("PLAYER_EQUIPMENT_CHANGED")
twoSeconds()
check(soundCount == 1, "pole off during the fight: sound stops")
C_Item = poleInfo
fireCore("PLAYER_EQUIPMENT_CHANGED")
check(soundCount == 2, "pole on again: sound again")
ns.SetRowEnabled("warn_fishing_combat", false)
twoSeconds()
check(soundCount == 2, "setting off: sound stops")
check(ns.UI.GetAlert("fishing") == nil, "setting off hides the text at once")
ns.SetRowEnabled("warn_fishing", false)
soundCount = 0
fireCore("PLAYER_REGEN_DISABLED")
check(
  ns.UI.GetAlert("fishing") == nil and soundCount == 0 and ns.Data.Collect()[1].key ~= "warn",
  "fishing warnings switchable"
)
ns.ResetRows()
GetInventoryItemID, C_Item = nil, savedItemInfo
check(ns.Data.Collect()[1].key ~= "warn", "no warning without a fishing pole")
fireCore("PLAYER_EQUIPMENT_CHANGED")
fireCore("PLAYER_REGEN_ENABLED")
C_Timer.After = afterNow
RaidWarningFrame, SOUNDKIT, PlaySound = nil, nil, nil

-- Soul shard warning, through the real event handler.
do
  local backup = {
    UnitClass = UnitClass,
    C_Item = C_Item,
    C_SpellBook = C_SpellBook,
    UnitExists = UnitExists,
    GetInventoryItemID = GetInventoryItemID,
  }
  local after, timers = C_Timer.After, {}
  local class, known, shards, sounds = "WARLOCK", true, 3, 0
  C_Timer.After = function(_, fn)
    timers[#timers + 1] = fn
  end
  UnitClass = function()
    return "Hexenmeister", class
  end
  C_SpellBook = {
    IsSpellKnown = function(id)
      return known and id == 697
    end,
  }
  C_Item = {
    GetItemCount = function(id)
      return id == 6265 and shards or 0
    end,
  }
  SOUNDKIT = { RAID_WARNING = 8959 }
  PlaySound = function()
    sounds = sounds + 1
  end
  local function after3s(event)
    StubFrames[1].scripts.OnEvent(StubFrames[1], event or "BAG_UPDATE_DELAYED")
    local due = timers
    timers = {}
    for _, fn in ipairs(due) do
      fn()
    end
    return ns.UI.GetAlert("shards")
  end
  ns.ResetRows()
  check(ns.IsRowEnabled("warn_shards"), "shard warning on by default")
  local text = after3s("PLAYER_ENTERING_WORLD")
  check(text == ns.L.WARN_SHARDS_FMT:format(3), "3 shards: warning with the count")
  check(sounds == 1, "sound once when it appears")
  shards = 5
  check(after3s() == ns.L.WARN_SHARDS_FMT:format(5), "5 shards: still a warning")
  check(sounds == 1, "new count: no new sound")
  shards = 6
  StubFrames[1].scripts.OnEvent(StubFrames[1], "BAG_UPDATE_DELAYED")
  check(ns.UI.GetAlert("shards") == nil, "6 shards: gone at once")
  shards = 0
  StubFrames[1].scripts.OnEvent(StubFrames[1], "BAG_UPDATE_DELAYED")
  check(ns.UI.GetAlert("shards") == nil, "waits before it appears")
  check(after3s() == ns.L.WARN_SHARDS_FMT:format(0), "no shards: warning")
  ns.SetRowEnabled("warn_shards", false)
  check(ns.UI.GetAlert("shards") == nil, "setting off hides at once")
  ns.SetRowEnabled("warn_shards", true)
  check(ns.UI.GetAlert("shards") ~= nil, "setting on shows at once")
  known = false
  check(after3s("SPELLS_CHANGED") == nil, "no shard spell known: no warning")
  known, class = true, "WARRIOR"
  check(after3s() == nil, "other classes: no warning")
  class = "WARLOCK"
  C_Item = {}
  check(after3s() == nil, "no count from the game: no guessing")
  C_SpellBook = nil
  check(after3s() == nil, "no spell API: no guessing")

  -- The other class warnings.
  local inv, ammo, auras, stance, happy, pet, deadPet = {}, 500, {}, 0, 3, true, false
  local alertStatus = {}
  C_SpellBook = {
    IsSpellKnown = function(id)
      return id == 883 or id == 6673
    end,
  }
  C_Item = {
    GetItemInfoInstant = function(id)
      local t = inv[id]
      if t then
        return id, "", "", "", 0, t[1], t[2]
      end
    end,
    GetItemCount = function()
      return 50
    end,
  }
  GetInventoryItemID = function(_, slot)
    return (slot == 18 and inv.ranged) or (slot == 17 and inv.off) or nil
  end
  GetInventoryItemCount = function(_, slot)
    return slot == 0 and ammo or 0
  end
  C_UnitAuras = {
    GetPlayerAuraBySpellID = function(id)
      return auras[id]
    end,
  }
  C_Secrets = {
    ShouldSpellAuraBeSecret = function()
      return false
    end,
  }
  GetShapeshiftForm = function()
    return stance == 0 and 0 or 1
  end
  GetShapeshiftFormInfo = function()
    return 0, true, true, stance
  end
  HasPetUI = function()
    return pet, pet
  end
  C_PetInfo = {
    GetPetHappiness = function()
      return happy, 100, 0
    end,
  }
  UnitExists = function(unit)
    return unit ~= "pet" or pet
  end
  UnitIsDead = function(unit)
    return unit == "pet" and deadPet
  end
  GetInventoryAlertStatus = function(index)
    return alertStatus[index] or 0
  end
  local function shown(key)
    return ns.UI.GetAlert(key)
  end
  local function fight(on)
    StubFrames[1].scripts.OnEvent(StubFrames[1], on and "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED")
    local due = timers
    timers = {}
    for _, fn in ipairs(due) do
      fn()
    end
  end

  class = "HUNTER"
  ns.ResetRows()
  inv.ranged, inv[1] = 1, { 2, 2 } -- bow
  after3s()
  check(shown("ammo") == nil, "hunter with 500 arrows: no warning")
  ammo = 200
  after3s()
  check(shown("ammo") == ns.L.WARN_AMMO_FMT:format(200), "200 arrows: warning")
  inv[1] = { 2, 16 } -- thrown
  after3s()
  check(shown("ammo") == nil, "thrown weapon: no ammo warning")
  inv[1] = { 2, 2 }
  ammo = 900
  after3s()
  auras[5118] = {}
  check(shown("aspect") == nil, "cheetah out of combat: fine")
  fight(true)
  check(shown("aspect") == ns.L.WARN_ASPECT_TEXT, "cheetah in combat: warning")
  auras[5118], auras[13159] = nil, {}
  StubFrames[1].scripts.OnEvent(StubFrames[1], "UNIT_AURA", "player")
  check(shown("aspect") ~= nil, "pack in combat: warning")
  auras[13159] = nil
  StubFrames[1].scripts.OnEvent(StubFrames[1], "UNIT_AURA", "player")
  check(shown("aspect") == nil, "aspect changed: gone at once")
  check(shown("pet_missing") == nil, "pet there: fine")
  deadPet = true
  StubFrames[1].scripts.OnEvent(StubFrames[1], "UNIT_PET", "player")
  check(shown("pet_missing") == ns.L.WARN_PET_DEAD, "dead pet in combat")
  pet, deadPet = false, false
  StubFrames[1].scripts.OnEvent(StubFrames[1], "UNIT_PET", "player")
  check(shown("pet_missing") == ns.L.WARN_PET_MISSING, "no pet in combat")
  fight(false)
  check(shown("pet_missing") == nil, "fight over: no pet text")
  pet, happy = true, 2
  check(after3s("UNIT_HAPPINESS") == nil and shown("pet_happy") == ns.L.WARN_PET_CONTENT, "content pet")
  happy = 1
  after3s("UNIT_HAPPINESS")
  check(shown("pet_happy") == ns.L.WARN_PET_MAD, "unhappy pet")
  happy = 3
  after3s("UNIT_HAPPINESS")
  check(shown("pet_happy") == nil, "happy pet: fine")

  class = "WARRIOR"
  ns.ResetRows()
  after3s()
  check(shown("ammo") == nil and shown("pet_happy") == nil, "warrior: no hunter texts")
  stance = 71
  after3s("UPDATE_SHAPESHIFT_FORM")
  check(shown("def_shield") == ns.L.WARN_DEF_SHIELD, "defensive stance, no shield")
  inv.off, inv[2] = 2, { 4, 6 }
  after3s("PLAYER_EQUIPMENT_CHANGED")
  check(shown("def_shield") == nil, "shield on: fine")
  check(ns.IsRowEnabled("warn_battle_shout"), "every warning on by default")
  fight(true)
  check(shown("battle_shout") == ns.L.WARN_BATTLE_SHOUT, "no battle shout in combat")
  check(shown("rage_stance") == nil, "no stance warning in combat (removed)")
  auras[6673] = {}
  StubFrames[1].scripts.OnEvent(StubFrames[1], "UNIT_AURA", "player")
  check(shown("battle_shout") == nil, "battle shout on: fine")
  auras[6673] = nil
  C_Secrets.ShouldSpellAuraBeSecret = function()
    return true
  end
  StubFrames[1].scripts.OnEvent(StubFrames[1], "UNIT_AURA", "player")
  check(shown("battle_shout") == nil, "hidden aura: no guessing")
  IsiStatsCharDB.rows.warn_rage_stance = true
  ns.PruneRows()
  check(IsiStatsCharDB.rows.warn_rage_stance == nil, "removed stance warning: saved setting dropped")
  fight(false)
  check(shown("battle_shout") == nil, "fight over: combat texts gone")

  alertStatus[9] = 1
  after3s("UPDATE_INVENTORY_ALERTS")
  check(shown("durability") == ns.L.WARN_GEAR_LOW, "weapon almost broken")
  alertStatus[3] = 2
  after3s("UPDATE_INVENTORY_ALERTS")
  check(shown("durability") == ns.L.WARN_GEAR_BROKEN, "chest broken")
  alertStatus = {}
  after3s("UPDATE_INVENTORY_ALERTS")
  check(shown("durability") == nil, "repaired: gone")

  -- Rogue: poison; Shaman: imbue in combat; self buffs; reagents.
  local enchanted, items = { [0] = false, [1] = false }, {}
  C_Item.GetWeaponEnchantInfo = function(slot)
    return { { hasEnchant = enchanted[slot] } }
  end
  C_Item.GetItemCount = function(id)
    return items[id] or 0
  end
  C_Item.GetItemNameByID = function(id)
    return "Item" .. id
  end
  local knownSpells = {}
  C_SpellBook.IsSpellKnown = function(id)
    return knownSpells[id] == true
  end
  UnitIsDeadOrGhost = function()
    return false
  end
  C_Secrets.ShouldSpellAuraBeSecret = function()
    return false
  end
  auras = {}
  inv.off, inv[1], inv[2] = 1, { 2, 7 }, nil -- sword in both hands
  inv.main = 1
  GetInventoryItemID = function(_, slot)
    return (slot == 16 and inv.main) or (slot == 17 and inv.off) or (slot == 18 and inv.ranged) or nil
  end

  class = "ROGUE"
  ns.ResetRows()
  knownSpells = { [2842] = true }
  after3s()
  check(shown("poison") == ns.L.WARN_POISON, "rogue without poison")
  enchanted[0] = true
  after3s("UNIT_INVENTORY_CHANGED")
  check(shown("poison") == ns.L.WARN_POISON, "off hand still without poison")
  enchanted[1] = true
  after3s("UNIT_INVENTORY_CHANGED")
  check(shown("poison") == nil, "both poisoned: fine")
  enchanted[0] = false
  local hiddenValue = {} -- stands for a secret value
  C_Item.GetWeaponEnchantInfo = function(slot)
    return { { hasEnchant = slot == 0 and hiddenValue or true } }
  end
  issecretvalue = function(v)
    return v == hiddenValue
  end
  after3s("UNIT_INVENTORY_CHANGED")
  check(shown("poison") == nil, "hidden enchant state: no error, no guessing")
  issecretvalue = function()
    return false
  end
  C_Item.GetWeaponEnchantInfo = function(slot)
    return { { hasEnchant = enchanted[slot] } }
  end
  inv[1] = { 2, 20 } -- fishing pole
  inv.off = nil
  after3s("PLAYER_EQUIPMENT_CHANGED")
  check(shown("poison") == nil, "fishing pole: no poison warning")
  inv[1], inv.off = { 2, 7 }, 1
  enchanted[0] = true
  knownSpells = { [2842] = true, [1856] = true, [1857] = true, [2094] = true }
  items[5140] = 3
  items[5530] = 9
  after3s()
  check(shown("reagents") == ns.L.WARN_REAGENTS_FMT:format("Item5140 3"), "flash powder low, blinding fine")
  local loading, requests = true, 0
  C_Item.GetItemNameByID = function(id)
    return not loading and ("Item" .. id) or nil
  end
  C_Item.RequestLoadItemDataByID = function()
    requests = requests + 1
  end
  items[5140] = 2
  after3s()
  check(shown("reagents") == ns.L.WARN_REAGENTS_FMT:format("#5140 2") and requests == 1, "name loading: id first")
  loading = false
  StubFrames[1].scripts.OnEvent(StubFrames[1], "ITEM_DATA_LOAD_RESULT", 99999, true)
  check(shown("reagents"):find("#5140", 1, true), "other item loaded: no update")
  StubFrames[1].scripts.OnEvent(StubFrames[1], "ITEM_DATA_LOAD_RESULT", 5140, true)
  check(shown("reagents") == ns.L.WARN_REAGENTS_FMT:format("Item5140 2"), "own item loaded: name")

  class = "DRUID"
  ns.ResetRows()
  knownSpells = { [20484] = true, [20739] = true, [1126] = true }
  items = { [17034] = 20 }
  after3s()
  check(shown("reagents") == ns.L.WARN_REAGENTS_FMT:format("Item17035 0"), "only the highest rank's seed counts")
  check(shown("druid_buffs") == ns.L.WARN_BUFFS_MISSING_FMT:format("#1126"), "mark of the wild missing")
  auras[21850] = {}
  after3s("UNIT_AURA")
  check(shown("druid_buffs") == nil, "gift of the wild counts")
  auras = {}
  fight(true)
  check(shown("druid_buffs") == nil, "self buffs: not in combat")
  fight(false)
  UnitIsDeadOrGhost = function()
    return true
  end
  after3s()
  check(shown("druid_buffs") == nil, "dead: no buff text")
  UnitIsDeadOrGhost = function()
    return false
  end

  class = "PALADIN"
  ns.ResetRows()
  knownSpells = { [465] = true, [19740] = true, [25780] = true }
  inv.off, inv[2] = 2, { 4, 6 }
  after3s()
  local both = ns.L.WARN_BUFFS_MISSING_FMT:format(ns.L.WARN_LABEL_AURA .. ", " .. ns.L.WARN_LABEL_BLESSING)
  check(shown("paladin_buffs") == both, "paladin: aura and blessing missing")
  check(shown("righteous_fury") ~= nil, "paladin with shield: righteous fury missing")
  auras[19900], auras[25898] = {}, {}
  after3s("UNIT_AURA")
  check(shown("paladin_buffs") == nil, "any aura and a greater blessing count")
  check(shown("reagents") == nil, "no greater blessing known: no symbol warning")

  class = "SHAMAN"
  ns.ResetRows()
  knownSpells = { [8017] = true, [324] = true }
  enchanted[0] = false
  after3s()
  check(shown("imbue") == nil, "imbue: only in combat")
  check(shown("shaman_buffs") ~= nil, "lightning shield missing out of combat")
  fight(true)
  check(shown("imbue") == ns.L.WARN_IMBUE, "no imbue in combat")
  enchanted[0] = true
  StubFrames[1].scripts.OnEvent(StubFrames[1], "UNIT_INVENTORY_CHANGED", "player")
  check(shown("imbue") == nil, "imbued: gone at once")
  fight(false)
  UnitIsDeadOrGhost = nil

  local catalogIds = {}
  for _, section in ipairs(ns.Data.GetCatalog()) do
    for _, row in ipairs(section.rows) do
      catalogIds[row.id] = row.label
    end
  end
  check(catalogIds.warn_imbue and catalogIds.warn_reagents and not catalogIds.warn_ammo, "own class only")
  for _, warning in ipairs(ns.Warnings.LIST) do
    check(ns.L["WARN_" .. warning.key:upper() .. "_OPT"], "option text for " .. warning.key)
  end
  GetShapeshiftForm, GetShapeshiftFormInfo, HasPetUI, C_PetInfo = nil, nil, nil, nil
  GetInventoryItemCount, GetInventoryAlertStatus, UnitIsDead, C_Secrets = nil, nil, nil, nil
  UnitExists, C_UnitAuras, GetInventoryItemID = backup.UnitExists, nil, backup.GetInventoryItemID

  for name, value in pairs(backup) do
    _G[name] = value
  end
  C_Timer.After = after
  SOUNDKIT, PlaySound = nil, nil
  after3s()
  check(ns.UI.GetAlert("shards") == nil, "warrior again: no text")
end

-- Damage meter: cleared once per group joined, through the real event handler.
do
  local resets, lines, printBackup, timeBackup = 0, {}, print, GetTime
  GetTime = function()
    return 500
  end
  C_DamageMeter = {
    ResetAllCombatSessions = function()
      resets = resets + 1
    end,
  }
  print = function(text)
    if text:find("^FAIL") then
      printBackup(text)
    else
      lines[#lines + 1] = text
    end
  end
  local function group(event, guid)
    StubFrames[1].scripts.OnEvent(StubFrames[1], event, 1, guid)
  end
  check(IsiStatsDB.resetMeterOnJoin == true, "meter reset on by default")
  group("GROUP_FORMED", "Party-1")
  check(resets == 1, "own group: meter cleared")
  check(lines[1] and lines[1]:find(ns.L.METER_RESET_DONE, 1, true), "chat line says so")
  group("GROUP_JOINED", "Party-1")
  check(resets == 1, "formed and joined for one group: one reset")
  group("GROUP_JOINED", "Party-2")
  check(resets == 2, "next group: cleared again")
  ns.SetResetMeterOnJoin(false)
  group("GROUP_JOINED", "Party-3")
  check(resets == 2 and IsiStatsDB.resetMeterOnJoin == false, "switched off: kept")
  ns.SetResetMeterOnJoin(true)
  group("GROUP_JOINED", nil)
  group("GROUP_FORMED", nil)
  check(resets == 3, "unreadable group id: one reset for both events")
  C_DamageMeter = {}
  group("GROUP_JOINED", "Party-4")
  check(#lines == 3, "no meter API: nothing happens")
  C_DamageMeter = nil
  print, GetTime = printBackup, timeBackup
end

-- Chat history: sent lines are saved, a repeat moves to the end, and the
-- saved lines go back into the edit box history (oldest first) on login.
check(IsiStatsDB.chatHistoryArrows == true, "chat history arrows on by default")
local box = ChatFrame1EditBox
box:AddHistoryLine("/w Freund hi")
box:AddHistoryLine("hallo")
box:AddHistoryLine("/w Freund hi")
local saved = IsiStatsDB.chatHistory
check(#saved == 2 and saved[1] == "hallo" and saved[2] == "/w Freund hi", "chat lines saved, repeat moved to the end")
check(box.altArrow == false, "Up / Down walk the history without Alt")
-- /console: the game sends it without a history line; the typed text counts.
box:Fire("OnEditFocusGained")
box:SetText("/console gxRestart", true)
box:SetText("", false) -- the game clears the box while sending
box:Fire("OnEnterPressed")
check(
  saved[#saved] == "/console gxRestart" and box.history[#box.history] == "/console gxRestart",
  "/console saved from the typed text"
)
-- A line the game already added is not added twice.
box:Fire("OnEditFocusGained")
box:SetText("hallo", true)
box:AddHistoryLine("hallo")
local historyCount = #box.history
box:Fire("OnEnterPressed")
check(#box.history == historyCount, "no double line when the game added it")
-- Text deleted by hand before Enter is not saved.
box:Fire("OnEditFocusGained")
box:SetText("/console x", true)
box:SetText("", true)
box:Fire("OnEnterPressed")
check(saved[#saved] ~= "/console x", "deleted text is not saved")
-- Up / Down walk the saved list themselves (newest first), Down past the
-- newest gives an empty line.
box:Fire("OnEditFocusGained")
local n = #IsiStatsDB.chatHistory
local clock = 0
GetTime = function()
  clock = clock + 1
  return clock
end
box:FireKey("OnArrowPressed", "UP")
check(box.text == IsiStatsDB.chatHistory[n], "Up shows the newest line")
box:FireKey("OnArrowPressed", "UP")
check(box.text == IsiStatsDB.chatHistory[n - 1], "Up again shows the one before")
box:FireKey("OnArrowPressed", "DOWN")
check(box.text == IsiStatsDB.chatHistory[n], "Down goes back")
box:FireKey("OnArrowPressed", "DOWN")
check(box.text == "", "Down past the newest line empties the box")
GetTime = function()
  return 5
end
box:FireKey("OnArrowPressed", "UP")
box:FireKey("OnArrowPressed", "UP")
check(box.text == IsiStatsDB.chatHistory[n], "one key press reported twice steps once")
GetTime = nil
box:Fire("OnEditFocusGained")
ns.ChatHistory.SetArrows(false)
check(box.altArrow == true, "arrow keys switchable")
local savedCount = #IsiStatsDB.chatHistory
box:AddHistoryLine("geheim")
check(#IsiStatsDB.chatHistory == savedCount, "nothing saved with the setting off")
ns.ChatHistory.SetArrows(true)
SlashCmdList.ISISTATS("chat clear")
check(#IsiStatsDB.chatHistory == 0, "chat history cleared")

-- XP to the next level, in thousands, at the very top; gone at max level.
UnitXP = function()
  return 5000
end
UnitXPMax = function()
  return 17400
end
GetMaxPlayerLevel = function()
  return 60
end
UnitLevel = function()
  return 41
end
local xpSections = ns.Data.Collect()
local xpRow = xpSections[1] and xpSections[1].rows[1]
check(xpSections[1].key == "xp" and xpRow and xpRow.value == "12.4k", "XP row first, 12.4k to go")
check(xpRow and xpRow.label == string.format(ns.L.XP_NEXT_FMT, 42), "XP row names the next level")
-- The login query mutes the chat windows for TIME_PLAYED_MSG and lets them
-- listen again once the answer is in (no global function replaced).
local chatListens = true
ChatFrame1 = {
  IsEventRegistered = function(_, event)
    return event == "TIME_PLAYED_MSG" and chatListens
  end,
  UnregisterEvent = function()
    chatListens = false
  end,
  RegisterEvent = function()
    chatListens = true
  end,
}
local pendingTimers, asked = {}, false
local realAfter = C_Timer.After
C_Timer.After = function(_, fn)
  pendingTimers[#pendingTimers + 1] = fn
end
RequestTimePlayed = function()
  asked = true
end
ns.LevelTime.Request()
check(asked and not chatListens, "played-time query sent with the chat muted")
ns.LevelTime.OnTimePlayed(100000, 3600)
for _, fn in ipairs(pendingTimers) do
  fn()
end
check(chatListens, "chat listens again after the answer")
C_Timer.After = realAfter
ChatFrame1, RequestTimePlayed = nil, nil

-- Time on this level from TIME_PLAYED_MSG (through the real event handler)
-- and the estimate from the XP rate: 5000 XP in 1h, 12400 to go -> ~2h 28m.
local clock = 1000
GetTime = function()
  return clock
end
local evFrame = StubFrames[1]
evFrame.scripts.OnEvent(evFrame, "TIME_PLAYED_MSG", 100000, 3600)
local function xpRowByKey(key)
  for _, r in ipairs(ns.Data.Collect()[1].rows) do
    if r.key == key then
      return r
    end
  end
end
check(xpRowByKey("xp_time") and xpRowByKey("xp_time").value == "1h 0m", "time on this level 1h 0m")
check(xpRowByKey("xp_eta") and xpRowByKey("xp_eta").value == "~2h 28m", "estimate ~2h 28m")
clock = clock + 1800
check(xpRowByKey("xp_time").value == "1h 30m", "time on this level keeps counting")
evFrame.scripts.OnEvent(evFrame, "PLAYER_LEVEL_UP", 42)
check(xpRowByKey("xp_time").value == "0m", "level up restarts the level time")
check(xpRowByKey("xp_eta").value == "-", "no estimate without data")

-- Rate from active play: 3h idle, then 10 kills of 500 XP a minute apart.
-- The idle gap counts as 5 min only: 5000 XP in 300 + 9 * 60 = 840 s,
-- 11400 to go -> 1915 s ~ 31m (the level average would say hours).
local xpNow = 1000
UnitXP = function()
  return xpNow
end
evFrame.scripts.OnEvent(evFrame, "PLAYER_XP_UPDATE", "player")
clock = clock + 3 * 3600
for i = 1, 10 do
  xpNow = xpNow + 500
  evFrame.scripts.OnEvent(evFrame, "PLAYER_XP_UPDATE", "player")
  if i < 10 then
    clock = clock + 60
  end
end
check(xpRowByKey("xp_eta").value == "~31m", "estimate from active play ignores the idle hours")
check(xpRowByKey("xp_eta").tip == ns.L.XP_ETA_TIP_ACTIVE, "tooltip names the active-play window")
check(#IsiStatsCharDB.xpRate.gains == 10, "gains saved per character")
clock = clock + 2 * 3600
check(xpRowByKey("xp_eta").value == "~31m", "rate stays frozen while idle")
-- Crossing a level: 17000 -> 400 of the next level is a gain of 800.
xpNow = 17000
evFrame.scripts.OnEvent(evFrame, "PLAYER_XP_UPDATE", "player")
xpNow = 400
evFrame.scripts.OnEvent(evFrame, "PLAYER_XP_UPDATE", "player")
local gains = IsiStatsCharDB.xpRate.gains
check(gains[#gains][3] == 800 and gains[#gains][2] == 0, "level-up gain counted across the level border")
-- Gains older than 30 min of active play leave the window.
for _ = 1, 8 do
  clock = clock + 300
  xpNow = xpNow + 100
  evFrame.scripts.OnEvent(evFrame, "PLAYER_XP_UPDATE", "player")
end
check(#IsiStatsCharDB.xpRate.gains <= 7, "old gains leave the window")
UnitLevel = function()
  return 60
end
check(ns.Data.Collect()[1].key ~= "xp", "no XP row at max level")
UnitXP, UnitXPMax, GetMaxPlayerLevel = nil, nil, nil

-- No guessing: a hostile level ?? target (not a world boss) gets no defense.
UnitExists = function()
  return true
end
UnitCanAttack = function()
  return true
end
UnitName = function()
  return "Elite"
end
UnitClassification = function()
  return "elite"
end
UnitLevel = function(unit)
  return unit == "target" and -1 or 60
end
local target = findRow(ns.Data.Collect(), "Elite")
check(target and target.value == ns.L.T_LEVEL_UNKNOWN, "level ?? target shows unknown defense")

-- Error log: own errors are captured and de-duplicated, others are not
-- (debugstack is stubbed to point into isiStatsForever, so the filter is the message
-- for the foreign case).
debugstack = function()
  return "[Interface/AddOns/isiStatsForever/ErrorLog.lua]:84: in function <...>\n"
    .. "[Interface/AddOns/OtherAddon/x.lua]:1: in function <...>\n"
end
geterrorhandler()("Interface/AddOns/OtherAddon/x.lua:1: boom")
geterrorhandler()(
  "...face/AddOns/Blizzard_TextStatusBar/TextStatusBar.lua:110: attempt to compare a secret number value "
    .. "(execution tainted by 'ForeverLootSparkles_Coloring')"
)
check(#IsiStatsDB.errors == 0, "foreign error not logged, even with the error handler in the stack")
geterrorhandler()("Interface/AddOns/isiStatsForever/Data.lua:42: attempt to index nil")
geterrorhandler()("Interface/AddOns/isiStatsForever/Data.lua:42: attempt to index nil")
check(#IsiStatsDB.errors == 1 and IsiStatsDB.errors[1].count == 2, "own error logged once, counted twice")
SlashCmdList.ISISTATS("errors")
SlashCmdList.ISISTATS("reset")
check(#IsiStatsDB.errors == 1, "error log survives reset")
SlashCmdList.ISISTATS("errors clear")
check(#IsiStatsDB.errors == 0, "error log cleared")

-- Fade-in: a changed value plays the animation, an unchanged one does not.
UnitLevel = function()
  return 60
end
UnitExists = function()
  return false
end
ns.Show()
check(ns.UI.GetFrame():IsShown(), "window shown for the fade-in test")
ns.Refresh()
local before = flashPlays
ns.Refresh()
check(flashPlays == before, "no fade-in without a change")
UnitAttackPower = function()
  return 900, 250, 0
end
ns.Refresh()
check(flashPlays > before, "fade-in when attack power changes")
ns.SetFlashChanges(false)
before = flashPlays
UnitAttackPower = function()
  return 900, 300, 0
end
ns.Refresh()
check(flashPlays == before, "no fade-in when switched off")

-- Hit results and the five corrected sources, through the real event handler.
do
  local names = {
    "GetInventoryItemID",
    "C_Item",
    "C_SkillInfo",
    "UnitLevel",
    "UnitExists",
    "UnitCanAttack",
    "UnitClassification",
    "UnitIsPlayer",
    "GetCombatRatingBonus",
    "GetHitModifier",
    "GetOffhandHitModifier",
    "GetRangedHitModifier",
    "GetGlancingBlowChance",
    "GetGlancingBlowPenalty",
    "GetExpertise",
    "issecretvalue",
    "InCombatLockdown",
    "UnitAttackSpeed",
    "UnitDamage",
  }
  local backup = {}
  for _, name in ipairs(names) do
    backup[name] = _G[name]
  end
  local handler = StubFrames[1]
  local targetLevel, rank, combat, hasTarget = 45, 207, false, true
  local hit, expertise = 0, 0
  local gear = { [16] = 7 }
  local hidden = {} -- stands for a secret value
  issecretvalue = function(v)
    return v == hidden
  end
  local function secretInCombat(value)
    if combat then
      return hidden
    end
    return value
  end
  InCombatLockdown = function()
    return combat
  end
  GetInventoryItemID = function(_, slot)
    return gear[slot] and slot or nil
  end
  C_Item = {
    GetItemInfoInstant = function(slot)
      return slot, nil, nil, nil, nil, 2, gear[slot]
    end,
  }
  C_SkillInfo = {
    GetSkillLineInfoByID = function(id)
      return { name = "S" .. id, rank = rank, maxRank = id == 95 and 300 or 230, modifier = 0 }
    end,
  }
  UnitExists = function()
    return hasTarget
  end
  UnitCanAttack = UnitExists
  UnitIsPlayer = function()
    return false
  end
  UnitClassification = function()
    return "normal"
  end
  UnitLevel = function(unit)
    return unit == "target" and targetLevel or 46
  end
  GetCombatRatingBonus = function()
    return secretInCombat(0)
  end
  GetHitModifier = function()
    return secretInCombat(hit)
  end
  GetExpertise = function()
    return secretInCombat(expertise), secretInCombat(expertise)
  end
  GetGlancingBlowChance = function(skill, defense)
    return secretInCombat(math.max(0, math.min(1, 0.1 + (defense - skill) * 0.02)))
  end
  GetGlancingBlowPenalty = function()
    return secretInCombat(0.47)
  end
  ns.ResetRows()

  local function byKey(key)
    for _, s in ipairs(ns.Data.Collect()) do
      for _, r in ipairs(s.rows) do
        if r.key == key then
          return r
        end
      end
    end
  end
  local function expect(message, value, color)
    local row = byKey("w:S43")
    check(
      row.pct == value and row.pctColor == color,
      message .. (" (got %s %s)"):format(row.pct, tostring(row.pctColor))
    )
  end

  expect("skill 207 vs. level 45", "63%", "bad")
  local tip = byKey("w:S43").tip
  for _, part in ipairs({ "63%", "17%", "46%", "37%" }) do
    check(tip:find(part, 1, true), "tooltip has the split: " .. part)
  end
  check(byKey("wr:43:fail") == nil, "one value, no rows below the weapon")
  hit = 2
  expect("hit lowers the miss", "61%", "bad")
  hit, expertise = 0, 2
  expect("expertise lowers dodge and parry", "59%", "bad")
  expertise = 0
  gear[17] = 7
  expect("dual wielding: 19% more miss", "82%", "bad")
  gear[17] = nil

  -- Primed through the event, as with a hidden window: no Collect before combat.
  targetLevel = 45
  rank = 210
  handler.scripts.OnEvent(handler, "SKILL_LINES_CHANGED")
  combat = true
  targetLevel = 42
  expect("another target level in combat", "25%", nil)
  rank = 212
  targetLevel = 44
  expect("skill rises in combat", "42%", "warn")
  check(not byKey("w:S43").stale, "calculated live in combat")
  rank = 225 -- never asked before combat
  expect("glancing unknown: no value that looks too good", "...", nil)
  combat = false

  rank = 207
  hasTarget = false
  check(byKey("w_vs_target").label == ns.L.SAME_LEVEL, "without a target: an enemy of your level")
  hasTarget = true
  targetLevel = 45
  UnitIsPlayer = function()
    return true
  end
  expect("no glancing against players", "17%", nil)
  UnitIsPlayer = function()
    return false
  end

  local U = ns.Util
  local function near(a, b)
    return math.abs(a - b) < 0.001
  end
  local dodge, parry = U.avoidChance(300, 315, 0, true)
  check(near(dodge, 6.5) and near(parry, 16.5), "boss dodge 6.5% / parry 16.5% as in the game's tooltip")
  dodge, parry = U.avoidChance(300, 300, 0)
  check(near(dodge, 5) and near(parry, 5), "same level dodge 5% / parry 5%")
  dodge, parry = U.avoidChance(300, 300, 7)
  check(dodge == 0 and parry == 0, "expertise never below 0")

  -- The five fixes.
  ns.SetAllRows(true)
  gear = { [16] = 7, [17] = 15, [18] = 2 }
  UnitAttackSpeed = function()
    return 2.6, 1.8
  end
  UnitDamage = function()
    return 100, 180, 50, 90
  end
  GetHitModifier = function()
    return 1
  end
  GetOffhandHitModifier = function()
    return 4
  end
  GetRangedHitModifier = function()
    return 3
  end
  GetCombatRatingBonus = function(rating)
    return rating == 6 and 2 or 0.5
  end
  check(byKey("m_hit").value == "3.00%", "hit = rating + modifier")
  check(byKey("m_hit").tip == ns.L.HIT_OFF:format(6), "off hand has its own hit")
  check(byKey("r_hit").value == "3.50%", "ranged hit from the ranged API")
  check(near(U.missChance(300, 315, 0, true), 8), "boss miss 8%")
  check(near(U.missChance(300, 315, 0, true, true), 27), "boss miss dual wield 27%")
  check(near(U.missChance(300, 300, 0, false, true), 24), "same level dual wield 24%")
  check(ns.Skills.SUBCLASS_SKILL[13] == 162, "fist weapons use unarmed")
  local chance, penalty = U.glancing(200, 225)
  check(near(chance, 60) and near(penalty, 47), "glancing from the game's API")

  -- What the test builds saved is dropped on load.
  IsiStatsCharDB.swings = { version = 3, trace = { "x" } }
  handler.scripts.OnEvent(handler, "ADDON_LOADED", "isiStatsForever")
  check(IsiStatsCharDB.swings == nil, "saved swings of the test builds removed")

  ns.ResetRows()
  for _, name in ipairs(names) do
    _G[name] = backup[name]
  end
end

-- Gathering tracking warning, through the real event handler.
do
  local backup = { C_SkillInfo = C_SkillInfo, InCombatLockdown = InCombatLockdown, issecretvalue = issecretvalue }
  local after = C_Timer.After
  local herb, mining, herbOn, mineralsOn, otherOn, loaded, secret = false, false, false, false, false, true, false
  local combat = false
  local hidden = {}
  local timers = {}
  local alert = setmetatable({}, { -- what the player sees
    __index = function(_, key)
      local text = ns.UI.GetAlert("tracking")
      if key == "shown" then
        return text ~= nil
      end
      return text
    end,
  })
  C_Timer.After = function(_, fn)
    timers[#timers + 1] = fn
  end
  issecretvalue = function(v)
    return v == hidden
  end
  InCombatLockdown = function()
    return combat
  end
  C_SkillInfo = {
    GetSkillLineInfoByID = function(id)
      if (id == 182 and herb) or (id == 186 and mining) then
        return { name = "P" .. id, rank = 174, maxRank = 225, modifier = 0 }
      end
    end,
  }
  local function list()
    local out = { { name = "Briefkasten" }, { name = "Humanoide", spellID = 5225, active = otherOn } }
    if loaded and herb then
      out[#out + 1] = { name = "Kräutersuche", spellID = 2383, active = herbOn }
    end
    if loaded and mining then
      local active = mineralsOn
      if secret then
        active = hidden
      end
      out[#out + 1] = { name = "Mineraliensuche", spellID = 2580, active = active }
    end
    return out
  end
  C_Minimap = {
    GetNumTrackingTypes = function()
      return #list()
    end,
    GetTrackingInfo = function(index)
      return list()[index]
    end,
  }
  local function fire(event)
    StubFrames[1].scripts.OnEvent(StubFrames[1], event or "MINIMAP_UPDATE_TRACKING")
  end
  local function settle()
    local due = timers
    timers = {}
    for _, fn in ipairs(due) do
      fn()
    end
  end
  -- Is the text on screen after the event and the delay?
  local function after3s(event)
    fire(event)
    settle()
    return alert.shown
  end
  local function reset()
    herb, mining, herbOn, mineralsOn, otherOn, loaded, secret = false, false, false, false, false, true, false
    combat = false
    after3s()
  end
  local sounds = 0
  SOUNDKIT = { RAID_WARNING = 8959 }
  PlaySound = function()
    sounds = sounds + 1
  end
  ns.ResetRows()
  check(ns.IsRowEnabled("warn_tracking"), "tracking warning on by default")

  reset()
  check(not after3s("PLAYER_ENTERING_WORLD"), "no profession: no warning")

  mining = true
  fire("PLAYER_ENTERING_WORLD")
  check(not alert.shown, "waits before it appears")
  check(sounds == 0, "no sound before it appears")
  settle()
  check(alert.shown, "mining without tracking: warning")
  check(sounds == 1, "sound once when the warning appears")
  check(alert.text == ns.L.WARN_TRACKING_FMT:format("Mineraliensuche"), "warning names the tracking")
  settle()
  check(alert.shown, "stays")
  check(after3s("LOADING_SCREEN_DISABLED"), "stays after a loading screen")
  combat = true
  check(after3s("SKILL_LINES_CHANGED"), "stays in combat")
  combat = false
  check(after3s("PLAYER_REGEN_ENABLED"), "stays after a fight")
  loaded = false
  check(after3s(), "stays while the list is not loaded")
  loaded, secret = true, true
  check(after3s(), "stays while the state is hidden")
  check(sounds == 1, "no more sounds while it stays")
  secret, mineralsOn = false, true
  fire()
  check(not alert.shown, "gone at once when switched on")
  settle()
  check(not alert.shown, "stays gone while on")
  mineralsOn = false
  check(after3s(), "back when switched off")
  check(sounds == 2, "sound again when it appears again")
  herb = true
  check(after3s() and sounds == 2, "only the text changes: no sound")

  reset()
  check(not alert.shown, "profession unlearned: gone")
  herb = true
  check(after3s() and alert.text:find("Kräutersuche", 1, true), "herbalism: warning")

  reset()
  herb, mining, herbOn = true, true, true
  check(not after3s(), "both learned, herbs on: no warning")
  herbOn, mineralsOn = false, true
  check(not after3s(), "both learned, minerals on: no warning")
  mineralsOn = false
  check(after3s(), "both learned, none on: warning")
  check(alert.text:find("Kräutersuche / Mineraliensuche", 1, true), "both trackings named")

  reset()
  herb, mining, herbOn = true, true, true
  after3s()
  herbOn = false
  fire()
  check(not alert.shown, "switching between both: nothing in between")
  mineralsOn = true
  fire()
  settle()
  check(not alert.shown, "switching between both: no warning")

  reset()
  mining, otherOn = true, true
  check(after3s(), "another tracking does not count")

  reset()
  mining, loaded = true, false
  check(not after3s(), "list not loaded: no guessing")
  loaded, secret = true, true
  check(not after3s(), "secret state: no guessing")

  reset()
  mining = true
  after3s()
  ns.SetRowEnabled("warn_tracking", false)
  check(not alert.shown, "switching the setting off hides at once")
  check(not after3s(), "stays off")
  ns.SetRowEnabled("warn_tracking", true)
  check(alert.shown, "switching the setting on shows at once")
  ns.SetAllRows(false)
  check(not alert.shown, "all off hides it")
  ns.ResetRows()
  check(alert.shown, "class defaults show it again")

  reset()
  for name, value in pairs(backup) do
    _G[name] = value
  end
  C_Timer.After = after
  C_Minimap, SOUNDKIT, PlaySound = nil, nil, nil
end

-- Buff reminder, through the real event handler.
do
  local afterNow = C_Timer.After
  C_Timer.After = function() end -- the warnings have their own test below
  local backup = {
    InCombatLockdown = InCombatLockdown,
    issecretvalue = issecretvalue,
    GetTime = GetTime,
    UnitLevel = UnitLevel,
  }
  local now, combat, restricted, faction, level = 1000, false, false, "Alliance", 46
  UnitLevel = function()
    return level
  end
  local auras, hidden = {}, {}
  GetTime = function()
    return now
  end
  InCombatLockdown = function()
    return combat
  end
  issecretvalue = function(v)
    return v == hidden
  end
  UnitFactionGroup = function()
    return faction
  end
  local names = { [429959] = "Gut erholt", [460939] = "Macht von Stormwind", [12345] = "Dritter Buff" }
  C_Spell = {
    GetSpellName = function(id)
      return names[id]
    end,
  }
  C_Secrets = {
    ShouldSpellAuraBeSecret = function()
      return restricted
    end,
  }
  C_UnitAuras = {
    -- Like the client: a hidden aura is simply nil.
    GetPlayerAuraBySpellID = function(id)
      if not restricted then
        return auras[id]
      end
    end,
  }
  ns.ResetRows()

  local function buff(key)
    for _, s in ipairs(ns.Data.Collect()) do
      for _, r in ipairs(s.rows) do
        if r.key == "buff_" .. key then
          return r
        end
      end
    end
  end
  local function fire(event)
    StubFrames[1].scripts.OnEvent(StubFrames[1], event, "player")
  end
  local function expect(message, key, value, color)
    local r = buff(key)
    check(r and r.value == value and r.color == color, message .. (" (got %s)"):format(r and r.value or "no row"))
  end
  local missing = ns.L.BUFF_MISSING

  check(ns.IsRowEnabled("buff_well_rested") and ns.IsRowEnabled("buff_might_stormwind"), "both buffs on by default")
  local top = ns.Data.Collect()[1]
  check(top.key == "buffs" and #top.rows == 2, "buffs at the very top")
  check(top.rows[1].label == "Gut erholt" and top.rows[2].label == "Macht von Stormwind", "names from the game")
  expect("well rested missing", "well_rested", missing, "bad")
  expect("stormwind missing", "might_stormwind", missing, "bad")

  auras[429959] = { applications = 3, expirationTime = now + 7200 }
  expect("3 stacks, full time", "well_rested", "3/3  2h 0m", "good")
  auras[429959] = { applications = 2, expirationTime = now + 6120 }
  expect("2 stacks", "well_rested", "2/3  1h 42m", "warn")
  auras[429959] = { applications = 0, expirationTime = now + 6120 }
  expect("no count means one stack", "well_rested", "1/3  1h 42m", "warn")
  auras[429959] = { applications = 3, expirationTime = now + 960 }
  expect("16 minutes left", "well_rested", "3/3  16m", "good")
  auras[429959] = { applications = 3, expirationTime = now + 900 }
  expect("last 15 minutes", "well_rested", "3/3  15m", "warn")
  auras[429959] = { applications = 3, expirationTime = now + 20 }
  expect("last minute is not 0m", "well_rested", "3/3  1m", "warn")

  for _, id in ipairs({ 460939, 460940, 1304678 }) do
    auras[id] = { applications = 0, expirationTime = now + 3600 }
    expect("stormwind version " .. id, "might_stormwind", "1h 0m", "good")
    auras[id] = nil
  end
  auras[460939] = { applications = 0, expirationTime = 0 }
  expect("no time limit", "might_stormwind", ns.L.BUFF_ACTIVE, "good")

  -- Combat: hidden must not read as missing.
  auras[429959] = { applications = 3, expirationTime = now + 1500 }
  auras[460939] = nil
  fire("UNIT_AURA") -- read without drawing the window
  combat, restricted = true, true
  now = now + 120
  expect("hidden: last state, time counts on", "well_rested", "3/3  23m", "dim")
  check(buff("well_rested").stale, "hidden: marked as last readable")
  expect("hidden and missing before", "might_stormwind", missing, "dim")
  now = now + 1500
  expect("run out while hidden", "well_rested", missing, "bad")
  combat, restricted = false, false
  auras[429959] = nil
  fire("PLAYER_REGEN_ENABLED")
  expect("readable again", "well_rested", missing, "bad")

  -- Readable in combat: live.
  combat = true
  auras[460939] = { applications = 0, expirationTime = now + 3600 }
  expect("readable in combat: live", "might_stormwind", "1h 0m", "good")
  combat = false
  auras[460939] = nil

  -- No C_Secrets: nothing is called missing during combat.
  local secrets = C_Secrets
  C_Secrets = nil
  auras[429959] = { applications = 3, expirationTime = now + 3600 }
  fire("UNIT_AURA")
  combat = true
  auras[429959] = nil
  expect("no secrecy API in combat: last state", "well_rested", "3/3  1h 0m", "dim")
  combat = false
  C_Secrets = secrets

  -- Switches, faction and a further buff.
  ns.SetRowEnabled("buff_well_rested", false)
  check(buff("well_rested") == nil and buff("might_stormwind") ~= nil, "each buff switchable")
  ns.SetRowEnabled("buff_might_stormwind", false)
  check(ns.Data.Collect()[1].key ~= "buffs", "both off: no section")
  ns.ResetRows()
  faction = "Horde"
  check(buff("might_stormwind") == nil and buff("well_rested") ~= nil, "stormwind only for the Alliance")
  faction = "Alliance"

  level = 59
  check(buff("well_rested") ~= nil, "well rested still shown at 59")
  level = 60
  check(buff("well_rested") == nil, "well rested gone at 60")
  check(buff("might_stormwind") ~= nil, "world buff stays at 60")
  check(ns.IsRowEnabled("buff_well_rested"), "level 60 does not change the saved switch")
  level = 46

  local list = ns.Buffs.LIST
  list[#list + 1] = { key = "third", spells = { 12345 } }
  ns.ResetRows()
  local option
  for _, row in ipairs(ns.Data.GetCatalog()[1].rows) do
    if row.id == "buff_third" then
      option = row
    end
  end
  check(option and option.label == "Dritter Buff", "new entry: option by itself")
  check(ns.IsRowEnabled("buff_third"), "new entry: on by default")
  expect("new entry: row by itself", "third", missing, "bad")
  table.remove(list)
  list[#list + 1] = { key = "unread", spells = { 23456 } }
  combat, restricted = true, true
  ns.ResetRows() -- already draws the window
  expect("never read and hidden: no guessing", "unread", "...", "dim")
  combat, restricted = false, false
  table.remove(list)
  ns.ResetRows()

  for name, value in pairs(backup) do
    _G[name] = value
  end
  GetTime = backup.GetTime
  C_Spell, C_Secrets, C_UnitAuras, UnitFactionGroup = nil, nil, nil, nil
  C_Timer.After = afterNow
end

-- Buff warnings: a clock and the timers run by hand.
do
  local backup = { InCombatLockdown = InCombatLockdown, UnitLevel = UnitLevel }
  local getTime, afterNow = GetTime, C_Timer.After
  local now, level, faction, restricted = 50000, 46, "Alliance", false
  local auras, timers, sounds = {}, {}, 0
  GetTime = function()
    return now
  end
  C_Timer.After = function(delay, fn)
    timers[#timers + 1] = { at = now + delay, fn = fn }
  end
  local function advance(seconds)
    local finish, steps = now + seconds, 0
    while true do
      local first
      for i, timer in ipairs(timers) do
        if timer.at <= finish and (not first or timer.at < timers[first].at) then
          first = i
        end
      end
      if not first then
        break
      end
      steps = steps + 1
      assert(steps < 2000, "timers never come to rest")
      local timer = table.remove(timers, first)
      now = math.max(now, timer.at)
      timer.fn()
    end
    now = finish
  end
  InCombatLockdown = function()
    return restricted
  end
  UnitLevel = function()
    return level
  end
  UnitFactionGroup = function()
    return faction
  end
  local names = { [429959] = "Gut erholt", [460939] = "Macht von Stormwind" }
  C_Spell = {
    GetSpellName = function(id)
      return names[id]
    end,
  }
  C_Secrets = {
    ShouldSpellAuraBeSecret = function()
      return restricted
    end,
  }
  C_UnitAuras = {
    GetPlayerAuraBySpellID = function(id)
      if not restricted then
        return auras[id]
      end
    end,
  }
  SOUNDKIT = { RAID_WARNING = 8959 }
  PlaySound = function()
    sounds = sounds + 1
  end
  local function fire(event)
    StubFrames[1].scripts.OnEvent(StubFrames[1], event, "player")
  end
  local function rested(seconds)
    auras[429959] = seconds and { applications = 3, expirationTime = now + seconds } or nil
    fire("UNIT_AURA")
  end
  local function worldBuff(seconds)
    auras[460939] = seconds and { applications = 0, expirationTime = now + seconds } or nil
    fire("UNIT_AURA")
  end
  local function restedText()
    return ns.UI.GetAlert("buff_well_rested")
  end
  local function worldText()
    return ns.UI.GetAlert("buff_might_stormwind")
  end
  local missingText = ns.L.BUFF_MISSING_ALERT_FMT:format("Gut erholt")
  local soonRested = ns.L.BUFF_SOON_ALERT_FMT:format("Gut erholt", 15)
  local soonWorld = ns.L.BUFF_SOON_ALERT_FMT:format("Macht von Stormwind", 5)

  -- Login: the auras come a moment late.
  ns.ResetRows()
  fire("PLAYER_ENTERING_WORLD")
  advance(1)
  rested(7200)
  advance(10)
  check(restedText() == nil and sounds == 0, "auras late at login: no false alarm")
  check(ns.IsRowEnabled("buff_well_rested_alert"), "well rested warning on by default")
  check(ns.IsRowEnabled("buff_might_stormwind_alert"), "world buff warning on by default")

  -- 15 minutes before the end: once, 10 seconds.
  rested(920)
  advance(19)
  check(restedText() == nil, "nothing before the last 15 minutes")
  advance(2)
  check(restedText() == soonRested and sounds == 1, "15 minutes left: message with sound")
  fire("UNIT_AURA")
  advance(7)
  check(restedText() == soonRested and sounds == 1, "message stays a few seconds")
  advance(4)
  check(restedText() == nil, "message gone after 10 seconds")
  fire("UNIT_AURA")
  advance(120)
  fire("UNIT_AURA")
  check(restedText() == nil and sounds == 1, "message only once")
  local held = auras[429959]
  auras[429959] = nil
  fire("UNIT_AURA")
  advance(1)
  auras[429959] = held
  fire("UNIT_AURA")
  advance(1)
  check(restedText() == nil and sounds == 1, "a short gap: no second message")

  -- Reload: the saved flag holds, also with the auras empty for a moment.
  local saved = auras[429959]
  check(IsiStatsCharDB.buffNoticed.well_rested == true, "message saved per character")
  fire("LOADING_SCREEN_ENABLED")
  auras[429959] = nil
  fire("UNIT_AURA")
  advance(30)
  check(restedText() == nil, "no warning during a loading screen")
  fire("LOADING_SCREEN_DISABLED")
  advance(1)
  auras[429959] = saved
  fire("UNIT_AURA")
  advance(10)
  check(restedText() == nil and sounds == 1, "no second message after a loading screen")

  -- Run out: the text stays.
  advance(760)
  check(restedText() == missingText and sounds == 2, "run out: lasting text with sound")
  advance(1800)
  fire("UNIT_AURA")
  check(restedText() == missingText and sounds == 2, "stays, no repeated sound")
  restricted = true
  fire("UNIT_AURA")
  advance(60)
  check(restedText() == missingText, "stays while the game hides the buff")
  restricted = false
  rested(7200)
  check(restedText() == nil, "gone at once with the buff")
  check(IsiStatsCharDB.buffNoticed.well_rested == nil, "a new buff can warn again")

  rested(nil)
  advance(1)
  check(restedText() == nil, "a short gap is no alarm")
  rested(7200)
  advance(5)
  check(restedText() == nil and sounds == 2, "renewed within the gap: nothing")

  rested(905)
  advance(7)
  check(restedText() == soonRested and sounds == 3, "next run: message again")
  rested(7200)
  check(restedText() == nil, "renewed: message gone at once")

  -- Hidden in combat: the clock still runs.
  rested(905)
  restricted = true
  fire("UNIT_AURA")
  advance(7)
  check(restedText() == soonRested and sounds == 4, "15 minutes also while hidden")
  advance(910)
  check(restedText() == missingText and sounds == 5, "run out also while hidden")
  restricted = false
  rested(7200)
  restricted = true
  fire("UNIT_AURA")
  advance(30)
  check(restedText() == nil, "hidden is not missing")
  restricted = false

  -- World buff: one message, no text when it is missing.
  worldBuff(3600)
  advance(3290)
  check(worldText() == nil, "world buff: nothing before 5 minutes")
  advance(11)
  check(worldText() == soonWorld and sounds == 6, "world buff: message at 5 minutes")
  advance(11)
  check(worldText() == nil, "world buff message gone after 10 seconds")
  advance(320)
  worldBuff(nil)
  advance(30)
  check(worldText() == nil and sounds == 6, "world buff missing: no text")

  -- Switches, level, faction.
  rested(nil)
  advance(4)
  check(restedText() == missingText and sounds == 7, "missing: text after the delay")
  ns.SetRowEnabled("buff_well_rested", false)
  check(restedText() == missingText, "row and warning switch separately")
  ns.SetRowEnabled("buff_well_rested_alert", false)
  check(restedText() == nil, "warning off: gone at once")
  ns.ResetRows()
  advance(4)
  check(restedText() == missingText, "warning on again")
  level = 60
  fire("PLAYER_LEVEL_UP")
  advance(5)
  check(restedText() == nil, "no well rested warning at 60")
  faction = "Horde"
  worldBuff(200)
  advance(5)
  check(worldText() == nil, "no stormwind warning for the Horde")

  ns.SetAllRows(false)
  check(restedText() == nil and worldText() == nil, "all off hides the warnings")
  for name, value in pairs(backup) do
    _G[name] = value
  end
  GetTime, C_Timer.After = getTime, afterNow
  C_Spell, C_Secrets, C_UnitAuras, UnitFactionGroup, SOUNDKIT, PlaySound = nil, nil, nil, nil, nil, nil
  ns.ResetRows()
end

-- Language follows the client: German strings only on a deDE client.
if clientLocale == "deDE" then
  check(ns.L.MELEE == "Nahkampf", "deDE client shows German")
else
  check(ns.L.MELEE == "Melee", clientLocale .. " client shows English")
  -- UTF-8 umlauts/eszett all start with byte 195 (0xC3); English text has none.
  for key, value in pairs(ns.L) do
    for i = 1, #value do
      if value:byte(i) == 195 then
        check(false, "non-ASCII (German) text in English locale: " .. key)
        break
      end
    end
  end
end

-- Combat visibility: fired through the real event handler.
local ev = StubFrames[1]
local frame = ns.UI.GetFrame()
local combat = false
InCombatLockdown = function()
  return combat
end
SlashCmdList.ISISTATS("free")
ns.Show()
ns.SetCombatMode("hide")
combat = true
ev.scripts.OnEvent(ev, "PLAYER_REGEN_DISABLED")
check(not frame:IsShown(), "hide in combat: hidden when combat starts")
combat = false
ev.scripts.OnEvent(ev, "PLAYER_REGEN_ENABLED")
check(frame:IsShown(), "hide in combat: back after combat")
ns.SetCombatMode("only")
check(not frame:IsShown(), "only in combat: hidden out of combat")
combat = true
ev.scripts.OnEvent(ev, "PLAYER_REGEN_DISABLED")
check(frame:IsShown(), "only in combat: shown when combat starts")
combat = false
ev.scripts.OnEvent(ev, "PLAYER_REGEN_ENABLED")
check(not frame:IsShown(), "only in combat: hidden after combat")
ns.SetCombatMode("always")
check(IsiStatsDB.combatMode == "always", "combat mode back to always")

-- Debug output is kept for reading from the SavedVariables file.
SlashCmdList.ISISTATS("debug")
check(type(IsiStatsDB.lastDebug) == "table" and #IsiStatsDB.lastDebug.lines > 3, "debug dump saved")

-- Lock
SlashCmdList.ISISTATS("lock")
check(IsiStatsDB.locked == true and ns.IsLocked(), "lock")
SlashCmdList.ISISTATS("unlock")
check(IsiStatsDB.locked == false, "unlock")

if failures > 0 then
  print(("load test: %d failure(s)"):format(failures))
  os.exit(1)
end
print("load test (" .. clientLocale .. "): all checks passed")
