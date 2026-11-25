local _, ns = ...
local db = ns.db

--------------------------------------------------------------------------------
-- Combat text (warriors only)
-- Adapted from SCT Mover by KidMoxie (Derek Springer), MIT, see
-- LICENSE-SCTMover.txt. Moves the game's own combat text; it draws none.
--   target text  the numbers above your target. The engine draws them, so
--                two game settings (CVars) are the only control: "Target
--                height" lifts or lowers them, for example clear of the
--                nameplate. The CVars hold the value, so WU saves nothing for
--                it and it stays even with the addon off.
--   self text    the numbers near your character (Blizzard's CombatText
--                frame): optionally drawn above other UI, and moved anywhere,
--                with offsets or by dragging a box with sample text.
-- In Forever combat amounts are secret, and any Lua field an addon writes on
-- CombatText taints Blizzard's code, which then fails on them. So the frame
-- is only moved by a Translation animation held on it (it writes no field),
-- and the sample text is drawn by WU, never sent through CombatText.
-- Blizzard_CombatText loads on demand, so the settings are applied again when
-- it loads and when the screen size changes (the offset is in screen units).
-- Events: ADDON_LOADED, DISPLAY_SIZE_CHANGED, UI_SCALE_CHANGED,
--   PLAYER_REGEN_DISABLED
-- SavedVariables: ctRaised, ctX, ctY
--------------------------------------------------------------------------------
local HIT_CVAR, CRIT_CVAR = "WorldTextScreenY_v2", "WorldTextCritScreenY_v2"
local STEP = 0.005 -- target height per step, as a fraction of the screen height
-- The self text offset is in Blizzard's reference units: a 1024 x 768 screen
-- with the text starting at its centre, so these ranges reach every point.
local REF_W, REF_H, START_Y = 1024, 768, 384
ns.CT_MAX_X, ns.CT_MAX_Y = 512, 384
local HOLD = 1e6 -- seconds the offset animation holds (it loops, so it never ends)
local strata, shiftGroup, shift, marker, sample

--------------------------------------------------------------------------------
-- Target text
--------------------------------------------------------------------------------

-- True when this client has the target text settings (they were renamed once).
function ns.HasTargetText()
  return C_CVar.GetCVar(HIT_CVAR) ~= nil and C_CVar.GetCVar(CRIT_CVAR) ~= nil
end

local function Default(cvar) return tonumber(C_CVar.GetCVarDefault(cvar)) or 0 end

-- Target height in steps from the game default.
function ns.GetTargetHeight()
  local value = tonumber(C_CVar.GetCVar(HIT_CVAR)) or 0
  return math.floor((value - Default(HIT_CVAR)) / STEP + 0.5)
end

-- Sets the target height; crits move with normal hits, each from its own
-- default.
function ns.SetTargetHeight(steps)
  C_CVar.SetCVar(HIT_CVAR, Default(HIT_CVAR) + steps * STEP)
  C_CVar.SetCVar(CRIT_CVAR, Default(CRIT_CVAR) + steps * STEP)
end

--------------------------------------------------------------------------------
-- Self text
--------------------------------------------------------------------------------

-- False when self text is turned off in the game's options.
function ns.SelfTextOn()
  return C_CVar.GetCVarBool("enableFloatingCombatText")
end

-- Factors from Blizzard's reference screen to the real one.
local function Scales()
  return WorldFrame:GetWidth() / REF_W, WorldFrame:GetHeight() / REF_H
end

-- Puts the drag box where self text starts, the way Blizzard anchors it: top
-- centre to the bottom centre of the WorldFrame.
local function PlaceMarker()
  local sx, sy = Scales()
  marker:ClearAllPoints()
  marker:SetPoint("TOP", WorldFrame, "BOTTOM", db.ctX * sx, (START_Y + db.ctY) * sy)
end

-- Applies the self text settings to Blizzard's CombatText frame, when loaded:
-- its strata, and its offset as a held Translation animation.
local function Apply()
  if not CombatText then return end
  strata = strata or CombatText:GetFrameStrata()
  CombatText:SetFrameStrata(db.ctRaised and "HIGH" or strata)
  if not shiftGroup then
    shiftGroup = CombatText:CreateAnimationGroup()
    shiftGroup:SetLooping("REPEAT")
    shift = shiftGroup:CreateAnimation("Translation")
    shift:SetDuration(0)
    shift:SetEndDelay(HOLD)
  end
  shiftGroup:Stop() -- a running group keeps its old offset
  if db.ctX ~= 0 or db.ctY ~= 0 then
    local sx, sy = Scales()
    shift:SetOffset(db.ctX * sx, db.ctY * sy)
    shiftGroup:Play()
  end
