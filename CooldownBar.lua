local _, ns = ...
local db, LEM = ns.db, ns.LibEditMode

--------------------------------------------------------------------------------
-- Cooldown bar (warriors only)
-- A row of ability icons for the stance the player is in, each with
-- Blizzard's cooldown swipe and countdown. Each stance has its own list, set
-- up on its tab of the options page: the bar on or off, a "ready" glow on or
-- off, and each ability on or off. Abilities the player hasn't learned are
-- left out.
-- In combat cooldown times can be secret, so Lua never reads them. The game
-- hands back a duration object for each ability's cooldown: the Cooldown
-- widget draws the swipe from it, and the ready glow's alpha is a curve the
-- object evaluates (1 while the time left is at most GRACE seconds, else 0),
-- the same way the rage bar's glow works. GRACE covers the global cooldown so
-- the glow doesn't blink off after every ability. The icons are plain frames
-- with no mouse input: they only show cooldowns and never cast anything.
-- Moved and sized in Edit Mode as "WU Cooldown Bar" (see ns.AddEditModeFrame
-- in Core.lua). In Edit Mode it always shows (the current stance, or Battle
-- Stance when out of stance) so it can be placed, faded when that bar is off.
-- Events: PLAYER_ENTERING_WORLD, UPDATE_SHAPESHIFT_FORM, SPELLS_CHANGED,
--   SPELL_UPDATE_COOLDOWN
-- SavedVariables: cdLayouts, cdSize, battleCdOff, defensiveCdOff,
--   berserkerCdOff, battleAlertOff, defensiveAlertOff, berserkerAlertOff,
--   cdHide
--------------------------------------------------------------------------------

-- Each stance: saved-settings key, stance spell ID, name and its abilities
-- (rank 1 spell IDs; every rank shares one cooldown), in bar order.
ns.STANCES = {
  { key = "battle", form = 2457, name = "Battle Stance", spells = {
    100, -- Charge
    7384, -- Overpower
    6343, -- Thunder Clap
    694, -- Mocking Blow
    12294, -- Mortal Strike
    12292, -- Sweeping Strikes
    20230, -- Retaliation
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
    2687, -- Bloodrage
  } },
  { key = "berserker", form = 2458, name = "Berserker Stance", spells = {
    20252, -- Intercept
    23881, -- Bloodthirst
    1680, -- Whirlwind
    6552, -- Pummel
    18499, -- Berserker Rage
    12328, -- Death Wish
    1719, -- Recklessness
    2687, -- Bloodrage
  } },
}

local GRACE = 1.6 -- seconds left that still count as ready (the global cooldown)
local INTERVAL = 0.1 -- seconds between glow updates
local GAP = 4 -- pixels between icons
local GOLD = { 1, 0.82, 0.2 }
local WHITE = "Interface\\Buttons\\WHITE8X8"
local DEFAULT_POS = { point = "CENTER", x = 0, y = -215 }
local holder, watcher, readyCurve, PlacePosition
local icons, count = {}, 0 -- icon frames (reused) and how many are in use
local alertOn -- the ready glow is on for the bar being shown

-- The stance the player is in, or nil when out of stance.
local function CurrentStance()
  local form = GetShapeshiftForm()
  if form == 0 then return end
  local id = select(4, GetShapeshiftFormInfo(form))
  for _, s in ipairs(ns.STANCES) do
    if s.form == id then return s end
  end
end

-- Returns icon frame i, creating it the first time: the ability's icon, its
-- cooldown swipe and a pulsing gold ready glow whose alpha Glow sets.
local function Icon(i)
  if icons[i] then return icons[i] end
  local f = CreateFrame("Frame", nil, holder)
  f.tex = f:CreateTexture(nil, "ARTWORK")
  f.tex:SetAllPoints()
  f.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- trims the icon art's own border
  f.cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
  f.cd:SetAllPoints()
  f.cd:SetHideCountdownNumbers(false)

  f.ready = CreateFrame("Frame", nil, f)
  f.ready:SetAllPoints()
  f.ready:SetFrameLevel(f.cd:GetFrameLevel() + 2)
  f.ready:SetAlpha(0)
  local pulse = CreateFrame("Frame", nil, f.ready, "BackdropTemplate")
  pulse:SetPoint("TOPLEFT", -2, 2)
  pulse:SetPoint("BOTTOMRIGHT", 2, -2)
  pulse:SetBackdrop({ edgeFile = WHITE, edgeSize = 2 })
  pulse:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 1)
  local shine = pulse:CreateTexture(nil, "ARTWORK")
  shine:SetPoint("TOPLEFT", 2, -2)
  shine:SetPoint("BOTTOMRIGHT", -2, 2)
  shine:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.25)
  shine:SetBlendMode("ADD")
  local ag = pulse:CreateAnimationGroup()
  ag:SetLooping("BOUNCE")
  local fade = ag:CreateAnimation("Alpha")
  fade:SetFromAlpha(1)
  fade:SetToAlpha(0.3)
  fade:SetDuration(0.5)
  ag:Play()

  icons[i] = f
  return f
