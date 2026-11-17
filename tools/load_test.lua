local dir = arg[1]
local function stub(name)
  local o = { __name = name, scripts = {}, shown = false, scale = 1 }
  return setmetatable(o, {
    -- WoW widget methods are CamelCase; plain lowercase fields stay nil, as
    -- on a real frame table.
    __index = function(t, k)
      if type(k) == "string" and k:match("^%l") then
        return nil
      end
      return function(self, ...)
        return nil
      end
    end,
  })
end
local frames = {}
flashPlays = 0
function CreateFrame(kind, name, parent, template)
  local f = stub(kind)
  f.SetScript = function(self, k, fn)
    self.scripts[k] = fn
  end
  f.GetScript = function(self, k)
    return self.scripts[k]
  end
  f.HookScript = function(self, k, fn)
    local old = self.scripts[k]
    self.scripts[k] = function(...)
      if old then
        old(...)
      end
      fn(...)
    end
  end
  f.Show = function(self)
    self.shown = true
    if self.scripts.OnShow then
      self.scripts.OnShow(self)
    end
  end
  f.Hide = function(self)
    self.shown = false
    if self.scripts.OnHide then
      self.scripts.OnHide(self)
    end
  end
  f.IsShown = function(self)
    return self.shown
  end
  f.CreateFontString = function()
    local fs = stub("fs")
    fs.CreateAnimationGroup = function()
      local group = stub("anim")
      group.CreateAnimation = function()
        return stub("alpha")
      end
      group.Play = function()
        flashPlays = flashPlays + 1
      end
      return group
    end
    return fs
  end
  f.CreateTexture = function()
    return stub("tex")
  end
  f.GetFrameLevel = function()
    return 1
  end
  f.SetScale = function(self, s)
    self.scale = s
  end
  f.GetScale = function(self)
    return self.scale
  end
  f.GetEffectiveScale = function(self)
    return self.scale
  end
  f.GetLeft = function()
    return 100
  end
  f.GetTop = function()
    return 800
  end
  f.GetPoint = function()
    return "TOPLEFT", nil, "BOTTOMLEFT", 100, 800
  end
  f.GetChecked = function()
    return true
  end
  f.RegisterEvent = function(self, e)
    frames[#frames + 1] = self
  end
  f.RegisterUnitEvent = f.RegisterEvent
  if name then
    _G[name] = f
  end
  return f
end
local errorHandler = function() end
geterrorhandler = function()
  return errorHandler
end
seterrorhandler = function(fn)
  errorHandler = fn
end
debugstack = function()
  return "Interface/AddOns/isiStats/Data.lua:1: in function"
end
time = os.time
date = os.date
CreateColor = function(r, g, b, a)
  return { r, g, b, a }
end
UIParent = CreateFrame("Frame")
CharacterFrame = CreateFrame("Frame")
GameTooltip = stub("tt")
GetLocale = function()
  return "deDE"
end
issecretvalue = function()
  return false
end
C_Timer = {
  After = function(_, fn)
    fn()
  end,
}
GetCursorPosition = function()
  return 400, 500
end
Settings = {
  RegisterCanvasLayoutCategory = function()
    return {
      GetID = function()
        return 1
      end,
    }
  end,
  RegisterAddOnCategory = function() end,
  OpenToCategory = function() end,
}
SlashCmdList = {}
strtrim = function(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end
UnitClass = function()
  return "Krieger", "WARRIOR"
end
UnitLevel = function()
  return 60
end
UnitStat = function()
  return 50, 80, 30, 0
end
UnitHealthMax = function()
  return 4000
end
UnitPowerMax = function()
  return 0
end
UnitAttackPower = function()
  return 900, 200, 0
end
UnitDamage = function()
  return 100, 180, 0, 0
end
UnitAttackSpeed = function()
  return 2.6, nil
end
UnitArmor = function()
  return 3000, 3500
end
C_SkillInfo = {
  GetSkillLineInfoByID = function(id)
    if id == 95 then
      return { name = "Verteidigung", rank = 300, maxRank = 300, modifier = 5 }
    elseif id == 162 then
      return { name = "Unbewaffnet", rank = 290, maxRank = 300, modifier = 0 }
    end
  end,
}
local ns = {}
local tocFiles = {}
for line in io.lines(dir .. "/isiStats.toc") do
  line = line:gsub("\r", "")
  if line:match("%.lua$") then
    tocFiles[#tocFiles + 1] = line
  end
end
assert(#tocFiles > 0, "no files in isiStats.toc")
for _, f in ipairs(tocFiles) do
  assert(loadfile(dir .. "/" .. f))("isiStats", ns)
end
local ev = frames[1]
ev.scripts.OnEvent(ev, "ADDON_LOADED", "isiStats")
ev.scripts.OnEvent(ev, "PLAYER_LOGIN")
ev.scripts.OnEvent(ev, "UNIT_STATS", "player")
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
for _, id in ipairs({ "stat1", "m_ap", "d_def", "w_equipped", "w_vs" }) do
  check(ns.IsRowEnabled(id), "default on: " .. id)
end
for _, id in ipairs({ "stat4", "s_dmg", "r_ap", "w_other", "m_dps" }) do
  check(not ns.IsRowEnabled(id), "default off: " .. id)
end
check(IsiStatsDB.showHeaders == false, "headers hidden by default")
check(IsiStatsDB.alpha == 55, "alpha saved")
check(IsiStatsDB.scale == 1, "scale reset to 1")

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
-- (debugstack is stubbed to point into isiStats, so the filter is the message
-- for the foreign case).
debugstack = function()
  return "Interface/AddOns/OtherAddon/x.lua:1"
end
errorHandler("Interface/AddOns/OtherAddon/x.lua:1: boom")
check(#IsiStatsDB.errors == 0, "foreign error not logged")
errorHandler("Interface/AddOns/isiStats/Data.lua:42: attempt to index nil")
errorHandler("Interface/AddOns/isiStats/Data.lua:42: attempt to index nil")
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

if failures > 0 then
  print(("load test: %d failure(s)"):format(failures))
  os.exit(1)
end
print("load test: all checks passed")
