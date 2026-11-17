local _, ns = ...
local db = ns.db

--------------------------------------------------------------------------------
-- Battle Shout timer on the player frame (warriors only)
-- Behind the player's name on Blizzard's player frame:
--   bar    empties as the player's Battle Shout runs down
--   clock  countdown numbers at the right end of the name
--   alarm  red flash while Battle Shout is missing in combat
-- and, above the player frame, "Battle Shout Missing" (warn), also while
-- Battle Shout is missing in combat. The flash and warning turn off separately.
-- The buff is found by each rank's spell ID, so no aura names are compared.
-- The bar and countdown run from the aura's duration object
-- (StatusBar:SetTimerDuration, Cooldown:SetCooldownFromDurationObject): the
-- game animates the bar and formats the numbers, and no time left is worked
-- out in Lua, so they keep working when aura timings are secret in combat.
-- All of them are parented to the player frame so they hide and scale with it;
-- they are the addon's own frames, and the player frame itself is never
-- changed. Set up on the Battle Shout tab of the options page.
-- Events: UNIT_AURA (player), PLAYER_ENTERING_WORLD, PLAYER_REGEN_DISABLED,
--   PLAYER_REGEN_ENABLED
-- SavedVariables: shoutOff, shoutTextOff, shoutFlashOff, shoutWarnOff, shoutColor
--------------------------------------------------------------------------------
local RANKS = { 6673, 5242, 6192, 11549, 11550, 11551, 25289, 27578 }
local WHITE = "Interface\\Buttons\\WHITE8X8"
local bar, clock, alarm, warn
local inCombat = false

-- Returns the auraInstanceID of the player's Battle Shout (any rank), or nil.
local function FindShout()
  for _, id in ipairs(RANKS) do
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(id)
    if aura then return aura.auraInstanceID end
  end
end

-- Shows the bar and countdown with the buff's current timer while it is up,
-- or the flash and warning while it is missing in combat. Everything hides
-- when the timer is turned off.
local function Update()
  local instance = not db.shoutOff and FindShout()
  if instance then
    local duration = C_UnitAuras.GetAuraDuration("player", instance)
    bar:SetTimerDuration(duration, Enum.StatusBarInterpolation.Immediate,
      Enum.StatusBarTimerDirection.RemainingTime)
    clock:SetCooldownFromDurationObject(duration)
  end
  bar:SetShown(instance and true or false)
  clock:SetShown(instance and not db.shoutTextOff or false)
  local missing = not db.shoutOff and not instance and inCombat
  alarm:SetShown(missing and not db.shoutFlashOff)
  warn:SetShown(missing and not db.shoutWarnOff)
end

ns.On("UNIT_AURA", function() if bar then Update() end end)
ns.On("PLAYER_ENTERING_WORLD", function()
  inCombat = UnitAffectingCombat("player")
  if bar then Update() end
end)
ns.On("PLAYER_REGEN_DISABLED", function()
  inCombat = true
  if bar then Update() end
end)
ns.On("PLAYER_REGEN_ENABLED", function()
  inCombat = false
  if bar then Update() end
end)

-- Applies the bar color, then redraws. Used when built, after a setting
-- changes on the options page and after /wu reset.
function ns.RefreshShout()
  local c = db.shoutColor
  bar:SetStatusBarColor(c.r, c.g, c.b, c.a)
  Update()
end

-- Frame over the player name's box, a little wider and taller than it.
local function OverName(kind, name)
  local f = CreateFrame(kind, nil, PlayerFrame)
  f:SetPoint("TOPLEFT", name, "TOPLEFT", -3, 2)
  f:SetPoint("BOTTOMRIGHT", name, "BOTTOMRIGHT", 3, -2)
  return f
end

-- Builds the bar and flash one level under the player frame's own art, so the
-- name stays on top, and the countdown above it so the numbers can be read.
function ns.BuildShoutTimer()
  local name = PlayerFrame.name
  local level = PlayerFrame:GetFrameLevel()

  bar = OverName("StatusBar", name)
  bar:SetFrameLevel(level)
  bar:SetStatusBarTexture(WHITE)
  local bg = bar:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0, 0, 0.45)

  -- Red fill that pulses while shown.
  alarm = OverName("Frame", name)
  alarm:SetFrameLevel(level)
  local red = alarm:CreateTexture(nil, "ARTWORK")
  red:SetAllPoints()
  red:SetColorTexture(0.9, 0.08, 0.05, 0.85)
  local pulse = alarm:CreateAnimationGroup()
  pulse:SetLooping("BOUNCE")
  local fade = pulse:CreateAnimation("Alpha")
  fade:SetFromAlpha(1)
  fade:SetToAlpha(0.1)
  fade:SetDuration(0.45)
  pulse:Play()

  -- A Cooldown frame used only for its countdown numbers: no swipe, edge or
  -- finish flash.
  clock = CreateFrame("Cooldown", nil, PlayerFrame, "CooldownFrameTemplate")
  clock:SetFrameLevel(name:GetParent():GetFrameLevel() + 5)
  clock:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -1, 0)
  clock:SetPoint("BOTTOMLEFT", bar, "BOTTOMRIGHT", -30, 0)
  clock:SetDrawSwipe(false)
  clock:SetDrawEdge(false)
  clock:SetDrawBling(false)
  clock:SetHideCountdownNumbers(false)
  clock:GetCountdownFontString():SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")

  -- Warning text just above the top edge of the player frame, over the name.
  warn = CreateFrame("Frame", nil, PlayerFrame)
  warn:SetFrameLevel(clock:GetFrameLevel())
  warn:SetSize(200, 20)
  warn:SetPoint("BOTTOM", bar, "TOP", 0, 14)
  local text = warn:CreateFontString(nil, "OVERLAY")
  text:SetAllPoints()
  text:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
  text:SetTextColor(1, 0.15, 0.1)
  text:SetText("Battle Shout Missing")

  ns.RefreshShout()
end
