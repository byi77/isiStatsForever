local _, ns = ...
local L = ns.L
local Data = ns.Data
local U = ns.Util
local call, str = U.call, U.str

-- Every value row (settings page) and the class defaults.
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
  local buffs = {}
  for _, buff in ipairs(ns.Buffs.LIST) do
    local name = ns.Buffs.Name(buff)
    buffs[#buffs + 1] = { id = ns.Buffs.RowId(buff), label = name }
    local alertId = ns.Buffs.AlertId(buff)
    if alertId then
      buffs[#buffs + 1] = { id = alertId, label = string.format(L.BUFF_ALERT_OPT_FMT, name) }
    end
  end
  local warn = {
    { id = "warn_fishing", label = L.WARN_FISHING_OPT },
    { id = "warn_fishing_combat", label = L.WARN_FISHING_COMBAT_OPT },
    { id = "warn_tracking", label = L.WARN_TRACKING_OPT },
  }
  local _, classToken = call(UnitClass, "player")
  classToken = str(classToken)
  for _, warning in ipairs(ns.Warnings.LIST) do
    if ns.Warnings.AppliesTo(warning, classToken) then
      local id = ns.Warnings.OptionId(warning)
      warn[#warn + 1] = { id = id, label = L["WARN_" .. warning.key:upper() .. "_OPT"] }
    end
  end
  -- Same order as the window: status, level, attributes, offense, weapon
  -- skills, defense, then gear and session (collapsed by default).
  return {
    { key = "buffs", title = L.BUFF_SECTION, rows = buffs },
    {
      key = "warn",
      title = L.WARN_SECTION,
      rows = warn,
    },
    {
      key = "xp",
      title = L.XP_SECTION,
      rows = {
        { id = "xp_next", label = L.XP_OPT },
        { id = "xp_time", label = L.XP_TIME },
        { id = "xp_eta", label = L.XP_ETA_OPT },
      },
    },
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
      key = "skills",
      title = L.WEAPON_SKILLS,
      rows = {
        { id = "w_equipped", label = L.SKILLS_EQUIPPED },
        { id = "w_other", label = L.SKILLS_OTHER },
        { id = "w_vs", label = L.OPT_W_VS },
        { id = "w_vs_none", label = L.OPT_W_VS_NONE },
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
    {
      key = "gear",
      title = L.GEAR_SECTION,
      rows = {
        { id = "gear_durability", label = L.GEAR_DURABILITY },
        { id = "gear_ilvl", label = L.GEAR_ILVL },
      },
    },
    {
      key = "session",
      title = L.SESSION_SECTION,
      rows = {
        { id = "session_time", label = L.SESSION_TIME },
        { id = "session_xp", label = L.SESSION_XP },
        { id = "session_gold", label = L.SESSION_GOLD },
        { id = "session_gold_rate", label = L.SESSION_GOLD_RATE },
        { id = "session_kills", label = L.SESSION_KILLS },
        { id = "session_deaths", label = L.SESSION_DEATHS },
        { id = "xp_rate", label = L.XP_RATE },
        { id = "xp_kills", label = L.XP_KILLS_OPT },
        { id = "hearth", label = L.HEARTH },
      },
    },
  }
end

-- Class defaults: main stat, the class's attack value and weapon damage
-- (spell damage for casters), crit and hit (user decision 2026-11-28), defense
-- and the skills of the equipped weapons. Everything else starts off.
local CLASS_DEFAULTS = {
  WARRIOR = { "stat1", "m_ap", "m_dmg", "m_crit", "m_hit" },
  PALADIN = { "stat1", "m_ap", "m_dmg", "m_crit", "m_hit" },
  ROGUE = { "stat2", "m_ap", "m_dmg", "m_crit", "m_hit" },
  HUNTER = { "stat2", "r_ap", "r_dmg", "r_crit", "r_hit" },
  SHAMAN = { "stat4", "s_dmg", "s_crit", "s_hit" },
  DRUID = { "stat4", "s_dmg", "s_crit", "s_hit" },
  PRIEST = { "stat4", "s_dmg", "s_crit", "s_hit" },
  MAGE = { "stat4", "s_dmg", "s_crit", "s_hit" },
  WARLOCK = { "stat4", "s_dmg", "s_crit", "s_hit" },
}

-- Key value tiles under the level bar (main stat, power, DPS or spell crit).
-- Their rows are shown as tiles even when switched off as rows, and only once.
local CLASS_TILES = {
  WARRIOR = { "stat1", "m_ap", "m_dps" },
  PALADIN = { "stat1", "m_ap", "m_dps" },
  ROGUE = { "stat2", "m_ap", "m_dps" },
  HUNTER = { "stat2", "r_ap", "r_dps" },
  SHAMAN = { "stat4", "s_dmg", "s_crit" },
  DRUID = { "stat4", "s_dmg", "s_crit" },
  PRIEST = { "stat4", "s_dmg", "s_crit" },
  MAGE = { "stat4", "s_dmg", "s_crit" },
  WARLOCK = { "stat4", "s_dmg", "s_crit" },
}

function Data.GetTileIds()
  local _, classToken = call(UnitClass, "player")
  classToken = str(classToken)
  return classToken and CLASS_TILES[classToken] or { "stat1", "m_ap", "m_dps" }
end
local COMMON_DEFAULTS = {
  "warn_fishing",
  "warn_fishing_combat",
  "warn_tracking",
  "xp_next",
  "xp_time",
  "xp_eta",
  "d_def",
  "w_equipped",
  "w_vs",
  "w_vs_none",
}

local MAX_LEVEL_DEFAULTS = { "gear_durability", "gear_ilvl", "res2", "res3", "res4", "res5", "res6" }

function Data.GetDefaults()
  local defaults = {}
  local _, classToken = call(UnitClass, "player")
  -- A secret class token must not be used as a table key.
  classToken = str(classToken)
  for _, id in ipairs(classToken and CLASS_DEFAULTS[classToken] or { "stat1", "m_ap" }) do
    defaults[id] = true
  end
  for _, id in ipairs(COMMON_DEFAULTS) do
    defaults[id] = true
  end
  -- Level 60: gear and resistances matter (raids), melee classes see the
  -- miss chance vs. a raid boss. Rows nobody touched follow the level.
  if Data.AtMaxLevel() then
    for _, id in ipairs(MAX_LEVEL_DEFAULTS) do
      defaults[id] = true
    end
    if defaults.m_ap then
      defaults.m_miss = true
    end
  end
  for _, warning in ipairs(ns.Warnings.LIST) do
    defaults[ns.Warnings.OptionId(warning)] = true
  end
  for _, buff in ipairs(ns.Buffs.LIST) do
    defaults[ns.Buffs.RowId(buff)] = true
    local alertId = ns.Buffs.AlertId(buff)
    if alertId then
      defaults[alertId] = true
    end
  end
  return defaults
end
