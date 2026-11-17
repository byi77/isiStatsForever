local _, ns = ...
local L = ns.L

-- isiLive "modern" look: graphite surface, hairline border, cool accent,
-- dimmed labels so the values carry the weight.
local C = {
  bg = { 0.043, 0.047, 0.060, 0.94 },
  title = { 0.090, 0.098, 0.122, 0.95 },
  border = { 0.62, 0.72, 0.86, 0.16 },
  heading = { 0.96, 0.97, 1 },
  section = { 0.60, 0.67, 0.78 },
  sectionBg = { 0.105, 0.115, 0.145, 0.85 },
  label = { 0.70, 0.74, 0.82 },
  value = { 0.96, 0.97, 1 },
  alt = { 1, 1, 1, 0.028 },
  hover = { 0.3, 0.65, 1, 0.10 },
  accent = { 0.46, 0.72, 1.0 },
  good = { 0.45, 0.85, 0.45 },
  warn = { 1, 0.82, 0.18 },
  bad = { 1, 0.42, 0.38 },
  dim = { 0.44, 0.51, 0.62 },
  close = { 1, 0.35, 0.35 },
}
ns.Colors = C

local WIDTH = 270
local PAD = 8
local TITLE_H = 22
local HEADER_H = 18
local ROW_H = 15
local SECTION_GAP = 4
local HEADERLESS_GAP = 8
local WHITE = "Interface\\Buttons\\WHITE8X8"
local GRIP_SIZE = 14
local MIN_SCALE, MAX_SCALE = 0.5, 2

local UI = {}
ns.UI = UI

local frame, rows, rowCount = nil, {}, 0
local bgAlpha = 1 -- background opacity factor (0..1); text is never faded

local function rgba(c, a)
  return c[1], c[2], c[3], (c[4] or 1) * a
end

local function setColor(fs, key, fallback)
  local c = C[key or fallback] or C[fallback]
  fs:SetTextColor(c[1], c[2], c[3])
end

local function showTip(owner)
  local data = owner.data
  if not data or not data.tip then
    return
  end
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:AddLine(data.label or "", 1, 1, 1)
  GameTooltip:AddLine(data.tip, C.label[1], C.label[2], C.label[3], true)
  GameTooltip:Show()
end

local function acquireRow(index)
  local row = rows[index]
  if row then
    return row
  end
  row = CreateFrame("Button", nil, frame)
  row:SetHeight(ROW_H)
  row.bg = row:CreateTexture(nil, "BACKGROUND")
  row.bg:SetAllPoints()
  row.bg:SetTexture(WHITE)
  row.hl = row:CreateTexture(nil, "HIGHLIGHT")
  row.hl:SetAllPoints()
  row.hl:SetColorTexture(C.hover[1], C.hover[2], C.hover[3], C.hover[4])
  row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.label:SetPoint("LEFT", 6, 0)
  row.label:SetJustifyH("LEFT")
  row.label:SetWordWrap(false)
  row.value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.value:SetPoint("RIGHT", -6, 0)
  row.value:SetJustifyH("RIGHT")
  row.value:SetWordWrap(false)
  row.label:SetPoint("RIGHT", row.value, "LEFT", -6, 0)
  row:RegisterForClicks("LeftButtonUp")
  row:SetScript("OnEnter", showTip)
  row:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  row:SetScript("OnClick", function(self)
    if self.sectionKey then
      ns.ToggleSection(self.sectionKey)
    end
  end)
  rows[index] = row
  return row
end

local function layoutHeader(row, section, collapsed, y)
  row:SetHeight(HEADER_H)
  row:ClearAllPoints()
  row:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, y)
  row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, y)
  row.bg:SetVertexColor(rgba(C.sectionBg, bgAlpha))
  row.label:SetFontObject("GameFontNormalSmall")
  row.label:SetText(string.upper(section.title))
  setColor(row.label, "section")
  row.value:SetFontObject("GameFontNormalSmall")
  row.value:SetText(collapsed and "+" or "-")
  setColor(row.value, "dim")
  row.sectionKey = section.key
  row.data = nil
  row:Show()
end

local function layoutRow(row, data, alt, y)
  row:SetHeight(ROW_H)
  row:ClearAllPoints()
  row:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, y)
  row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, y)
  row.alt = alt
  if alt then
    row.bg:SetVertexColor(rgba(C.alt, bgAlpha))
  else
    row.bg:SetVertexColor(0, 0, 0, 0)
  end
  row.label:SetFontObject("GameFontHighlightSmall")
  row.label:SetText(data.label or "")
  setColor(row.label, data.labelColor, "label")
  row.value:SetFontObject("GameFontHighlightSmall")
  row.value:SetText(data.value or "")
  setColor(row.value, data.color, "value")
  row.sectionKey = nil
  row.data = data
  row:Show()
end

-- showHeaders false: no section headers; then nothing can be collapsed, so
-- every section shows its rows, separated by a small gap.
function UI.Render(sections, collapsedMap, showHeaders)
  if not frame then
    return
  end
  rowCount = 0
  local y = -TITLE_H - 6
  for si, section in ipairs(sections) do
    if si > 1 then
      y = y - (showHeaders and SECTION_GAP or HEADERLESS_GAP)
    end
    local collapsed = showHeaders and collapsedMap and collapsedMap[section.key]
    if showHeaders then
      rowCount = rowCount + 1
      layoutHeader(acquireRow(rowCount), section, collapsed, y)
      y = y - HEADER_H - 1
    end
    if not collapsed then
      for ri, data in ipairs(section.rows) do
        rowCount = rowCount + 1
        layoutRow(acquireRow(rowCount), data, ri % 2 == 0, y)
        y = y - ROW_H
      end
    end
  end
  for i = rowCount + 1, #rows do
    rows[i]:Hide()
  end
  -- Bottom margin leaves room for the resize grip.
  frame:SetHeight(-y + GRIP_SIZE + 2)
