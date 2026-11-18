local _, ns = ...

-- Chat history: Up / Down in the chat input steps through the lines you sent
-- (walked by the addon over the saved list, Alt mode of the box off), and the lines
-- are kept in IsiStatsDB.chatHistory so they survive /reload and restarts.
--
-- Only the game's own edit box methods are used and hooked with
-- hooksecurefunc, so nothing of the chat code is replaced or tainted.

local ChatHistory = {}
ns.ChatHistory = ChatHistory

local MAX_LINES = 100

local db
local hooked = {}
local restoring = false
local typed = setmetatable({}, { __mode = "k" }) -- last non-empty text per box
local addedByGame = false

local function isSecret(v)
  return type(issecretvalue) == "function" and issecretvalue(v)
end

local function editBoxes()
  local boxes = {}
  local count = type(NUM_CHAT_WINDOWS) == "number" and NUM_CHAT_WINDOWS or 10
  for i = 1, count do
    local box = _G["ChatFrame" .. i .. "EditBox"]
    if type(box) == "table" and box.AddHistoryLine then
      boxes[#boxes + 1] = box
    end
  end
  return boxes
end

-- Every line the game adds to an edit box history (each sent line, also
-- slash commands) goes to the saved list; a repeat moves to the end. With the
-- setting off nothing is saved and the game's Alt mode is back.
local function remember(_, line)
  if restoring or not db or not db.chatHistoryArrows or isSecret(line) or type(line) ~= "string" then
    return
  end
  line = strtrim(line)
  if line == "" then
    return
  end
  addedByGame = true
  local list = db.chatHistory
  for i = #list, 1, -1 do
    if list[i] == line then
      table.remove(list, i)
    end
  end
  list[#list + 1] = line
  while #list > MAX_LINES do
    table.remove(list, 1)
  end
end

-- Own walk through the saved list: the client may reset the edit box's
-- arrow mode or not walk its history at all, so Up / Down set the text
-- themselves. pos = index into db.chatHistory, nil = not walking (empty line).
local pos = setmetatable({}, { __mode = "k" })
local lastStep = setmetatable({}, { __mode = "k" })

local function step(box, key)
  if not db or not db.chatHistoryArrows or (key ~= "UP" and key ~= "DOWN") then
    return
  end
  -- OnArrowPressed and OnKeyDown can both report the same key press.
  local now = type(GetTime) == "function" and GetTime() or nil
  if now and lastStep[box] == now then
    return
  end
  lastStep[box] = now
  local list = db.chatHistory
  if #list == 0 then
    return
  end
  local p = pos[box]
  if key == "UP" then
    p = math.max(1, (p or #list + 1) - 1)
  elseif p then
    p = p + 1
    if p > #list then
      p = nil
    end
  else
    return
  end
  pos[box] = p
  local text = p and list[p] or ""
  pcall(box.SetText, box, text)
  if box.SetCursorPosition then
    pcall(box.SetCursorPosition, box, #text)
  end
end

local function applyArrowMode(box)
  if box.SetAltArrowKeyMode then
    -- false: Up / Down without Alt walk the history, Left / Right move the cursor.
    pcall(box.SetAltArrowKeyMode, box, not db.chatHistoryArrows)
  end
end

function ChatHistory.Setup(savedDB)
  db = savedDB
  if type(db.chatHistory) ~= "table" then
    db.chatHistory = {}
  end
  for _, box in ipairs(editBoxes()) do
    if not hooked[box] then
      hooked[box] = true
      if box.SetHistoryLines then
        pcall(box.SetHistoryLines, box, MAX_LINES)
      end
      -- Saved lines first (oldest first), so Up starts with the newest one.
      restoring = true
      for _, line in ipairs(db.chatHistory) do
        pcall(box.AddHistoryLine, box, line)
      end
      restoring = false
      hooksecurefunc(box, "AddHistoryLine", remember)
      -- Slash commands the game does not put into the history itself
      -- (e.g. /console) are taken from the text that was in the box when
      -- Enter was pressed.
      box:HookScript("OnTextChanged", function(self, userInput)
        local text = self:GetText()
        if isSecret(text) then
          typed[self] = nil
        elseif text ~= "" then
          typed[self] = text
        elseif userInput then
          typed[self] = nil
        end
      end)
      box:HookScript("OnEditFocusGained", function(self)
        typed[self] = nil
        pos[self] = nil
        addedByGame = false
        applyArrowMode(self) -- the client may reset it when the box opens
      end)
      box:HookScript("OnArrowPressed", step)
      if box.HasScript and box:HasScript("OnKeyDown") then
        box:HookScript("OnKeyDown", step)
      end
      box:HookScript("OnEnterPressed", function(self)
        local text = typed[self]
        typed[self] = nil
        pos[self] = nil
        if not addedByGame and text and db.chatHistoryArrows then
          pcall(self.AddHistoryLine, self, text)
        end
        addedByGame = false
      end)
    end
    applyArrowMode(box)
  end
end

function ChatHistory.SetArrows(value)
  db.chatHistoryArrows = value and true or false
  for _, box in ipairs(editBoxes()) do
    applyArrowMode(box)
  end
end

function ChatHistory.GetArrows()
  return db and db.chatHistoryArrows and true or false
end

function ChatHistory.Clear()
  if db then
    db.chatHistory = {}
  end
end
