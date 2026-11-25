--[[
  WU - Warrior Utilities (WoW Forever)
  Rage bar with up to three marks, a range display (distance to the target,
  adapted from Good Range), a Battle Shout timer on the player frame, a
  tracker for Sunder Armor and Demoralizing Shout on the target and a
  cooldown bar for each stance. Loads on warriors and
  druids; druids get the rage bar only (shown while in a form that uses rage),
  not the warrior features.

  Forever runs the Midnight (12.x) UI engine and its addon restrictions: in
  combat some values are "secret" (they can be shown, but not compared, indexed
  or used in math). The rage bar only displays rage and turns it into glow
  through curves; the Battle Shout timer and the debuff tracker are drawn by
  Blizzard's aura containers, so the addon never reads the auras; the cooldown bar hands cooldowns to
  Blizzard's Cooldown widget and curves, so it never reads their times.

  Files (TOC load order): Libs\LibEditMode (embedded on the namespace as
  ns.LibEditMode, no LibStub), Core, RageBar, RangeEstimator, RangeTape, Range,
  ShoutTimer, Debuffs, CooldownBar, Minimap, Options.
  Code and state shared between files live on the addon namespace (ns); code
  used by one file stays local to it.
]]
local addonName, ns = ...
local LEM = ns.LibEditMode

--------------------------------------------------------------------------------
-- Saved settings
-- SavedVariables (per character): WUDB.
-- Defaults are applied once on ADDON_LOADED. Keys from older versions are
-- dropped and invalid choices are reset. ns.db is the table the game saves
-- (WUDB points to it), so every file can keep its own reference to ns.db.
--------------------------------------------------------------------------------
local defaults = {
  minimapOff = false, minimapAngle = 225, -- minimap icon; angle in degrees, counterclockwise from the right
  barOff = false, marksOff = false, mark1 = 30, mark2 = 60, mark3 = 0, hideTicks = false, -- mark 0 = off
  layouts = {}, -- rage bar position per Edit Mode layout name: { point, x, y }
  combatOnly = false, scale = 100,
  style = "rage", color = "red", border = "molten",
  rangeOff = false, rangeOocOff = false, -- range display on; shown out of combat
  rangeLook = "tape", rangeTextFont = "changa", rangeSize = 32, -- rangeSize: number font size
  rangeWidth = 130, rangeHeight = 31, rangeScale = 20, -- tape size; rangeScale: pixels per yard
  rangeUnitOff = false, rangeOpacity = 100, rangeFriendlyOff = true,
  rangeLayouts = {}, -- range display position per Edit Mode layout name
  rangePlace = "screen", rangePlateY = 4, rangePlateScale = 100, -- nameplate display
  rangeFocusOff = true, rangeMouseOff = true, rangeLabelScale = 100, -- focus and mouseover labels
  rangeFocusLayouts = {}, -- focus label position per Edit Mode layout name
  rangeAutoOff = false, rangeZone1 = 5, rangeZone2 = 8, rangeZone3 = 25, -- zones set by hand: where each ends
  rangeColorPrimary = { r = 0.373, g = 0.878, b = 0.416, a = 1 },
  rangeColorSecondary = { r = 0.302, g = 0.659, b = 1, a = 1 },
  rangeColorDead = { r = 0.95, g = 0.33, b = 0.31, a = 1 },
  rangeColorFar = { r = 0.545, g = 0.565, b = 0.6, a = 1 },
  shoutOff = false, shoutTextOff = false, shoutFlashOff = false, shoutWarnOff = false,
  shoutWarnSize = 14, -- "Battle Shout Missing" font size
  shoutColor = { r = 0.85, g = 0.32, b = 0.08, a = 0.75 }, -- Battle Shout bar
  debuffOff = false, sunderOff = false, demoOff = false,
  debuffLayouts = {}, -- debuff tracker position per Edit Mode layout name
  debuffSize = 36, debuffCombatOnly = false, -- debuff icon size in pixels
  cdLayouts = {}, -- cooldown bar position per Edit Mode layout name
  cdSize = 36, -- cooldown icon size in pixels
  cdCombatOnly = false,
  battleCdOff = false, defensiveCdOff = false, berserkerCdOff = false,
  battleAlertOff = false, defensiveAlertOff = false, berserkerAlertOff = false,
  cdHide = { battle = {}, defensive = {}, berserker = {} }, -- [spell ID] = true: left off that stance's bar
  cdOrder = { battle = {}, defensive = {}, berserker = {} }, -- spell IDs in bar order; empty = default order
  cdNoGlow = { battle = {}, defensive = {}, berserker = {} }, -- [spell ID] = true: that ability never glows
}

