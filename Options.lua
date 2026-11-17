local addonName, ns = ...
local db = ns.db
local GOLD = { 0.90, 0.80, 0.50 }

--------------------------------------------------------------------------------
-- Options page
-- General tab (how to use the addon, slash commands and the Discord link) and,
-- on warriors only, Battle Shout tab (the player frame timer's switches),
-- shown in Esc > Options > AddOns > WU - Warrior Utilities. Blizzard's Settings
-- panel
-- hosts the page as a canvas layout category: it parents, sizes, shows and
-- hides the frame, and Escape closes the panel. All rage bar settings are in
-- Edit Mode (see RageBar.lua), so the page only explains them.
-- The header shows the addon version from the TOC's ## Version line.
-- SavedVariables: shoutOff, shoutTextOff, shoutFlashOff, shoutWarnOff, shoutColor
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

  ------------------------------------------------------------------------------
  -- Tabs
  ------------------------------------------------------------------------------
  local pages, tabBtns = {}, {}
  local function ShowTab(name)
    for k, page in pairs(pages) do
      page:SetShown(k == name)
      tabBtns[k].label:SetTextColor(unpack(k == name and GOLD or { 0.72, 0.70, 0.64 }))
      tabBtns[k].bar:SetShown(k == name)
    end
  end
  local TABS = { { "general", "General" } }
  if ns.isWarrior then TABS[2] = { "shout", "Battle Shout" } end
  for i, info in ipairs(TABS) do
    local b = CreateFrame("Button", nil, opt)
    b:SetSize(120, 28)
    b:SetPoint("TOPLEFT", 18 + (i - 1) * 128, -56)
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.label:SetPoint("CENTER", 0, 2)
    b.label:SetText(info[2])
    b.bar = b:CreateTexture(nil, "ARTWORK")
    b.bar:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.9)
    b.bar:SetHeight(2)
    b.bar:SetPoint("BOTTOMLEFT", 8, 2)
    b.bar:SetPoint("BOTTOMRIGHT", -8, 2)
    b:SetScript("OnClick", function() ShowTab(info[1]) end)
    tabBtns[info[1]] = b
    local page = CreateFrame("Frame", nil, opt)
    page:SetPoint("TOPLEFT", 18, -96)
    page:SetPoint("BOTTOMRIGHT", -18, 16)
    pages[info[1]] = page
  end

  ------------------------------------------------------------------------------
  -- Page builders
  -- Each tab is laid out like a short readme: gold headings with a rule under
  -- them, then bullets, commands or checkboxes. Begin(page) starts a page or a
  -- column; each piece is then anchored under the last one placed.
  ------------------------------------------------------------------------------
  local page, prev

  local function Begin(p) page, prev = p, nil end

  -- Splits p into two side-by-side columns 16 px apart; returns left, right.
  -- Pass each to Begin to fill it.
  local function Columns(p)
    local left = CreateFrame("Frame", nil, p)
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMRIGHT", p, "BOTTOM", -8, 0)
    local right = CreateFrame("Frame", nil, p)
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMLEFT", p, "BOTTOM", 8, 0)
    return left, right
  end

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

  -- One slash command: the command in gold, then its description on one
  -- line that ends at the page's right edge.
  local function Command(cmd, desc)
    local c = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    c:SetWidth(72)
    c:SetJustifyH("LEFT")
    c:SetTextColor(unpack(GOLD))
    c:SetText(cmd)
    local d = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    d:SetPoint("LEFT", c, "RIGHT", 8, 0)
    d:SetPoint("RIGHT", page, "RIGHT", -4, 0)
    d:SetJustifyH("LEFT")
    d:SetWordWrap(false)
    d:SetTextColor(0.90, 0.88, 0.82)
    d:SetText(desc)
    Place(c, 6)
  end

  -- Setting controls (checkboxes and color swatches). Each has a label and
  -- a Draw method that draws it from db. All are redrawn when their page
  -- shows (so /wu reset is reflected) and after any of them changes, so a
  -- control whose disabled() returns true is greyed out as soon as the
  -- setting it depends on changes.
  local controls = {}
  local function RefreshControls()
    for _, c in ipairs(controls) do
      local off = c.disabled and c.disabled()
      c:SetEnabled(not off)
      if c.reset then c.reset:SetEnabled(not off) end
      c.label:SetFontObject(off and "GameFontDisable" or "GameFontHighlight")
      c:Draw()
    end
  end

  -- Every control's label starts this far right of the page's left edge, so
  -- labels line up whatever the control's size.
  local LABEL_X = 26

  -- Places control under the previous piece with its left edge indent pixels
  -- from the page's left edge, gives it a label at LABEL_X and adds it to
  -- controls. Place offsets from the previous piece, so the previous
  -- control's indent is taken off.
  local function AddControl(control, label, indent, disabled)
    control.disabled, control.indent = disabled, indent
    control.label = control:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    control.label:SetPoint("LEFT", control, "LEFT", LABEL_X - indent, 0)
    control.label:SetText(label)
    control:SetScript("OnShow", RefreshControls)
    Place(control, 6, indent - (prev and prev.indent or 0))
    controls[#controls + 1] = control
  end

  -- Checkbox for an "off" setting: checked while db[key] is false. apply runs
  -- after a click.
  local function OnOff(label, key, apply, disabled)
    local cb = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
    cb:SetSize(26, 26)
    function cb:Draw() self:SetChecked(not db[key]) end
    cb:SetScript("OnClick", function(self)
      db[key] = not self:GetChecked()
      apply()
      RefreshControls()
    end)
    -- The checkbox art has a few transparent pixels around the box, so -4
    -- lines the box up with the text above.
    AddControl(cb, label, -4, disabled)
  end

  -- Color swatch for db[key] ({ r, g, b, a }). Clicking it opens Blizzard's
  -- color picker with opacity; changes apply as the color is picked, and
  -- Cancel puts back the color from before it opened. The Default button next
  -- to it restores the default color. apply runs after every change.
  local function ColorSwatch(label, key, apply, disabled)
    local sw = CreateFrame("Button", nil, page) -- the size of the checkbox's box
    sw:SetSize(20, 20)
    local edge = sw:CreateTexture(nil, "BACKGROUND")
    edge:SetAllPoints()
    edge:SetColorTexture(0.6, 0.58, 0.52, 1)
    local fill = sw:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", 2, -2)
    fill:SetPoint("BOTTOMRIGHT", -2, 2)
    function sw:Draw()
      local c = db[key]
      fill:SetColorTexture(c.r, c.g, c.b, c.a)
    end
    local function Set(r, g, b, a)
      db[key] = { r = r, g = g, b = b, a = a }
      apply()
      RefreshControls()
    end
    local function FromPicker()
      local r, g, b = ColorPickerFrame:GetColorRGB()
      Set(r, g, b, ColorPickerFrame:GetColorAlpha())
    end
    sw:SetScript("OnClick", function()
      local old = db[key]
      ColorPickerFrame:SetupColorPickerAndShow({
        r = old.r, g = old.g, b = old.b, opacity = old.a, hasOpacity = true,
        swatchFunc = FromPicker, opacityFunc = FromPicker,
        cancelFunc = function() Set(old.r, old.g, old.b, old.a) end,
      })
    end)
    AddControl(sw, label, 0, disabled)
    sw.reset = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    sw.reset:SetSize(80, 22)
    sw.reset:SetText("Default")
    sw.reset:SetPoint("LEFT", sw.label, "RIGHT", 12, 0)
    sw.reset:SetScript("OnClick", function()
      local c = ns.Default(key)
      Set(c.r, c.g, c.b, c.a)
    end)
  end

  ------------------------------------------------------------------------------
  -- General tab, in two columns so it fits the Settings panel: the rage bar on
  -- the left; the range warning (warriors), slash commands and Discord link on
  -- the right. The link is a read-only edit box because addons can't open URLs
  -- or write to the clipboard; clicking it selects the text for Ctrl+C.
  ------------------------------------------------------------------------------
  local DISCORD = "https://discord.gg/Xja4mR87Bk"
  local left, right = Columns(pages.general)

  Begin(left)
  Heading("Rage bar setup")
  Bullets({
    "Press " .. Key("Esc") .. ", choose " .. Key("Edit Mode") .. " and click the " .. Key("WU Rage Bar") .. ".",
    Key("Style") .. ", " .. Key("Border") .. ", " .. Key("Color") .. " and "
      .. Key("Bar Size") .. " change the look.",
    Key("Mark I") .. " and " .. Key("Mark II") .. " set the glow points.",
    Key("Only Show in Combat") .. " or " .. Key("Disable Rage Bar") .. " hide it.",
    "Druids only see it in " .. Key("Bear Form") .. " and " .. Key("Dire Bear Form") .. ".",
  })

  Heading("Moving the bar")
  Bullets({
    "Drag it, or click it and use the " .. Key("arrow keys") .. ".",
    Key("Shift") .. " moves 10 pixels at a time.",
    "Each Edit Mode layout keeps its own position.",
  })

  Begin(right)
  if ns.isWarrior then
    Heading("Out of range warning")
    Bullets({
      "Flashes " .. Key("OUT OF RANGE") .. " when your target is out of melee range.",
      "In " .. Key("Edit Mode") .. ", click " .. Key("WU Range Warning") .. " to move it and set its font, size and flash.",
    })
  end

  Heading("Slash commands")
  Command("/wu", "Open options")
  Command("/wu 30 60", "Set the marks (1 to 99)")
  Command("/wu reset", "Reset all settings")
  Command("/wuutil", "Same as /wu")

  Heading("Bugs, features and questions")
  Text("Join the WU Discord:")
  -- InputBoxTemplate draws its border outside the box, hence the 6px inset.
  local link = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
  link:SetHeight(20)
  link:SetAutoFocus(false)
  link:SetText(DISCORD)
  link:SetCursorPosition(0)
  Place(link, 6, 6)
  link:SetPoint("RIGHT", page, "RIGHT", -6, 0)
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

  ------------------------------------------------------------------------------
  -- Battle Shout tab: what the player frame timer shows and its switches (see
  -- ShoutTimer.lua). The countdown and flash are greyed out while the whole
  -- timer is off. Warriors only (see Tabs).
  ------------------------------------------------------------------------------
  if pages.shout then
    Begin(pages.shout)
    local function TimerOff() return db.shoutOff end

    Heading("On the player frame")
    Bullets({
      "A bar behind your name empties as " .. Key("Battle Shout") .. " runs out.",
      "A countdown at the end of your name shows the time left.",
      "Your name flashes " .. Key("red") .. " while Battle Shout is missing in combat.",
      Key("Battle Shout Missing") .. " also shows above the player frame then.",
      "Out of combat, nothing shows while Battle Shout is missing.",
    })

    Heading("Settings")
    OnOff("Show Battle Shout timer", "shoutOff", ns.RefreshShout)
    OnOff("Show countdown", "shoutTextOff", ns.RefreshShout, TimerOff)
    OnOff("Flash when missing in combat", "shoutFlashOff", ns.RefreshShout, TimerOff)
    OnOff("Show \"Battle Shout Missing\" text", "shoutWarnOff", ns.RefreshShout, TimerOff)
    ColorSwatch("Bar color", "shoutColor", ns.RefreshShout, TimerOff)
  end

  ShowTab("general")

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
