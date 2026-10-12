--[[
  WU - Warrior Utilities (WoW Forever)
  Rage bar with two marks, and a button that adds a WU layout to Blizzard's
  Cooldown Manager (Battle Shout, Demoralizing Shout and Sunder Armor in
  Tracked Buffs). Loads only on warriors.

  Forever runs the Midnight (12.x) UI engine and its addon restrictions: in
  combat some values are "secret" (they can be shown, but not compared, indexed
  or used in math). The rage bar only displays rage and turns it into glow
  through curves; the Cooldown Manager layout is only written out of combat.

  Files (TOC load order): Libs\LibEditMode (embedded on the namespace as
  ns.LibEditMode, no LibStub), Core, RageBar, CDM, Options.
  Code and state shared between files live on the addon namespace (ns).
]]
local addonName, ns = ...

--------------------------------------------------------------------------------
-- Shared constants
--------------------------------------------------------------------------------
ns.ROOT = "Interface\\AddOns\\" .. addonName .. "\\"
ns.FONT = "Fonts\\FRIZQT__.TTF"
ns.WHITE = "Interface\\Buttons\\WHITE8X8"
ns.BASE_W, ns.BASE_H = 268, 38
ns.GOLD = { 0.90, 0.80, 0.50 }
ns.BORDER = { 0.32, 0.28, 0.22, 1 }

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
  style = "rage", color = "red",
  cdmBackup = false, -- Cooldown Manager layout data from before the first Create
}

-- Choice lists: saved value and display name. Used by validation and dropdowns.
ns.LISTS = {
  style = { { "modern", "Modern" }, { "classic", "Classic" }, { "rage", "Rage" } },
  color = { { "red", "Red" }, { "blue", "Blue" }, { "yellow", "Yellow" }, { "green", "Green" } },
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
-- Helpers
--------------------------------------------------------------------------------
-- Nearest whole number to n (number or text), limited to lo..hi.
function ns.Clamp(n, lo, hi)
  return math.min(hi, math.max(lo, math.floor((tonumber(n) or lo) + 0.5)))
end

function ns.InCombat()
  return UnitAffectingCombat("player")
end

-- Flat dark panel with a 1px border.
function ns.Paint(frame, alpha)
  frame:SetBackdrop({
    bgFile = ns.WHITE, edgeFile = ns.WHITE, tile = true, tileSize = 8, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  frame:SetBackdropColor(0.07, 0.07, 0.08, alpha)
  frame:SetBackdropBorderColor(0.28, 0.26, 0.22, 1)
end

-- Standard panel button; the caller anchors it.
function ns.Button(parent, text, width, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width, 24)
  b:SetText(text)
  b:SetScript("OnClick", onClick)
  return b
end

--------------------------------------------------------------------------------
-- Event dispatch
-- One event frame for the addon. Each feature file adds its handlers with
-- ns.On when it loads; they are registered on PLAYER_LOGIN, for warriors only.
-- Events: ADDON_LOADED (settings), PLAYER_LOGIN (build frames, register events)
--------------------------------------------------------------------------------
local handlers, unitFilters = {}, {}

-- Adds fn as a handler for event. For UNIT_ events, the optional units limit
-- it to those units (default "player"); all handlers of one event share them.
function ns.On(event, fn, ...)
  handlers[event] = handlers[event] or {}
  table.insert(handlers[event], fn)
  if ... then unitFilters[event] = { ... } end
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
        self:RegisterUnitEvent(name, unpack(unitFilters[name] or { "player" }))
      else
        self:RegisterEvent(name)
      end
    end
    ns.built = true -- PLAYER_ENTERING_WORLD follows and does the first refresh
  else
    for _, fn in ipairs(handlers[event]) do fn(...) end
  end
end)
