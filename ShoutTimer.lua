local _, ns = ...
local db = ns.db

--------------------------------------------------------------------------------
-- Battle Shout timer on the player frame (warriors only)
-- A thin bar behind the player's name on Blizzard's player frame that empties
-- as the player's Battle Shout runs down, and is hidden while the buff is
-- missing. The buff is found by each rank's spell ID, so no aura names are
-- compared. The bar runs from the aura's duration object
-- (StatusBar:SetTimerDuration): the game animates it, and no time left is
-- worked out in Lua, so it keeps working when aura timings are secret in
-- combat. The bar is parented to the player frame so it hides and scales with
-- it; it is the addon's own frame, and the player frame itself is never
-- changed. Turned on and off on the options page (General tab).
-- Events: UNIT_AURA (player), PLAYER_ENTERING_WORLD
-- SavedVariables: shoutOff
--------------------------------------------------------------------------------
local RANKS = { 6673, 5242, 6192, 11549, 11550, 11551, 25289, 27578 }
local WHITE = "Interface\\Buttons\\WHITE8X8"
local bar

-- Returns the auraInstanceID of the player's Battle Shout (any rank), or nil.
local function FindShout()
  for _, id in ipairs(RANKS) do
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(id)
    if aura then return aura.auraInstanceID end
  end
end

-- Shows the bar with the buff's current timer, or hides it when the buff is
-- missing or the timer is turned off.
local function Update()
  local instance = not db.shoutOff and FindShout()
  if instance then
    bar:SetTimerDuration(C_UnitAuras.GetAuraDuration("player", instance),
      Enum.StatusBarInterpolation.Immediate, Enum.StatusBarTimerDirection.RemainingTime)
  end
  bar:SetShown(instance and true or false)
end

ns.On("UNIT_AURA", function() if bar then Update() end end)
ns.On("PLAYER_ENTERING_WORLD", function() if bar then Update() end end)

ns.RefreshShout = Update

-- Builds the bar over the player name's box, one level under the player
-- frame's own art so the name stays on top.
function ns.BuildShoutTimer()
  local name = PlayerFrame.name
  bar = CreateFrame("StatusBar", nil, PlayerFrame)
  bar:SetFrameLevel(PlayerFrame:GetFrameLevel())
  bar:SetPoint("TOPLEFT", name, "TOPLEFT", -3, 2)
  bar:SetPoint("BOTTOMRIGHT", name, "BOTTOMRIGHT", 3, -2)
  bar:SetStatusBarTexture(WHITE)
  bar:SetStatusBarColor(0.85, 0.32, 0.08, 0.75)
  local bg = bar:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0, 0, 0.45)
  Update()
end
