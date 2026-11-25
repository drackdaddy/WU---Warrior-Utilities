local _, ns = ...
local db, LEM = ns.db, ns.LibEditMode

--------------------------------------------------------------------------------
-- Cooldown bar (warriors only)
-- A row of ability icons for the stance the player is in, each with
-- Blizzard's cooldown swipe and countdown. Each stance has its own list, set
-- up on the Stances tab under CDM on the options page: the bar on or off, a
-- "ready" glow on or off for the whole bar and for each ability, each
-- ability's own glow type, each ability on or off, and the order they show
-- in. Abilities the player hasn't learned
-- are left out. The icons, their glow and how they look on cooldown or short
-- of rage come from CooldownLook.lua, which never reads cooldown times. The
-- icons are plain frames with no mouse input: they only show cooldowns and
-- never cast anything.
-- Moved and set up in Edit Mode as "WU Cooldown Bar" (see ns.AddEditModeFrame
-- in Core.lua): icon size and "only show in combat". In Edit Mode it always
-- shows (the current stance, or Battle Stance when out of stance) so it can
-- be placed, faded when that bar is off.
-- Events: PLAYER_ENTERING_WORLD, PLAYER_REGEN_DISABLED, PLAYER_REGEN_ENABLED,
--   UPDATE_SHAPESHIFT_FORM, SPELLS_CHANGED, SPELL_UPDATE_COOLDOWN
-- SavedVariables: cdLayouts, cdSize, cdCombatOnly, battleCdOff, defensiveCdOff,
--   berserkerCdOff, battleAlertOff, defensiveAlertOff, berserkerAlertOff,
--   cdHide, cdOrder, cdNoGlow, cdGlowStyle
--------------------------------------------------------------------------------

-- Each stance: saved-settings key, stance spell ID, name and its abilities
-- (rank 1 spell IDs; every rank shares one cooldown), in default bar order.
ns.STANCES = {
  { key = "battle", form = 2457, name = "Battle Stance", spells = {
    100, -- Charge
    7384, -- Overpower
    6343, -- Thunder Clap
    694, -- Mocking Blow
    12294, -- Mortal Strike
    12292, -- Sweeping Strikes
    20230, -- Retaliation
    402927, -- Victory Rush (Forever ability)
    2687, -- Bloodrage
  } },
  { key = "defensive", form = 71, name = "Defensive Stance", spells = {
    355, -- Taunt
    2565, -- Shield Block
    6572, -- Revenge
    23922, -- Shield Slam
    72, -- Shield Bash
    676, -- Disarm
    12975, -- Last Stand
    871, -- Shield Wall
    402927, -- Victory Rush (Forever ability)
    2687, -- Bloodrage
  } },
  { key = "berserker", form = 2458, name = "Berserker Stance", spells = {
    20252, -- Intercept
    23881, -- Bloodthirst
    1680, -- Whirlwind
    1329555, -- Reckless Swings (Forever ability)
    6552, -- Pummel
    18499, -- Berserker Rage
    12328, -- Death Wish
    1719, -- Recklessness
    402927, -- Victory Rush (Forever ability)
    2687, -- Bloodrage
  } },
}

local GAP = 4 -- pixels between icons
local DEFAULT_POS = { point = "CENTER", x = 0, y = -215 }
local holder, PlacePosition
local icons, count = {}, 0 -- icon frames (reused) and how many are in use

-- Returns a new list of stance s's abilities in the player's order: the saved
-- order (db.cdOrder), then any ability it doesn't list (such as one added in
-- a later version) in default order. Used by the bar and the options page.
function ns.CooldownOrder(s)
  local order, seen = {}, {}
  for _, id in ipairs(db.cdOrder[s.key]) do
    if tContains(s.spells, id) and not seen[id] then
      order[#order + 1], seen[id] = id, true
    end
  end
  for _, id in ipairs(s.spells) do
    if not seen[id] then order[#order + 1] = id end
  end
  return order
end

-- The stance the player is in, or nil when out of stance.
local function CurrentStance()
  local form = GetShapeshiftForm()
  if form == 0 then return end
  local id = select(4, GetShapeshiftFormInfo(form))
  for _, s in ipairs(ns.STANCES) do
    if s.form == id then return s end
  end
end

-- Hands each icon's cooldown to its swipe and glow (see CooldownLook.lua).
local function UpdateCooldowns()
  for i = 1, count do ns.UpdateIconCooldown(icons[i]) end
end

-- Lays out the icons for the current stance (Battle Stance in Edit Mode when
-- out of stance), sizes the bar to fit them and shows or hides it. The bar
-- always shows in Edit Mode, even when "only show in combat" would hide it.
-- An icon glows when ready only if the stance's glow and its own are on.
local function Update()
  local edit = LEM:IsInEditMode()
  local s = CurrentStance() or edit and ns.STANCES[1]
  local off = not s or db[s.key .. "CdOff"]
  count = 0
  if s then
    local hide, noGlow = db.cdHide[s.key], db.cdNoGlow[s.key]
    local glow = not off and not db[s.key .. "AlertOff"]
    for _, id in ipairs(ns.CooldownOrder(s)) do
      if IsPlayerSpell(id) and not hide[id] then
        count = count + 1
        icons[count] = icons[count] or ns.NewCooldownIcon(holder)
        local f, tex = icons[count], C_Spell.GetSpellTexture(id)
        f.spell = id
        ns.SetIconGlow(f, glow and not noGlow[id], db.cdGlowStyle[s.key][id])
        f.tex:SetTexture(tex)
        f.cdGrey.tex:SetTexture(tex)
        f.unusable.tex:SetTexture(tex)
        f:SetSize(db.cdSize, db.cdSize)
        f:ClearAllPoints()
        f:SetPoint("LEFT", (count - 1) * (db.cdSize + GAP), 0)
        f:Show()
      end
    end
  end
  for i = count + 1, #icons do icons[i]:Hide() end

  local n = math.max(count, 1) -- keeps one icon's room in Edit Mode
  holder:SetSize(n * db.cdSize + (n - 1) * GAP, db.cdSize)
  holder:SetShown(edit or not off and count > 0
    and (not db.cdCombatOnly or UnitAffectingCombat("player")))
  holder:SetAlpha(off and 0.4 or 1)
  UpdateCooldowns()
end

ns.On("PLAYER_ENTERING_WORLD", function() if holder then Update() end end)
local function Changed() if holder then Update() end end
ns.On("PLAYER_REGEN_DISABLED", Changed)
ns.On("PLAYER_REGEN_ENABLED", Changed)
ns.On("UPDATE_SHAPESHIFT_FORM", Changed)
ns.On("SPELLS_CHANGED", Changed)
ns.On("SPELL_UPDATE_COOLDOWN", function() if holder and holder:IsShown() then UpdateCooldowns() end end)

-- Applies every cooldown bar setting; used when built, after a setting
-- changes on the options page and after /wu reset.
function ns.RefreshCooldowns()
  PlacePosition()
  Update()
end

function ns.BuildCooldownBar()
  holder = CreateFrame("Frame", nil, UIParent)
  holder:SetClampedToScreen(true)

  local T, Option = LEM.SettingType, ns.EditModeOption
  PlacePosition = ns.AddEditModeFrame(holder, "cdLayouts", DEFAULT_POS, "WU Cooldown Bar", {
    Option(T.Slider, "Icon Size", "cdSize", Update, nil, { minValue = 24, maxValue = 64, valueStep = 2 }),
    Option(T.Checkbox, "Only Show in Combat", "cdCombatOnly", Update),
  }, Update)
  ns.RefreshCooldowns()
end
