local addonName, ns = ...
local db, GOLD, Button = ns.db, ns.GOLD, ns.Button

--------------------------------------------------------------------------------
-- Options page
-- General tab (how to use the addon) and CDM tab, shown in Esc > Options >
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
  -- General tab: how to use the addon, one instruction per paragraph in a
  -- larger font, each wrapped to the page width with a gap below it.
  ------------------------------------------------------------------------------
  local INSTRUCTIONS = {
    "Open Edit Mode (Esc > Edit Mode) and click the rage bar to change its size, "
      .. "style, color and marks, show it only in combat, or turn it off.",
    "Drag the rage bar to move it, or click it and use the arrow keys "
      .. "(hold Shift to move 10).",
    "Each Edit Mode layout keeps its own rage bar position.",
    "Open this page from Esc > Options > AddOns, or by typing /wu.",
    "Type /wu 30 60 to set the marks.",
  }
  local prev
  for _, text in ipairs(INSTRUCTIONS) do
    local fs = pages.general:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    fs:SetWidth(396)
    fs:SetJustifyH("LEFT")
    fs:SetTextColor(0.90, 0.88, 0.82)
    fs:SetText(text)
    if prev then fs:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -14) else fs:SetPoint("TOPLEFT", 4, -8) end
    prev = fs
  end

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
    print("WU - Warrior Utilities: /wu  |  /wu 30 60  |  reset")
  end
end
