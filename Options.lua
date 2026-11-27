local _, ns = ...
local L = ns.L

-- Settings page (Game Menu -> Options -> AddOns -> isiStatsForever): one checkbox
-- per value, grouped like the window. Canvas layout so it works without the
-- typed RegisterAddOnSetting API, whose signature differs between clients.

local Options = {}
ns.Options = Options

local panel, category
local checkboxes = {}

local COL_W = 290
local ROW_H = 26
local SLIDER_W = 220

local function heading(parent, text, y)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fs:SetPoint("TOPLEFT", 16, y)
  fs:SetText(text)
  local line = parent:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(0.62, 0.72, 0.86, 0.18)
  line:SetHeight(1)
  line:SetPoint("TOPLEFT", 16, y - 18)
  line:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
  return y - 26
end

local function checkbox(parent, x, y, label, onClick)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetSize(24, 24)
  cb:SetPoint("TOPLEFT", x, y)
  -- Own label: the template's text region is named differently per client.
  local template = cb.Text or cb.text
  if type(template) == "table" and template.SetText then
    template:SetText("")
  end
  local fs = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  fs:SetPoint("LEFT", cb, "RIGHT", 4, 0)
  fs:SetWidth(COL_W - 40)
  fs:SetJustifyH("LEFT")
  fs:SetWordWrap(false)
  fs:SetText(label)
  cb:SetHitRectInsets(0, -(COL_W - 40), 0, 0)
  cb:SetScript("OnClick", function(self)
    onClick(self:GetChecked() and true or false)
  end)
  return cb
end

local function button(parent, text, width)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width or 130, 22)
  b:SetText(text)
  return b
end

-- Self-built slider (no template: their names differ between clients).
local function slider(parent, x, y, label, minV, maxV, step, onChange)
  local holder = CreateFrame("Frame", nil, parent)
  holder:SetPoint("TOPLEFT", x, y)
  holder:SetSize(COL_W * 2 - 40, 24)

  local fs = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  fs:SetPoint("LEFT", 4, 0)
  fs:SetText(label)

  local s = CreateFrame("Slider", nil, holder)
  s:SetOrientation("HORIZONTAL")
  s:SetSize(SLIDER_W, 16)
  s:SetPoint("LEFT", holder, "LEFT", COL_W - 10, 0)
  s:SetMinMaxValues(minV, maxV)
  s:SetValueStep(step)
  if s.SetObeyStepOnDrag then
    s:SetObeyStepOnDrag(true)
  end
  s:EnableMouse(true)
  s:EnableMouseWheel(true)

  local track = s:CreateTexture(nil, "BACKGROUND")
  track:SetColorTexture(0.20, 0.23, 0.29, 0.9)
  track:SetPoint("LEFT")
  track:SetPoint("RIGHT")
  track:SetHeight(4)
  local fill = s:CreateTexture(nil, "BORDER")
  fill:SetColorTexture(0.30, 0.62, 1.0, 0.9)
  fill:SetPoint("LEFT", track, "LEFT")
  fill:SetHeight(4)
  local thumb = s:CreateTexture(nil, "OVERLAY")
  thumb:SetColorTexture(0.96, 0.97, 1, 1)
  thumb:SetSize(8, 16)
  s:SetThumbTexture(thumb)

  local valueText = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  valueText:SetPoint("LEFT", s, "RIGHT", 10, 0)

  local syncing = false
  local function show(v)
    valueText:SetText(string.format("%d%%", v))
    local w = SLIDER_W * (v - minV) / (maxV - minV)
    fill:SetWidth(math.max(1, w))
  end
  s:SetScript("OnValueChanged", function(_, v)
    v = math.floor(v / step + 0.5) * step
    show(v)
    if not syncing then
      onChange(v)
    end
  end)
  s:SetScript("OnMouseWheel", function(self, delta)
    self:SetValue(math.max(minV, math.min(maxV, self:GetValue() + delta * step)))
  end)

  holder.SetSliderValue = function(_, v)
    syncing = true
    s:SetValue(v)
    show(v)
    syncing = false
  end
  return holder
end

function Options.Sync()
  if not panel then
    return
  end
  for id, cb in pairs(checkboxes) do
    cb:SetChecked(ns.IsRowEnabled(id))
  end
  if panel.dock then
    panel.dock:SetChecked(ns.IsDocked())
  end
  if panel.headers then
    panel.headers:SetChecked(ns.GetShowHeaders())
  end
  if panel.flash then
    panel.flash:SetChecked(ns.GetFlashChanges())
  end
  if panel.lock then
    panel.lock:SetChecked(ns.IsLocked())
  end
  if panel.chatHistory then
    panel.chatHistory:SetChecked(ns.ChatHistory.GetArrows())
  end
  if panel.meterReset then
    panel.meterReset:SetChecked(ns.GetResetMeterOnJoin())
  end
  if panel.combatBanner then
    panel.combatBanner:SetChecked(ns.GetCombatBanner())
  end
  if panel.flightTimes then
    panel.flightTimes:SetChecked(ns.GetFlightTimes())
    panel.flightBar:SetChecked(ns.GetFlightBar())
    panel.flightBarUnknown:SetChecked(ns.GetFlightBarUnknown())
  end
  if panel.combatHide then
    panel.combatHide:SetChecked(ns.GetCombatMode() == "hide")
    panel.combatOnly:SetChecked(ns.GetCombatMode() == "only")
  end
  if panel.alpha then
    panel.alpha:SetSliderValue(ns.GetAlpha())
  end
end

