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
-- In combat the game won't tell addons whether the player has Battle Shout
-- (the aura lookup comes back empty), so the addon keeps its own timer:
--   expires  GetTime() when the buff ends (0 or past: not up)
--   length   the buff's full length, from the last time the game showed it
-- Out of combat, and at the moment combat starts, the timer is read from the
-- aura itself. In combat an empty lookup is ignored, and a successful cast of
-- any Battle Shout rank by the player (UNIT_SPELLCAST_SUCCEEDED, whose spell ID
-- the game does not hide) restarts the timer at length. When combat ends the
-- aura is read again, which catches anything the timer couldn't see in combat:
-- another warrior's Battle Shout, or the buff being cancelled or removed.
-- Any value the game marks secret is skipped, never read. The buff is found by
-- each rank's spell ID, so no aura names are compared.
-- The bar, countdown, flash and warning are parented to the player frame so they hide and scale with it;
-- they are the addon's own frames, and the player frame itself is never
-- changed. Set up on the Battle Shout tab of the options page.
-- Events: UNIT_AURA, UNIT_SPELLCAST_SUCCEEDED (player), PLAYER_ENTERING_WORLD,
--   PLAYER_REGEN_DISABLED, PLAYER_REGEN_ENABLED
-- SavedVariables: shoutOff, shoutTextOff, shoutFlashOff, shoutWarnOff,
--   shoutWarnSize, shoutColor
--------------------------------------------------------------------------------
local RANKS = { 6673, 5242, 6192, 11549, 11550, 11551, 25289, 27578 }
local IS_SHOUT = {}
for _, id in ipairs(RANKS) do IS_SHOUT[id] = true end
local WHITE = "Interface\\Buttons\\WHITE8X8"
local FONT = "Fonts\\FRIZQT__.TTF"
local bar, clock, alarm, warn, warnText
local inCombat = false
local expires, length = 0, 120

-- Returns the player's Battle Shout aura (any rank), or nil.
local function FindShout()
  for _, id in ipairs(RANKS) do
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(id)
    if aura then return aura end
  end
end

-- Sets the timer from the aura when the game reports it, or clears it when
-- the buff is gone out of combat. In combat an empty lookup says nothing, and
-- hidden (secret) timings are skipped, so the timer is left as it is.
local function Scan()
  local aura = FindShout()
  if aura then
    if not issecretvalue(aura.expirationTime) and not issecretvalue(aura.duration) then
      expires, length = aura.expirationTime, aura.duration
    end
  elseif not inCombat then
    expires = 0
  end
end

-- Shows the bar and countdown while the timer runs, or the flash and warning
-- while Battle Shout is missing in combat. Everything hides when the timer is
-- turned off.
local function Update()
  local left = db.shoutOff and 0 or expires - GetTime()
  local up = left > 0
  if up then
    bar:SetMinMaxValues(0, length)
    bar:SetValue(left)
    clock:SetCooldown(expires - length, length)
  end
  bar:SetShown(up)
  clock:SetShown(up and not db.shoutTextOff)
  local missing = not db.shoutOff and not up and inCombat
  alarm:SetShown(missing and not db.shoutFlashOff)
  warn:SetShown(missing and not db.shoutWarnOff)
end

-- Reads the aura, then redraws.
local function Refresh()
  Scan()
  Update()
end

-- Sets the combat flag for the combat events, then reads the aura.
local function SetCombat(state)
  inCombat = state
  if bar then Refresh() end
end

ns.On("UNIT_AURA", function() if bar then Refresh() end end)
ns.On("UNIT_SPELLCAST_SUCCEEDED", function(_, _, spellID)
  if bar and not issecretvalue(spellID) and IS_SHOUT[spellID] then
    expires = GetTime() + length
    Update()
  end
end)
ns.On("PLAYER_ENTERING_WORLD", function() SetCombat(UnitAffectingCombat("player")) end)
ns.On("PLAYER_REGEN_DISABLED", function() SetCombat(true) end)
ns.On("PLAYER_REGEN_ENABLED", function() SetCombat(false) end)

-- Applies the bar color and warning size, then redraws. Used when built,
-- after a setting changes on the options page and after /wu reset.
function ns.RefreshShout()
  local c = db.shoutColor
  bar:SetStatusBarColor(c.r, c.g, c.b, c.a)
  -- The warning's box is as tall as the text, so its bottom stays just above
  -- the name bar at every size.
  warnText:SetFont(FONT, db.shoutWarnSize, "OUTLINE")
  warn:SetHeight(db.shoutWarnSize + 4)
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
-- name stays on top, and the warning and countdown above the art so they can
-- be read.
function ns.BuildShoutTimer()
  local name = PlayerFrame.name
  local level = PlayerFrame:GetFrameLevel()
  local top = name:GetParent():GetFrameLevel() + 5 -- above the name and frame art

  bar = OverName("StatusBar", name)
  bar:SetFrameLevel(level)
  bar:SetStatusBarTexture(WHITE)
  local bg = bar:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0, 0, 0.45)
  -- Drains the bar while it is shown; when the time runs out, Update hides it
  -- (and shows the flash and warning in combat).
  bar:SetScript("OnUpdate", function(self)
    local left = expires - GetTime()
    if left > 0 then self:SetValue(left) else Update() end
  end)

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

  -- Warning text just above the name bar at the top of the player frame;
  -- RefreshShout sets its size. A font string needs a font before its text.
  warn = CreateFrame("Frame", nil, PlayerFrame)
  warn:SetFrameLevel(top)
  warn:SetWidth(400)
  warn:SetPoint("BOTTOM", bar, "TOP", 0, 6)
  warnText = warn:CreateFontString(nil, "OVERLAY")
  warnText:SetAllPoints()
  warnText:SetFont(FONT, db.shoutWarnSize, "OUTLINE")
  warnText:SetTextColor(1, 0.15, 0.1)
  warnText:SetText("Battle Shout Missing")

  -- A Cooldown frame used only for its countdown numbers: no swipe, edge or
  -- finish flash.
  clock = CreateFrame("Cooldown", nil, PlayerFrame, "CooldownFrameTemplate")
  clock:SetFrameLevel(top)
  clock:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -1, 0)
  clock:SetPoint("BOTTOMLEFT", bar, "BOTTOMRIGHT", -30, 0)
  clock:SetDrawSwipe(false)
  clock:SetDrawEdge(false)
  clock:SetDrawBling(false)
  clock:SetHideCountdownNumbers(false)
  clock:GetCountdownFontString():SetFont(FONT, 11, "OUTLINE")

  Scan()
  ns.RefreshShout()
end
