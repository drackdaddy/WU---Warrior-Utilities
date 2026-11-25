local _, ns = ...
local db = ns.db

--------------------------------------------------------------------------------
-- Cooldown icon look (warriors only)
-- The icons the stance cooldown bars and the custom bar are made of, and the
-- look they share, set on the Appearance tab under CDM:
--   glow     when an ability is ready: a pulsing border, marching sparks or a
--            static border, in a chosen color, speed and thickness, and
--            optionally only in combat. An icon can have its own glow type,
--            set per ability on the Stances and Custom tabs.
--   on cooldown  normal, greyed out, faded or hidden
-- In combat cooldown times and "usable" answers can be secret, so Lua never
-- reads them. The game hands back a duration object for each spell's
-- cooldown; curves turn its time left into alphas (the object evaluates them)
-- and "usable" goes to SetAlphaFromBoolean. Every effect runs all the time and
-- only those alphas decide whether it can be seen, so nothing ever needs to
-- know when an ability became ready. That is also why a hidden icon keeps its
-- place on the bar. GRACE counts the global cooldown as ready so nothing
-- blinks after every ability. Items have no duration object, so their icons
-- only show the cooldown swipe.
-- One ticker redraws the alphas of every shown spell icon and moves the
-- sparks.
-- Events: PLAYER_REGEN_DISABLED, PLAYER_REGEN_ENABLED
-- SavedVariables: glowStyle, glowColor, glowSpeed, glowSize, glowOocOff, cdLook
--------------------------------------------------------------------------------
local GRACE = 1.6 -- seconds left that still count as ready (the global cooldown)
local INTERVAL = 0.1 -- seconds between alpha updates
local SPARKS = 4
local WHITE = "Interface\\Buttons\\WHITE8X8"
local PULSE = { slow = 0.8, medium = 0.5, fast = 0.25 } -- seconds per fade
local LAP = { slow = 4, medium = 2.5, fast = 1.5 } -- seconds per spark lap
local ON_COOLDOWN = { normal = 1, grey = 1, faded = 0.35, hidden = 0 } -- icon alpha on cooldown
local icons = {} -- every icon made, bars and preview alike
local readyCurve, bodyCurve, greyCurve, ticker
local inCombat = false

-- A curve that is ready (up to GRACE seconds left) for the first value and
-- on cooldown for the second.
local function Curve(ready, cooling)
  local c = C_CurveUtil.CreateCurve()
  c:AddPoint(0, ready)
  c:AddPoint(GRACE, ready)
  c:AddPoint(GRACE + 0.01, cooling)
  c:AddPoint(3600, cooling)
  return c
end

-- Shows or hides icon f's glow: on for this icon, and in combat when the
-- glow is set to combat only (previews always glow).
local function ShowGlow(f)
  f.glow:SetShown(f.glowOn and (f.preview or inCombat or not db.glowOocOff))
end

-- Applies the Appearance settings to icon f: glow color, thickness and style
-- (its own glow type, or the Appearance one).
local function Style(f)
  local c, size, style = db.glowColor, db.glowSize, f.glowStyle or db.glowStyle
  f.border:SetBackdrop({ edgeFile = WHITE, edgeSize = size })
  f.border:SetPoint("TOPLEFT", -size, size)
  f.border:SetPoint("BOTTOMRIGHT", size, -size)
  f.border:SetBackdropBorderColor(c.r, c.g, c.b, style == "sparks" and 0.35 or 1)
  f.shine:SetColorTexture(c.r, c.g, c.b, 0.25)
  f.shine:SetShown(style ~= "sparks")
  for _, s in ipairs(f.sparks) do
    s:SetColorTexture(math.min(1, c.r + 0.3), math.min(1, c.g + 0.3), math.min(1, c.b + 0.3), 1)
    s:SetShown(style == "sparks")
  end
  f.fade:SetDuration(PULSE[db.glowSpeed])
  if style == "pulse" then f.pulse:Play() else f.pulse:Stop() end
  ShowGlow(f)