end

-- Ends move mode (combat starting ends it too).
local function StopMoving()
  if marker and marker:IsShown() then
    sample:Stop()
    marker:Hide()
  end
end

-- Move mode: a box where self text starts, with sample text rising from it
-- (drawn by WU), to drag anywhere. Closes the options, which cover the
-- middle of the screen; Done opens them again. Not in combat.
function ns.MoveSelfText()
  if InCombatLockdown() or not ns.SelfTextOn() then return end
  if not marker then
    marker = CreateFrame("Frame", nil, UIParent)
    marker:SetSize(170, 40)
    marker:SetFrameStrata("DIALOG")
    marker:SetClampedToScreen(true)
    marker:SetMovable(true)
    marker:EnableMouse(true)
    marker:RegisterForDrag("LeftButton")
    marker:SetScript("OnDragStart", marker.StartMoving)
    -- Reads the dropped box back as an offset (the reverse of PlaceMarker),
    -- in whole reference units within the screen, and snaps to it.
    marker:SetScript("OnDragStop", function(self)
      self:StopMovingOrSizing()
      local sx, sy = Scales()
      local k = WorldFrame:GetEffectiveScale() / self:GetEffectiveScale()
      local x = (self:GetCenter() - WorldFrame:GetCenter() * k) / sx
      local y = (self:GetTop() - WorldFrame:GetBottom() * k) / sy - START_Y
      db.ctX = math.max(-ns.CT_MAX_X, math.min(ns.CT_MAX_X, math.floor(x + 0.5)))
      db.ctY = math.max(-ns.CT_MAX_Y, math.min(ns.CT_MAX_Y, math.floor(y + 0.5)))
      Apply()
      PlaceMarker()
    end)
    local bg = marker:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.6)
    local label = marker:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("BOTTOM", 0, 6)
    label:SetText("Self text starts here")
    local done = CreateFrame("Button", nil, marker, "UIPanelButtonTemplate")
    done:SetPoint("TOP", marker, "BOTTOM", 0, -4)
    done:SetSize(80, 22)
    done:SetText(DONE)
    marker:SetClampRectInsets(0, 0, 0, -(4 + done:GetHeight())) -- keeps Done on screen
    done:SetScript("OnClick", function()
      StopMoving()
      ns.OpenOptions()
    end)
    -- Sample text rising and fading like Blizzard's (225 reference units in
    -- 1.9 seconds).
    local holder = CreateFrame("Frame", nil, marker)
    holder:SetSize(1, 1)
    holder:SetPoint("TOP")
    local text = holder:CreateFontString(nil, "ARTWORK")
    text:SetFontObject(CombatTextFont)
    text:SetTextHeight(25)
    text:SetPoint("TOP")
    text:SetText("-123")
    text:SetTextColor(1, 0.1, 0.1)
    sample = text:CreateAnimationGroup()
    sample:SetLooping("REPEAT")
    sample.rise = sample:CreateAnimation("Translation")
    sample.rise:SetDuration(1.9)
    local fade = sample:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0)
    fade:SetStartDelay(1.9 * 0.7)
    fade:SetDuration(1.9 * 0.3)
    marker.holder = holder
  end
  HideUIPanel(SettingsPanel)
  PlaceMarker()
  local _, sy = Scales()
  sample.rise:SetOffset(0, 225 * sy)
  marker.holder:SetFrameStrata(db.ctRaised and "HIGH" or strata or "MEDIUM")
  marker:Show()
  sample:Play()
end

ns.On("ADDON_LOADED", function(name)
  if name == "Blizzard_CombatText" and ns.built then Apply() end
end)
ns.On("DISPLAY_SIZE_CHANGED", function() if ns.built then Apply() end end)
ns.On("UI_SCALE_CHANGED", function() if ns.built then Apply() end end)
ns.On("PLAYER_REGEN_DISABLED", StopMoving) -- a box mid-screen is a danger in a fight

-- Applies the self text settings; used when built, after a change on the
-- options page and after /wu reset.
function ns.RefreshCombatText()
  Apply()
  if marker and marker:IsShown() then PlaceMarker() end
end

function ns.BuildCombatText()
  if not ns.HasTargetText() then
    print("WU - Warrior Utilities: this game client doesn't have the settings that move target text.")
  end
  Apply()
end
