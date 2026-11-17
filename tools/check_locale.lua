-- Locale gate (adapted from isiLive's locale-drift and format-string checks):
-- enUS and deDE in Locale.lua must have the same keys and the same format
-- placeholders per key. Exit 1 on any difference.
local path = (arg and arg[1]) or "Locale.lua"
local fh = assert(io.open(path, "r"))
local text = fh:read("*a")
fh:close()

local function tableBody(startPattern)
  local s = text:find(startPattern)
  assert(s, "table not found: " .. startPattern)
  local depth, i = 0, text:find("{", s, true)
  local open = i
  while i <= #text do
    local c = text:sub(i, i)
    if c == "{" then
      depth = depth + 1
    elseif c == "}" then
      depth = depth - 1
      if depth == 0 then
        return text:sub(open + 1, i - 1)
      end
    end
    i = i + 1
  end
  error("unterminated table: " .. startPattern)
end

local function entries(body)
  local out = {}
  for key, value in body:gmatch('\n%s*([A-Z][A-Z0-9_]*)%s*=%s*"(.-)",') do
    out[key] = value
  end
  return out
end

local function placeholders(s)
  local list = {}
  for p in s:gsub("%%%%", ""):gmatch("%%[%-%+ #0]*%d*%.?%d*[dsfx]") do
    list[#list + 1] = p:sub(-1)
  end
  return table.concat(list, ",")
end

local en = entries(tableBody("local L = {"))
local de = entries(tableBody("local de = {"))
local failures = 0
local function fail(msg)
  failures = failures + 1
  print("FAIL " .. msg)
end

for key, value in pairs(en) do
  if de[key] == nil then
    fail("deDE missing key " .. key)
  elseif placeholders(value) ~= placeholders(de[key]) then
    fail(("placeholder mismatch %s: enUS [%s] deDE [%s]"):format(key, placeholders(value), placeholders(de[key])))
  end
end
for key in pairs(de) do
  if en[key] == nil then
    fail("enUS missing key " .. key)
  end
end

local count = 0
for _ in pairs(en) do
  count = count + 1
end
if failures > 0 then
  print(("locale check: %d problem(s)"):format(failures))
  os.exit(1)
end
print(("locale check: %d keys, enUS = deDE"):format(count))
