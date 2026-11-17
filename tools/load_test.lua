local dir = arg[1]
local function stub(name)
  local o = { __name = name, scripts = {}, shown = false, scale = 1 }
  return setmetatable(o, {
    __index = function(t, k)
      return function(self, ...)
        return nil
      end
    end,
  })
end
local frames = {}
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
    return stub("fs")
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
    end
  end,
}
local ns = {}
for _, f in ipairs({ "Locale.lua", "Data.lua", "UI.lua", "Options.lua", "Core.lua" }) do
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
print("ALL OK, scale", IsiStatsDB.scale, "alpha", IsiStatsDB.alpha)
