local _, ns = ...
local db = ns.db

--------------------------------------------------------------------------------
-- Trinket rotation and mount swap (warriors only)
-- Adapted from Forever Trinket Menu by sk0lu (MIT, see LICENSE-ForeverTrinketMenu.txt).
--   rotation     each trinket slot can have a list of trinkets in priority
--                order (Alt+click one in the swap list, see Trinkets.lua;
--                ordered on the Trinket tab). When the one worn is on
--                cooldown, the first one on the list that is ready goes on.
--                One with 30 seconds or less left counts as ready, as putting
--                a trinket on starts a 30 second cooldown anyway. A ready
--                trinket stays on until used, and one without a "Use:" effect
--                (put on by hand) is left alone.
--   mount swap   on mounting, your riding trinket (Carrot on a Stick or
--                Riding Crop) goes in the chosen trinket slot; on getting off,
--                the one it replaced goes back.
-- The game won't change gear in combat, so both only swap out of combat, and
-- they only put items on: nothing ever uses an item or casts for the player.
-- Swaps that come due in combat wait for it to end (see ns.Equip). Mounting
-- and cooldowns are checked twice a second out of combat, as Forever Trinket
-- Menu does; cooldowns are plain values then.
-- Events: PLAYER_REGEN_DISABLED, PLAYER_REGEN_ENABLED
-- SavedVariables: trinketQueue, rotate13Off, rotate14Off, mountSwapOff,
--   mountSlot, mountPrev
--------------------------------------------------------------------------------
local RIDING = { 11122, 25653 } -- Carrot on a Stick, Riding Crop
local READY = 30 -- seconds left that count as ready
local INTERVAL = 0.5 -- seconds between checks
local ticker, mounted

-- Adds item id to slot's rotation, or takes it off. Used by the swap list.
function ns.ToggleRotation(slot, id)
  local list = db.trinketQueue[slot]
  local i = tIndexOf(list, id)
  if i then table.remove(list, i) else list[#list + 1] = id end
end

-- Seconds left on item id's cooldown, worn in slot or in the bags.
local function Left(id, slot)
  if slot and GetInventoryItemID("player", slot) == id then
    return ns.CooldownLeft(GetInventoryItemCooldown("player", slot)) or 0
  end
  return ns.CooldownLeft(C_Item.GetItemCooldown(id)) or 0
end

-- Puts the first ready trinket on slot's list on, while the one worn is on
-- cooldown. The slot the mount swap holds is skipped while mounted.
local function Rotate(slot)
  local list = db.trinketQueue[slot]
  if db["rotate" .. slot .. "Off"] or #list == 0 or (mounted and slot == db.mountSlot) then return end
  local worn = GetInventoryItemID("player", slot)
  if worn and (not ns.HasUse(worn) or Left(worn, slot) <= READY) then return end
  for _, id in ipairs(list) do
    if id ~= worn and ns.FindInBags(id) and Left(id) <= READY then
      ns.Equip(id, slot)
      return
    end
  end
end

-- The riding trinket in the bags or worn, or nil.
local function RidingTrinket()
  for _, id in ipairs(RIDING) do
    if ns.FindInBags(id) or GetInventoryItemID("player", 13) == id or GetInventoryItemID("player", 14) == id then
      return id
    end
  end
end

-- On mounting, the riding trinket goes on (what it replaced is saved in
-- mountPrev); on getting off, that trinket goes back.
local function CheckMount()
  local now = IsMounted()
  if now == mounted then return end
  mounted = now
  if db.mountSwapOff then return end
  local slot, riding = db.mountSlot, RidingTrinket()
  if not riding then return end
  if now then
    local worn = GetInventoryItemID("player", slot)
    if worn ~= riding then
      db.mountPrev = worn or 0
      ns.Equip(riding, slot)
    end
  elseif db.mountPrev ~= 0 then
    if GetInventoryItemID("player", slot) == riding then ns.Equip(db.mountPrev, slot) end
    db.mountPrev = 0
  end
end

ns.On("PLAYER_REGEN_DISABLED", function() if ticker then ticker:Hide() end end)
ns.On("PLAYER_REGEN_ENABLED", function() if ticker then ticker:Show() end end)

function ns.BuildTrinketAuto()
  local elapsed = 0
  ticker = CreateFrame("Frame")
  ticker:SetShown(not UnitAffectingCombat("player"))
  ticker:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < INTERVAL then return end
    elapsed = 0
    CheckMount()
    Rotate(13)
    Rotate(14)
  end)
end
