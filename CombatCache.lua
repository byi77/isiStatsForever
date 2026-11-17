local _, ns = ...
local L = ns.L
local Data = ns.Data
local U = ns.Util
local secretFns = U.secretFns

-- Combat cache and the list of APIs that returned secret values.
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
