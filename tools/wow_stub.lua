---@diagnostic disable: undefined-global
-- Runs in standalone Lua (io, os, loadfile), not in the WoW client.
-- Shared WoW stub environment for the tools: defines the WoW globals the
-- addon reads, loads every file listed in isiStatsForever.toc and fires
-- ADDON_LOADED + PLAYER_LOGIN through the real event handler.
-- Usage: local ns = assert(loadfile("tools/wow_stub.lua"))(dir, clientLocale, setup)
-- `setup` (optional) runs after the default globals and before the addon
-- loads, to override class, gear, skills, ...
local dir, clientLocale, setup = ...
clientLocale = clientLocale or "deDE"
IsiStatsDB, IsiStatsCharDB = nil, nil
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
StubFrames = frames -- registered event frames, for tests that dispatch events
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
  return "Interface/AddOns/isiStatsForever/Data.lua:1: in function"
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
  return clientLocale
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
GetCombatRatingBonus = function()
  return 0
end
GetHitModifier = function()
  return 0
end
GetOffhandHitModifier = GetHitModifier
GetRangedHitModifier = GetHitModifier
GetExpertise = function()
  return 0, 0, 0
end
GetGlancingBlowChance = function()
  return 0.4
end
GetGlancingBlowPenalty = function()
  return 0.25
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
-- Client constant for the chat window count (NUM_CHAT_WINDOWS is only a
-- deprecation shim in Forever and stays undefined here).
Constants = { ChatFrameConstants = { MaxChatWindows = 10 } }
-- Chat input with the game's history methods (history line list + Alt mode).
ChatFrame1EditBox = {
  history = {},
  text = "",
  hooks = {},
  GetText = function(self)
    return self.text
  end,
  -- Sets the text like the game: OnTextChanged with userInput.
  SetText = function(self, text, userInput)
    self.text = text
    for _, fn in ipairs(self.hooks.OnTextChanged or {}) do
      fn(self, userInput and true or false)
    end
  end,
  HookScript = function(self, script, fn)
    self.hooks[script] = self.hooks[script] or {}
    table.insert(self.hooks[script], fn)
  end,
  Fire = function(self, script)
    for _, fn in ipairs(self.hooks[script] or {}) do
      fn(self)
    end
  end,
  FireKey = function(self, script, key)
    for _, fn in ipairs(self.hooks[script] or {}) do
      fn(self, key)
    end
  end,
  AddHistoryLine = function(self, line)
    self.history[#self.history + 1] = line
  end,
  SetHistoryLines = function() end,
  SetAltArrowKeyMode = function(self, value)
    self.altArrow = value
  end,
}
hooksecurefunc = hooksecurefunc
  or function(tbl, name, fn)
    local orig = tbl[name]
    tbl[name] = function(...)
      local r = { orig(...) }
      fn(...)
      return (table.unpack or unpack)(r)
    end
  end
if setup then
  setup()
end
local ns = {}
local tocFiles = {}
for line in io.lines(dir .. "/isiStatsForever.toc") do
  line = line:gsub("\r", "")
  if line:match("%.lua$") then
    tocFiles[#tocFiles + 1] = line
  end
end
assert(#tocFiles > 0, "no files in isiStatsForever.toc")
for _, f in ipairs(tocFiles) do
  assert(loadfile(dir .. "/" .. f))("isiStatsForever", ns)
end
local ev = frames[1]
ev.scripts.OnEvent(ev, "ADDON_LOADED", "isiStatsForever")
ev.scripts.OnEvent(ev, "PLAYER_LOGIN")
ev.scripts.OnEvent(ev, "UNIT_STATS", "player")
return ns
