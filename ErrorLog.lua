local _, ns = ...
local L = ns.L

-- Always-on capture of isiStatsForever's own Lua errors (from isiLive's error log).
-- Joins WoW's error handler chain - the previous handler (Blizzard's script
-- errors, BugSack, ...) is always called too - and keeps a bounded,
-- de-duplicated list in IsiStatsDB.errors. Captured even when the player has
-- script errors switched off. Shown with /isistats errors.

local ErrorLog = {}
ns.ErrorLog = ErrorLog

local MAX_ENTRIES = 30
local MAX_STACK = 1500
local FILTER_TOKEN = "isiStatsForever"

local db
local installed = false
local notified = false

local function now()
  return type(time) == "function" and time() or 0
end

local function addonVersion()
  local getMeta = type(C_AddOns) == "table" and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
  if type(getMeta) ~= "function" then
    return "?"
  end
  local ok, version = pcall(getMeta, "isiStatsForever", "Version")
  return ok and type(version) == "string" and version or "?"
end

local function record(message)
  if type(db) ~= "table" or type(db.errors) ~= "table" then
    return
  end
  if type(issecretvalue) == "function" and issecretvalue(message) then
    return
  end
  message = type(message) == "string" and message or tostring(message)
  local stack = type(debugstack) == "function" and debugstack(3) or ""
  if not message:find(FILTER_TOKEN, 1, true) and not stack:find(FILTER_TOKEN, 1, true) then
    return
  end
  local stamp = now()
  for _, entry in ipairs(db.errors) do
    if entry.message == message then
      entry.count = (entry.count or 1) + 1
      entry.last = stamp
      return
    end
  end
  table.insert(db.errors, 1, {
    message = message,
    count = 1,
    first = stamp,
    last = stamp,
    version = addonVersion(),
    stack = stack:sub(1, MAX_STACK),
  })
  while #db.errors > MAX_ENTRIES do
    table.remove(db.errors)
  end
  if not notified then
    notified = true
    print("|cff1e90ffisiStatsForever|r: " .. L.ERR_NOTICE)
  end
end

-- Points the log at the saved table (also after /isistats reset) and joins
-- the error handler chain once per session.
function ErrorLog.Install(savedDB)
  db = savedDB
  if type(db.errors) ~= "table" then
    db.errors = {}
  end
  if installed or type(geterrorhandler) ~= "function" or type(seterrorhandler) ~= "function" then
    return
  end
  installed = true
  local previous = geterrorhandler()
  seterrorhandler(function(message, ...)
    pcall(record, message)
    if type(previous) == "function" then
      return previous(message, ...)
    end
  end)
end

function ErrorLog.Print(out)
  local list = type(db) == "table" and db.errors or {}
  if #list == 0 then
    out(L.ERR_NONE)
    return
  end
  out(string.format(L.ERR_HEADER, #list))
  for i = 1, math.min(#list, 10) do
    local e = list[i]
    local when = type(date) == "function" and date("%Y-%m-%d %H:%M", e.last or 0) or ""
    out(string.format("%d. [%s, v%s, %dx] %s", i, when, e.version or "?", e.count or 1, e.message or ""))
  end
end

function ErrorLog.Clear()
  if type(db) == "table" then
    db.errors = {}
  end
end
