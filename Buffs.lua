local _, ns = ...
local L = ns.L
local U = ns.Util
local call, num, str, isSecret = U.call, U.num, U.str, U.isSecret

-- Buff reminder: the rows at the very top of the window.
local Buffs = {}
ns.Buffs = Buffs

-- ---------------------------------------------------------------- the list

-- A new buff is one entry here, nothing else: the row, its switch on the
-- settings page, the default (on) and the name in the player's language (from
-- the first spell ID) follow from it.
--
--   key      permanent id, the saved setting hangs on it - never rename it
--   spells   every spell ID of the buff (wowhead.com/forever or wago.tools
--            SpellName), the one with the wanted name first
--   stacks   optional: full stack count, fewer is shown yellow
--   minutes  optional: longest duration, only for the tooltip
--   faction  optional: "Alliance" or "Horde", others don't get the row
--   hideFromLevel  optional: from this player level on there is no row
--
-- IDs, stacks and durations: game data 1.60.1.71037 (SpellName, SpellMisc,
-- SpellAuraOptions).
Buffs.LIST = {
  -- Well-Rested, from the sleeping bag: only more XP, so nothing at 60
  { key = "well_rested", spells = { 429959 }, stacks = 3, minutes = 120, hideFromLevel = 60 },
  -- Might of Stormwind, world buff (three versions in the game data)
  { key = "might_stormwind", spells = { 460939, 460940, 1304678 }, minutes = 60, faction = "Alliance" },
}

-- ---------------------------------------------------------------- state

local EXPIRES_SOON = 5 * 60 -- seconds left from which the row is yellow

-- key -> the last readable state: { present, count, expires }
local known = {}

function Buffs.RowId(buff)
  return "buff_" .. buff.key
end

function Buffs.Name(buff)
  local getName = type(C_Spell) == "table" and C_Spell.GetSpellName or nil
  return str(call(getName, buff.spells[1])) or ("#" .. buff.spells[1])
end

-- In combat the aura API answers nil for a hidden buff, which looks exactly
-- like a missing one. So nil only counts as missing when the aura is readable.
local function hiddenNow(spellID)
  local ask = type(C_Secrets) == "table" and C_Secrets.ShouldSpellAuraBeSecret or nil
  local hidden = call(ask, spellID)
  if isSecret(hidden) then
    return true
  elseif hidden ~= nil then
    return hidden == true
  end
  return type(InCombatLockdown) == "function" and InCombatLockdown() and true or false
end

-- The state, or nil when the game does not say.
local function readNow(buff, getAura)
  local unknown = false
  for _, spellID in ipairs(buff.spells) do
    local aura = call(getAura, spellID)
    if isSecret(aura) then
      unknown = true
    elseif type(aura) == "table" then
      local count, expires = num(aura.applications), num(aura.expirationTime)
      if count and expires then
        return { present = true, count = math.max(1, count), expires = expires > 0 and expires or nil }
      end
      unknown = true
    elseif hiddenNow(spellID) then
      unknown = true
    end
  end
  if unknown then
    return nil
  end
  return { present = false }
end

local function auraApi()
  return type(C_UnitAuras) == "table" and C_UnitAuras.GetPlayerAuraBySpellID or nil
end

-- Returns state and whether it is only the last readable one.
local function currentState(buff, getAura)
  local state = readNow(buff, getAura)
  if state then
    known[buff.key] = state
    return state, false
  end
  return known[buff.key], true
end

-- On aura events, also with the window hidden: a fight starts from what was
-- last readable.
function Buffs.Read()
  local getAura = auraApi()
  if not getAura then
    return
  end
  for _, buff in ipairs(Buffs.LIST) do
    currentState(buff, getAura)
  end
end

-- ---------------------------------------------------------------- rows

local function duration(seconds)
  return ns.LevelTime.Format(math.ceil(seconds / 60) * 60)
end

local function buffRow(buff, getAura, now)
  local state, old = currentState(buff, getAura)
  local row = { key = Buffs.RowId(buff), label = Buffs.Name(buff) }
  local lines = {}

  if state and state.present then
    local left = state.expires and now and state.expires - now or nil
    if left and left <= 0 then
      -- Run out: that is certain, also while the game hides the buff.
      state, old = { present = false }, false
    else
      local parts, color = {}, "good"
      if buff.stacks then
        parts[#parts + 1] = string.format("%d/%d", state.count, buff.stacks)
        lines[#lines + 1] = string.format(L.BUFF_STACKS_FMT, state.count, buff.stacks)
        if state.count < buff.stacks then
          color = "warn"
        end
      end
      if left then
        parts[#parts + 1] = duration(left)
        lines[#lines + 1] = string.format(L.BUFF_LEFT_FMT, duration(left))
        if left <= EXPIRES_SOON then
          color = "warn"
        end
      end
      row.value = #parts > 0 and table.concat(parts, "  ") or L.BUFF_ACTIVE
      row.color = color
    end
  end

  if not state then
    row.value = "..."
  elseif not state.present then
    row.value = L.BUFF_MISSING
    row.color, row.labelColor = "bad", "bad"
    lines[#lines + 1] = L.BUFF_MISSING_TIP
  end
  if buff.minutes then
    lines[#lines + 1] = string.format(L.BUFF_MAX_FMT, duration(buff.minutes * 60))
  end
  if old then
    row.color, row.labelColor, row.stale = "dim", "dim", true
    lines[#lines + 1] = "\n" .. L.STALE_TIP
  end
  row.tip = #lines > 0 and table.concat(lines, "\n") or nil
  return row
end

local function appliesTo(buff, faction, level)
  if buff.faction and buff.faction ~= faction then
    return false
  end
  return not (buff.hideFromLevel and level and level >= buff.hideFromLevel)
end

function Buffs.Section()
  local getAura = auraApi()
  if not getAura then
    return nil
  end
  local faction = str(call(UnitFactionGroup, "player"))
  local level = num(call(UnitLevel, "player"))
  local now = num(call(GetTime))
  local rows = {}
  for _, buff in ipairs(Buffs.LIST) do
    if ns.IsRowEnabled(Buffs.RowId(buff)) and appliesTo(buff, faction, level) then
      rows[#rows + 1] = buffRow(buff, getAura, now)
    end
  end
  return { key = "buffs", title = L.BUFF_SECTION, rows = rows }
end