-- Choice lists: saved value and display name. Used by validation and dropdowns.
ns.LISTS = {
  style = { { "modern", "Modern" }, { "classic", "Classic" }, { "rage", "Rage" } },
  color = { { "red", "Red" }, { "blue", "Blue" }, { "yellow", "Yellow" }, { "green", "Green" } },
  border = {
    { "iron", "Iron" }, { "riveted", "Riveted Plate" }, { "spiked", "Spiked" },
    { "bronze", "Bloodied Bronze" }, { "chain", "Chain Link" }, { "molten", "Molten Cracks" },
    { "lava", "Lava Rock" }, { "blade", "Blade Ends" }, { "none", "None" },
  },
  rangeLook = {
    { "tape", "Tape" }, { "label", "Label + Number" }, { "badge", "Label Only" }, { "number", "Number Only" },
  },
  rangePlace = { { "screen", "Screen" }, { "plate", "Nameplate" }, { "both", "Screen and Nameplate" } },
  rangeTextFont = {
    { "changa", "Changa Bold" }, { "skurri", "Skurri" }, { "arial", "Arial Narrow" }, { "2002", "2002 Bold" },
    { "friz", "Friz Quadrata" }, { "nimrod", "Nimrod" }, { "morpheus", "Morpheus" },
  },
}

local db = {}
ns.db = db

-- Copies known keys from saved (the loaded WUDB, or nil after /wu reset) into
-- db, fills defaults, fixes invalid choices and makes WUDB point at db.
-- Table defaults are copied so a reset never hands out the defaults table.
function ns.LoadDB(saved)
  for k, v in pairs(saved or {}) do
    if defaults[k] ~= nil then db[k] = v end
  end
  for k, v in pairs(defaults) do
    if db[k] == nil then db[k] = type(v) == "table" and CopyTable(v) or v end
  end
  for key, list in pairs(ns.LISTS) do
    local valid
    for _, o in ipairs(list) do valid = valid or o[1] == db[key] end
    if not valid then db[key] = defaults[key] end
  end
  WUDB = db
end

-- Returns the default value for key (a copy for tables).
function ns.Default(key)
  local v = defaults[key]
  return type(v) == "table" and CopyTable(v) or v
end

--------------------------------------------------------------------------------
-- Aura containers
-- Shared by the Battle Shout timer and the debuff tracker. Blizzard's aura
-- containers (Blizzard_AuraContainer) watch a unit's auras themselves, in and
-- out of combat, and draw what the addon hands them, so Lua never reads the
-- auras. Spell ID filters only work on helpful auras of friendly units and
-- harmful auras of enemies.
--------------------------------------------------------------------------------

-- New aura container at the top left of parent, watching unit's auras that
-- match filter ("HELPFUL" or "HARMFUL") and whose spell ID is in ids (a
-- list), from any caster, with room for one w x h frame. init(frame), if
-- given, sets up that frame once when the game creates it. Returns the
-- container.
function ns.AuraContainer(parent, unit, filter, ids, w, h, init)
  local set = {}
  for _, id in ipairs(ids) do set[id] = true end
  local c = CreateFrame("AuraContainer", nil, parent, "CustomAuraContainerTemplate")
  c:SetPoint("TOPLEFT")
  c:AddAuraGroup("aura", filter, {
    candidateFilters = { includeSpellIDs = set },
    maxFrameCount = 1,
    layout = { elementWidth = w, elementHeight = h },
    initializeFrame = function(frame)
      frame:SetSize(w, h)
      frame:SetMouseClickEnabled(false)
      frame:EnableMouseMotion(false)
      if init then init(frame) end
    end,
  })
  c:SetUnit(unit)
  return c
end

