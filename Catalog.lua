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
        { id = "w_vs_none", label = L.OPT_W_VS_NONE },
        { id = "d_def", label = L.DEFENSE },
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
local COMMON_DEFAULTS = { "d_def", "w_equipped", "w_vs", "w_vs_none" }

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
