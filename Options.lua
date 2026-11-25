local addonName, ns = ...
local db = ns.db
local GOLD = { 0.90, 0.80, 0.50 }

--------------------------------------------------------------------------------
-- Options page
-- General tab (how to use the addon, the minimap icon switch, slash commands,
-- the Discord link and, on warriors, the audio alert voice) and, on warriors
-- only, a Range tab (the range display, in three sub-tabs) and a CDM tab
-- with Stances (each stance's cooldown bar), Battle Shout (the player frame
-- timer), Debuffs (the debuff tracker), Custom (the custom cooldown bar) and
-- Appearance (the look the cooldown bars share) sub-tabs, and a Trinket tab
-- (the trinket and gear bars, rotation and mount swap) and a Combat Text tab
-- (moving the game's combat text), shown in Esc > Options >
-- AddOns > WU - Warrior Utilities. Blizzard's Settings panel hosts the page
-- as a canvas layout category: it parents, sizes, shows and
-- hides the frame, and Escape closes the panel. All rage bar settings are in
-- Edit Mode (see RageBar.lua), so the page only explains them.
-- The header shows the addon version from the TOC's ## Version line, and a
-- Change Log button at the top right (see Changelog.lua).
-- SavedVariables: minimapOff, shoutOff, shoutTextOff, shoutFlashOff, shoutWarnOff,
--   shoutWarnSize, shoutColor, debuffOff, sunderOff, demoOff, debuffFont,
--   debuffTextColor, debuffTextPos, sunderAlertOff,
--   demoAlertOff, shoutAlertOff, sunderAlertSec, demoAlertSec, shoutAlertSec,
--   alertVoice, alertVolume, rangeOff,
--   rangeOocOff, rangeFriendlyOff,
--   rangeLook, rangeTextFont, rangeSize, rangeWidth, rangeHeight, rangeScale,
--   rangeUnitOff, rangeOpacity, rangePlace, rangePlateY, rangePlateScale,
--   rangeFocusOff, rangeMouseOff, rangeLabelScale, rangeAutoOff, rangeZone1,
--   rangeZone2, rangeZone3, rangeColorPrimary, rangeColorSecondary,
--   rangeColorDead, rangeColorFar,
--   battleCdOff, defensiveCdOff, berserkerCdOff, battleAlertOff,
--   defensiveAlertOff, berserkerAlertOff, cdHide, cdOrder, cdNoGlow,
--   customOff, customList, glowStyle, glowColor, glowSpeed, glowSize,
--   glowOocOff, cdLook, trinketOff, trinketMenuOff, gearOff, trinketQueue,
--   rotate13Off, rotate14Off, mountSwapOff, mountSlot, trinketBorder, ctRaised,
--   ctX, ctY
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
  -- shows one of them. A page added to pages afterwards has no tab button
  -- (the change log); showing it leaves every tab unselected.
  local function Tabs(parent, list, x, y, w, pageY, right, bottom)
    local pages, btns = {}, {}
    local function Show(name)
      for k, page in pairs(pages) do
        page:SetShown(k == name)
        if btns[k] then
          btns[k].label:SetTextColor(unpack(k == name and GOLD or { 0.72, 0.70, 0.64 }))
          btns[k].bar:SetShown(k == name)
        end
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
    TABS[2] = { "range", "Range" }
    TABS[3] = { "cdm", "CDM" }
    TABS[4] = { "trinket", "Trinket" }
    TABS[5] = { "combat", "Combat Text" }
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

  -- Audio alert settings are read when an alert plays (see Alerts.lua), so
  -- changing one needs nothing else applied.
  local function Nothing() end

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

  -- Checkbox for an "off" setting: checked while db[key] is false. key can be
  -- a function returning the key, for a page that switches what it shows
  -- (the Stances tab). apply runs after a click.
  local function OnOff(label, key, apply, disabled)
    local function K() return type(key) == "function" and key() or key end
    local cb = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
    cb:SetSize(26, 26)
    function cb:Draw() self:SetChecked(not db[K()]) end
    cb:SetScript("OnClick", function(self)
      db[K()] = not self:GetChecked()
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

  -- Slider for a whole number from low to high: the label, with Blizzard's
  -- slider (arrows at each end, the value on its right) under it. key is a db
  -- key, or { get = function, set = function } for a game setting. apply runs
  -- after the player moves it, not when the page redraws it. The control is an
  -- empty box tall enough for both, so the label lines up with the others.
  local function Slider(label, key, low, high, apply, disabled)
    local get = type(key) == "table" and key.get or function() return db[key] end
    local set = type(key) == "table" and key.set or function(v) db[key] = v end
    local sl = CreateFrame("Frame", nil, page)
    sl:SetSize(26, 42)
    local bar = CreateFrame("Frame", nil, page, "MinimalSliderWithSteppersTemplate")
    bar:SetWidth(220)
    local Right = MinimalSliderWithSteppersMixin.Label.Right
    bar:Init(get(), low, high, high - low, { [Right] = CreateMinimalSliderFormatter(Right) })
    bar:RegisterCallback("OnValueChanged", function(_, v)
      if v ~= get() then
        set(v)
        apply()
      end
    end, sl)
    function sl:Draw() bar:SetValue(get()) end
    function sl:SetEnabled(on) bar:SetEnabled(on) end
    AddControl(sl, label, -4, disabled)
    sl.label:ClearAllPoints()
    sl.label:SetPoint("TOPLEFT", sl, "TOPLEFT", LABEL_X + 4, 0)
    bar:SetPoint("TOPLEFT", sl.label, "BOTTOMLEFT", -6, -4)
  end

  -- Dropdown: the label, then Blizzard's dropdown button showing the current
  -- choice, one of the { value, name } pairs getList() returns when the menu
  -- opens. get() returns the current value and set(value) stores a pick. Like
  -- the stepper, the control itself is an empty checkbox-sized box so the
  -- label lines up.
  local function Pick(label, getList, get, set, disabled)
    local ch = CreateFrame("Frame", nil, page)
    ch:SetSize(26, 26)
    local dd = CreateFrame("DropdownButton", nil, page, "WowStyle1DropdownTemplate")
    dd:SetWidth(150)
    dd:SetupMenu(function(_, root)
      for _, o in ipairs(getList()) do
        root:CreateRadio(o[2], function() return get() == o[1] end, function()
          set(o[1])
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

  -- Dropdown for db[key], one of the ns.LISTS[key] choices (see Core.lua), or
  -- of the list getList returns. apply runs after a pick.
  local function Choice(label, key, apply, disabled, getList)
    Pick(label, getList or function() return ns.LISTS[key] end, function() return db[key] end,
      function(v)
        db[key] = v
        apply()
      end, disabled)
  end

  -- Checkbox drawn from get(); set(checked) runs after a click.
  local function Check(label, get, set, disabled)
    local cb = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
    cb:SetSize(26, 26)
    function cb:Draw() self:SetChecked(get()) end
    cb:SetScript("OnClick", function(self)
      set(self:GetChecked())
      RefreshControls()
    end)
    AddControl(cb, label, -4, disabled)
  end

  -- Grid of clickable icon slots, perRow to a row and at most max, one per
  -- entry of the list spec.list() returns, in order. spec.look(e) returns the
  -- entry's texture, name, whether it is left off the bar (drawn faded) and
  -- whether it glows (a gold tick in the corner). Clicking a slot selects it
  -- (spec.select(i); spec.selected() says which is, outlined in gold), and
  -- dragging a slot onto another runs spec.move(from, to). spec.empty is
  -- shown while the list is empty.
  local SLOT, SLOT_GAP = 36, 6
  local function SlotGrid(max, perRow, spec)
    local grid = CreateFrame("Frame", nil, page)
    grid:SetSize(perRow * (SLOT + SLOT_GAP), math.ceil(max / perRow) * (SLOT + SLOT_GAP))
    local empty = grid:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    empty:SetPoint("TOPLEFT", 0, -4)
    empty:SetText(spec.empty or "")
    local slots, from = {}, nil
    function grid:Draw()
      local list = spec.list()
      empty:SetShown(#list == 0)
      for i, b in ipairs(slots) do
        local e = list[i]
        b:SetShown(e ~= nil)
        if e then
          local tex, _, off, glow = spec.look(e)
          b.icon:SetTexture(tex)
          b.icon:SetDesaturated(off)
          b.icon:SetAlpha(off and 0.35 or 1)
          b.tick:SetShown(glow)
          b.sel:SetShown(i == spec.selected())
        end
      end
    end
    function grid:SetEnabled(on)
      for _, b in ipairs(slots) do b:SetEnabled(on) end
      grid:SetAlpha(on and 1 or 0.5)
    end
    for i = 1, max do
      local b = CreateFrame("Button", nil, grid)
      b:SetSize(SLOT, SLOT)
      b:SetPoint("TOPLEFT", ((i - 1) % perRow) * (SLOT + SLOT_GAP), -math.floor((i - 1) / perRow) * (SLOT + SLOT_GAP))
      b.icon = b:CreateTexture(nil, "ARTWORK")
      b.icon:SetAllPoints()
      b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
      b.tick = b:CreateTexture(nil, "OVERLAY")
      b.tick:SetSize(16, 16)
      b.tick:SetPoint("TOPRIGHT", 4, 4)
      b.tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
      b.tick:SetVertexColor(1, 0.82, 0.2)
      b.sel = CreateFrame("Frame", nil, b, "BackdropTemplate")
      b.sel:SetPoint("TOPLEFT", -3, 3)
      b.sel:SetPoint("BOTTOMRIGHT", 3, -3)
      b.sel:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
      b.sel:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 1)
      b:RegisterForDrag("LeftButton")
      b:SetScript("OnClick", function()
        spec.select(i)
        RefreshControls()
      end)
      b:SetScript("OnDragStart", function(self)
        from = i
        self:SetAlpha(0.4)
      end)
      b:SetScript("OnDragStop", function(self)
        self:SetAlpha(1)
        for to, t in ipairs(slots) do
          if to ~= from and t:IsShown() and t:IsMouseOver() then
            spec.move(from, to)
            RefreshControls()
            break
          end
        end
        from = nil
      end)
      b:SetScript("OnEnter", function(self)
        local _, name = spec.look(spec.list()[i])
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(name or "?", 1, 1, 1)
        GameTooltip:AddLine("Click: select. Drag: move.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
      end)
      b:SetScript("OnLeave", GameTooltip_Hide)
      slots[i] = b
    end
    grid.label = grid:CreateFontString() -- RefreshControls sets every control's label font
    grid:SetScript("OnShow", RefreshControls)
    Place(grid, 8, 0)
    controls[#controls + 1] = grid
    return grid
  end

  -- Moves entry from to position to in list l (the others shift along).
  local function Move(l, from, to)
    table.insert(l, to, table.remove(l, from))
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
    "Drag it, or click it and use the " .. Key("arrow keys") .. " (" .. Key("Shift") .. ": 10 pixels).",
    "Each Edit Mode layout keeps its own position.",
  })

  if ns.isWarrior then
    Heading("Cooldown bars")
    Bullets({
      "Set them up on the " .. Key("CDM") .. " tab, and the trinket bars on " .. Key("Trinket") .. ".",
      "Move and size them in " .. Key("Edit Mode") .. ", where each has a " .. Key("WU") .. " name.",
    })
  end

  Heading("Minimap icon")
  Text("Click it to open these options" .. (ns.isWarrior and "; right-click to unlock the trinket bars" or "")
    .. ". Drag it around the minimap's edge to move it.")
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

  -- The voice and volume every audio alert uses (warriors only).
  if ns.isWarrior then
    Heading("Audio alert voice")
    Choice("Voice", "alertVoice", Nothing, nil, ns.AlertVoices)
    Choice("Volume", "alertVolume", Nothing)
    local test = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    test:SetSize(80, 22)
    test:SetText("Test")
    test:SetScript("OnClick", function() ns.PlayAlert("Sunder") end)
    Place(test, 8, 4)
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
    })
    Heading("Show")
    OnOff("Show range display", "rangeOff", ns.RefreshRange)
    OnOff("Show out of combat", "rangeOocOff", ns.RefreshRange, Off)
    OnOff("Show on friendly players", "rangeFriendlyOff", ns.RefreshRange, Off)
    OnOff("Show \"yd\" after the number", "rangeUnitOff", ns.RefreshRange,
      function() return db.rangeOff or db.rangeLook == "badge" end)
    Heading("Credits")
    Text("Thanks to " .. Key("artand") .. " (Andrii Zolotarenko), creator of the "
      .. Key("Good Range") .. " addon, for the idea behind this range display. "
      .. "It is adapted from Good Range under the MIT license.")

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
  -- CDM tab: sub-tabs for the stance cooldown bars, the Battle Shout timer,
  -- the debuff tracker, the custom bar and the look the cooldown bars share.
  -- Warriors only (see Tabs).
  ------------------------------------------------------------------------------
  if pages.cdm then
    local list = {
      { "stances", "Stances" }, { "shout", "Battle Shout" }, { "debuffs", "Debuffs" },
      { "custom", "Custom" }, { "look", "Appearance" },
    }
    local sub, ShowSub = Tabs(pages.cdm, list, 0, 0, 94, -36, 0, 0)

    -- Stances sub-tab: one stance at a time, picked from the dropdown at the
    -- top (see CooldownBar.lua). On the left the stance's bar and glow
    -- switches; on the right its abilities as icon slots in bar order (click
    -- to select, drag to move) and the selected ability's own settings: on
    -- the bar, glow when ready and its glow type. Everything is greyed out
    -- while that bar is off, and the glow settings while the stance's glow is
    -- off.
    local stance, selected = ns.STANCES[1], 1
    local function BarKey() return stance.key .. "CdOff" end
    local function GlowKey() return stance.key .. "AlertOff" end
    local function BarOff() return db[BarKey()] end
    local left, right = Columns(sub.stances)

    Begin(left)
    Heading("Stance bars")
    local pick = CreateFrame("Frame", nil, page)
    pick:SetSize(26, 26)
    local dd = CreateFrame("DropdownButton", nil, page, "WowStyle1DropdownTemplate")
    dd:SetWidth(150)
    dd:SetupMenu(function(_, root)
      for _, s in ipairs(ns.STANCES) do
        root:CreateRadio(s.name, function() return stance == s end, function()
          stance, selected = s, 1
          RefreshControls()
        end)
      end
    end)
    function pick:Draw() dd:GenerateMenu() end
    function pick:SetEnabled() end
    AddControl(pick, "Stance", -4)
    dd:SetPoint("LEFT", pick, "LEFT", 130, 0)
    Bullets({
      "Each stance has its own bar, shown while you are in it.",
      "Each icon shows its cooldown and the time left.",
      "Abilities you haven't learned are left off.",
      "Change how the icons look on the " .. Key("Appearance") .. " tab; an ability can have its own glow type.",
      "Move it and set its size in " .. Key("Edit Mode") .. " (" .. Key("WU Cooldown Bar") .. ").",
    })
    Heading("Settings")
    OnOff("Show cooldown bar", BarKey, ns.RefreshCooldowns)
    OnOff("Glow when ready", GlowKey, ns.RefreshCooldowns, BarOff)

    Begin(right)
    Heading("Abilities")
    Text(Key("Click") .. " an icon to set it up below. " .. Key("Drag") .. " it onto another to move it"
      .. " (top left is leftmost on the bar).")
    -- The stance's ability on the selected slot.
    local function Ability() return ns.CooldownOrder(stance)[selected] end
    SlotGrid(10, 6, {
      list = function() return ns.CooldownOrder(stance) end,
      look = function(id)
        return C_Spell.GetSpellTexture(id), C_Spell.GetSpellName(id), db.cdHide[stance.key][id],
          not db[GlowKey()] and not db.cdNoGlow[stance.key][id]
      end,
      selected = function() return selected end,
      select = function(i) selected = i end,
      move = function(from, to)
        local order = ns.CooldownOrder(stance)
        Move(order, from, to)
        db.cdOrder[stance.key] = order
        if selected == from then selected = to end
        ns.RefreshCooldowns()
      end,
    }).disabled = BarOff

    -- The selected ability's own settings.
    local name = CreateFrame("Frame", nil, page)
    name:SetSize(26, 26)
    function name:Draw()
      self.label:SetText("|T" .. C_Spell.GetSpellTexture(Ability()) .. ":18|t  " .. Key(C_Spell.GetSpellName(Ability())))
    end
    function name:SetEnabled() end
    AddControl(name, "", -4)
    local function NoGlow() return BarOff() or db[GlowKey()] or db.cdNoGlow[stance.key][Ability()] end
    Check("Show on bar", function() return not db.cdHide[stance.key][Ability()] end, function(on)
      db.cdHide[stance.key][Ability()] = not on or nil
      ns.RefreshCooldowns()
    end, BarOff)
    Check("Glow when ready", function() return not db.cdNoGlow[stance.key][Ability()] end, function(on)
      db.cdNoGlow[stance.key][Ability()] = not on or nil
      ns.RefreshCooldowns()
    end, function() return BarOff() or db[GlowKey()] end)
    Pick("Glow type", function() return ns.GLOW_TYPES end,
      function() return db.cdGlowStyle[stance.key][Ability()] or "default" end, function(v)
        db.cdGlowStyle[stance.key][Ability()] = v ~= "default" and v or nil
        ns.RefreshCooldowns()
      end, NoGlow)

    -- Battle Shout sub-tab: what the player frame timer shows and its
    -- switches (see ShoutTimer.lua), then its audio alert. The rest of the
    -- timer is greyed out while the whole timer is off.
    Begin(sub.shout)
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

    Heading("Audio alert")
    Text("Says " .. Key("Battle Shout") .. " in combat when it is about to run out, or when you enter combat"
      .. " without it. Voice and volume are on the " .. Key("General") .. " tab.")
    OnOff("Battle Shout alert", "shoutAlertOff", Nothing)
    Stepper("Seconds left when it plays", "shoutAlertSec", 0, 10, 1, Nothing, function() return db.shoutAlertOff end)

    -- Debuffs sub-tab: the debuff tracker (see Debuffs.lua) on the left, its
    -- debuff switches greyed out while it is off; the debuff audio alerts
    -- (see Alerts.lua) on the right. Their voice is on the General tab.
    local left, right = Columns(sub.debuffs)
    Begin(left)
    local function TrackerOff() return db.debuffOff end

    Heading("On your target")
    Bullets({
      Key("Sunder Armor") .. " shows its stacks (from 2 up) and the time left.",
      Key("Demoralizing Shout") .. " shows the time left; " .. Key("Demoralizing Roar") .. " and "
        .. Key("Curse of Weakness") .. " count too.",
      "A dimmed icon means that debuff is missing.",
      "It shows while you target an enemy, and counts every player's debuffs.",
      "Move it and set its size in " .. Key("Edit Mode") .. " (" .. Key("WU Debuffs") .. ").",
    })

    Heading("Settings")
    OnOff("Show debuff tracker", "debuffOff", ns.RefreshDebuffs)
    OnOff("Track Sunder Armor", "sunderOff", ns.RefreshDebuffs, TrackerOff)
    OnOff("Track Demoralizing Shout", "demoOff", ns.RefreshDebuffs, TrackerOff)

    Heading("Countdown")
    Choice("Position", "debuffTextPos", ns.RefreshDebuffs, TrackerOff)
    Choice("Font", "debuffFont", ns.RefreshDebuffs, TrackerOff)
    ColorSwatch("Color", "debuffTextColor", ns.RefreshDebuffs, TrackerOff, true)

    Begin(right)
    Heading("Audio alerts")
    Bullets({
      "In combat, says the debuff's name when it is about to fall off your target.",
      "Read from the target (or its nameplate) when the game allows; otherwise timed from your casts.",
      "A Sunder that is dodged, parried or misses is taken back when you're solo.",
    })
    OnOff("Sunder Armor alert", "sunderAlertOff", Nothing)
    Stepper("Seconds left", "sunderAlertSec", 0, 10, 1, Nothing, function() return db.sunderAlertOff end)
    OnOff("Demoralizing Shout alert", "demoAlertOff", Nothing)
    Stepper("Seconds left", "demoAlertSec", 0, 10, 1, Nothing, function() return db.demoAlertOff end)
    -- Custom sub-tab: the custom bar (see CustomBar.lua). On the left the bar
    -- switch and a box to add a spell or item by ID; on the right one row per
    -- entry, in bar order, with Up, Down and Remove. Like the stance rows,
    -- row i shows whichever entry is i-th, and rows past the end hide (the
    -- first one says the list is empty instead).
    left, right = Columns(sub.custom)
    Begin(left)
    Heading("Custom cooldowns")
    Bullets({
      "Tracks the cooldowns you add here, in the order you set.",
      "Type a " .. Key("spell ID") .. " or an " .. Key("item ID") .. " (for trinkets) and press " .. Key("Add") .. ".",
      "An ID that is both counts as an item you carry, then a spell you know.",
      "Find IDs on Wowhead: the number in the page's address.",
      "Move it and set its size in " .. Key("Edit Mode") .. " (" .. Key("WU Custom Bar") .. ").",
    })
    Heading("Settings")
    OnOff("Show custom bar", "customOff", ns.RefreshCustom)

    Heading("Add")
    local picked = 1 -- the selected entry on the right; a new entry is selected
    local box = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
    box:SetSize(90, 20)
    box:SetAutoFocus(false)
    box:SetNumeric(true)
    Place(box, 10, 10)
    local status = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetJustifyH("LEFT")
    -- Works out what an ID means, since a number can be both a spell and an
    -- item: an item the player has (equipped or in the bags), then a spell
    -- the player knows, then any item, then any spell. Returns "item",
    -- "spell" or nil.
    local function KindOf(id)
      if C_Item.GetItemCount(id) > 0 then return "item" end
      if IsPlayerSpell(id) then return "spell" end
      if C_Item.DoesItemExistByID(id) then return "item" end
      if C_Spell.DoesSpellExist(id) then return "spell" end
    end
    -- Adds the ID in the box as whatever KindOf finds.
    local add = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    add:SetSize(80, 22)
    add:SetText("Add")
    add:SetPoint("LEFT", box, "RIGHT", 8, 0)
    add:SetScript("OnClick", function()
      local id = tonumber(box:GetText())
      local kind = id and KindOf(id)
      if #db.customList >= ns.CUSTOM_MAX then
        status:SetText("The bar holds " .. ns.CUSTOM_MAX .. " at most.")
      elseif not kind then
        status:SetText("No spell or item with that ID.")
      else
        if kind == "item" then C_Item.RequestLoadItemDataByID(id) end
        table.insert(db.customList, { kind = kind, id = id })
        picked = #db.customList
        box:SetText("")
        status:SetText("Added " .. kind .. " " .. id .. ".")
        ns.RefreshCustom()
        RefreshControls()
      end
    end)
    status:SetPoint("TOPLEFT", box, "BOTTOMLEFT", -6, -6)
    status:SetPoint("RIGHT", page, "RIGHT", -4, 0)

    Begin(right)
    Heading("Tracked")
    Text(Key("Click") .. " an icon to set it up below. " .. Key("Drag") .. " it onto another to move it"
      .. " (top left is leftmost on the bar).")
    -- The selected entry, or nil while the list is empty.
    local function Entry()
      picked = math.max(1, math.min(picked, #db.customList))
      return db.customList[picked]
    end
    SlotGrid(ns.CUSTOM_MAX, 6, {
      list = function() return db.customList end,
      look = function(e)
        local name, tex = ns.CustomInfo(e)
        return tex or 134400, name or (e.kind == "item" and "Item " or "Spell ") .. e.id, e.off,
          e.kind == "spell" and not e.noGlow
      end,
      selected = function() return picked end,
      select = function(i) picked = i end,
      move = function(from, to)
        Move(db.customList, from, to)
        if picked == from then picked = to end
        ns.RefreshCustom()
      end,
      empty = "Nothing added yet.",
    })

    -- The selected entry's own settings. Items can't glow (see
    -- CooldownLook.lua), so their glow settings stay greyed out.
    local info = CreateFrame("Frame", nil, page)
    info:SetSize(26, 26)
    function info:Draw()
      local e = Entry()
      if not e then
        self.label:SetText("")
        return
      end
      local name, tex = ns.CustomInfo(e)
      self.label:SetText("|T" .. (tex or 134400) .. ":18|t  " .. Key(name or "") .. " (" .. e.kind .. " " .. e.id .. ")")
    end
    function info:SetEnabled() end
    AddControl(info, "", -4)
    local function None() return not Entry() end
    local function NotSpell() return not Entry() or Entry().kind ~= "spell" end
    Check("Show on bar", function() return Entry() and not Entry().off end, function(on)
      Entry().off = not on or nil
      ns.RefreshCustom()
    end, None)
    Check("Glow when ready", function() return Entry() and Entry().kind == "spell" and not Entry().noGlow end,
      function(on)
        Entry().noGlow = not on or nil
        ns.RefreshCustom()
      end, NotSpell)
    Pick("Glow type", function() return ns.GLOW_TYPES end,
      function() return Entry() and Entry().glowStyle or "default" end, function(v)
        Entry().glowStyle = v ~= "default" and v or nil
        ns.RefreshCustom()
      end, function() return NotSpell() or Entry().noGlow end)
    local remove = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    remove:SetSize(80, 22)
    remove:SetText("Remove")
    remove:SetScript("OnClick", function()
      if not Entry() then return end
      table.remove(db.customList, picked)
      ns.RefreshCustom()
      RefreshControls()
    end)
    Place(remove, 8, 4)

    -- Appearance sub-tab: the look every cooldown bar's icons share (see
    -- CooldownLook.lua): the ready glow on the left, the on-cooldown look and
    -- a preview of both on the right. The preview icons always show, ready
    -- and on cooldown, whatever the player's cooldowns are doing.
    left, right = Columns(sub.look)
    local function Look()
      ns.RefreshLook()
      RefreshControls()
    end
    Begin(left)
    Heading("When an ability is ready")
    Choice("Glow", "glowStyle", Look)
    ColorSwatch("Glow color", "glowColor", Look, nil, true)
    Choice("Speed", "glowSpeed", Look, function() return db.glowStyle == "static" end)
    Stepper("Thickness", "glowSize", 1, 4, 1, Look)
    OnOff("Glow out of combat", "glowOocOff", Look)

    Heading("While on cooldown")
    Choice("Icon", "cdLook", Look)
    Bullets({
      "An icon still greys out while you can't use it (no rage, or its trigger hasn't happened).",
      Key("Hidden") .. " icons keep their place on the bar.",
      "This is for every cooldown bar: each stance's and the custom bar.",
      "Items on the custom bar only show their cooldown.",
    })

    Begin(right)
    Heading("Preview")
    local preview = CreateFrame("Frame", nil, page)
    preview:SetSize(140, 64)
    local readyIcon, coolIcon = ns.NewCooldownIcon(preview), ns.NewCooldownIcon(preview)
    for i, f in ipairs({ readyIcon, coolIcon }) do
      f.preview = true
      f:SetSize(44, 44)
      f:SetPoint("TOPLEFT", 8 + (i - 1) * 72, -6)
      local tex = C_Spell.GetSpellTexture(ns.STANCES[1].spells[i + 1])
      f.tex:SetTexture(tex)
      f.cdGrey.tex:SetTexture(tex)
      ns.SetIconGlow(f, true)
      local label = preview:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      label:SetPoint("TOP", f, "BOTTOM", 0, -4)
      label:SetText(i == 1 and "Ready" or "On cooldown")
    end
    function preview:Draw()
      ns.PreviewIcon(readyIcon, true)
      ns.PreviewIcon(coolIcon, false)
    end
    function preview:SetEnabled() end
    preview.label = preview:CreateFontString()
    preview:SetScript("OnShow", RefreshControls)
    Place(preview, 8, 0)
    controls[#controls + 1] = preview

    ShowSub(list[1][1])
  end

  ------------------------------------------------------------------------------
  -- Trinket tab (see Trinkets.lua and TrinketAuto.lua): the bars, the mount
  -- swap and credits on the left; each trinket slot's rotation on the right,
  -- as icon slots in priority order (click to select, drag to move). Warriors
  -- only (see Tabs).
  ------------------------------------------------------------------------------
  if pages.trinket then
    local left, right = Columns(pages.trinket)
    Begin(left)
    Heading("Trinket bar")
    Bullets({
      Key("Click") .. " a trinket, or its key (" .. Key("Key Bindings") .. "), to use it.",
      "Hover a slot to swap in an item from your bags; a pick made in combat goes on when it ends.",
      Key("Alt+click") .. " a trinket in that list to add it to the slot's rotation.",
      "Move the bars in " .. Key("Edit Mode") .. ", or " .. Key("right-click") .. " the minimap icon to unlock and drag them.",
    })
    OnOff("Show trinket bar", "trinketOff", ns.RefreshTrinkets)
    OnOff("Show the list on hover", "trinketMenuOff", ns.RefreshTrinkets)
    OnOff("Show usable gear bar", "gearOff", ns.RefreshTrinkets)
    Choice("Bar border", "trinketBorder", ns.RefreshTrinkets)

    Heading("Mount")
    OnOff("Carrot or Riding Crop when mounted", "mountSwapOff", ns.RefreshTrinkets)
    Choice("Put it in", "mountSlot", ns.RefreshTrinkets, function() return db.mountSwapOff end)

    Begin(right)
    Heading("Rotation")
    Text("When your trinket is on cooldown, the first ready one on the list goes on (out of combat)."
      .. " " .. Key("Drag") .. " to change the order.")
    for i, slot in ipairs({ 13, 14 }) do
      local picked = 1
      local function Rotation() return db.trinketQueue[slot] end
      local function Off() return db["rotate" .. slot .. "Off"] end
      OnOff("Rotate Trinket " .. i, "rotate" .. slot .. "Off", Nothing)
      SlotGrid(6, 6, {
        list = Rotation,
        look = function(id)
          return C_Item.GetItemIconByID(id), C_Item.GetItemNameByID(id) or ("Item " .. id), false, false
        end,
        selected = function() return picked end,
        select = function(n) picked = n end,
        move = function(from, to)
          Move(Rotation(), from, to)
          if picked == from then picked = to end
        end,
        empty = "Alt+click trinkets in the swap list to add them.",
      }).disabled = Off
      local remove = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
      remove:SetSize(130, 22)
      remove:SetText("Remove selected")
      remove:SetScript("OnClick", function()
        if Rotation()[picked] then table.remove(Rotation(), picked) end
        RefreshControls()
      end)
      Place(remove, 4, 4)
    end

    Heading("Credits")
    Text("Adapted from " .. Key("Forever Trinket Menu") .. " by " .. Key("sk0lu") .. " (MIT license).")
  end

  ------------------------------------------------------------------------------
  -- Combat Text tab (see CombatText.lua), with a Mover sub-tab: target text
  -- on the left, self text on the right. The self text controls are greyed out while self text is
  -- off in the game's options. Warriors only (see Tabs).
  ------------------------------------------------------------------------------
  if pages.combat then
    local sub, ShowSub = Tabs(pages.combat, { { "mover", "Mover" } }, 0, 0, 120, -36, 0, 0)
    local left, right = Columns(sub.mover)
    Begin(left)
    Heading("Target text")
    if ns.HasTargetText() then
      Text("The numbers above your target: damage you deal, heals, misses. Lift them when nameplates hide them."
        .. " This is a game setting, so it stays even with WU off.")
      Slider("Target height", { get = ns.GetTargetHeight, set = ns.SetTargetHeight }, -40, 40, Nothing)
      local reset = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
      reset:SetSize(120, 22)
      reset:SetText("Reset height")
      reset:SetScript("OnClick", function()
        ns.SetTargetHeight(0)
        RefreshControls()
      end)
      Place(reset, 8, 4)
    else
      Text("This game client doesn't have the settings that move target text.")
    end

    Heading("Credits")
    Text("Adapted from " .. Key("SCT Mover") .. " by " .. Key("KidMoxie") .. " (MIT license).")

    Begin(right)
    local function Off() return not ns.SelfTextOn() end
    Heading("Self text")
    Text("The numbers near your character: damage you take, heals you get.")
    local note = Text("Self text is off in the game's options.")
    note:SetTextColor(1, 0.25, 0.25)
    local watch = CreateFrame("Frame", nil, page) -- shows the note only while self text is off
    function watch:Draw() note:SetShown(Off()) end
    function watch:SetEnabled() end
    watch.label = watch:CreateFontString()
    controls[#controls + 1] = watch
    Check("Show above other UI elements", function() return db.ctRaised end, function(on)
      db.ctRaised = on
      ns.RefreshCombatText()
    end, Off)
    Slider("Horizontal", "ctX", -ns.CT_MAX_X, ns.CT_MAX_X, ns.RefreshCombatText, Off)
    Slider("Vertical", "ctY", -ns.CT_MAX_Y, ns.CT_MAX_Y, ns.RefreshCombatText, Off)
    local move = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    move:SetSize(80, 22)
    move:SetText("Move")
    move:SetScript("OnClick", ns.MoveSelfText)
    Place(move, 8, 4)
    local resetPos = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    resetPos:SetSize(120, 22)
    resetPos:SetText("Reset position")
    resetPos:SetPoint("LEFT", move, "RIGHT", 8, 0)
    resetPos:SetScript("OnClick", function()
      db.ctX, db.ctY = 0, 0
      ns.RefreshCombatText()
      RefreshControls()
    end)
    Text(Key("Move") .. " shows a box with sample text where self text starts: drag it, then click "
      .. Key("Done") .. ". Not in combat.")
    ShowSub("mover")
  end

  ------------------------------------------------------------------------------
  -- Change log: the Change Log button at the top right shows every version's
  -- changes (ns.CHANGELOG, see Changelog.lua) in a scrolling page in place of
  -- the tabs, filtered by the Version dropdown. Clicking a tab goes back.
  ------------------------------------------------------------------------------
  local log = CreateFrame("Frame", nil, opt)
  log:SetPoint("TOPLEFT", 18, -96)
  log:SetPoint("BOTTOMRIGHT", -18, 16)
  log:Hide()
  pages.changelog = log
  local logButton = CreateFrame("Button", nil, opt, "UIPanelButtonTemplate")
  logButton:SetSize(100, 22)
  logButton:SetText("Change Log")
  logButton:SetPoint("TOPRIGHT", -18, -14)
  logButton:SetScript("OnClick", function() ShowTab("changelog") end)

  local shown = "all" -- the version picked in the dropdown
  local SECTIONS = { { "added", "New" }, { "changed", "Changed" }, { "removed", "Removed" }, { "fixed", "Fixed" } }
  local scroll = CreateFrame("ScrollFrame", nil, log, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 0, -36)
  scroll:SetPoint("BOTTOMRIGHT", -26, 0)
  local body = CreateFrame("Frame", nil, scroll)
  scroll:SetScrollChild(body)
  local text = body:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  text:SetPoint("TOPLEFT", 4, -4)
  text:SetJustifyH("LEFT")
  text:SetSpacing(4)

  -- Writes the picked version (or every version) into the page and sizes
  -- the scrolling area to fit it.
  local function DrawLog()
    local gold, bullet, lines = "|cffe6cc80", "|cffe6cc80\226\128\162|r  ", {}
    for _, v in ipairs(ns.CHANGELOG) do
      if shown == "all" or shown == v.version then
        lines[#lines + 1] = gold .. "Version " .. v.version .. "|r  |cff9d9d9d" .. v.date .. "|r"
        for _, sec in ipairs(SECTIONS) do
          if v[sec[1]] then
            lines[#lines + 1] = "|cffffffff" .. sec[2] .. "|r"
            for _, item in ipairs(v[sec[1]]) do lines[#lines + 1] = bullet .. item end
          end
        end
        lines[#lines + 1] = " "
      end
    end
    local w = scroll:GetWidth()
    body:SetWidth(w)
    text:SetWidth(w - 8)
    text:SetText(table.concat(lines, "\n"))
    body:SetHeight(text:GetStringHeight() + 8)
    scroll:SetVerticalScroll(0)
  end
  log:SetScript("OnShow", DrawLog)
  scroll:SetScript("OnSizeChanged", DrawLog)

  local versionLabel = log:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  versionLabel:SetPoint("TOPLEFT", 4, -8)
  versionLabel:SetText("Version")
  local versions = CreateFrame("DropdownButton", nil, log, "WowStyle1DropdownTemplate")
  versions:SetWidth(150)
  versions:SetPoint("LEFT", versionLabel, "RIGHT", 12, 0)
  versions:SetupMenu(function(_, root)
    local function Radio(value, name)
      root:CreateRadio(name, function() return shown == value end, function()
        shown = value
        DrawLog()
      end)
    end
    Radio("all", "All versions")
    for _, v in ipairs(ns.CHANGELOG) do Radio(v.version, v.version) end
  end)

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
      ns.RefreshDebuffs()
      ns.RefreshLook()
      ns.RefreshCooldowns()
      ns.RefreshCustom()
      ns.RefreshTrinkets()
      ns.RefreshCombatText()
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
