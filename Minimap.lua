local addonName, ns = ...
local db = ns.db

--------------------------------------------------------------------------------
-- Minimap icon
-- A round button on the minimap's edge with the addon's icon. Clicking it
-- opens or closes the options window (the same as /wu); right-clicking it unlocks or
-- locks the trinket bars for dragging (warriors); dragging it moves it around the
-- edge, and the spot is saved as an angle. Built from plain textures with the
-- game's own minimap button art, so it needs no library. Shown on warriors
-- and druids (whoever gets the options page); hidden with "Show minimap icon"
-- on the General tab.
-- Events: none
-- SavedVariables: minimapOff, minimapAngle
--------------------------------------------------------------------------------
local ICON = "Interface\\AddOns\\" .. addonName .. "\\icon"
local GAP = 5 -- px between the minimap's edge and the button's centre ring
local button

-- Puts the button on the minimap's edge at db.minimapAngle (degrees,
-- counterclockwise from the right).
local function Place()
  local a = math.rad(db.minimapAngle)
  local r = Minimap:GetWidth() / 2 + GAP
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

-- While dragging: follows the cursor around the minimap's edge.
local function FollowCursor()
  local mx, my = Minimap:GetCenter()
  local cx, cy = GetCursorPosition()
  local scale = Minimap:GetEffectiveScale()
  db.minimapAngle = math.deg(math.atan2(cy / scale - my, cx / scale - mx)) % 360
  Place()
end

-- Applies the minimap settings; used when built, after the setting changes on
-- the options page and after /wu reset.
function ns.RefreshMinimap()
  Place()
  button:SetShown(not db.minimapOff)
end

function ns.BuildMinimap()
  -- Named so minimap-button collectors (e.g. OneForAll) can find it; they skip unnamed buttons.
  button = CreateFrame("Button", "WUMinimapButton", Minimap)
  button:SetSize(31, 31)
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel(8)
  button:RegisterForDrag("LeftButton")
  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  local background = button:CreateTexture(nil, "BACKGROUND")
  background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  background:SetSize(24, 24)
  background:SetPoint("CENTER")
  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetTexture(ICON)
  icon:SetTexCoord(0.05, 0.95, 0.05, 0.95) -- trims the edge so it sits inside the ring
  icon:SetSize(18, 18)
  icon:SetPoint("CENTER")
  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetSize(50, 50)
  border:SetPoint("TOPLEFT")

  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:SetScript("OnClick", function(_, mouse)
    if mouse == "RightButton" then
      if ns.isWarrior then ns.ToggleTrinketLock() end
    else
      ns.ToggleOptions()
    end
  end)
  button:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", FollowCursor)
  end)
  button:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
  end)
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("WU - Warrior Utilities", 1, 1, 1)
    GameTooltip:AddLine("Click to open the options.")
    if ns.isWarrior then GameTooltip:AddLine("Right-click to lock or unlock moving the trinket bars.") end
    GameTooltip:AddLine("Drag to move this icon.")
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", GameTooltip_Hide)

  ns.RefreshMinimap()
end