end

-- Sets each icon's ready glow from its cooldown. The curve's result may be
-- secret, so it is only handed to SetAlpha, never tested.
local function Glow()
  for i = 1, count do
    local f = icons[i]
    if f.dur then
      f.ready:SetAlpha(f.dur:EvaluateRemainingDuration(readyCurve))
    else
      f.ready:SetAlpha(0)
    end
  end
end

-- Fetches each icon's cooldown and hands it to the swipe and the glow.
local function UpdateCooldowns()
  for i = 1, count do
    local f = icons[i]
    f.dur = C_Spell.GetSpellCooldownDuration(f.spell)
    if f.dur then
      f.cd:SetCooldownFromDurationObject(f.dur)
    else
      f.cd:Clear()
    end
    if not alertOn then f.ready:SetAlpha(0) end
  end
  if alertOn then Glow() end
end

-- Lays out the icons for the current stance (Battle Stance in Edit Mode when
-- out of stance), sizes the bar to fit them and shows or hides it.
local function Update()
  local edit = LEM:IsInEditMode()
  local s = CurrentStance() or edit and ns.STANCES[1]
  count = 0
  if s then
    local hide = db.cdHide[s.key]
    for _, id in ipairs(s.spells) do
      if IsPlayerSpell(id) and not hide[id] then
        count = count + 1
        local f = Icon(count)
        f.spell = id
        f.tex:SetTexture(C_Spell.GetSpellTexture(id))
        f:SetSize(db.cdSize, db.cdSize)
        f:ClearAllPoints()
        f:SetPoint("LEFT", (count - 1) * (db.cdSize + GAP), 0)
        f:Show()
      end
    end
  end
  for i = count + 1, #icons do icons[i]:Hide() end

  local off = not s or db[s.key .. "CdOff"]
  local n = math.max(count, 1) -- keeps one icon's room in Edit Mode
  holder:SetSize(n * db.cdSize + (n - 1) * GAP, db.cdSize)
  holder:SetShown(edit or not off and count > 0)
  holder:SetAlpha(off and 0.4 or 1)
  alertOn = not off and not db[s.key .. "AlertOff"]
  watcher:SetShown(holder:IsShown() and alertOn)
  UpdateCooldowns()
end

ns.On("PLAYER_ENTERING_WORLD", Update)
ns.On("UPDATE_SHAPESHIFT_FORM", Update)
ns.On("SPELLS_CHANGED", Update)
ns.On("SPELL_UPDATE_COOLDOWN", function() if holder:IsShown() then UpdateCooldowns() end end)

-- Applies every cooldown bar setting; used when built, after a setting
-- changes on the options page and after /wu reset.
function ns.RefreshCooldowns()
  PlacePosition()
  Update()
end

function ns.BuildCooldownBar()
  holder = CreateFrame("Frame", nil, UIParent)
  holder:SetClampedToScreen(true)

  readyCurve = C_CurveUtil.CreateCurve()
  readyCurve:AddPoint(0, 1)
  readyCurve:AddPoint(GRACE, 1)
  readyCurve:AddPoint(GRACE + 0.01, 0)
  readyCurve:AddPoint(3600, 0)

  -- The glow needs redrawing as time passes; no event fires for that.
  local elapsed = 0
  watcher = CreateFrame("Frame", nil, UIParent)
  watcher:Hide()
  watcher:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < INTERVAL then return end
    elapsed = 0
    Glow()
  end)

  PlacePosition = ns.AddEditModeFrame(holder, "cdLayouts", DEFAULT_POS, "WU Cooldown Bar", {
    ns.EditModeOption(LEM.SettingType.Slider, "Icon Size", "cdSize", Update, nil,
      { minValue = 24, maxValue = 64, valueStep = 2 }),
  }, Update)
  ns.RefreshCooldowns()
end
