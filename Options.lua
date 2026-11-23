local addonName, ns = ...
local db = ns.db
local GOLD = { 0.90, 0.80, 0.50 }

--------------------------------------------------------------------------------
-- Options page
-- General tab (how to use the addon, the minimap icon switch, slash commands
-- and the Discord link) and,
-- on warriors only, a Battle Shout tab (the player frame timer's switches), a
-- Range tab (the range display, in three sub-tabs) and one tab per stance (that stance's cooldown
-- bar), shown in Esc > Options >
-- AddOns > WU - Warrior Utilities. Blizzard's Settings panel hosts the page
-- as a canvas layout category: it parents, sizes, shows and
-- hides the frame, and Escape closes the panel. All rage bar settings are in
-- Edit Mode (see RageBar.lua), so the page only explains them.
-- The header shows the addon version from the TOC's ## Version line.
-- SavedVariables: minimapOff, shoutOff, shoutTextOff, shoutFlashOff, shoutWarnOff,
--   shoutWarnSize, shoutColor, rangeOff, rangeOocOff, rangeFriendlyOff,
--   rangeLook, rangeTextFont, rangeSize, rangeWidth, rangeHeight, rangeScale,
--   rangeUnitOff, rangeOpacity, rangePlace, rangePlateY, rangePlateScale,
--   rangeFocusOff, rangeMouseOff, rangeLabelScale, rangeAutoOff, rangeZone1,
--   rangeZone2, rangeZone3, rangeColorPrimary, rangeColorSecondary,
--   rangeColorDead, rangeColorFar,
--   battleCdOff, defensiveCdOff, berserkerCdOff, battleAlertOff,
--   defensiveAlertOff, berserkerAlertOff, cdHide, cdOrder
--------------------------------------------------------------------------------
local category

-- Opens the Settings panel on this addon's page (only built on warriors and
-- druids). Used by /wu and the minimap icon.
function ns.OpenOptions()
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
  -- Builds a row of tabs on parent from list ({ key, name } each): buttons w
  -- px wide from (x, y), each with a page from (x, pageY) to (right, bottom)
  -- off parent's bottom right. Returns the pages by key and a function that
  -- shows one of them.
  local function Tabs(parent, list, x, y, w, pageY, right, bottom)
    local pages, btns = {}, {}
    local function Show(name)
      for k, page in pairs(pages) do
        page:SetShown(k == name)
        btns[k].label:SetTextColor(unpack(k == name and GOLD or { 0.72, 0.70, 0.64 }))
        btns[k].bar:SetShown(k == name)
      end
    end
    for i, info in ipairs(list) do
      local b = CreateFrame("Button", nil, parent)
      b:SetSize(w, 28)
      b:SetPoint("TOPLEFT", x + (i - 1) * (w + 4), y)
      b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
      b.label:SetPoint("CENTER", 0, 2)
      b.label:SetText(info[2])
      b.bar = b:CreateTexture(nil, "ARTWORK")
      b.bar:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.9)
      b.bar:SetHeight(2)
      b.bar:SetPoint("BOTTOMLEFT", 8, 2)
      b.bar:SetPoint("BOTTOMRIGHT", -8, 2)
      b:SetScript("OnClick", function() Show(info[1]) end)
      btns[info[1]] = b
      local page = CreateFrame("Frame", nil, parent)
      page:SetPoint("TOPLEFT", x, pageY)
      page:SetPoint("BOTTOMRIGHT", right, bottom)
      pages[info[1]] = page
    end
    return pages, Show
  end

  local TABS = { { "general", "General" } }
  if ns.isWarrior then
    TABS[2] = { "shout", "Battle Shout" }
    TABS[3] = { "range", "Range" }
    for _, s in ipairs(ns.STANCES) do
      TABS[#TABS + 1] = { s.key, (s.name:gsub(" Stance", "")) }
    end
  end
  local pages, ShowTab = Tabs(opt, TABS, 18, -56, 96, -96, -18, 16)

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

  -- One slash command: the command in gold (w px wide, 88 when nil), then its
  -- description on one line that ends at the page's right edge.
  local function Command(cmd, desc, w)
    local c = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    c:SetWidth(w or 88)
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

  -- Setting controls (checkboxes, steppers, dropdowns and color swatches). Each has a label and
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

  -- Number setting db[key], from low to high in steps of step: the label, then
  -- - and + buttons with the value between them. The control itself is an
  -- empty box the size of a checkbox, so the label lines up with the others.
  -- apply runs after every change.
  local function Stepper(label, key, low, high, step, apply, disabled)
    local st = CreateFrame("Frame", nil, page)
    st:SetSize(26, 26)
    local value = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    value:SetWidth(30)
    local function StepButton(text, dir)
      local b = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
      b:SetSize(24, 22)
      b:SetText(text)
      b:SetScript("OnClick", function()
        db[key] = math.min(high, math.max(low, db[key] + dir * step))
        apply()
        RefreshControls()
      end)
      return b
    end
    local minus, plus = StepButton("-", -1), StepButton("+", 1)
    function st:Draw() value:SetText(db[key]) end
    function st:SetEnabled(on)
      minus:SetEnabled(on)
      plus:SetEnabled(on)
      value:SetFontObject(on and "GameFontHighlight" or "GameFontDisable")
    end
    AddControl(st, label, -4, disabled)
    minus:SetPoint("LEFT", st.label, "RIGHT", 10, 0)
    value:SetPoint("LEFT", minus, "RIGHT", 2, 0)
    plus:SetPoint("LEFT", value, "RIGHT", 2, 0)
  end

  -- Dropdown for db[key], one of the ns.LISTS[key] choices (see Core.lua): the
  -- label, then Blizzard's dropdown button showing the current choice. Like the
  -- stepper, the control itself is an empty checkbox-sized box so the label
  -- lines up. apply runs after a pick.
  local function Choice(label, key, apply, disabled)
    local ch = CreateFrame("Frame", nil, page)
    ch:SetSize(26, 26)
    local dd = CreateFrame("DropdownButton", nil, page, "WowStyle1DropdownTemplate")
    dd:SetWidth(150)
    dd:SetupMenu(function(_, root)
      for _, o in ipairs(ns.LISTS[key]) do
        root:CreateRadio(o[2], function() return db[key] == o[1] end, function()
          db[key] = o[1]
          apply()
          RefreshControls()
        end)
      end
    end)
    -- Regenerating the menu updates the shown choice (after /wu reset).
    function ch:Draw() dd:GenerateMenu() end
    function ch:SetEnabled(on) dd:SetEnabled(on) end
    AddControl(ch, label, -4, disabled)
    dd:SetPoint("LEFT", ch, "LEFT", 130, 0)
  end

  -- Color swatch for db[key] ({ r, g, b, a }). Clicking it opens Blizzard's
  -- color picker, with opacity unless noAlpha (then a stays 1); changes apply
  -- as the color is picked, and
  -- Cancel puts back the color from before it opened. The Default button next
  -- to it restores the default color. apply runs after every change.
  local function ColorSwatch(label, key, apply, disabled, noAlpha)
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
      Set(r, g, b, noAlpha and 1 or ColorPickerFrame:GetColorAlpha())
    end
    sw:SetScript("OnClick", function()
      local old = db[key]
      ColorPickerFrame:SetupColorPickerAndShow({
        r = old.r, g = old.g, b = old.b, opacity = old.a, hasOpacity = not noAlpha,
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
  -- the left; the range display (warriors), slash commands and Discord link on
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
    Key("Mark I") .. ", " .. Key("Mark II") .. " and " .. Key("Mark III") .. " set the glow points; 0 turns one off.",
    Key("Only Show in Combat") .. " or " .. Key("Disable Rage Bar") .. " hide it.",
    "Druids only see it in " .. Key("Bear Form") .. " and " .. Key("Dire Bear Form") .. ".",
  })

  Heading("Moving the bar")
  Bullets({
    "Drag it, or click it and use the " .. Key("arrow keys") .. ".",
    Key("Shift") .. " moves 10 pixels at a time.",
    "Each Edit Mode layout keeps its own position.",
  })

  if ns.isWarrior then
    Heading("Cooldown bar")
    Bullets({
      "Set up each stance's bar on its own tab above.",
      "In " .. Key("Edit Mode") .. ", click " .. Key("WU Cooldown Bar") .. " to move it, set its icon size"
        .. " or turn on " .. Key("Only Show in Combat") .. ".",
    })
  end

  Heading("Minimap icon")
  Text("Click it to open these options; drag it around the minimap's edge to move it.")
  OnOff("Show minimap icon", "minimapOff", ns.RefreshMinimap)

  Begin(right)
  if ns.isWarrior then
    Heading("Range display")
    Bullets({
      "Shows how far your enemy target is, colored by what you can do from there.",
      "Set it up on the " .. Key("Range") .. " tab; move it in " .. Key("Edit Mode") .. " (" .. Key("WU Range Display") .. ").",
    })
  end

  Heading("Slash commands")
  Command("/wu", "Open options")
  Command("/wu 30 60 90", "Set the marks (0 = off)")
  Command("/wu reset", "Reset all settings")
  if ns.isWarrior then Command("/wu range", "Range debug commands") end
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
    Stepper("Text size", "shoutWarnSize", 10, 30, 2, ns.RefreshShout,
      function() return db.shoutOff or db.shoutWarnOff end)
    ColorSwatch("Bar color", "shoutColor", ns.RefreshShout, TimerOff)
  end

  ------------------------------------------------------------------------------
  -- Range tab (see Range.lua), in three sub-tabs: Display (what it shows, when
  -- and how it looks), Nameplate & Labels (the nameplate display and the
  -- focus and mouseover labels) and Zones (zones set by hand, colours and the
  -- debug commands). Everything but the display switch is greyed out while the
  -- display is off, and each group's settings while that group is off.
  -- Warriors only (see Tabs).
  ------------------------------------------------------------------------------
  if pages.range then
    local sub, ShowSub = Tabs(pages.range, {
      { "display", "Display" }, { "plates", "Nameplate & Labels" }, { "zones", "Zones" },
    }, 0, 0, 150, -36, 0, 0)
    local function Off() return db.rangeOff end
    local function NotTape() return db.rangeOff or db.rangeLook ~= "tape" end

    -- Display
    local left, right = Columns(sub.display)
    Begin(left)
    Heading("Distance to your target")
    Bullets({
      Key("Green") .. " melee, " .. Key("blue") .. " Charge, Intercept, Throw or Shoot while you can use it now.",
      Key("Red") .. " dead zone, " .. Key("grey") .. " out of range or a friendly player.",
      Key("no data") .. ": the game gave no range answer.",
      "Move it in " .. Key("Edit Mode") .. " (" .. Key("WU Range Display") .. ").",
      "Based on " .. Key("Good Range") .. " by Andrii Zolotarenko.",
    })
    Heading("Show")
    OnOff("Show range display", "rangeOff", ns.RefreshRange)
    OnOff("Show out of combat", "rangeOocOff", ns.RefreshRange, Off)
    OnOff("Show on friendly players", "rangeFriendlyOff", ns.RefreshRange, Off)
    OnOff("Show \"yd\" after the number", "rangeUnitOff", ns.RefreshRange,
      function() return db.rangeOff or db.rangeLook == "badge" end)

    Begin(right)
    Heading("Look")
    Choice("Look", "rangeLook", ns.RefreshRange, Off)
    Choice("Font", "rangeTextFont", ns.RefreshRange, Off)
    Stepper("Font size", "rangeSize", 12, 64, 2, ns.RefreshRange, Off)
    Stepper("Opacity (%)", "rangeOpacity", 10, 100, 10, ns.RefreshRange, Off)
    Heading("Tape")
    Stepper("Width", "rangeWidth", 80, 300, 10, ns.RefreshRange, NotTape)
    Stepper("Height", "rangeHeight", 16, 60, 1, ns.RefreshRange, NotTape)
    Stepper("Pixels per yard", "rangeScale", 10, 40, 2, ns.RefreshRange, NotTape)

    -- Nameplate & Labels
    left, right = Columns(sub.plates)
    Begin(left)
    Heading("Nameplate")
    Bullets({
      "Puts the display on your target's nameplate, with the same look.",
      Key("Nameplate") .. " uses the screen spot while the target has no nameplate.",
    })
    local function NoPlate() return db.rangeOff or db.rangePlace == "screen" end
    Choice("Show on", "rangePlace", ns.RefreshRange, Off)
    Stepper("Height above nameplate", "rangePlateY", 0, 60, 2, ns.RefreshRange, NoPlate)
    Stepper("Nameplate size (%)", "rangePlateScale", 50, 150, 10, ns.RefreshRange, NoPlate)

    Begin(right)
    Heading("Focus and mouseover")
    Bullets({
      "Small labels with the distance to your focus and to the unit under the mouse.",
      "Move the focus label in " .. Key("Edit Mode") .. " (" .. Key("WU Range Focus") .. "); with nameplates on, it sits on the focus's nameplate.",
    })
    OnOff("Focus label", "rangeFocusOff", ns.RefreshRange, Off)
    OnOff("Mouseover label", "rangeMouseOff", ns.RefreshRange, Off)
    Stepper("Label size (%)", "rangeLabelScale", 50, 200, 10, ns.RefreshRange,
      function() return db.rangeOff or db.rangeFocusOff and db.rangeMouseOff end)

    -- Zones
    left, right = Columns(sub.zones)
    Begin(left)
    Heading("Zones")
    Bullets({
      Key("Automatic") .. " zones follow what you can use right now.",
      "Untick it to set them by hand, in a row from 0 yd: each ends where you set it.",
      "Set a zone's end to the one before it to leave it out.",
    })
    local function Auto() return db.rangeOff or not db.rangeAutoOff end
    OnOff("Automatic zones", "rangeAutoOff", ns.RefreshRange, Off)
    Stepper("Melee (green) to", "rangeZone1", 0, 50, 1, ns.RefreshRange, Auto)
    Stepper("Dead zone (red) to", "rangeZone2", 0, 50, 1, ns.RefreshRange, Auto)
    Stepper("Ranged (blue) to", "rangeZone3", 0, 50, 1, ns.RefreshRange, Auto)

    Begin(right)
    Heading("Colors")
    ColorSwatch("Melee", "rangeColorPrimary", ns.RefreshRange, Off, true)
    ColorSwatch("Ranged", "rangeColorSecondary", ns.RefreshRange, Off, true)
    ColorSwatch("Dead zone", "rangeColorDead", ns.RefreshRange, Off, true)
    ColorSwatch("Out of range", "rangeColorFar", ns.RefreshRange, Off, true)
    Heading("Debug commands")
    Command("/wu range list", "Range steps and answers", 112)
    Command("/wu range stats", "The estimate's error", 112)
    Command("/wu range clear", "Clear the stats", 112)

    ShowSub("display")
  end

  ------------------------------------------------------------------------------
  -- Stance tabs: one per stance, for that stance's cooldown bar (see
  -- CooldownBar.lua): the bar and its ready glow on the left, the abilities on
  -- the right in bar order. Each ability row is a slot: row i shows whichever
  -- ability is i-th in the stance's order, so moving one up or down redraws
  -- the rows. Everything but the bar switch is greyed out while the bar is
  -- off. Warriors only (see Tabs).
  ------------------------------------------------------------------------------
  for _, s in ipairs(ns.STANCES) do
    if pages[s.key] then
      local barKey = s.key .. "CdOff"
      local function BarOff() return db[barKey] end
      local left, right = Columns(pages[s.key])

      Begin(left)
      Heading(s.name .. " cooldowns")
      Bullets({
        "Shows while you are in " .. Key(s.name) .. ".",
        "Each icon shows its cooldown and the time left.",
        "Abilities you haven't learned are left off.",
        "Move it and set its size in " .. Key("Edit Mode") .. " (" .. Key("WU Cooldown Bar") .. ").",
      })
      Heading("Settings")
      OnOff("Show cooldown bar", barKey, ns.RefreshCooldowns)
      OnOff("Glow when ready", s.key .. "AlertOff", ns.RefreshCooldowns, BarOff)

      Begin(right)
      Heading("Abilities")
      Text("Untick an ability to leave it off. " .. Key("Up") .. " and " .. Key("Down")
        .. " move it along the bar (top is leftmost).")
      local last = #s.spells

      -- Button that swaps the ability in row i with the one in row i + dir
      -- and saves the new order.
      local function MoveButton(text, i, dir)
        local b = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
        b:SetSize(44, 20)
        b:SetText(text)
        b:SetScript("OnClick", function()
          local order = ns.CooldownOrder(s)
          order[i], order[i + dir] = order[i + dir], order[i]
          db.cdOrder[s.key] = order
          ns.RefreshCooldowns()
          RefreshControls()
        end)
        return b
      end

      for i = 1, last do
        local cb = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        cb:SetSize(26, 26)
        local up, down = MoveButton("Up", i, -1), MoveButton("Down", i, 1)
        function cb:Draw()
          local id = ns.CooldownOrder(s)[i]
          self.label:SetText("|T" .. C_Spell.GetSpellTexture(id) .. ":16|t  " .. C_Spell.GetSpellName(id))
          self:SetChecked(not db.cdHide[s.key][id])
          up:SetEnabled(not BarOff() and i > 1)
          down:SetEnabled(not BarOff() and i < last)
        end
        cb:SetScript("OnClick", function(self)
          db.cdHide[s.key][ns.CooldownOrder(s)[i]] = not self:GetChecked()
          ns.RefreshCooldowns()
          RefreshControls()
        end)
        AddControl(cb, "", -4, BarOff)
        up:SetPoint("LEFT", cb, "LEFT", 180, 0)
        down:SetPoint("LEFT", up, "RIGHT", 2, 0)
      end
    end
  end

  ShowTab("general")

  category = Settings.RegisterCanvasLayoutCategory(opt, "WU - Warrior Utilities")
  Settings.RegisterAddOnCategory(category)
end

--------------------------------------------------------------------------------
-- Slash commands: /wu (or /wuutil)
--   /wu            open options
--   /wu 30 60 [90] set marks (the third is optional; 0 = off)
--   /wu reset
--   /wu range list | stats | clear   range debug output (warriors, see Range.lua)
-- SLASH_WU1, SLASH_WU2 and SlashCmdList.WU are globals the game requires.
--------------------------------------------------------------------------------
SLASH_WU1, SLASH_WU2 = "/wu", "/wuutil"
SlashCmdList.WU = function(msg)
  if not ns.built then return end -- not a warrior or druid
  msg = strtrim(msg:lower())
  local a, b, c = msg:match("^(%d+)%s+(%d+)%s*(%d*)$")
  if msg == "" then
    ns.OpenOptions()
  elseif ns.isWarrior and msg:match("^range") then
    ns.RangeCommand(strtrim(msg:sub(6)))
  elseif msg == "reset" then
    wipe(db)
    ns.LoadDB()
    ns.RefreshBar()
    ns.RefreshMinimap()
    if ns.isWarrior then
      ns.RefreshRange()
      ns.RefreshShout()
      ns.RefreshCooldowns()
    end
    print("WU - Warrior Utilities reset")
  elseif a then
    ns.SetMarks(a, b, c ~= "" and c or nil)
    local shown = {}
    for i = 1, 3 do
      local m = db["mark" .. i]
      shown[i] = m > 0 and m or "off"
    end
    print("WU - Warrior Utilities marks set to " .. table.concat(shown, " / "))
  else
    print("WU - Warrior Utilities: /wu, /wu 30 60 90, /wu reset" .. (ns.isWarrior and ", /wu range" or ""))
  end
end
