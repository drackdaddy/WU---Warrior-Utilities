local _, ns = ...
local db, LEM = ns.db, ns.LibEditMode

--------------------------------------------------------------------------------
-- Range warning (warriors only)
-- Flashes "OUT OF RANGE" while the player has a living target they can attack
-- that is out of melee range. Melee range is Heroic Strike's range, asked of
-- C_Spell.IsSpellInRange: false means out of range; nil (no answer, such as
-- an unknown spell or an invalid target) shows nothing. There is no event for
-- range changes, so a hidden watcher frame checks 10 times a second, and only
-- while the warning is on and the player has a target.
-- Moved and set up in Edit Mode as "WU Range Warning" (see ns.AddEditModeFrame
-- in Core.lua): on/off, font, font size, flash style and flash speed. In Edit
-- Mode the warning always shows so it can be placed (faded when turned off).
-- Events: PLAYER_TARGET_CHANGED
-- SavedVariables: rangeOff, rangeFont, rangeSize, rangeFlash, rangeSpeed,
--   rangeLayouts
--------------------------------------------------------------------------------
local MELEE_SPELL = 78 -- Heroic Strike, known from level 1
local INTERVAL = 0.1 -- seconds between range checks
local DEFAULT_POS = { point = "CENTER", x = 0, y = 120 }
local FONTS = {
  friz = "Fonts\\FRIZQT__.TTF", arial = "Fonts\\ARIALN.TTF",
  morpheus = "Fonts\\MORPHEUS.TTF", skurri = "Fonts\\SKURRI.TTF",
}
local PERIODS = { slow = 1.2, normal = 0.8, fast = 0.4 } -- seconds per flash
local holder, flash, text, watcher, PlacePosition
local pulse, blink -- animation groups on flash; Steady plays neither

-- True when the target can be attacked, is alive and is out of melee range.
local function OutOfRange()
  if not UnitCanAttack("player", "target") or UnitIsDeadOrGhost("target") then return false end
  return C_Spell.IsSpellInRange(MELEE_SPELL, "target") == false
end

-- Shows or hides the warning and starts or stops the chosen flash.
local function UpdateShown()
  local show = LEM:IsInEditMode() or not db.rangeOff and OutOfRange()
  holder:SetShown(show)
  holder:SetAlpha(db.rangeOff and 0.4 or 1)
  local anim = db.rangeFlash == "pulse" and pulse or db.rangeFlash == "blink" and blink
  for _, ag in ipairs({ pulse, blink }) do
    if ag == anim and show then
      if not ag:IsPlaying() then ag:Play() end
    else
      ag:Stop()
    end
  end
end

-- Runs the range checks only while they can matter.
local function Watch()
  watcher:SetShown(not db.rangeOff and UnitExists("target"))
  UpdateShown()
end

ns.On("PLAYER_TARGET_CHANGED", function() if holder then Watch() end end)

-- Applies font, size and flash speed; the frame fits the text so the Edit
-- Mode selection box matches what is drawn. The text is set after the font
-- because a font string can't take text before it has a font.
local function ApplyLook()
  text:SetFont(FONTS[db.rangeFont], db.rangeSize, "THICKOUTLINE")
  text:SetText("OUT OF RANGE")
  holder:SetSize(text:GetStringWidth() + 8, text:GetStringHeight() + 4)
  local half = PERIODS[db.rangeSpeed] / 2
  pulse.fade:SetDuration(half)
  blink.on:SetDuration(half)
  blink.off:SetDuration(half)
  -- A playing group keeps its old timing until restarted.
  pulse:Stop()
  blink:Stop()
  UpdateShown()
end

-- Applies every range warning setting; used when built and after /wu reset.
function ns.RefreshRange()
  PlacePosition()
  ApplyLook()
  Watch()
end

-- Alpha animation on flash from -> to, played in order within its group.
local function Fade(ag, from, to, order)
  local a = ag:CreateAnimation("Alpha")
  a:SetFromAlpha(from)
  a:SetToAlpha(to)
  a:SetOrder(order)
  return a
end

function ns.BuildRangeWarning()
  holder = CreateFrame("Frame", nil, UIParent)
  holder:SetClampedToScreen(true)
  flash = CreateFrame("Frame", nil, holder)
  flash:SetAllPoints()
  text = flash:CreateFontString(nil, "OVERLAY")
  text:SetPoint("CENTER")
  text:SetTextColor(1, 0.12, 0.08)

  -- Pulse fades smoothly down and back; Blink snaps between full and hidden.
  pulse = flash:CreateAnimationGroup()
  pulse:SetLooping("BOUNCE")
  pulse.fade = Fade(pulse, 1, 0.15, 1)
  blink = flash:CreateAnimationGroup()
  blink:SetLooping("REPEAT")
  blink.on = Fade(blink, 1, 1, 1)
  blink.off = Fade(blink, 0, 0, 2)

  local elapsed = 0
  watcher = CreateFrame("Frame", nil, UIParent)
  watcher:Hide()
  watcher:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < INTERVAL then return end
    elapsed = 0
    UpdateShown()
  end)

  local T, Option, Choices = LEM.SettingType, ns.EditModeOption, ns.EditModeChoices
  local function Off() return db.rangeOff end
  local function NoFlash() return db.rangeOff or db.rangeFlash == "steady" end
  PlacePosition = ns.AddEditModeFrame(holder, "rangeLayouts", DEFAULT_POS, "WU Range Warning", {
    Option(T.Checkbox, "Disable Range Warning", "rangeOff", Watch),
    Option(T.Dropdown, "Font", "rangeFont", ApplyLook, Off, Choices("rangeFont")),
    Option(T.Slider, "Font Size", "rangeSize", ApplyLook, Off, { minValue = 16, maxValue = 64, valueStep = 2 }),
    Option(T.Dropdown, "Flash", "rangeFlash", ApplyLook, Off, Choices("rangeFlash")),
    Option(T.Dropdown, "Flash Speed", "rangeSpeed", ApplyLook, NoFlash, Choices("rangeSpeed")),
  }, Watch)
  ns.RefreshRange()
end
