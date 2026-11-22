local _, ns = ...
local L = ns.L
local U = ns.Util
local call, num, str, isSecret = U.call, U.num, U.str, U.isSecret

-- Buff reminder: the rows at the very top of the window and their warnings in
-- the middle of the screen.
local Buffs = {}
ns.Buffs = Buffs

-- ---------------------------------------------------------------- the list

-- A new buff is one entry here, nothing else: the row, its switches on the
-- settings page, the defaults (on) and the name in the player's language (from
-- the first spell ID) follow from it.
--
--   key      permanent id, the saved setting hangs on it - never rename it
--   spells   every spell ID of the buff (wowhead.com/forever or wago.tools
--            SpellName), the one with the wanted name first
--   stacks   optional: full stack count, fewer is shown yellow
--   minutes  optional: longest duration, only for the tooltip
--   faction  optional: "Alliance" or "Horde", others don't get the row
--   hideFromLevel  optional: from this player level on there is no row and
--                  no warning
--   warnMinutes    optional: this many minutes before the end one short screen
--                  message with sound; the row turns yellow then (else at 5)
--   warnMissing    optional: true = the screen text stays while the buff is
--                  missing, like the tracking warning
--
-- IDs, stacks and durations: game data 1.60.1.71037 (SpellName, SpellMisc,
-- SpellAuraOptions).
Buffs.LIST = {
  -- Well-Rested, from the sleeping bag: only more XP, so nothing at 60
  {
    key = "well_rested",
    spells = { 429959 },
    stacks = 3,
    minutes = 120,
    hideFromLevel = 60,
    warnMinutes = 15,
    warnMissing = true,
  },
  -- Might of Stormwind, world buff (three versions in the game data)
  {
    key = "might_stormwind",
    spells = { 460939, 460940, 1304678 },
    minutes = 60,
    faction = "Alliance",
    warnMinutes = 5,
  },
}

-- ---------------------------------------------------------------- state

local EXPIRES_SOON = 5 * 60 -- yellow row, for a buff without warnMinutes

-- key -> the last readable state: { present, count, expires }
local known = {}

function Buffs.RowId(buff)
  return "buff_" .. buff.key
end

-- The switch of the screen warnings, nil for a buff without any.
function Buffs.AlertId(buff)
  if buff.warnMinutes or buff.warnMissing then
    return "buff_" .. buff.key .. "_alert"
  end
  return nil
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

-- currentState, and a buff that ran out is missing: that is certain, also
-- while the game hides it.
local function resolvedState(buff, getAura, now)
  local state, old = currentState(buff, getAura)
  if state and state.present and state.expires and now and state.expires <= now then
    return { present = false }, false
  end
  return state, old
end

local function soonSeconds(buff)
  return buff.warnMinutes and buff.warnMinutes * 60 or EXPIRES_SOON
end

local function appliesTo(buff, faction, level)
  if buff.faction and buff.faction ~= faction then
    return false
  end
  return not (buff.hideFromLevel and level and level >= buff.hideFromLevel)
end

-- ---------------------------------------------------------------- warnings

-- After login and loading screens the auras are empty for a moment, and
-- renewing a buff can drop it briefly.
local SETTLE = 3
local NOTICE_SECONDS = 10
local TIMER_SLACK = 0.1

local noticed = {} -- key -> true once the "runs out soon" message came (saved per character)
local showing = {} -- key -> "missing" | "soon"
local noticeUntil = {}
local missingSince = {}
local loading, settledAt = false, 0
local wakeAt

function Buffs.Init(charDB)
  charDB.buffNoticed = charDB.buffNoticed or {}
  noticed = charDB.buffNoticed
end

local function wake(at, now)
  if type(C_Timer) ~= "table" or not C_Timer.After then
    return
  end
  if wakeAt and wakeAt > now and wakeAt <= at then
    return -- an earlier look is already planned, it plans the next one
  end
  wakeAt = at
  C_Timer.After(at - now + TIMER_SLACK, function()
    if wakeAt == at then
      wakeAt = nil
      Buffs.Update()
      ns.RequestRefresh()
    end
  end)
