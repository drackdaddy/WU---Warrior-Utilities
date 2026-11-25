local _, ns = ...
local db, LEM = ns.db, ns.LibEditMode

--------------------------------------------------------------------------------
-- Debuff tracker (warriors only)
-- A row of icons for the debuffs a warrior keeps on an enemy target:
--   Sunder Armor        stack count and time left
--   Demoralizing Shout  time left; Demoralizing Roar (druid) and Curse of
--                       Weakness (warlock) count too, since a raid keeps up
--                       one of them
-- Each slot shows a dimmed icon while its debuff is missing and the debuff's
-- own icon over it while it is up, from any caster.
-- In combat the game won't tell addons what is on the target, so, as with the
-- Battle Shout timer, Blizzard's aura containers (see ns.AuraContainer in
-- Core.lua) watch the target and draw the icon (SetIcon), stacks
-- (SetApplicationCount, which the game only shows from 2 up) and countdown
-- (SetDurationText). Lua never reads the debuffs. Containers don't follow
-- target changes on their own, so a target change asks them to refresh. A
-- frame the game set up is never touched again: a new icon size builds new
-- containers. The icons have no mouse input and never cast anything.
-- Shown while the player has a target they can attack; always in Edit Mode
-- (faded when the tracker is off) so it can be placed. Moved and set up in
-- Edit Mode as "WU Debuffs" (icon size, only show in combat); switches on the
-- Debuffs tab under CDM on the options page.
-- Events: PLAYER_ENTERING_WORLD, PLAYER_TARGET_CHANGED, PLAYER_REGEN_DISABLED,
--   PLAYER_REGEN_ENABLED
-- SavedVariables: debuffOff, sunderOff, demoOff, debuffLayouts, debuffSize,
--   debuffCombatOnly
--------------------------------------------------------------------------------

-- Each slot: its on/off setting and the spell IDs it watches (every rank).
-- The first ID's icon is the dimmed "missing" icon.
local demo = CopyTable(ns.RANKS.demo)
for _, id in ipairs({
  99, 1735, 9490, 9747, 9898, -- Demoralizing Roar
  702, 1108, 6205, 7646, 11707, 11708, -- Curse of Weakness
}) do demo[#demo + 1] = id end
local SLOTS = {
  { key = "sunderOff", spells = ns.RANKS.sunder },
  { key = "demoOff", spells = demo },
}
local GAP = 4 -- pixels between icons
local FONT = "Fonts\\FRIZQT__.TTF"
local DEFAULT_POS = { point = "CENTER", x = 0, y = -260 }
local holder, PlacePosition, builtSize

-- Builds each slot's container at the current icon size, retiring the old
-- ones: the debuff's icon, the time left in its middle and its stack count
-- in the bottom right corner.
local function BuildContainers()
  local size = db.debuffSize
  for _, s in ipairs(SLOTS) do
    if s.container then
      s.container:SetEnabled(false)
      s.container:Hide()
    end
    s.container = ns.AuraContainer(s.frame, "target", "HARMFUL", s.spells, size, size, function(frame)
      local icon = frame:CreateTexture(nil, "ARTWORK")
      icon:SetAllPoints()
      frame:SetIcon(icon)
      local count = frame:CreateFontString(nil, "OVERLAY")
      count:SetFont(FONT, math.floor(size * 0.45), "OUTLINE")
      count:SetPoint("BOTTOMRIGHT", -1, 2)
      frame:SetApplicationCount(count, {})
      local time = frame:CreateFontString(nil, "OVERLAY")
      time:SetFont(FONT, math.floor(size * 0.4), "OUTLINE")
      time:SetPoint("CENTER")
      frame:SetDurationText(time, {})
    end)
  end
  builtSize = size
end

-- Lays out the slots that are on, sizes the tracker to fit them and shows or
-- hides it. It always shows in Edit Mode.
local function Update()
  if not holder then return end -- not built (druids)
  if db.debuffSize ~= builtSize then BuildContainers() end
  local size, n = db.debuffSize, 0
  for _, s in ipairs(SLOTS) do
    local on = not db[s.key]
    s.frame:SetShown(on)
    s.container:SetEnabled(on)
    if on then
      s.frame:SetSize(size, size)
      s.frame:ClearAllPoints()
      s.frame:SetPoint("LEFT", n * (size + GAP), 0)
      n = n + 1
    end
  end
  n = math.max(n, 1) -- keeps one icon's room in Edit Mode
  holder:SetSize(n * size + (n - 1) * GAP, size)
  holder:SetShown(LEM:IsInEditMode() or not db.debuffOff and UnitCanAttack("player", "target")
    and (not db.debuffCombatOnly or UnitAffectingCombat("player")))
  holder:SetAlpha(db.debuffOff and 0.4 or 1)
end

ns.On("PLAYER_ENTERING_WORLD", Update)
ns.On("PLAYER_REGEN_DISABLED", Update)
ns.On("PLAYER_REGEN_ENABLED", Update)
ns.On("PLAYER_TARGET_CHANGED", function()
  if not holder then return end
  Update()
  for _, s in ipairs(SLOTS) do s.container:UpdateAllAuras() end
end)

-- Applies every debuff tracker setting; used when built, after a setting
-- changes on the options page and after /wu reset.
function ns.RefreshDebuffs()
  PlacePosition()
  Update()
end

function ns.BuildDebuffs()
  holder = CreateFrame("Frame", nil, UIParent)
  holder:SetClampedToScreen(true)
  for _, s in ipairs(SLOTS) do
    s.frame = CreateFrame("Frame", nil, holder)
    local dim = s.frame:CreateTexture(nil, "ARTWORK")
    dim:SetAllPoints()
    dim:SetTexture(C_Spell.GetSpellTexture(s.spells[1]))
    dim:SetDesaturated(true)
    dim:SetAlpha(0.4)
  end

  local T, Option = LEM.SettingType, ns.EditModeOption
  PlacePosition = ns.AddEditModeFrame(holder, "debuffLayouts", DEFAULT_POS, "WU Debuffs", {
    Option(T.Slider, "Icon Size", "debuffSize", Update, nil, { minValue = 24, maxValue = 64, valueStep = 2 }),
    Option(T.Checkbox, "Only Show in Combat", "debuffCombatOnly", Update),
  }, Update)
  ns.RefreshDebuffs()
end
