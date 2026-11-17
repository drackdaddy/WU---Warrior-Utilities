local addonName, ns = ...
local db = ns.db
local GOLD = { 0.90, 0.80, 0.50 }

--------------------------------------------------------------------------------
-- Options page
-- One page (how to use the addon, the Battle Shout timer switch on warriors,
-- slash commands and the Discord link), shown in
-- Esc > Options > AddOns > WU - Warrior Utilities. Blizzard's Settings panel
-- hosts the page as a canvas layout category: it parents, sizes, shows and
-- hides the frame, and Escape closes the panel. All rage bar settings are in
-- Edit Mode (see RageBar.lua), so the page only explains them.
-- The header shows the addon version from the TOC's ## Version line.
-- SavedVariables: shoutOff (checkbox)
--------------------------------------------------------------------------------
local category

-- Opens the Settings panel on this addon's page (only built on warriors and
-- druids).
local function Open()
  if category then Settings.OpenToCategory(category:GetID()) end
end

function ns.BuildOptions()
  local opt = CreateFrame("Frame")

  -- Header
  local title = opt:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 18, -14)
  title:SetText("WU - Warrior Utilities")
  title:SetTextColor(unpack(GOLD))
  -- Read from the TOC so the version is only ever set in one place.
  local version = opt:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  version:SetPoint("LEFT", title, "RIGHT", 8, -1)
  version:SetText("v" .. C_AddOns.GetAddOnMetadata(addonName, "Version"))
  local line = opt:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.55)
  line:SetHeight(1)
  line:SetPoint("TOPLEFT", 16, -48)
  line:SetPoint("TOPRIGHT", -16, -48)

  local page = CreateFrame("Frame", nil, opt)
  page:SetPoint("TOPLEFT", 18, -56)
  page:SetPoint("BOTTOMRIGHT", -18, 16)

  ------------------------------------------------------------------------------
  -- Page builders
  -- The page is laid out like a short readme: gold headings with a rule under
  -- them, then bullets, columns or a checkbox. Each piece is anchored under the
  -- last one placed.
  ------------------------------------------------------------------------------
  local prev

  -- Anchors region under the previous one (gap pixels down, x pixels in). A
  -- stretched region also reaches the page's right edge, so text wraps there.
  local function Place(region, gap, x, stretch)
    if prev then
      region:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", x or 0, -gap)
    else
      region:SetPoint("TOPLEFT", 4, -4)
    end
    if stretch then region:SetPoint("RIGHT", page, "RIGHT", -4, 0) end
    prev = region
  end

  -- White text for names the player looks for on screen (keys, settings).
  local function Key(text) return "|cffffffff" .. text .. "|r" end

  local function Heading(text)
    local fs = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetJustifyH("LEFT")
    fs:SetTextColor(unpack(GOLD))
    fs:SetText(text)
    Place(fs, 18, 0, true)
    local rule = page:CreateTexture(nil, "ARTWORK")
    rule:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.35)
    rule:SetHeight(1)
    Place(rule, 4, 0, true)
  end

  -- Body text wrapped to the page width; returns the font string.
  local function Text(text, gap, x)
    local fs = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetJustifyH("LEFT")
    fs:SetSpacing(4)
    fs:SetTextColor(0.90, 0.88, 0.82)
    fs:SetText(text)
    Place(fs, gap or 8, x, true)
    return fs
  end

  -- One text block with a gold bullet before each line.
  local function Bullets(lines)
    local bullet = "|cffe6cc80\226\128\162|r  "
    Text(bullet .. table.concat(lines, "\n" .. bullet))
  end

  -- One row of columns, widths[i] pixels wide with 8 between them. The first
  -- gold cells are gold, the rest body text. The row is as tall as its
  -- tallest cell, so a cell that wraps never overlaps the next row.
  local function Row(widths, gold, ...)
    local cells, height = {}, 0
    for i, w in ipairs(widths) do
      local fs = page:CreateFontString(nil, "OVERLAY", i <= gold and "GameFontNormal" or "GameFontHighlight")
      fs:SetWidth(w)
      fs:SetJustifyH("LEFT")
      fs:SetJustifyV("TOP")
      fs:SetSpacing(4)
      if i <= gold then fs:SetTextColor(unpack(GOLD)) else fs:SetTextColor(0.90, 0.88, 0.82) end
      fs:SetText((select(i, ...)))
      if i > 1 then fs:SetPoint("TOPLEFT", cells[i - 1], "TOPRIGHT", 8, 0) end
      height = math.max(height, fs:GetStringHeight())
      cells[i] = fs
    end
    cells[1]:SetHeight(height)
    Place(cells[1], 6)
  end

  -- Checkbox for an "off" setting: checked while db[key] is false. apply runs
  -- after a click. It re-reads db each time the page shows, so /wu reset is
  -- reflected.
  local function OnOff(label, key, apply)
    local cb = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
    cb:SetSize(26, 26)
    local fs = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    fs:SetText(label)
    cb:SetScript("OnShow", function(self) self:SetChecked(not db[key]) end)
    cb:SetScript("OnClick", function(self)
      db[key] = not self:GetChecked()
      apply()
    end)
    Place(cb, 6, -4)
  end

  ------------------------------------------------------------------------------
  -- Page content: how to use the addon, the slash commands and the Discord
  -- link. The link is a read-only edit box because addons can't open URLs or
  -- write to the clipboard; clicking it selects the text for Ctrl+C.
  ------------------------------------------------------------------------------
  local DISCORD = "https://discord.gg/Xja4mR87Bk"

  Heading("Rage bar setup")
  Bullets({
    "Press " .. Key("Esc") .. " and choose " .. Key("Edit Mode") .. ".",
    "Click the " .. Key("WU Rage Bar") .. " to open its settings.",
    Key("Style") .. ", " .. Key("Border") .. ", " .. Key("Color") .. " and "
      .. Key("Bar Size") .. " change the look.",
    Key("Mark I") .. " and " .. Key("Mark II") .. " set the glow points.",
    Key("Only Show in Combat") .. " or " .. Key("Disable Rage Bar") .. " hide it.",
    "On druids the bar only shows in " .. Key("Bear Form") .. " and " .. Key("Dire Bear Form") .. ".",
  })

  Heading("Moving the bar")
  Bullets({
    "Drag it, or click it and use the " .. Key("arrow keys") .. ".",
    "Hold " .. Key("Shift") .. " to move 10 pixels at a time.",
    "Each Edit Mode layout keeps its own position.",
  })

  if ns.isWarrior then
    Heading("Out of range warning")
    Bullets({
      "Flashes " .. Key("OUT OF RANGE") .. " when your target is out of melee range.",
      "In " .. Key("Edit Mode") .. ", click " .. Key("WU Range Warning") .. " to move it.",
      "Its panel sets the font, size and flash, or turns it off.",
    })

    Heading("Battle Shout timer")
    Bullets({
      "A bar behind your name on the " .. Key("player frame") .. " empties as Battle Shout runs out.",
      "It is hidden while Battle Shout is missing.",
    })
    OnOff("Show Battle Shout timer", "shoutOff", ns.RefreshShout)
  end

  Heading("Slash commands")
  local COMMAND_WIDTHS = { 100, 340 }
  Row(COMMAND_WIDTHS, 1, "/wu", "Open this page")
  Row(COMMAND_WIDTHS, 1, "/wu 30 60", "Set Mark I and Mark II (1 to 99)")
  Row(COMMAND_WIDTHS, 1, "/wu reset", "Reset all settings")
  Row(COMMAND_WIDTHS, 1, "/wuutil", "Same as /wu")

  Heading("Bugs, features and questions")
  Text("Join the WU Discord:")
  -- InputBoxTemplate draws its border outside the box, hence the 6px inset.
  local link = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
  link:SetSize(240, 20)
  link:SetAutoFocus(false)
  link:SetText(DISCORD)
  link:SetCursorPosition(0)
  Place(link, 6, 6)
  local function SelectAll(self) self:HighlightText() end
  link:SetScript("OnEditFocusGained", SelectAll)
  link:SetScript("OnMouseUp", SelectAll)
  -- Typing or pasting puts the link back, so it can't be changed.
  link:SetScript("OnTextChanged", function(self, userInput)
    if userInput then
      self:SetText(DISCORD)
      self:HighlightText()
    end
  end)
  Text("Click the link, then press Ctrl+C to copy.", 6, -6)

  category = Settings.RegisterCanvasLayoutCategory(opt, "WU - Warrior Utilities")
  Settings.RegisterAddOnCategory(category)
end

--------------------------------------------------------------------------------
-- Slash commands: /wu (or /wuutil)
--   /wu            open options
--   /wu 30 60      set marks
--   /wu reset
-- SLASH_WU1, SLASH_WU2 and SlashCmdList.WU are globals the game requires.
--------------------------------------------------------------------------------
SLASH_WU1, SLASH_WU2 = "/wu", "/wuutil"
SlashCmdList.WU = function(msg)
  if not ns.built then return end -- not a warrior or druid
  msg = strtrim(msg:lower())
  local a, b = msg:match("^(%d+)%s+(%d+)$")
  if msg == "" then
    Open()
  elseif msg == "reset" then
    wipe(db)
    ns.LoadDB()
    ns.RefreshBar()
    if ns.isWarrior then
      ns.RefreshRange()
      ns.RefreshShout()
    end
    print("WU - Warrior Utilities reset")
  elseif a then
    ns.SetMarks(a, b)
    print(string.format("WU - Warrior Utilities marks set to %d / %d", db.mark1, db.mark2))
  else
    print("WU - Warrior Utilities: /wu, /wu 30 60, /wu reset")
  end
end
