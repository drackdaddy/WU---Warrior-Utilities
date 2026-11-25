local _, ns = ...
local db = ns.db

--------------------------------------------------------------------------------
-- Battle Shout timer on the player frame (warriors only)
-- On Blizzard's player frame, over the player's name:
--   bar        empties as the player's Battle Shout runs down
--   countdown  time left, at the right end of the name
--   alarm      red flash while Battle Shout is missing in combat
--   warn       "Battle Shout Missing" just above the name, at the same time
-- The flash and warning turn off separately.
--
-- In combat the game won't tell addons whether the player has Battle Shout,
-- so the addon never asks. Blizzard's aura containers (see ns.AuraContainer
-- in Core.lua) watch the player's buffs themselves, in and out of combat,
-- filtered to Battle Shout's rank spell IDs, and hold one frame
-- while any Battle Shout is on the player (the player's own or another
-- warrior's):
--   timer     its frame carries the bar and countdown; the game fills the bar
--             (SetDurationBar) and writes the time (SetDurationText). No buff,
--             no frame, so both disappear on their own.
--   presence  an invisible frame ZONE px wide. The flash and warning sit in a
--             clip frame that starts at the container's right edge, so they
--             are cut off while the buff is up and show while it is missing.
-- Lua never reads the buff, its timings or the containers' sizes. Frames whose
-- layout follows a container use DisableUntrustedLayoutScriptsTemplate, as
-- that layout is the game's. A frame the game set up is never touched again:
-- a new color or the countdown switch builds a new timer container.
-- Everything is parented to the player frame so it hides and scales with it;
-- the player frame itself is never changed. Set up on the Battle Shout tab
-- under CDM on the options page.
-- Events: PLAYER_ENTERING_WORLD, PLAYER_REGEN_DISABLED, PLAYER_REGEN_ENABLED
-- SavedVariables: shoutOff, shoutTextOff, shoutFlashOff, shoutWarnOff,
--   shoutWarnSize, shoutColor
--------------------------------------------------------------------------------
local RANKS = { 6673, 5242, 6192, 11549, 11550, 11551, 25289, 27578 }
local WHITE = "Interface\\Buttons\\WHITE8X8"
local FONT = "Fonts\\FRIZQT__.TTF"
local ZONE = 400 -- width of the area the flash and warning can show in
local host, zone, presence, gate, alarm, warn, warnText, timer, timerLook
local level, top -- frame levels under and above the player frame's art
local inCombat = false

-- Builds the timer container with the current bar color and countdown
-- switch, retiring the old one.
local function BuildTimer()
  if timer then
    timer:SetEnabled(false)
    timer:Hide()
  end
  local c, w, h = db.shoutColor, host:GetSize()
  timer = ns.AuraContainer(host, "player", "HELPFUL", RANKS, w, h, function(frame)
    local bar = CreateFrame("StatusBar", nil, frame)
    bar:SetAllPoints()
    bar:SetStatusBarTexture(WHITE)
    bar:SetStatusBarColor(c.r, c.g, c.b, c.a)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.45)
    frame:SetDurationBar(bar, { direction = Enum.StatusBarTimerDirection.RemainingTime })
    if not db.shoutTextOff then
      -- On its own frame above the player frame's art so it can be read.
      local over = CreateFrame("Frame", nil, frame)
      over:SetAllPoints()
      over:SetFrameLevel(top)
      local countdown = over:CreateFontString(nil, "OVERLAY")
      countdown:SetFont(FONT, 11, "OUTLINE")
      countdown:SetPoint("RIGHT", -2, 0)
      frame:SetDurationText(countdown, {})
    end
  end)
  timer:SetFrameLevel(level)
end

-- Turns the containers on or off and shows the flash and warning area in
-- combat only.
local function Update()
  timer:SetEnabled(not db.shoutOff)
  presence:SetEnabled(not db.shoutOff)
  gate:SetShown(not db.shoutOff and inCombat)
  alarm:SetShown(not db.shoutFlashOff)
  warn:SetShown(not db.shoutWarnOff)
end

-- Sets the combat flag for the combat events, then redraws.
local function SetCombat(state)
  inCombat = state
  if host then Update() end
end

ns.On("PLAYER_ENTERING_WORLD", function() SetCombat(UnitAffectingCombat("player")) end)
ns.On("PLAYER_REGEN_DISABLED", function() SetCombat(true) end)
ns.On("PLAYER_REGEN_ENABLED", function() SetCombat(false) end)

-- Applies the settings, then redraws. The timer container is only rebuilt
-- when the bar color or countdown switch changed. The warning area grows with
-- the text so the warning's bottom stays just above the name bar. Used when
-- built, after a setting changes on the options page and after /wu reset.
function ns.RefreshShout()
  local c = db.shoutColor
  local look = table.concat({ c.r, c.g, c.b, c.a, tostring(db.shoutTextOff) }, ",")
  if look ~= timerLook then
    timerLook = look
    BuildTimer()
  end
  warnText:SetFont(FONT, db.shoutWarnSize, "OUTLINE")
  warn:SetHeight(db.shoutWarnSize + 4)
  zone:SetPoint("TOPRIGHT", host, "TOP", ZONE / 2, db.shoutWarnSize + 14)
  Update()
end

-- Builds the frames over the player's name. The bar and flash sit one level
-- under the player frame's own art so the name stays on top; the countdown
-- and warning sit above it.
function ns.BuildShoutTimer()
  local name = PlayerFrame.name
  level = PlayerFrame:GetFrameLevel()
  top = name:GetParent():GetFrameLevel() + 5

  -- The name's box, a little wider and taller than it.
  host = CreateFrame("Frame", nil, PlayerFrame)
  host:SetFrameLevel(level)
  host:SetPoint("TOPLEFT", name, "TOPLEFT", -3, 2)
  host:SetPoint("BOTTOMRIGHT", name, "BOTTOMRIGHT", 3, -2)

  -- The flash and warning area: ZONE wide, centered on the name, from the
  -- bottom of the name box up past the warning (RefreshShout sets its top).
  zone = CreateFrame("Frame", nil, host)
  zone:SetPoint("BOTTOMLEFT", host, "BOTTOM", -ZONE / 2, 0)
  presence = ns.AuraContainer(zone, "player", "HELPFUL", RANKS, ZONE + 1, 1)
  gate = CreateFrame("Frame", nil, host)
  gate:SetAllPoints(zone)
  local clip = CreateFrame("Frame", nil, gate, "DisableUntrustedLayoutScriptsTemplate")
  clip:SetClipsChildren(true)
  clip:SetPoint("TOPLEFT", presence, "TOPRIGHT", -1, 0)
  clip:SetPoint("BOTTOMRIGHT", zone, "BOTTOMRIGHT")

  -- Red fill over the name box that pulses while shown.
  alarm = CreateFrame("Frame", nil, clip, "DisableUntrustedLayoutScriptsTemplate")
  alarm:SetAllPoints(host)
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

  -- Warning text just above the name bar; RefreshShout sets its size. A font
  -- string needs a font before its text.
  warn = CreateFrame("Frame", nil, clip, "DisableUntrustedLayoutScriptsTemplate")
  warn:SetFrameLevel(top)
  warn:SetWidth(ZONE)
  warn:SetPoint("BOTTOM", host, "TOP", 0, 6)
  warnText = warn:CreateFontString(nil, "OVERLAY")
  warnText:SetAllPoints()
  warnText:SetFont(FONT, db.shoutWarnSize, "OUTLINE")
  warnText:SetTextColor(1, 0.15, 0.1)
  warnText:SetText("Battle Shout Missing")

  ns.RefreshShout()
end
