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
--   mount swap   on mounting, your riding trinket goes in the chosen trinket
--                slot: The Desert Rose in sandy zones, otherwise Carrot on a
--                Stick or Riding Crop. Riding into or out of a sandy zone
--                swaps between them (or back to your own trinket when you
--                have no riding trinket for that zone). On getting off, the
--                one it replaced goes back. Until it is back, the rotation
--                leaves that trinket in the bags so it is there to go back.
--                A flight path doesn't count as mounting: nothing is swapped
--                while the flight map is open, while you fly, or for HOLD
--                seconds after either ends.
-- The game won't change gear in combat, and both only put items on: nothing
-- ever uses an item or casts for the player. In combat both queue their swap
-- instead (see ns.Equip): the slot shows it waiting and it goes on when combat
-- ends. Both are checked twice a second, as Forever Trinket Menu does. A
-- cooldown the game hides in combat is never read or worked around: the
-- rotation just waits until it can see it.
-- Events: TAXIMAP_OPENED, TAXIMAP_CLOSED (the flight map, see CheckMount)
-- SavedVariables: trinketQueue, rotate13Off, rotate14Off, mountSwapOff,
--   mountSlot, mountPrev (the trinket that belongs in the mount slot)
--------------------------------------------------------------------------------
local RIDING = { 11122, 25653 } -- Carrot on a Stick, Riding Crop
local DESERT_ROSE = 274648 -- mount speed in sandy zones only
-- Sandy zones by UiMapID: Tanaris, Silithus. Each zone is listed under both
-- its Mainline and its Classic map ID, as which one Forever uses is unconfirmed.
local SANDY = { [71] = true, [1446] = true, [81] = true, [1451] = true }
local READY = 30 -- seconds left that count as ready
local INTERVAL = 0.5 -- seconds between checks
local RETRY = 3 -- seconds between tries at a mount swap the game refused
local HOLD = 3 -- seconds the mount swap keeps waiting after a flight path or the flight map
local mounted, nextTry, taxiMap, taxiEnd

