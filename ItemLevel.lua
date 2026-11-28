local _, ns = ...
local L = ns.L
local U = ns.Util
local call, num, str = U.call, U.num, U.str

-- Item levels: a tooltip line, a number on the character window's slots and on
-- the bag slots (each its own option), and the average as a row (Data.lua).
-- Forever has the item level in its data but hides it: the character window's
-- ITEMLEVEL stat is left out of PAPERDOLL_STATCATEGORIES (Camelot).
local ItemLevel = {}
ns.ItemLevel = ItemLevel

local db

-- Weapons and armour; shirt and tabard have a level that says nothing.
local GEAR_CLASS = { [2] = true, [4] = true }
local NO_LEVEL_SLOT = { INVTYPE_BODY = true, INVTYPE_TABARD = true }
-- Equipment slots with a level that counts: 1-17 and ranged (18) without
-- shirt (4); the tabard (19) and the ammo (0) are left out.
ItemLevel.SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }
-- Character window slot buttons by slot (Blizzard's names).
local SLOT_BUTTONS = {
  [1] = "CharacterHeadSlot",
  [2] = "CharacterNeckSlot",
  [3] = "CharacterShoulderSlot",
  [5] = "CharacterChestSlot",
  [6] = "CharacterWaistSlot",
  [7] = "CharacterLegsSlot",
  [8] = "CharacterFeetSlot",
  [9] = "CharacterWristSlot",
  [10] = "CharacterHandsSlot",
  [11] = "CharacterFinger0Slot",
  [12] = "CharacterFinger1Slot",
  [13] = "CharacterTrinket0Slot",
  [14] = "CharacterTrinket1Slot",
  [15] = "CharacterBackSlot",
  [16] = "CharacterMainHandSlot",
  [17] = "CharacterSecondaryHandSlot",
  [18] = "CharacterRangedSlot",
}
local MAX_CONTAINER_FRAMES = 13

local function itemApi()
  return type(C_Item) == "table" and C_Item or {}
end

-- Per item link (a link names one item with its bonuses, so its level never
-- changes): { level, name, r, g, b }, false for anything that is not gear.
-- Only complete answers are kept; an item the client has not loaded yet is
-- asked again next time. The bags ask for every slot on every bag update.
local known, knownCount = {}, 0
local KNOWN_MAX = 2000 -- then start over (tooltips of many different items)

local function lookup(link)
  local hit = known[link]
  if hit ~= nil then
    return hit
  end
  local item = itemApi()
  local _, _, _, equipLoc, _, classID = call(item.GetItemInfoInstant or GetItemInfoInstant, link)
  classID = num(classID)
  if not classID then
    return nil -- not loaded: ask again
  end
  local result = false
  if GEAR_CLASS[classID] and not NO_LEVEL_SLOT[str(equipLoc)] then
    local level = num(call(item.GetDetailedItemLevelInfo or GetDetailedItemLevelInfo, link))
    local name, _, quality, base = call(item.GetItemInfo or GetItemInfo, link)
    level = level or num(base)
    quality = num(quality)
    if not (level and level > 0 and quality) then
      return nil -- level or quality not loaded yet: ask again
    end
    local colors = type(ITEM_QUALITY_COLORS) == "table" and ITEM_QUALITY_COLORS
    local c = colors and colors[quality]
    local r, g, b = 1, 1, 1
    if type(c) == "table" and c.r then
      r, g, b = c.r, c.g, c.b
    end
    result = { math.floor(level), str(name), r, g, b }
  end
  if knownCount >= KNOWN_MAX then
    known, knownCount = {}, 0
  end
  known[link], knownCount = result, knownCount + 1
  return result
end

-- The item level of a gear link, nil for anything else or when unknown.
function ItemLevel.Of(link)
  link = str(link)
  local hit = link and lookup(link)
  return hit and hit[1] or nil
end

local function qualityColor(link)
  local hit = lookup(link)
  if hit then
    return hit[3], hit[4], hit[5]
  end
  return 1, 1, 1
end

-- The small number on a slot button; hidden without a level or option.
local function mark(button, link, on)
  if type(button) ~= "table" then
    return
  end
  local level = on and ItemLevel.Of(link)
  if not level then
    if button.isiItemLevel then
      button.isiItemLevel:Hide()
    end
    return
  end
  local text = button.isiItemLevel
  if not text then
    text = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    text:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
    button.isiItemLevel = text
  end
  text:SetText(level)
  text:SetTextColor(qualityColor(link))
  text:Show()
end

-- ------------------------------------------------------------------ tooltip

-- The text of the game's own item level line, for both the line and the check.
local function levelFormat()
  return type(ITEM_LEVEL) == "string" and ITEM_LEVEL or L.ITEM_LEVEL_FMT
end

-- True when a tooltip line already says the item level (the game's own line).
local function hasLevelLine(data)
  local prefix = levelFormat():match("^(.-)%%") or ""
  if prefix == "" or type(data) ~= "table" or type(data.lines) ~= "table" then
    return false
  end
  for _, line in ipairs(data.lines) do
    local text = type(line) == "table" and str(line.leftText)
    if text and text:sub(1, #prefix) == prefix then
      return true
    end
  end
  return false
end

function ItemLevel.OnTooltip(tooltip, data)
  if not (db and db.ilvlTooltip) or type(tooltip) ~= "table" or hasLevelLine(data) then
    return
  end
  local link
  if tooltip.GetItem then
    local _, l = call(tooltip.GetItem, tooltip)
    link = str(l)
  end
  link = link or (type(data) == "table" and str(data.hyperlink))
  local level = ItemLevel.Of(link)
  if level then
    tooltip:AddLine(string.format(levelFormat(), level), 1, 0.82, 0)
  end
end

-- ---------------------------------------------------------- character window

local function updateSlot(button)
  local slot = type(button) == "table" and button.GetID and num(button:GetID())
  if not slot or not SLOT_BUTTONS[slot] then
    return
  end
  mark(button, call(GetInventoryItemLink, "player", slot), db and db.ilvlCharacter)
end

function ItemLevel.UpdateCharacter()
  for _, name in pairs(SLOT_BUTTONS) do
    updateSlot(_G[name])
  end
end

-- -------------------------------------------------------------------- bags

local function updateBagFrame(frame)
  if type(frame) ~= "table" or type(frame.EnumerateValidItems) ~= "function" then
    return
  end
  local api = type(C_Container) == "table" and C_Container or {}
  local on = db and db.ilvlBags
  for _, button in frame:EnumerateValidItems() do
    local bag = button.GetBagID and num(button:GetBagID())
    local slot = button.GetID and num(button:GetID())
    local info = bag and slot and call(api.GetContainerItemInfo, bag, slot)
    mark(button, type(info) == "table" and info.hyperlink, on)
  end
end

local function bagFrames()
  local frames = {}
  for i = 1, MAX_CONTAINER_FRAMES do
    frames[#frames + 1] = _G["ContainerFrame" .. i]
  end
  frames[#frames + 1] = _G.ContainerFrameCombinedBags
  return frames
end

function ItemLevel.UpdateBags()
  for _, frame in ipairs(bagFrames()) do
    if frame.IsShown and frame:IsShown() then
      updateBagFrame(frame)
    end
  end
end

-- ------------------------------------------------------------------ setup

function ItemLevel.Init(saved)
  db = saved
end

-- PLAYER_LOGIN: hooks only, nothing replaced.
function ItemLevel.Setup()
  local processor = type(TooltipDataProcessor) == "table" and TooltipDataProcessor
  local types = type(Enum) == "table" and Enum.TooltipDataType
  if processor and processor.AddTooltipPostCall and types and types.Item then
    processor.AddTooltipPostCall(types.Item, ItemLevel.OnTooltip)
  end
  if type(PaperDollItemSlotButton_Update) == "function" then
    hooksecurefunc("PaperDollItemSlotButton_Update", updateSlot)
  end
  for _, frame in ipairs(bagFrames()) do
    if type(frame.UpdateItems) == "function" then
      hooksecurefunc(frame, "UpdateItems", updateBagFrame)
    end
  end
end

-- The average the game reports and the weakest equipped item.
function ItemLevel.Equipped()
  local _, equipped = call(GetAverageItemLevel)
  local average = num(equipped)
  local lowest, lowestLink
  for _, slot in ipairs(ItemLevel.SLOTS) do
    local link = str(call(GetInventoryItemLink, "player", slot))
    local level = ItemLevel.Of(link)
    if level and (not lowest or level < lowest) then
      lowest, lowestLink = level, link
    end
  end
  if not average or average <= 0 then
    return nil
  end
  local hit = lowestLink and lookup(lowestLink)
  return math.floor(average), lowest, hit and hit[2]
end

function ItemLevel.Get(key)
  return db and db[key] and true or false
end

function ItemLevel.Set(key, value)
  db[key] = value and true or false
  if key == "ilvlCharacter" then
    ItemLevel.UpdateCharacter()
  elseif key == "ilvlBags" then
    ItemLevel.UpdateBags()
  end
end
