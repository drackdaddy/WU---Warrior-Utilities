--[[
  WU - Warrior Utilities (WoW Forever)
  Rage bar with two marks, an "OUT OF RANGE" warning, and buttons that add WU
  layouts (such as WU-Fury) to Blizzard's Cooldown Manager. Loads on warriors
  and druids; druids get the rage bar only (shown while in a form that uses
  rage), not the range warning or the CDM layouts.

  Forever runs the Midnight (12.x) UI engine and its addon restrictions: in
  combat some values are "secret" (they can be shown, but not compared, indexed
  or used in math). The rage bar only displays rage and turns it into glow
  through curves; Cooldown Manager layouts are only written out of combat.

  Files (TOC load order): Libs\LibEditMode (embedded on the namespace as
  ns.LibEditMode, no LibStub), Core, RageBar, RangeWarning, CDM, Options.
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
  barOff = false, marksOff = false, mark1 = 30, mark2 = 60, hideTicks = false,
  layouts = {}, -- rage bar position per Edit Mode layout name: { point, x, y }
  combatOnly = false, scale = 100,
  style = "rage", color = "red", border = "molten",
  rangeOff = false, rangeFont = "friz", rangeSize = 32,
  rangeFlash = "pulse", rangeSpeed = "normal",
  rangeLayouts = {}, -- range warning position per Edit Mode layout name
  cdmBackup = false, -- Cooldown Manager layout data from before the first Create
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
  rangeFont = {
    { "friz", "Friz Quadrata" }, { "arial", "Arial Narrow" },
    { "morpheus", "Morpheus" }, { "skurri", "Skurri" },
  },
  rangeFlash = { { "pulse", "Pulse" }, { "blink", "Blink" }, { "steady", "Steady (no flash)" } },
  rangeSpeed = { { "slow", "Slow" }, { "normal", "Normal" }, { "fast", "Fast" } },
}

local db = {}
ns.db = db

-- Copies known keys from saved (the loaded WUDB, or the values /wu reset keeps)
-- into db, fills defaults, fixes invalid choices and makes WUDB point at db.
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

--------------------------------------------------------------------------------
-- Edit Mode helpers
-- Shared by the rage bar and the range warning. LibEditMode registers a frame
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
    if ns.isWarrior then ns.BuildRangeWarning() end
    ns.BuildOptions()
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