--------------------------------------------------------------------------------
-- Edit Mode helpers
-- Shared by the rage bar, the range display, the debuff tracker and the
-- cooldown bar. LibEditMode registers a frame
-- with Blizzard's Edit Mode: it draws the selection highlight, handles
-- dragging, arrow-key nudges and "Reset To Default Position", shows the
-- settings panel when the frame is selected, and reports the active Edit Mode
-- layout. Positions are saved per layout name in db[key], so each layout
-- keeps its own spot; layouts created as copies, renamed or deleted are kept
-- in step. Panel settings are per character (the same in every layout).
-- LibEditMode does not snap custom frames to the grid or to other frames.
--------------------------------------------------------------------------------

-- One panel setting bound to db[key]: apply runs after a change, disabled
-- greys it out, extra holds the kind's own fields. The layout name LibEditMode
-- passes is ignored because these settings are per character.
function ns.EditModeOption(kind, name, key, apply, disabled, extra)
  local s = {
    kind = kind, name = name, default = defaults[key], disabled = disabled,
    get = function() return db[key] end,
    set = function(_, value)
      db[key] = value
      apply()
    end,
  }
  for k, v in pairs(extra or {}) do s[k] = v end
  return s
end

-- Dropdown fields for a ns.LISTS choice list.
function ns.EditModeChoices(key)
  local values = {}
  for _, o in ipairs(ns.LISTS[key]) do values[#values + 1] = { text = o[2], value = o[1] } end
  return { values = values }
end

-- Registers frame in Edit Mode under name with the given panel settings, its
-- position saved per layout in db[key] (default: { point, x, y }). onToggle
-- runs on entering and leaving Edit Mode. Returns a function that moves the
-- frame to its saved spot in the active layout (used again after /wu reset).
function ns.AddEditModeFrame(frame, key, default, name, settings, onToggle)
  local layoutName -- nil until the game reports the active layout
  local function Place()
    local p = layoutName and db[key][layoutName] or default
    frame:ClearAllPoints()
    frame:SetPoint(p.point, UIParent, p.point, p.x, p.y)
  end
  LEM:AddFrame(frame, function(_, layout, point, x, y)
    db[key][layout] = { point = point, x = x, y = y }
  end, default, name)
  LEM:AddFrameSettings(frame, settings)
  LEM:RegisterCallback("layout", function(layout)
    layoutName = layout
    Place()
  end)
  LEM:RegisterCallback("create", function(layout, _, source)
    if source and db[key][source] then db[key][layout] = CopyTable(db[key][source]) end
  end)
  LEM:RegisterCallback("rename", function(old, new)
    db[key][new], db[key][old] = db[key][old], nil
  end)
  LEM:RegisterCallback("delete", function(layout) db[key][layout] = nil end)
  LEM:RegisterCallback("enter", onToggle)
  LEM:RegisterCallback("exit", onToggle)
  return Place
end

--------------------------------------------------------------------------------
-- Event dispatch
-- One event frame for the addon. Each feature file adds its handlers with
-- ns.On when it loads; they are registered on PLAYER_LOGIN, for warriors and
-- druids only. ns.isWarrior tells the other files which class loaded.
-- UNIT_ events are registered for the player only.
-- Events: ADDON_LOADED (settings), PLAYER_LOGIN (build frames, register events)
--------------------------------------------------------------------------------
local handlers = {}

function ns.On(event, fn)
  handlers[event] = handlers[event] or {}
  table.insert(handlers[event], fn)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(self, event, ...)
  if event == "ADDON_LOADED" then
    if ... ~= addonName then return end
    self:UnregisterEvent(event)
    ns.LoadDB(WUDB)
  elseif event == "PLAYER_LOGIN" then
    self:UnregisterEvent(event)
    local class = select(2, UnitClass("player"))
    if class ~= "WARRIOR" and class ~= "DRUID" then return end
    ns.isWarrior = class == "WARRIOR"
    ns.BuildBar()
    if ns.isWarrior then
      ns.BuildRange()
      ns.BuildShoutTimer()
      ns.BuildDebuffs()
      ns.BuildCooldownBar()
    end
    ns.BuildOptions()
    ns.BuildMinimap()
    for name in pairs(handlers) do
      if name:find("^UNIT_") then
        self:RegisterUnitEvent(name, "player")
      else
        self:RegisterEvent(name)
      end
    end
    ns.built = true
  else
    for _, fn in ipairs(handlers[event]) do fn(...) end
  end
end)