end

-- Returns a new cooldown icon on parent: the icon art, a greyed copy for
-- "on cooldown" and one for "can't be used now", the cooldown swipe with its
-- countdown, and the glow (ready layer, usable layer, then the style). A bar
-- sets f.spell (or f.item) and the texture, and calls ns.SetIconGlow. Plain
-- frames with no mouse input.
function ns.NewCooldownIcon(parent)
  local f = CreateFrame("Frame", nil, parent)
  f.body = CreateFrame("Frame", nil, f)
  f.body:SetAllPoints()
  f.tex = f.body:CreateTexture(nil, "ARTWORK")
  f.tex:SetAllPoints()
  f.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- trims the icon art's own border
  local function Grey(r, g, b)
    local layer = CreateFrame("Frame", nil, f.body)
    layer:SetAllPoints()
    layer:SetAlpha(0)
    layer.tex = layer:CreateTexture(nil, "ARTWORK")
    layer.tex:SetAllPoints()
    layer.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    layer.tex:SetDesaturated(true)
    layer.tex:SetVertexColor(r, g, b)
    return layer
  end
  f.cdGrey = Grey(0.75, 0.75, 0.75)
  f.unusable = Grey(0.55, 0.55, 0.55)
  f.cd = CreateFrame("Cooldown", nil, f.body, "CooldownFrameTemplate")
  f.cd:SetAllPoints()
  f.cd:SetHideCountdownNumbers(false)

  f.glow = CreateFrame("Frame", nil, f)
  f.glow:SetAllPoints()
  f.glow:SetFrameLevel(f.cd:GetFrameLevel() + 2)
  f.ready = CreateFrame("Frame", nil, f.glow)
  f.ready:SetAllPoints()
  f.ready:SetAlpha(0)
  f.usable = CreateFrame("Frame", nil, f.ready)
  f.usable:SetAllPoints()
  f.border = CreateFrame("Frame", nil, f.usable, "BackdropTemplate")
  f.shine = f.border:CreateTexture(nil, "ARTWORK")
  f.shine:SetPoint("TOPLEFT", f, 0, 0)
  f.shine:SetPoint("BOTTOMRIGHT", f, 0, 0)
  f.shine:SetBlendMode("ADD")
  f.pulse = f.border:CreateAnimationGroup()
  f.pulse:SetLooping("BOUNCE")
  f.fade = f.pulse:CreateAnimation("Alpha")
  f.fade:SetFromAlpha(1)
  f.fade:SetToAlpha(0.3)
  f.sparks = {}
  for i = 1, SPARKS do f.sparks[i] = f.usable:CreateTexture(nil, "OVERLAY") end

  icons[#icons + 1] = f
  Style(f)
  return f
end

-- Turns icon f's glow on or off (its bar's and its own glow switches) and
-- sets its own glow type (nil = the Appearance one).
function ns.SetIconGlow(f, on, style)
  f.glowOn = on
  if style ~= f.glowStyle then
    f.glowStyle = style
    Style(f)
  else
    ShowGlow(f)
  end
end

-- Fetches icon f's cooldown and hands it to the swipe; a spell's duration
-- object is kept for the alphas. An item icon gets the plain look, as a
-- reused icon may still have a spell's alphas.
function ns.UpdateIconCooldown(f)
  if f.item then
    local start, duration = C_Item.GetItemCooldown(f.item)
    f.cd:SetCooldown(start, duration)
    f.body:SetAlpha(1)
    f.cdGrey:SetAlpha(0)
    f.unusable:SetAlpha(0)
    f.ready:SetAlpha(0)
    return
  end
  f.dur = C_Spell.GetSpellCooldownDuration(f.spell)
  if f.dur then f.cd:SetCooldownFromDurationObject(f.dur) else f.cd:Clear() end
end

