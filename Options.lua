local addonName, ns = ...
local db, GOLD, Button = ns.db, ns.GOLD, ns.Button

--------------------------------------------------------------------------------
-- Options page
-- General tab (how to use the addon, slash commands and the Discord link) and
-- CDM tab, shown in Esc > Options >
-- AddOns > WU - Warrior Utilities. Blizzard's Settings panel hosts the page as
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
  -- Control builders
  ------------------------------------------------------------------------------
  local function Label(parent, text, x, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(text)
    fs:SetTextColor(0.86, 0.84, 0.78)
    return fs
  end

  local function Hint(parent, text, x, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    return fs
  end

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
  -- General tab: how to use the addon, laid out like a short readme. Each
  -- section is a gold heading with a rule under it, then bullets or a command
  -- list. Everything stacks top to bottom, each piece anchored under the last.
  -- The Discord link is a read-only edit box because addons can't open URLs or
  -- write to the clipboard; clicking it selects the text for Ctrl+C.
  ------------------------------------------------------------------------------
  local general = pages.general
  local DISCORD = "https://discord.gg/Xja4mR87Bk"
  local prev -- last region placed; the next one goes under it

  -- Anchors region under the previous one (gap pixels down, x pixels in) and
  -- stretches it to the page's right edge so text wraps to the page width.
  local function Place(region, gap, x)
    if prev then
      region:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", x or 0, -gap)
    else
      region:SetPoint("TOPLEFT", 4, -4)
    end
    region:SetPoint("RIGHT", general, "RIGHT", -4, 0)
    prev = region
  end

  -- White text for names the player looks for on screen (keys, settings).
  local function Key(text) return "|cffffffff" .. text .. "|r" end

  local function Heading(text)
    local fs = general:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetJustifyH("LEFT")
    fs:SetTextColor(unpack(GOLD))
    fs:SetText(text)
    Place(fs, 18)
    local rule = general:CreateTexture(nil, "ARTWORK")
    rule:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.35)
    rule:SetHeight(1)
    Place(rule, 4)
  end

  local function Text(text, gap, x)
    local fs = general:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetJustifyH("LEFT")
    fs:SetSpacing(4)
    fs:SetTextColor(0.90, 0.88, 0.82)
    fs:SetText(text)
    Place(fs, gap or 8, x)
  end

  -- One text block with a gold bullet before each line.
  local function Bullets(lines)
    local bullet = "|cffe6cc80\226\128\162|r  "
    Text(bullet .. table.concat(lines, "\n" .. bullet))
  end

  -- A gold command in a fixed-width column with its description beside it.
  local function Command(cmd, desc)
    local c = general:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    c:SetWidth(100)
    c:SetJustifyH("LEFT")
    c:SetTextColor(unpack(GOLD))
    c:SetText(cmd)
    c:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -6)
    local d = general:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    d:SetJustifyH("LEFT")
    d:SetTextColor(0.90, 0.88, 0.82)
    d:SetText(desc)
    d:SetPoint("LEFT", c, "RIGHT", 8, 0)
    prev = c
  end

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
  Command("/wu", "Open this page")
  Command("/wu 30 60", "Set Mark I and Mark II (1 to 99)")
  Command("/wu reset", "Reset all settings (keeps your CDM backup)")
  Command("/wuutil", "Same as /wu")

  Heading("Bugs, features and questions")
  Text("Join the WU Discord:")
  -- InputBoxTemplate draws its border outside the box, hence the 6px inset.
  local link = CreateFrame("EditBox", nil, general, "InputBoxTemplate")
  link:SetSize(240, 20)
  link:SetAutoFocus(false)
  link:SetText(DISCORD)
  link:SetCursorPosition(0)
  link:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 6, -6)
  prev = link
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
  -- CDM tab: create or restore the WU Cooldown Manager layout (see CDM.lua).
  -- Both buttons reload the UI after a successful write so the Cooldown
  -- Manager loads the new data; on failure the reason is shown instead.
  ------------------------------------------------------------------------------
  local cdm = pages.cdm
  Label(cdm, "COOLDOWN MANAGER", 4, -8)
  Hint(cdm, "Adds a layout named WU with Battle Shout, Demoralizing Shout\n"
    .. "and Sunder Armor first in Tracked Buffs, copied from your active\n"
    .. "layout. Sunder Armor gets a text-to-speech alert when it falls off.\n"
    .. "WU becomes active; running it again rebuilds WU.\n"
    .. "Out of combat only. The UI reloads afterwards.", 4, -32)
  local status = Hint(cdm, "", 4, -176)
  status:SetWidth(380)
  status:SetTextColor(1, 0.35, 0.25)
  local function Run(fn)
    local ok, reason = fn()
    if ok then ReloadUI() else status:SetText(reason) end
  end
  Button(cdm, "Create WU Layout", 160, function() Run(ns.CreateCDMLayout) end):SetPoint("TOPLEFT", 4, -110)
  local restore = Button(cdm, "Restore Backup", 140, function() Run(ns.RestoreCDMLayout) end)
  restore:SetPoint("TOPLEFT", 172, -110)
  Hint(cdm, "Restore Backup puts back your layouts from before the first\n"
    .. "Create. Cooldown Manager changes made since then are lost.", 4, -144)
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
