local _, ns = ...
local db, LEM = ns.db, ns.LibEditMode

--------------------------------------------------------------------------------
-- Combat text (warriors only)
-- Numbers that float up and fade, in two columns moved in Edit Mode:
--   incoming  (left) damage you take, colored by spell school, heals in green
--             and what you avoided (Dodge, Parry, Block...)
--   outgoing  (right) hits on your target and what it avoided. The game gives
--             addons no combat log and no feed of only your own hits, so this
--             is everything your target takes, from anyone: yours when solo,
--             everyone's in a group (shown only while solo unless that is
--             turned off)
-- Both come from UNIT_COMBAT. Its amount is a secret value: Lua never reads
-- it, only hands it to the game's number formatting and SetFormattedText,
-- which accept secrets. What happened (hit, heal, dodge...), the critical
-- flag and the school are plain values. Critical hits show bigger.
-- Each line is a small frame with an animation (rise, then fade), reused
-- once it finishes; lines take turns in three lanes so they don't stack.
-- In Edit Mode each column shows its name so it can be placed.
-- Events: UNIT_COMBAT (player and target)
-- SavedVariables: ctOff, ctInOff, ctOutOff, ctOutGroupOff, ctInLayouts,
--   ctOutLayouts, ctSize, ctFont, ctTime, ctShort, ctHurtColor, ctHealColor,
--   ctHitColor, ctCritColor
--------------------------------------------------------------------------------
local RISE = 90 -- pixels a line floats up
local LANE = 28 -- pixels between lanes
-- What the game reports for an avoided or reduced attack, and what is shown.
local MISSES = {
  MISS = "Miss", DODGE = "Dodge", PARRY = "Parry", BLOCK = "Block", RESIST = "Resist", IMMUNE = "Immune",
  ABSORB = "Absorb", EVADE = "Evade", DEFLECT = "Deflect", REFLECT = "Reflect",
}
local SCHOOLS = { -- colors of damage you take from magic, by school bit
  [2] = { 1, 0.9, 0.5 }, [4] = { 1, 0.5, 0 }, [8] = { 0.3, 1, 0.3 },
  [16] = { 0.5, 1, 1 }, [32] = { 0.6, 0.4, 1 }, [64] = { 1, 0.5, 1 },
}
local sides = {} -- incoming and outgoing: holder, lines not in use, next lane

-- Returns a free line on side (a new one if all are in use): a frame with a
-- font string and its rise-and-fade animation, put back when it finishes.
local function Line(side)
  local f = table.remove(side.free)
  if f then return f end
  f = CreateFrame("Frame", nil, side.holder)
  f:SetSize(1, 1)
  f.text = f:CreateFontString(nil, "OVERLAY")
  f.text:SetPoint("BOTTOM")
  f.anim = f:CreateAnimationGroup()
  f.rise = f.anim:CreateAnimation("Translation")
  f.fade = f.anim:CreateAnimation("Alpha")
  f.fade:SetFromAlpha(1)
  f.fade:SetToAlpha(0)
  f.anim:SetScript("OnFinished", function()
    f:Hide()
    side.free[#side.free + 1] = f
  end)
  return f
end

-- Floats one line on side: fmt filled with value (may be secret) in color,
-- bigger when big.
local function Float(side, fmt, value, color, big)
  local f, time = Line(side), db.ctTime
  f.text:SetFont(ns.FONTS[db.ctFont], db.ctSize * (big and 1.5 or 1), "OUTLINE")
  f.text:SetTextColor(color.r or color[1], color.g or color[2], color.b or color[3])
  f.text:SetFormattedText(fmt, value)
  side.lane = side.lane % 3 + 1
  f:ClearAllPoints()
  f:SetPoint("BOTTOM", side.holder, "CENTER", (side.lane - 2) * LANE, 0)
  f.rise:SetOffset(0, RISE)
  f.rise:SetDuration(time)
  f.fade:SetStartDelay(time * 0.6)
  f.fade:SetDuration(time * 0.4)
  f:SetAlpha(1)
  f:Show()
  f.anim:Restart()
end

-- The amount as the game formats it: 1,234 or, when shortened, 1.2K.
local function Number(amount)
  return db.ctShort and AbbreviateNumbers(amount) or BreakUpLargeNumbers(amount)
end

-- Shows one UNIT_COMBAT report on the player (incoming) or the target
-- (outgoing). action, flag and school are plain values; amount is secret.
local function OnCombat(unit, action, flag, amount, school)
  if db.ctOff or issecretvalue(action) or issecretvalue(flag) or issecretvalue(school) then return end
  local crit = flag == "CRITICAL"
  if unit == "player" and not db.ctInOff then
    local side = sides[1]
    if action == "WOUND" then
      Float(side, "-%s", Number(amount), school ~= 1 and SCHOOLS[school] or db.ctHurtColor, crit)
    elseif action == "HEAL" then
      Float(side, "+%s", Number(amount), db.ctHealColor, crit)
    elseif MISSES[action] then
      Float(side, "%s", MISSES[action], db.ctHurtColor)
    end
  elseif unit == "target" and not db.ctOutOff and not (db.ctOutGroupOff and IsInGroup())
    and UnitCanAttack("player", "target") then
    local side = sides[2]
    if action == "WOUND" then
      Float(side, crit and "%s!" or "%s", Number(amount), crit and db.ctCritColor or db.ctHitColor, crit)
    elseif MISSES[action] then
      Float(side, "%s", MISSES[action], db.ctHitColor)
    end
  end
end
ns.On("UNIT_COMBAT", function(...) if sides[1] then OnCombat(...) end end, "player", "target")

-- Shows each column's name while in Edit Mode, so it can be placed.
local function EditMode()
  for _, side in ipairs(sides) do side.label:SetShown(LEM:IsInEditMode()) end
end

-- Applies the combat text settings; used when built, after a change on the
-- options page and after /wu reset.
function ns.RefreshCombatText()
  for _, side in ipairs(sides) do side.Place() end
  EditMode()
end

function ns.BuildCombatText()
  for i, info in ipairs({
    { key = "ctInLayouts", name = "WU Incoming Text", x = -220 },
    { key = "ctOutLayouts", name = "WU Outgoing Text", x = 220 },
  }) do
    local side = { free = {}, lane = 0 }
    side.holder = CreateFrame("Frame", nil, UIParent)
    side.holder:SetSize(120, 40)
    side.holder:SetClampedToScreen(true)
    side.label = side.holder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    side.label:SetPoint("CENTER")
    side.label:SetText(i == 1 and "Incoming" or "Outgoing")
    side.Place = ns.AddEditModeFrame(side.holder, info.key, { point = "CENTER", x = info.x, y = 40 }, info.name, {},
      EditMode)
    sides[i] = side
  end
  ns.RefreshCombatText()
end