end

local function hideAlert(buff)
  if showing[buff.key] then
    showing[buff.key] = nil
    ns.UI.SetAlert(Buffs.RowId(buff), nil)
  end
end

local function showAlert(buff, kind, text, color)
  hideAlert(buff) -- so each kind of message has its own sound
  showing[buff.key] = kind
  ns.UI.SetAlert(Buffs.RowId(buff), text, false, color)
end

-- Missing counts after SETTLE, so a short gap neither warns nor allows a
-- second "runs out soon".
local function warnMissing(buff, now)
  if showing[buff.key] == "missing" then
    return
  end
  hideAlert(buff)
  local since = missingSince[buff.key] or now
  missingSince[buff.key] = since
  if now - since < SETTLE then
    wake(since + SETTLE, now)
    return
  end
  noticed[buff.key] = nil
  if buff.warnMissing then
    showAlert(buff, "missing", string.format(L.BUFF_MISSING_ALERT_FMT, Buffs.Name(buff)), "bad")
  end
end

local function warnSoon(buff, state, now)
  local key = buff.key
  if showing[key] == "missing" then
    hideAlert(buff) -- it is back
  end
  if not buff.warnMinutes or not state.expires then
    return
  end
  local left, threshold = state.expires - now, buff.warnMinutes * 60
  if left > threshold then
    noticed[key] = nil
    hideAlert(buff) -- renewed
    wake(state.expires - threshold, now)
    return
  end
  wake(state.expires, now)
  if not noticed[key] then
    noticed[key] = true
    local text = string.format(L.BUFF_SOON_ALERT_FMT, Buffs.Name(buff), math.ceil(left / 60))
    showAlert(buff, "soon", text, "warn")
    noticeUntil[key] = now + NOTICE_SECONDS
  end
  if showing[key] == "soon" then
    if now >= noticeUntil[key] then
      hideAlert(buff)
    else
      wake(noticeUntil[key], now)
    end
  end
end

-- Reads every buff (a fight starts from what was last readable, also with the
-- window hidden) and shows or takes away the screen warnings.
function Buffs.Update()
  local getAura, now = auraApi(), num(call(GetTime))
  if not getAura then
    return
  end
  local settled = now ~= nil and not loading and now >= settledAt
  if now and not loading and not settled then
    wake(settledAt, now)
  end
  local faction = str(call(UnitFactionGroup, "player"))
  local level = num(call(UnitLevel, "player"))
  for _, buff in ipairs(Buffs.LIST) do
    local state, old = resolvedState(buff, getAura, now)
    local alertId = Buffs.AlertId(buff)
    if not alertId or not ns.IsRowEnabled(alertId) or not appliesTo(buff, faction, level) then
      hideAlert(buff)
      missingSince[buff.key] = nil
    elseif settled and state then
      if state.present then
        missingSince[buff.key] = nil
        warnSoon(buff, state, now)
      elseif not old then -- "missing" counts only when the game really says it
        warnMissing(buff, now)
      end
    end
  end
end

-- true: a loading screen starts. false: it is over (also login).
function Buffs.SetLoading(value)
  loading = value
  missingSince = {}
  if not value then
    settledAt = (num(call(GetTime)) or 0) + SETTLE
  end
  Buffs.Update()
end

-- ---------------------------------------------------------------- rows

local function duration(seconds)
  return ns.LevelTime.Format(math.ceil(seconds / 60) * 60)
end

local function buffRow(buff, getAura, now)
  local state, old = resolvedState(buff, getAura, now)
  local row = { key = Buffs.RowId(buff), label = Buffs.Name(buff) }
  local lines = {}

  if state and state.present then
    local left = state.expires and now and state.expires - now or nil
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
      if left <= soonSeconds(buff) then
        color = "warn"
      end
    end
    row.value = #parts > 0 and table.concat(parts, "  ") or L.BUFF_ACTIVE
    row.color = color
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
