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
  bar = { 0.30, 0.62, 1.0, 0.65 },
  barTrack = { 1, 1, 1, 0.05 },
  shadow = { 0, 0, 0 },
}
ns.Colors = C

local WIDTH = 270
local PAD = 8
local TITLE_H = 22
local HEADER_H = 18
local ROW_H = 15
local SECTION_GAP = 4
local WHITE = "Interface\\Buttons\\WHITE8X8"
local GRIP_SIZE = 14

-- Skill rows use fixed right-aligned columns so the numbers line up:
-- [label ........ ] [not a full hit] [bonus] [current / max]
local COL_VALUE = 64
local COL_BONUS = 26
local COL_PCT = 52
local COL_GAP = 4
local BAR_HEIGHT = 2
local MIN_SCALE, MAX_SCALE = 0.5, 2

-- Rounded window (from isiLive's modern design): quarter-circle corner
-- textures mirrored with SetTexCoord, plain rectangles in between, a hairline
-- ring and a soft drop shadow that follows the rounding.
local MEDIA = "Interface\\AddOns\\isiStatsForever\\media\\"
local CORNER_DISC = MEDIA .. "corner_disc"
local CORNER_RING = MEDIA .. "corner_ring6"
local CORNER_SHADOW = MEDIA .. "corner_shadow"
local RADIUS = 6 -- corner_ring6 is drawn for this radius
local SHADOW_SIZE = 7
local SHADOW_ALPHA = 0.2
local CORNER_COORDS = {
  TOPLEFT = { 0, 1, 0, 1 },
  TOPRIGHT = { 1, 0, 0, 1 },
  BOTTOMLEFT = { 0, 1, 1, 0 },
  BOTTOMRIGHT = { 1, 0, 1, 0 },
}

-- Value fade-in when a shown value changes (from isiLive's stats box).
local FLASH_FROM_ALPHA = 0.15
local FLASH_DURATION = 0.5

local UI = {}
ns.UI = UI

local frame, rows, rowCount = nil, {}, 0
local bgAlpha = 1 -- background opacity factor (0..1); text is never faded
local surfaces = {} -- painted background pieces, repainted on opacity changes
local flashEnabled = true
local lastValues = {} -- last plain value text per row key

local function rgba(c, a)
  return c[1], c[2], c[3], (c[4] or 1) * a
end

local function isSecret(v)
  return type(issecretvalue) == "function" and issecretvalue(v) or false
end

local function setColor(fs, key, fallback)
  local c = C[key or fallback] or C[fallback]
  fs:SetTextColor(c[1], c[2], c[3])
end

-- ---------------------------------------------------------------- surfaces

local function paint(surface)
  local tex, kind = surface.texture, surface.kind
  if kind == "corner" then
    tex:SetVertexColor(rgba(surface.color, bgAlpha))
  elseif kind == "rect" then
    tex:SetColorTexture(rgba(surface.color, bgAlpha))
  elseif kind == "gradient" then
    local from, to = surface.from * bgAlpha, surface.to * bgAlpha
    local c = surface.color
    if type(CreateColor) == "function" and tex.SetGradient then
      tex:SetTexture(WHITE)
      tex:SetGradient(surface.orientation, CreateColor(c[1], c[2], c[3], from), CreateColor(c[1], c[2], c[3], to))
    else
      tex:SetColorTexture(c[1], c[2], c[3], math.max(from, to))
    end
  end
end

local function addSurface(texture, kind, color, extra)
  local surface = extra or {}
  surface.texture, surface.kind, surface.color = texture, kind, color
  surfaces[#surfaces + 1] = surface
  paint(surface)
end

local function newCorner(layer, sublevel, path, corner, size)
  local texture = frame:CreateTexture(nil, layer, nil, sublevel)
  texture:SetTexture(path)
  local coords = CORNER_COORDS[corner]
  texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
  texture:SetSize(size, size)
  texture:SetPoint(corner, frame, corner, 0, 0)
  return texture
end

local function newRect(layer, sublevel, point1, x1, y1, point2, x2, y2)
  local texture = frame:CreateTexture(nil, layer, nil, sublevel)
  texture:SetPoint(point1, frame, point1, x1, y1)
  texture:SetPoint(point2, frame, point2, x2, y2)
  return texture
end

-- Rounded fill; with `topHeight` only the top corners are rounded and the
-- fill stops at that height (title band).
local function roundedFill(layer, sublevel, color, topHeight)
  local r = RADIUS
  addSurface(newCorner(layer, sublevel, CORNER_DISC, "TOPLEFT", r), "corner", color)
  addSurface(newCorner(layer, sublevel, CORNER_DISC, "TOPRIGHT", r), "corner", color)
  local top = newRect(layer, sublevel, "TOPLEFT", r, 0, "TOPRIGHT", -r, 0)
  top:SetHeight(r)
  addSurface(top, "rect", color)
  if topHeight then
    local body = newRect(layer, sublevel, "TOPLEFT", 0, -r, "TOPRIGHT", 0, -r)
    body:SetHeight(math.max(1, topHeight - r))
    addSurface(body, "rect", color)
    return
  end
  addSurface(newCorner(layer, sublevel, CORNER_DISC, "BOTTOMLEFT", r), "corner", color)
  addSurface(newCorner(layer, sublevel, CORNER_DISC, "BOTTOMRIGHT", r), "corner", color)
  local bottom = newRect(layer, sublevel, "BOTTOMLEFT", r, 0, "BOTTOMRIGHT", -r, 0)
  bottom:SetHeight(r)
  addSurface(bottom, "rect", color)
  addSurface(newRect(layer, sublevel, "TOPLEFT", 0, -r, "BOTTOMRIGHT", 0, r), "rect", color)
end

-- One-unit rounded outline along the frame edge.
local function roundedRing(layer, sublevel, color)
  local r = RADIUS
  for corner in pairs(CORNER_COORDS) do
    addSurface(newCorner(layer, sublevel, CORNER_RING, corner, r), "corner", color)
  end
  local edges = {
    { "TOPLEFT", r, 0, "TOPRIGHT", -r, 0, nil, 1 },
    { "BOTTOMLEFT", r, 0, "BOTTOMRIGHT", -r, 0, nil, 1 },
    { "TOPLEFT", 0, -r, "BOTTOMLEFT", 0, r, 1, nil },
    { "TOPRIGHT", 0, -r, "BOTTOMRIGHT", 0, r, 1, nil },
  }
  for _, e in ipairs(edges) do
    local line = newRect(layer, sublevel, e[1], e[2], e[3], e[4], e[5], e[6])
    if e[7] then
      line:SetWidth(e[7])
    else
      line:SetHeight(e[8])
    end
    addSurface(line, "rect", color)
  end
end

-- Soft drop shadow: straight edges stop where the corner arcs begin; each
-- corner gets a quarter shadow ring so the shadow follows the rounding.
local function dropShadow()
  local r, s = RADIUS, SHADOW_SIZE
  local function edge(p1, rel1, x1, y1, p2, rel2, x2, y2, orientation, from, to, width, height)
    local tex = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    tex:SetPoint(p1, frame, rel1, x1, y1)
    tex:SetPoint(p2, frame, rel2, x2, y2)
    if width then
      tex:SetWidth(width)
    end
    if height then
      tex:SetHeight(height)
    end
    addSurface(tex, "gradient", C.shadow, { orientation = orientation, from = from, to = to })
  end
  edge("BOTTOMLEFT", "TOPLEFT", r, 0, "BOTTOMRIGHT", "TOPRIGHT", -r, 0, "VERTICAL", SHADOW_ALPHA, 0, nil, s)
  edge("TOPLEFT", "BOTTOMLEFT", r, 0, "TOPRIGHT", "BOTTOMRIGHT", -r, 0, "VERTICAL", 0, SHADOW_ALPHA, nil, s)
  edge("TOPRIGHT", "TOPLEFT", 0, -r, "BOTTOMRIGHT", "BOTTOMLEFT", 0, r, "HORIZONTAL", 0, SHADOW_ALPHA, s, nil)
  edge("TOPLEFT", "TOPRIGHT", 0, -r, "BOTTOMLEFT", "BOTTOMRIGHT", 0, r, "HORIZONTAL", SHADOW_ALPHA, 0, s, nil)
  local corners = {
    { "TOPLEFT", "BOTTOMRIGHT", r, -r },
    { "TOPRIGHT", "BOTTOMLEFT", -r, -r },
    { "BOTTOMLEFT", "TOPRIGHT", r, r },
    { "BOTTOMRIGHT", "TOPLEFT", -r, r },
  }
  local shadowColor = { 0, 0, 0, SHADOW_ALPHA }
  for _, spec in ipairs(corners) do
    local tex = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    tex:SetTexture(CORNER_SHADOW)
    local coords = CORNER_COORDS[spec[1]]
    tex:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    tex:SetSize(r + s, r + s)
    tex:SetPoint(spec[2], frame, spec[1], spec[3], spec[4])
    addSurface(tex, "corner", shadowColor)
  end
end

-- ---------------------------------------------------------------- rows

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

local function flash(row)
  if not row.fade then
    local group = row.value.CreateAnimationGroup and row.value:CreateAnimationGroup()
    if not group then
      return
    end
    local alpha = group:CreateAnimation("Alpha")
    alpha:SetFromAlpha(FLASH_FROM_ALPHA)
    alpha:SetToAlpha(1)
    alpha:SetDuration(FLASH_DURATION)
    alpha:SetSmoothing("OUT")
    row.fade = group
  end
  row.fade:Stop()
  row.fade:Play()
end

-- Fades a value in when it differs from the last value shown under the same
-- key. Secret values are never compared (that would raise and taint) and
-- reset the memory; greyed-out stale values are not remembered.
local function maybeFlash(row, data)
  local key = data.key
  if not key or data.stale then
    return
  end
  if isSecret(data.value) then
    lastValues[key] = nil
    return
  end
  local shown = (data.pct or "") .. "|" .. (data.bonus or "") .. "|" .. data.value
  local previous = lastValues[key]
  lastValues[key] = shown
  if flashEnabled and previous ~= nil and previous ~= shown then
    flash(row)
  end
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
  row.bonus = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.bonus:SetJustifyH("RIGHT")
  row.bonus:SetWordWrap(false)
  row.pct = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.pct:SetJustifyH("RIGHT")
  row.pct:SetWordWrap(false)
  row.track = row:CreateTexture(nil, "ARTWORK")
  row.track:SetPoint("BOTTOMLEFT", 6, 0)
  row.track:SetPoint("BOTTOMRIGHT", -6, 0)
  row.track:SetHeight(BAR_HEIGHT)
  row.track:SetColorTexture(C.barTrack[1], C.barTrack[2], C.barTrack[3], C.barTrack[4])
  row.bar = row:CreateTexture(nil, "ARTWORK", nil, 1)
  row.bar:SetPoint("BOTTOMLEFT", 6, 0)
  row.bar:SetHeight(BAR_HEIGHT)
  row.bar:SetColorTexture(C.bar[1], C.bar[2], C.bar[3], C.bar[4])
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

-- Places value (and for skill rows bonus and percent columns) and the label.
local function anchorColumns(row, columns)
  row.value:ClearAllPoints()
  row.label:ClearAllPoints()
  row.label:SetPoint("LEFT", 6, 0)
  row.value:SetPoint("RIGHT", -6, 0)
  if columns then
    row.value:SetWidth(COL_VALUE)
    row.bonus:ClearAllPoints()
    row.bonus:SetPoint("RIGHT", row.value, "LEFT", -COL_GAP, 0)
    row.bonus:SetWidth(COL_BONUS)
    row.pct:ClearAllPoints()
    row.pct:SetPoint("RIGHT", row.bonus, "LEFT", -COL_GAP, 0)
    row.pct:SetWidth(COL_PCT)
    row.label:SetPoint("RIGHT", row.pct, "LEFT", -COL_GAP, 0)
    row.bonus:Show()
    row.pct:Show()
  else
    row.value:SetWidth(0)
    row.label:SetPoint("RIGHT", row.value, "LEFT", -6, 0)
    row.bonus:Hide()
    row.pct:Hide()
  end
end

local function layoutProgress(row, progress)
  if not progress then
    row.track:Hide()
    row.bar:Hide()
    return
  end
  local width = WIDTH - 2 * PAD - 12
  row.track:Show()
  row.bar:SetWidth(math.max(1, width * progress))
  row.bar:Show()
end

-- Height, position and font only when they change: each SetPoint and
-- SetFontObject makes the game lay the row out again, on every refresh.
-- (Texts are set every time: a value may be secret and must not be compared.)
local function placeRow(row, height, y, font)
  if row.placedY ~= y or row.placedH ~= height then
    row:SetHeight(height)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, y)
    row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, y)
    row.placedY, row.placedH = y, height
  end
  if row.font ~= font then
    row.label:SetFontObject(font)
    row.value:SetFontObject(font)
    row.font = font
  end
end

local function layoutHeader(row, section, collapsed, y)
  placeRow(row, HEADER_H, y, "GameFontNormalSmall")
  row.bg:SetVertexColor(rgba(C.sectionBg, bgAlpha))
  row.label:SetText(string.upper(section.title))
  setColor(row.label, "section")
  row.value:SetText(collapsed and "+" or "-")
  setColor(row.value, "dim")
  anchorColumns(row, false)
  layoutProgress(row, nil)
  row.sectionKey = section.key
  row.data = nil
  row:Show()
end

local function layoutRow(row, data, alt, y)
  placeRow(row, ROW_H, y, "GameFontHighlightSmall")
  row.alt = alt
  if alt then
    row.bg:SetVertexColor(rgba(C.alt, bgAlpha))
  else
    row.bg:SetVertexColor(0, 0, 0, 0)
  end
  row.label:SetText(data.label or "")
  setColor(row.label, data.labelColor, "label")
  row.value:SetText(data.value or "")
  setColor(row.value, data.color, "value")
  anchorColumns(row, data.columns)
  if data.columns then
    row.bonus:SetText(data.bonus or "")
    setColor(row.bonus, data.stale and "dim" or nil, "value")
    row.pct:SetText(data.pct or "")
    setColor(row.pct, data.stale and "dim" or data.pctColor, "value")
  end
  layoutProgress(row, data.progress)
  row.sectionKey = nil
  row.data = data
  row:Show()
  maybeFlash(row, data)
end

-- showHeaders false: no section headers and no gaps; nothing can be
-- collapsed, every section shows its rows and the row striping runs on
-- across sections as one continuous list.
function UI.Render(sections, collapsedMap, showHeaders)
  if not frame then
    return
  end
  rowCount = 0
  local y = -TITLE_H - 6
  local stripe = 0
  for si, section in ipairs(sections) do
    if si > 1 and showHeaders then
      y = y - SECTION_GAP
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
        stripe = showHeaders and ri or (stripe + 1)
        layoutRow(acquireRow(rowCount), data, stripe % 2 == 0, y)
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

-- ---------------------------------------------------------------- screen alerts

-- Texts in the middle of the screen that stay until they are taken away (the
-- game's raid warnings always fade out). They sit above the raid warnings, so
-- they never cover one, and stack upwards: first the keys in ALERT_FIRST, then
-- the others by key. An alert plays the warning sound once when it appears,
-- unless its caller does the sound.
local ALERT_FIRST = { fishing = 1, tracking = 2 }
local ALERT_LINE_H = 26
local ALERT_GAP = 4
local ALERT_FALLBACK_Y = -156
local alerts, alertTexts, alertColors = nil, {}, {}

local function createAlerts()
  alerts = CreateFrame("Frame", nil, UIParent)
  alerts:SetSize(800, ALERT_LINE_H)
  alerts:SetFrameStrata("HIGH")
  alerts:EnableMouse(false)
  if RaidWarningFrame then
    alerts:SetPoint("BOTTOM", RaidWarningFrame, "TOP", 0, ALERT_GAP) -- follows it in edit mode
  else
    alerts:SetPoint("TOP", UIParent, "TOP", 0, ALERT_FALLBACK_Y)
  end
  alerts.lines = {}
end

local function alertLine(index)
  local line = alerts.lines[index]
  if not line then
    line = alerts:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    line:SetPoint("BOTTOM", alerts, "BOTTOM", 0, (index - 1) * ALERT_LINE_H)
    alerts.lines[index] = line
  end
  return line
end

local function alertBefore(a, b)
  local rankA, rankB = ALERT_FIRST[a] or math.huge, ALERT_FIRST[b] or math.huge
  if rankA ~= rankB then
    return rankA < rankB
  end
  return a < b
end

function UI.PlayAlertSound()
  if type(PlaySound) == "function" and type(SOUNDKIT) == "table" and SOUNDKIT.RAID_WARNING then
    pcall(PlaySound, SOUNDKIT.RAID_WARNING, "Master")
  end
end

-- text nil: takes the alert away. silent: the caller does the sound.
-- color: a palette key, default "bad".
function UI.SetAlert(key, text, silent, color)
  if alertTexts[key] == text then
    return
  end
  local appears = text ~= nil and alertTexts[key] == nil
  alertTexts[key], alertColors[key] = text, color
  if appears and not silent then
    UI.PlayAlertSound()
  end
  if not alerts then
    createAlerts()
  end
  local keys = {}
  for name in pairs(alertTexts) do
    keys[#keys + 1] = name
  end
  table.sort(keys, alertBefore)
  for i, name in ipairs(keys) do
    local line = alertLine(i)
    setColor(line, alertColors[name], "bad")
    line:SetText(alertTexts[name])
  end
  for i = #keys + 1, #alerts.lines do
    alerts.lines[i]:SetText("")
  end
  if #keys > 0 then
    alerts:Show()
  else
    alerts:Hide()
  end
end

function UI.GetAlert(key)
  return alertTexts[key]
end

-- ---------------------------------------------------------------- combat banner

-- Combat start / end: one big line in the middle of the screen that fades in,
-- stays a moment and fades out, rising all the while. A new one replaces the
-- one still showing.
local BANNER_IN, BANNER_HOLD, BANNER_OUT = 0.25, 1.2, 0.8
local BANNER_Y = 120 -- above the character
local BANNER_RISE = 60 -- px the text climbs from fading in to gone
local BANNER_SIZE = 34
local banner

local function bannerUpdate(self, elapsed)
  local age = self.age + elapsed
  self.age = age
  local life = BANNER_IN + BANNER_HOLD + BANNER_OUT
  if age >= life then
    self:Hide()
    return
  elseif age < BANNER_IN then
    self:SetAlpha(age / BANNER_IN)
  elseif age > BANNER_IN + BANNER_HOLD then
    self:SetAlpha(1 - (age - BANNER_IN - BANNER_HOLD) / BANNER_OUT)
  else
    self:SetAlpha(1)
  end
  self.text:SetPoint("CENTER", self, "CENTER", 0, BANNER_RISE * age / life)
end

function UI.ShowCombatBanner(text, color)
  if not banner then
    banner = CreateFrame("Frame", nil, UIParent)
    banner:SetSize(800, BANNER_SIZE + 10)
    banner:SetPoint("CENTER", UIParent, "CENTER", 0, BANNER_Y)
    banner:SetFrameStrata("HIGH")
    banner:EnableMouse(false)
    banner.text = banner:CreateFontString(nil, "OVERLAY")
    banner.text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", BANNER_SIZE, "THICKOUTLINE")
    banner.text:SetPoint("CENTER", banner, "CENTER", 0, 0)
    banner.text:SetShadowOffset(2, -2)
    banner:SetScript("OnUpdate", bannerUpdate)
    banner:Hide()
  end
  banner.text:SetText(text)
  banner.shownText = text
  setColor(banner.text, color, "value")
  banner.age = 0
  banner.text:SetPoint("CENTER", banner, "CENTER", 0, 0)
  banner:SetAlpha(0)
  banner:Show()
end

-- ---------------------------------------------------------------- flight bar

-- While on a flight (Flights.lua): a bar with start -> destination on the left.
-- mode "known": fills as the flight goes on, the time still to go on the
-- right; "estimate": the same with "~" before the time; "unknown": full and
-- dimmed, the time since take-off counting up ("+"). Shift + left drag moves it
-- (saved in IsiStatsDB.flightBarPos), Ctrl + click closes it for this flight.
local FBAR_W, FBAR_H = 320, 20
local FBAR_Y = -200
local flightBar

local function mmss(seconds)
  seconds = math.max(0, math.floor(seconds + 0.5))
  return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

-- Every frame while flying: the fill moves smoothly, the time text is only
-- built again when the shown second changes.
local function setBarTime(self, prefix, seconds)
  local whole = math.max(0, math.floor(seconds + 0.5))
  if self.shownSecond ~= whole or self.shownPrefix ~= prefix then
    self.shownSecond, self.shownPrefix = whole, prefix
    self.time:SetText(prefix .. mmss(whole))
  end
end

local function flightBarUpdate(self)
  local passed = math.max(0, GetTime() - self.start)
  if self.mode == "unknown" then
    self.fill:SetWidth(FBAR_W - 2)
    setBarTime(self, "+", passed)
    self.share = 1
    return
  end
  local share = math.min(1, passed / self.total)
  self.fill:SetWidth(math.max(1, (FBAR_W - 2) * share))
  setBarTime(self, self.mode == "estimate" and "~" or "", self.total - passed)
  self.share = share
end

local function createFlightBar()
  local f = CreateFrame("Frame", nil, UIParent)
  f:SetSize(FBAR_W, FBAR_H)
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  local edge = f:CreateTexture(nil, "BACKGROUND", nil, 0)
  edge:SetTexture(WHITE)
  edge:SetPoint("TOPLEFT", -1, 1)
  edge:SetPoint("BOTTOMRIGHT", 1, -1)
  edge:SetVertexColor(rgba(C.border, 1))
  local bg = f:CreateTexture(nil, "BACKGROUND", nil, 1)
  bg:SetTexture(WHITE)
  bg:SetAllPoints()
  bg:SetVertexColor(rgba(C.bg, 1))
  local track = f:CreateTexture(nil, "ARTWORK", nil, 0)
  track:SetTexture(WHITE)
  track:SetPoint("TOPLEFT", 1, -1)
  track:SetPoint("BOTTOMRIGHT", -1, 1)
  track:SetVertexColor(rgba(C.barTrack, 1))
  f.fill = f:CreateTexture(nil, "ARTWORK", nil, 1)
  f.fill:SetTexture(WHITE)
  f.fill:SetPoint("TOPLEFT", 1, -1)
  f.fill:SetPoint("BOTTOMLEFT", 1, 1)
  f.fill:SetWidth(1)
  f.fill:SetVertexColor(rgba(C.bar, 1))
  f.label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  f.label:SetPoint("LEFT", 8, 0)
  f.label:SetPoint("RIGHT", -52, 0)
  f.label:SetJustifyH("LEFT")
  f.label:SetWordWrap(false)
  setColor(f.label, "value")
  f.time = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  f.time:SetPoint("RIGHT", -8, 0)
  setColor(f.time, "value")
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self)
    if IsShiftKeyDown() then
      self:StartMoving()
    end
  end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, x, y = self:GetPoint()
    if point then
      IsiStatsDB.flightBarPos = { point, relativePoint, x, y }
    end
  end)
  f:SetScript("OnMouseUp", function(self, button)
    if button == "LeftButton" and IsControlKeyDown() then
      self:Hide()
    end
  end)
  f:SetScript("OnEnter", function(self)
    if type(GameTooltip) == "table" then
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      if self.route then
        GameTooltip:SetText(self.route, 1, 1, 1, 1, true)
        GameTooltip:AddLine(L.FLIGHT_BAR_TIP, 0.7, 0.7, 0.7, true)
      else
        GameTooltip:SetText(L.FLIGHT_BAR_TIP, 1, 1, 1, 1, true)
      end
      GameTooltip:Show()
    end
  end)
  f:SetScript("OnLeave", function()
    if type(GameTooltip) == "table" then
      GameTooltip:Hide()
    end
  end)
  f:SetScript("OnUpdate", flightBarUpdate)
  f:Hide()
  return f
end

-- mode: "known" | "estimate" (total = seconds) | "unknown" (total nil).
-- destination: the text in the bar (a smaller font when it does not fit);
-- route: the whole route for the tooltip.
function UI.ShowFlightBar(destination, total, start, mode, route)
  mode = mode or "known"
  if mode ~= "unknown" and (type(total) ~= "number" or total <= 0) then
    return
  end
  flightBar = flightBar or createFlightBar()
  flightBar:ClearAllPoints()
  local pos = IsiStatsDB and IsiStatsDB.flightBarPos
  if type(pos) == "table" and pos[1] then
    flightBar:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
  else
    flightBar:SetPoint("CENTER", UIParent, "CENTER", 0, FBAR_Y)
  end
  local label = flightBar.label
  label:SetFontObject("GameFontHighlight")
  label:SetText(destination or "")
  if label:IsTruncated() then
    label:SetFontObject("GameFontHighlightSmall")
  end
  setColor(label, "value")
  flightBar.text, flightBar.route = destination, route
  flightBar.total, flightBar.start, flightBar.mode = total, start or GetTime(), mode
  flightBar.shownSecond = nil -- a new flight: its first time text in any case
  flightBar.fill:SetVertexColor(rgba(mode == "unknown" and C.dim or C.bar, mode == "unknown" and 0.5 or 1))
  flightBarUpdate(flightBar)
  flightBar:Show()
end

function UI.HideFlightBar()
  if flightBar then
    flightBar:Hide()
  end
end

-- Shown or not, how full (0..1), the frame and the mode (for the load test).
function UI.GetFlightBar()
  return flightBar and flightBar:IsShown() or false,
    flightBar and flightBar.share,
    flightBar,
    flightBar and flightBar.mode
end

-- The text on screen (nil: none) and the frame (for the load test).
function UI.GetCombatBanner()
  return banner and banner:IsShown() and banner.shownText or nil, banner
end

function UI.SetFlashEnabled(enabled)
  flashEnabled = enabled and true or false
end

-- ---------------------------------------------------------------- frame

-- Bottom-right grip: dragging it scales the whole window (its height
-- follows the content, so size means scale). The top-left corner stays put.
local function createResizeGrip()
  local grip = CreateFrame("Button", nil, frame)
  grip:SetSize(GRIP_SIZE, GRIP_SIZE)
  grip:SetPoint("BOTTOMRIGHT", -2, 2)
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
    if mouseButton ~= "LeftButton" or ns.IsLocked() then
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
  frame = CreateFrame("Frame", "IsiStatsFrame", UIParent)
  frame:SetSize(WIDTH, 120)
  frame:SetFrameStrata("MEDIUM")
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:Hide()

  -- Background: shadow, rounded fill, rounded title band, hairline ring.
  dropShadow()
  roundedFill("BACKGROUND", -7, C.bg)
  roundedFill("BACKGROUND", -6, C.title, TITLE_H)
  roundedRing("BORDER", 0, C.border)

  -- Title bar: drag handle, right click docks/undocks.
  local bar = CreateFrame("Button", nil, frame)
  bar:SetPoint("TOPLEFT", 0, 0)
  bar:SetPoint("TOPRIGHT", 0, 0)
  bar:SetHeight(TITLE_H)
  local line = bar:CreateTexture(nil, "BORDER")
  line:SetPoint("BOTTOMLEFT", 1, 0)
  line:SetPoint("BOTTOMRIGHT", -1, 0)
  line:SetHeight(1)
  addSurface(line, "rect", C.border)

  local title = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("LEFT", 9, 0)
  title:SetText("isi|cff1e90ffStats|r|cff8a96a8Forever|r")
  setColor(title, "heading")

  local level = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  level:SetPoint("LEFT", title, "RIGHT", 6, 0)
  setColor(level, "dim")
  frame.subtitle = level

  bar:RegisterForDrag("LeftButton")
  bar:RegisterForClicks("RightButtonUp")
  bar:SetScript("OnDragStart", function()
    if ns.IsLocked() then
      return
    end
    ns.OnDragStart()
    frame.isMoving = true
    frame:StartMoving()
  end)
  bar:SetScript("OnDragStop", function()
    if not frame.isMoving then
      return
    end
    frame.isMoving = nil
    frame:StopMovingOrSizing()
    ns.SavePosition()
  end)
  bar:SetScript("OnClick", function()
    ns.ToggleDock()
  end)
  bar:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("isiStatsForever", 1, 1, 1)
    GameTooltip:AddLine(L.DRAG_HINT, C.label[1], C.label[2], C.label[3], true)
    GameTooltip:Show()
  end)
  bar:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  local close = CreateFrame("Button", nil, bar)
  close:SetSize(TITLE_H, TITLE_H)
  close:SetPoint("RIGHT", -2, 0)
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

  -- The installed version (TOC) at the bottom left, in the margin the resize
  -- grip keeps free on the right; nothing if unknown.
  local version = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  version:SetPoint("BOTTOMLEFT", PAD, 3)
  local fontPath, _, fontFlags = version:GetFont()
  if fontPath then
    version:SetFont(fontPath, 9, fontFlags) -- small
  end
  setColor(version, "dim")
  local v = ns.ErrorLog.Version()
  version:SetText(v ~= "?" and ("v" .. v) or "")
  frame.version = version

  createResizeGrip()
  UI.SetBackgroundAlpha(bgAlpha)

  frame:SetScript("OnShow", function()
    ns.Refresh()
  end)
  return frame
end

-- Background opacity 0..1: window, shadow, border, title bar and row tints.
function UI.SetBackgroundAlpha(a)
  bgAlpha = math.max(0, math.min(1, a or 1))
  if not frame then
    return
  end
  for _, surface in ipairs(surfaces) do
    paint(surface)
  end
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