-- Adds item id to slot's rotation, or takes it off. Used by the swap list.
function ns.ToggleRotation(slot, id)
  local list = db.trinketQueue[slot]
  local i = tIndexOf(list, id)
  if i then table.remove(list, i) else list[#list + 1] = id end
end

-- Seconds left on item id's cooldown, worn in slot or in the bags, or nil
-- while the game hides it.
local function Left(id, slot)
  if slot and GetInventoryItemID("player", slot) == id then
    return ns.CooldownLeft(GetInventoryItemCooldown("player", slot))
  end
  return ns.CooldownLeft(C_Item.GetItemCooldown(id))
end

-- True when item id is one of the riding trinkets.
local function IsRiding(id)
  return id == DESERT_ROSE or tContains(RIDING, id)
end

-- Puts the first ready trinket on slot's list on (queued in combat), while
-- the one worn is on cooldown. Nothing changes while a swap already waits for
-- the slot, so a pick made by hand in combat is kept, and a trinket queued
-- for the other slot is skipped. While mounted, the slot the mount swap holds
-- is skipped. While a riding trinket is in that slot, the trinket that goes
-- back there is left in the bags, or the swap back would only trade the
-- riding trinket into the other slot.
local function Rotate(slot)
  local list = db.trinketQueue[slot]
  if db["rotate" .. slot .. "Off"] or #list == 0 or (mounted and slot == db.mountSlot) then return end
  if ns.QueuedItem(slot) then return end
  local worn = GetInventoryItemID("player", slot)
  local wornLeft = worn and Left(worn, slot)
  if worn and (not ns.HasUse(worn) or not wornLeft or wornLeft <= READY) then return end
  local held = not db.mountSwapOff and IsRiding(GetInventoryItemID("player", db.mountSlot)) and db.mountPrev
  local taken = ns.QueuedItem(slot == 13 and 14 or 13)
  for _, id in ipairs(list) do
    local left = id ~= worn and id ~= held and id ~= taken and ns.FindInBags(id) and Left(id)
    if left and left <= READY then
      ns.Equip(id, slot)
      return
    end
  end
end

-- True when item id is in the bags or worn as a trinket.
local function Owned(id)
  return ns.FindInBags(id) or GetInventoryItemID("player", 13) == id or GetInventoryItemID("player", 14) == id
end

-- True when the player is in a sandy zone, or in a subzone, cave or building
-- map inside one (the map's parents are checked).
local function InSand()
  local map = C_Map.GetBestMapForUnit("player")
  while map and map > 0 do
    if SANDY[map] then return true end
    local info = C_Map.GetMapInfo(map)
    map = info and info.parentMapID
  end
end

-- Starts a mount swap of item id into slot, out of combat only. The game
-- refuses gear swaps while you cast or channel (mining, crafting, both of
-- which also take you off the mount), loot or are dead, so it waits for those
-- to end and then goes at once. Any other refusal is tried again at most once
-- every RETRY seconds, so it doesn't fill the screen with errors.
local function Swap(id, slot)
  local now = GetTime()
  if UnitAffectingCombat("player") or UnitIsDeadOrGhost("player") or UnitCastingInfo("player") or UnitChannelInfo("player")
    or GetNumLootItems() > 0 or (nextTry and now < nextTry) then return end
  nextTry = now + RETRY
  ns.Equip(id, slot)
end

-- The riding trinket to wear here: The Desert Rose in sandy zones, else
-- Carrot on a Stick or Riding Crop. Nil when none is owned for this zone.
local function RidingTrinket()
  if InSand() and Owned(DESERT_ROSE) then return DESERT_ROSE end
  for _, id in ipairs(RIDING) do
    if Owned(id) then return id end
  end
end

-- mountPrev is the trinket that belongs in the mount slot: whatever other
-- than a riding trinket is worn there while you're not mounted, or when you
-- mount. It is never cleared by a failed swap, so a swap the game refused
-- can't leave the riding trinket on for good.
-- On mounting, the riding trinket for the zone goes on. While mounted,
-- crossing into or out of a sandy zone swaps to the right riding trinket, or
-- back to mountPrev when there is none for the zone; a trinket put on by hand
-- is left alone. Off the mount, while a riding trinket is in the slot,
-- mountPrev is put back, tried again until it takes (see Swap). In combat it
-- is queued instead, whenever nothing else waits for the slot: Charging off
-- the mount leaves it a moment before combat starts, so the first try can be
-- refused before the queue is used. A pick made by hand in the fight is never
-- overwritten, and it is tried again after combat if the queued swap fails.
-- On a flight path IsMounted() is true, and for a moment as the flight
-- starts or ends it can be true while UnitOnTaxi() is not yet (or no longer)
-- true. So the check waits while the flight map is open or you fly, and for
-- HOLD seconds after, leaving the mounted state as it was before the flight.
local function CheckMount()
  if taxiMap or UnitOnTaxi("player") then taxiEnd = GetTime() return end
  if taxiEnd and GetTime() - taxiEnd < HOLD then return end
  local now = IsMounted()
  local changed = now ~= mounted
  mounted = now
  if changed then nextTry = nil end -- first try at a new swap goes at once
  if db.mountSwapOff then return end
  local slot = db.mountSlot
  local worn = GetInventoryItemID("player", slot)
  if not IsRiding(worn) and (changed or not now) then db.mountPrev = worn or 0 end
  local prev = db.mountPrev
  if now then
    local want = RidingTrinket() or prev
    if want ~= 0 and worn ~= want and (IsRiding(worn) or (worn or 0) == prev) then
      Swap(want, slot)
    end
  elseif prev ~= 0 and IsRiding(worn) then
    if not UnitAffectingCombat("player") then
      Swap(prev, slot)
    elseif not ns.QueuedItem(slot) then
      ns.Equip(prev, slot)
    end
  end
end

ns.On("TAXIMAP_OPENED", function() taxiMap = true end)
ns.On("TAXIMAP_CLOSED", function()
  taxiMap = false
  taxiEnd = GetTime()
end)

function ns.BuildTrinketAuto()
  local elapsed = 0
  CreateFrame("Frame"):SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < INTERVAL then return end
    elapsed = 0
    CheckMount()
    Rotate(13)
    Rotate(14)
  end)
end
