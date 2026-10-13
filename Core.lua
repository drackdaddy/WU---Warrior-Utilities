--[[
  WU - Warrior Utilities (WoW Forever)
  Rage bar with two marks, and buttons that add WU layouts (such as WU-Fury)
  to Blizzard's Cooldown Manager. Loads only on warriors.

  Forever runs the Midnight (12.x) UI engine and its addon restrictions: in
  combat some values are "secret" (they can be shown, but not compared, indexed
  or used in math). The rage bar only displays rage and turns it into glow
  through curves; Cooldown Manager layouts are only written out of combat.

  Files (TOC load order): Libs\LibEditMode (embedded on the namespace as
  ns.LibEditMode, no LibStub), Core, RageBar, CDM, Options.
  Code and state shared between files live on the addon namespace (ns); code
  used by one file stays local to it.
]]
local addonName, ns = ...

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
}

ns.DEFAULTS = defaults -- read by the Edit Mode panel's Reset To Default

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
-- Event dispatch
-- One event frame for the addon. Each feature file adds its handlers with
-- ns.On when it loads; they are registered on PLAYER_LOGIN, for warriors only.
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
    if select(2, UnitClass("player")) ~= "WARRIOR" then return end
    ns.BuildBar()
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