-- Sets spell icon f's alphas from its cooldown and whether it can be used now
-- (enough rage, and any trigger it needs, like Victory Rush's kill). The icon
-- greys out while it can't be. These answers may be secret, so they only go
-- to the alpha setters.
local function Draw(f)
  local usable = C_Spell.IsSpellUsable(f.spell)
  f.unusable:SetAlphaFromBoolean(usable, 0, 1)
  f.usable:SetAlphaFromBoolean(usable, 1, 0)
  if f.dur then
    f.ready:SetAlpha(f.dur:EvaluateRemainingDuration(readyCurve))
    f.body:SetAlpha(f.dur:EvaluateRemainingDuration(bodyCurve))
    f.cdGrey:SetAlpha(f.dur:EvaluateRemainingDuration(greyCurve))
  else
    f.ready:SetAlpha(0)
    f.body:SetAlpha(1)
    f.cdGrey:SetAlpha(0)
  end
end

-- Puts icon f's sparks at their place on its edge, lap seconds per lap, now
-- being t. Each is a short bar running clockwise from the top left corner.
local function MoveSparks(f, t, lap)
  local w = f:GetWidth()
  local len, thick = w * 0.3, db.glowSize + 1
  for i, s in ipairs(f.sparks) do
    local d = ((t / lap + (i - 1) / SPARKS) % 1) * 4 * w
    local side, along = math.floor(d / w), d % w
    s:ClearAllPoints()
    if side == 0 then
      s:SetSize(len, thick)
      s:SetPoint("CENTER", f, "TOPLEFT", along, 0)
    elseif side == 1 then
      s:SetSize(thick, len)
      s:SetPoint("CENTER", f, "TOPRIGHT", 0, -along)
    elseif side == 2 then
      s:SetSize(len, thick)
      s:SetPoint("CENTER", f, "BOTTOMRIGHT", -along, 0)
    else
      s:SetSize(thick, len)
      s:SetPoint("CENTER", f, "BOTTOMLEFT", 0, along)
    end
  end
end

-- Shows a still preview on icon: ready (glowing) or on cooldown (the
-- on-cooldown look, with a running swipe). Used by the Appearance tab.
function ns.PreviewIcon(f, ready)
  f.ready:SetAlpha(ready and 1 or 0)
  f.usable:SetAlpha(1)
  f.body:SetAlpha(ready and 1 or math.max(ON_COOLDOWN[db.cdLook], 0.15))
  f.cdGrey:SetAlpha(not ready and db.cdLook == "grey" and 1 or 0)
  if ready then f.cd:Clear() else f.cd:SetCooldown(GetTime(), 30) end
end

ns.On("PLAYER_REGEN_DISABLED", function()
  inCombat = true
  for _, f in ipairs(icons) do ShowGlow(f) end
end)
ns.On("PLAYER_REGEN_ENABLED", function()
  inCombat = false
  for _, f in ipairs(icons) do ShowGlow(f) end
end)

-- Applies the Appearance settings to every icon; used when built, after a
-- change on the options page and after /wu reset.
function ns.RefreshLook()
  local cooling = ON_COOLDOWN[db.cdLook]
  bodyCurve = Curve(1, cooling)
  greyCurve = Curve(0, db.cdLook == "grey" and 1 or 0)
  for _, f in ipairs(icons) do Style(f) end
end

function ns.BuildCooldownLook()
  readyCurve = Curve(1, 0)
  inCombat = UnitAffectingCombat("player")
  local elapsed = 0
  ticker = CreateFrame("Frame")
  ticker:SetScript("OnUpdate", function(_, dt)
    local t = GetTime()
    elapsed = elapsed + dt
    local redraw = elapsed >= INTERVAL
    if redraw then elapsed = 0 end
    for _, f in ipairs(icons) do
      if f:IsVisible() then
        if redraw and f.spell and not f.preview then Draw(f) end
        if (f.glowStyle or db.glowStyle) == "sparks" and f.glow:IsShown() then
          MoveSparks(f, t, LAP[db.glowSpeed])
        end
      end
    end
  end)
  ns.RefreshLook()
end
