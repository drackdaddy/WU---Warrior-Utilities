local addonName, ns = ...
local db, GOLD, Button = ns.db, ns.GOLD, ns.Button

--------------------------------------------------------------------------------
-- Options page
-- General tab (how to use the addon, slash commands and the Discord link) and
-- CDM tab (one section per WU Cooldown Manager layout, plus Restore Backup),
-- shown in Esc > Options > AddOns > WU - Warrior Utilities. Blizzard's Settings panel hosts the page as
-- a canvas layout category: it parents, sizes, shows and hides the frame, and
-- Escape closes the panel. Every control writes its setting and applies it at
-- once; Sync() reloads all controls from the settings when the page is shown.
-- All rage bar settings are in Edit Mode (see RageBar.lua).
-- The header shows the addon version from the TOC's ## Version line.
-- SavedVariables: cdmBackup (shown, not edited)
--------------------------------------------------------------------------------
local opt, category

-- Opens the Settings panel on this addon's page (only built on warriors).
local function Open()
  if category then Settings.OpenToCategory(category:GetID()) end
end

local function Sync()
  if opt then opt.Sync() end
end

function ns.BuildOptions()
  opt = CreateFrame("Frame")

  -- Every control registers a sync function; opt.Sync() runs all of them.
  local syncs = {}
  function opt.Sync() for _, f in ipairs(syncs) do f() end end
  opt:SetScript("OnShow", opt.Sync)

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
  local TABS = { { "general", "General" }, { "cdm", "CDM" } }
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
  -- Both tabs are laid out like a short readme: gold headings with a rule
  -- under them, then bullets, columns or buttons. Begin(page) starts a page;
  -- each piece is then anchored under the last one placed.
  ------------------------------------------------------------------------------
  local page, prev

  local function Begin(p) page, prev = p, nil end

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

  -- A UIPanelButtonTemplate button under the previous piece; returns it.
  local function PlaceButton(text, width, onClick)
    local b = Button(page, text, width, onClick)
    Place(b, 10)
    return b
  end

  ------------------------------------------------------------------------------
  -- General tab: how to use the addon, the slash commands and the Discord
  -- link. The link is a read-only edit box because addons can't open URLs or
  -- write to the clipboard; clicking it selects the text for Ctrl+C.
  ------------------------------------------------------------------------------
  local DISCORD = "https://discord.gg/Xja4mR87Bk"
  Begin(pages.general)

  Heading("Rage bar setup")
  Bullets({
    "Press " .. Key("Esc") .. " and choose " .. Key("Edit Mode") .. ".",
    "Click the " .. Key("WU Rage Bar") .. " to open its settings.",
    Key("Style") .. ", " .. Key("Border") .. ", " .. Key("Color") .. " and "
      .. Key("Bar Size") .. " change the look.",
    Key("Mark I") .. " and " .. Key("Mark II") .. " set the glow points.",
    Key("Only Show in Combat") .. " or " .. Key("Disable Rage Bar") .. " hide it.",
  })

  Heading("Moving the bar")
  Bullets({
    "Drag it, or click it and use the " .. Key("arrow keys") .. ".",
    "Hold " .. Key("Shift") .. " to move 10 pixels at a time.",
    "Each Edit Mode layout keeps its own position.",
  })

  Heading("Slash commands")
  local COMMAND_WIDTHS = { 100, 340 }
  Row(COMMAND_WIDTHS, 1, "/wu", "Open this page")
  Row(COMMAND_WIDTHS, 1, "/wu 30 60", "Set Mark I and Mark II (1 to 99)")
  Row(COMMAND_WIDTHS, 1, "/wu reset", "Reset all settings (keeps your CDM backup)")
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

  ------------------------------------------------------------------------------
  -- CDM tab: one section per Cooldown Manager layout in ns.CDM_LAYOUTS (see
  -- CDM.lua) listing where each buff goes and its alerts, with a Create
  -- button, then how Create works and Restore Backup. Both buttons reload the
  -- UI after a successful write so the Cooldown Manager loads the new data;
  -- on failure the reason is shown instead.
  ------------------------------------------------------------------------------
  Begin(pages.cdm)
  local status
  local function Run(fn, ...)
    local ok, reason = fn(...)
    if ok then ReloadUI() else status:SetText(reason) end
  end

  local LAYOUT_WIDTHS = { 50, 95, 130, 170 }
  local NONE = "|cff9a9381None|r"
  for _, def in ipairs(ns.CDM_LAYOUTS) do
    Heading(def.name .. " layout")
    Row(LAYOUT_WIDTHS, #LAYOUT_WIDTHS, "Tab", "Section", "Buff", "Alerts")
    for _, buff in ipairs(def.buffs) do
      local place = ns.CDM_PLACES[buff.category]
      local alerts = {}
      for j, a in ipairs(buff.alerts) do alerts[j] = j .. ". " .. a.text end
      Row(LAYOUT_WIDTHS, 0, place[1], place[2], C_Spell.GetSpellName(buff.spells.id) or "",
        #alerts > 0 and table.concat(alerts, "\n") or NONE)
    end
    PlaceButton("Create " .. def.name, 160, function() Run(ns.CreateCDMLayout, def) end)
  end

  Heading("How it works")
  Bullets({
    "Copies your active layout and puts these buffs first.",
    "The new layout becomes active. Creating it again rebuilds it.",
    "A layout named " .. Key("WU") .. " from older versions is renamed.",
    "Alerts are played by the Cooldown Manager, so they work in combat.",
    "Out of combat only. The UI reloads afterwards.",
  })

  Heading("Backup")
  Bullets({
    "The first Create saves your previous layouts.",
    Key("Restore Backup") .. " puts them back. Changes made since are lost.",
  })
  local restore = PlaceButton("Restore Backup", 140, function() Run(ns.RestoreCDMLayout) end)
  status = Text("", 8)
  status:SetTextColor(1, 0.35, 0.25)
  syncs[#syncs + 1] = function()
    restore:SetEnabled(db.cdmBackup ~= false)
    status:SetText("")
  end

  ShowTab("general")
  opt.Sync()

  category = Settings.RegisterCanvasLayoutCategory(opt, "WU - Warrior Utilities")
  Settings.RegisterAddOnCategory(category)
end

--------------------------------------------------------------------------------
-- Slash commands: /wu (or /wuutil)
--   /wu            open options
--   /wu 30 60      set marks
--   /wu reset
-- reset keeps the Cooldown Manager backup so Restore Backup still works.
-- SLASH_WU1, SLASH_WU2 and SlashCmdList.WU are globals the game requires.
--------------------------------------------------------------------------------
SLASH_WU1, SLASH_WU2 = "/wu", "/wuutil"
SlashCmdList.WU = function(msg)
  if not ns.built then return end -- not a warrior
  msg = strtrim(msg:lower())
  local a, b = msg:match("^(%d+)%s+(%d+)$")
  if msg == "" then
    Open()
  elseif msg == "reset" then
    local keep = { cdmBackup = db.cdmBackup }
    wipe(db)
    ns.LoadDB(keep)
    ns.ApplyPosition()
    ns.BuildCurves()
    ns.ApplySize()
    ns.Update()
    Sync()
    print("WU - Warrior Utilities reset")
  elseif a then
    ns.SetMarks(a, b)
    ns.Update()
    Sync()
    print(string.format("WU - Warrior Utilities marks set to %d / %d", db.mark1, db.mark2))
  else
    print("WU - Warrior Utilities: /wu, /wu 30 60, /wu reset")
  end
end