end

-- Bottom-right grip: dragging it scales the whole window (its height
-- follows the content, so size means scale). The top-left corner stays put.
local function createResizeGrip()
  local grip = CreateFrame("Button", nil, frame)
  grip:SetSize(GRIP_SIZE, GRIP_SIZE)
  grip:SetPoint("BOTTOMRIGHT", -1, 1)
  grip:SetFrameLevel(frame:GetFrameLevel() + 10)
  grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
  grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")

  local leftPx, topPx, keepCorner
  local function update()
    local cursorX = GetCursorPosition()
    local parentScale = UIParent:GetEffectiveScale()
    local scale = (cursorX - leftPx) / (WIDTH * parentScale)
    scale = math.max(MIN_SCALE, math.min(MAX_SCALE, scale))
    frame:SetScale(scale)
    if keepCorner then
      local eff = frame:GetEffectiveScale()
      frame:ClearAllPoints()
      frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", leftPx / eff, topPx / eff)
    end
  end

  grip:SetScript("OnMouseDown", function(self, mouseButton)
    if mouseButton ~= "LeftButton" then
      return
    end
    local eff = frame:GetEffectiveScale()
    leftPx, topPx = frame:GetLeft() * eff, frame:GetTop() * eff
    keepCorner = not ns.IsAnchoredToCharacter()
    self:SetScript("OnUpdate", update)
  end)
  grip:SetScript("OnMouseUp", function(self)
    if not self:GetScript("OnUpdate") then
      return
    end
    self:SetScript("OnUpdate", nil)
    ns.OnScaleChanged(frame:GetScale(), keepCorner)
  end)
  grip:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L.RESIZE_HINT, 1, 1, 1)
    GameTooltip:Show()
  end)
  grip:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
end

function UI.Create()
  if frame then
    return frame
  end
  frame = CreateFrame("Frame", "IsiStatsFrame", UIParent, "BackdropTemplate")
  frame:SetSize(WIDTH, 120)
  frame:SetFrameStrata("MEDIUM")
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:Hide()
  if frame.SetBackdrop then
    frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
  end

  -- Title bar: drag handle, right click docks/undocks.
  local bar = CreateFrame("Button", nil, frame)
  bar:SetPoint("TOPLEFT", 1, -1)
  bar:SetPoint("TOPRIGHT", -1, -1)
  bar:SetHeight(TITLE_H)
  local barBg = bar:CreateTexture(nil, "BACKGROUND")
  barBg:SetAllPoints()
  barBg:SetTexture(WHITE)
  frame.barBg = barBg
  local line = bar:CreateTexture(nil, "BORDER")
  line:SetPoint("BOTTOMLEFT")
  line:SetPoint("BOTTOMRIGHT")
  line:SetHeight(1)
  line:SetTexture(WHITE)
  frame.barLine = line

  local title = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("LEFT", 8, 0)
  title:SetText("isi|cff1e90ffStats|r")
  setColor(title, "heading")

  local level = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  level:SetPoint("LEFT", title, "RIGHT", 6, 0)
  setColor(level, "dim")
  frame.subtitle = level

  bar:RegisterForDrag("LeftButton")
  bar:RegisterForClicks("RightButtonUp")
  bar:SetScript("OnDragStart", function()
    ns.OnDragStart()
    frame:StartMoving()
  end)
  bar:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
    ns.SavePosition()
  end)
  bar:SetScript("OnClick", function()
    ns.ToggleDock()
  end)
  bar:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("isiStats", 1, 1, 1)
    GameTooltip:AddLine(L.DRAG_HINT, C.label[1], C.label[2], C.label[3], true)
    GameTooltip:Show()
  end)
  bar:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  local close = CreateFrame("Button", nil, bar)
  close:SetSize(TITLE_H, TITLE_H)
  close:SetPoint("RIGHT", 0, 0)
  local x = close:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  x:SetPoint("CENTER", 0, 1)
  x:SetText("x")
  setColor(x, "dim")
  close:SetScript("OnEnter", function()
    setColor(x, "close")
  end)
  close:SetScript("OnLeave", function()
    setColor(x, "dim")
  end)
  close:SetScript("OnClick", function()
    ns.Hide()
  end)

  createResizeGrip()
  UI.SetBackgroundAlpha(bgAlpha)

  frame:SetScript("OnShow", function()
    ns.Refresh()
  end)
  return frame
end

-- Background opacity 0..1: window, border, title bar and row tints.
function UI.SetBackgroundAlpha(a)
  bgAlpha = math.max(0, math.min(1, a or 1))
  if not frame then
    return
  end
  if frame.SetBackdropColor then
    frame:SetBackdropColor(rgba(C.bg, bgAlpha))
    frame:SetBackdropBorderColor(rgba(C.border, bgAlpha))
  end
  frame.barBg:SetVertexColor(rgba(C.title, bgAlpha))
  frame.barLine:SetVertexColor(rgba(C.border, bgAlpha))
  for _, row in ipairs(rows) do
    if row:IsShown() then
      if row.sectionKey then
        row.bg:SetVertexColor(rgba(C.sectionBg, bgAlpha))
      elseif row.alt then
        row.bg:SetVertexColor(rgba(C.alt, bgAlpha))
      end
    end
  end
end

function UI.GetFrame()
  return frame
end