local function build()
  panel = CreateFrame("Frame")
  panel.name = "isiStatsForever"
  panel:Hide()

  local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("isi|cff1e90ffStats|r|cff8a96a8Forever|r")

  local intro = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  intro:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  intro:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
  intro:SetJustifyH("LEFT")
  intro:SetText(L.OPT_INTRO)

  local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 0, -62)
  scroll:SetPoint("BOTTOMRIGHT", -28, 8)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(2 * COL_W + 40, 100)
  scroll:SetScrollChild(content)
  scroll:SetScript("OnSizeChanged", function(_, w)
    content:SetWidth(w)
  end)

  local y = -4
  y = heading(content, L.OPT_GENERAL, y)
  panel.dock = checkbox(content, 16, y, L.OPT_DOCK, function(checked)
    if checked ~= ns.IsDocked() then
      ns.ToggleDock()
    end
  end)
  local open = button(content, L.OPT_OPEN)
  open:SetPoint("TOPLEFT", 16 + COL_W, y - 1)
  open:SetScript("OnClick", function()
    ns.Show()
  end)
  y = y - ROW_H - 4

  panel.headers = checkbox(content, 16, y, L.OPT_HEADERS, function(checked)
    ns.SetShowHeaders(checked)
  end)
  panel.flash = checkbox(content, 16 + COL_W, y, L.OPT_FLASH, function(checked)
    ns.SetFlashChanges(checked)
  end)
  y = y - ROW_H - 4

  panel.lock = checkbox(content, 16, y, L.OPT_LOCK, function(checked)
    ns.SetLocked(checked)
  end)
  panel.chatHistory = checkbox(content, 16 + COL_W, y, L.OPT_CHAT_HISTORY, function(checked)
    ns.ChatHistory.SetArrows(checked)
  end)
  y = y - ROW_H - 4

  -- Combat visibility: two boxes that exclude each other (none = always).
  panel.combatHide = checkbox(content, 16, y, L.OPT_COMBAT_HIDE, function(checked)
    ns.SetCombatMode(checked and "hide" or "always")
  end)
  panel.combatOnly = checkbox(content, 16 + COL_W, y, L.OPT_COMBAT_ONLY, function(checked)
    ns.SetCombatMode(checked and "only" or "always")
  end)
  y = y - ROW_H - 4

  panel.meterReset = checkbox(content, 16, y, L.OPT_METER_RESET, function(checked)
    ns.SetResetMeterOnJoin(checked)
  end)
  panel.combatBanner = checkbox(content, 16 + COL_W, y, L.OPT_COMBAT_BANNER, function(checked)
    ns.SetCombatBanner(checked)
  end)
  y = y - ROW_H - 4

  panel.flightTimes = checkbox(content, 16, y, L.OPT_FLIGHT_TIMES, function(checked)
    ns.SetFlightTimes(checked)
  end)
  panel.flightBar = checkbox(content, 16 + COL_W, y, L.OPT_FLIGHT_BAR, function(checked)
    ns.SetFlightBar(checked)
  end)
  y = y - ROW_H - 4
  panel.flightBarUnknown = checkbox(content, 16 + COL_W, y, L.OPT_FLIGHT_BAR_UNKNOWN, function(checked)
    ns.SetFlightBarUnknown(checked)
  end)
  y = y - ROW_H - 4

  panel.alpha = slider(content, 16, y, L.OPT_ALPHA, 0, 100, 5, function(v)
    ns.SetAlpha(v)
  end)
  y = y - ROW_H - 8

  local defaults = button(content, L.OPT_DEFAULTS)
  defaults:SetPoint("TOPLEFT", 16, y)
  defaults:SetScript("OnClick", function()
    ns.ResetRows()
    Options.Sync()
  end)
  local allOn = button(content, L.OPT_ALL_ON, 100)
  allOn:SetPoint("LEFT", defaults, "RIGHT", 8, 0)
  allOn:SetScript("OnClick", function()
    ns.SetAllRows(true)
    Options.Sync()
  end)
  local allOff = button(content, L.OPT_ALL_OFF, 100)
  allOff:SetPoint("LEFT", allOn, "RIGHT", 8, 0)
  allOff:SetScript("OnClick", function()
    ns.SetAllRows(false)
    Options.Sync()
  end)
  y = y - 36

  for _, section in ipairs(ns.Data.GetCatalog()) do
    y = heading(content, section.title, y)
    for i, row in ipairs(section.rows) do
      local col = (i - 1) % 2
      local x = 16 + col * COL_W
      local id = row.id
      checkboxes[id] = checkbox(content, x, y, row.label, function(checked)
        ns.SetRowEnabled(id, checked)
      end)
      if col == 1 or i == #section.rows then
        y = y - ROW_H
      end
    end
    y = y - 8
  end
  content:SetHeight(-y + 8)

  panel:SetScript("OnShow", Options.Sync)
  -- Callbacks the settings frame may call on canvas pages.
  panel.OnCommit = function() end
  panel.OnRefresh = Options.Sync
  panel.OnDefault = function()
    ns.ResetRows()
    Options.Sync()
  end
end

function Options.Register()
  if panel then
    return
  end
  build()
  if type(Settings) == "table" and Settings.RegisterCanvasLayoutCategory then
    category = Settings.RegisterCanvasLayoutCategory(panel, "isiStatsForever")
    Settings.RegisterAddOnCategory(category)
  elseif type(InterfaceOptions_AddCategory) == "function" then
    InterfaceOptions_AddCategory(panel)
  end
end

function Options.Open()
  if category and type(Settings) == "table" and Settings.OpenToCategory then
    local id = category.GetID and category:GetID() or category.ID
    Settings.OpenToCategory(id)
  elseif type(InterfaceOptionsFrame_OpenToCategory) == "function" then
    InterfaceOptionsFrame_OpenToCategory(panel)
    InterfaceOptionsFrame_OpenToCategory(panel)
  end
end
