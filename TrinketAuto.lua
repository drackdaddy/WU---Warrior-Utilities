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
-- The game won't change gear in combat, so both only swap out of combat, and
-- they only put items on: nothing ever uses an item or casts for the player.
-- Swaps that come due in combat wait for it to end (see ns.Equip). Mounting
-- and cooldowns are checked twice a second out of combat, as Forever Trinket
-- Menu does; cooldowns are plain values then.
-- Events: PLAYER_REGEN_DISABLED, PLAYER_REGEN_ENABLED
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
local ticker, mounted, nextTry

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

-- True when item id is one of the riding trinkets.
local function IsRiding(id)
  return id == DESERT_ROSE or tContains(RIDING, id)
end

-- Puts the first ready trinket on slot's list on, while the one worn is on
-- cooldown. While mounted, the slot the mount swap holds is skipped. While a
-- riding trinket is in that slot, the trinket that goes back there is left in
-- the bags, or the swap back would only trade the riding trinket into the
-- other slot.
local function Rotate(slot)
  local list = db.trinketQueue[slot]
  if db["rotate" .. slot .. "Off"] or #list == 0 or (mounted and slot == db.mountSlot) then return end
  local worn = GetInventoryItemID("player", slot)
  if worn and (not ns.HasUse(worn) or Left(worn, slot) <= READY) then return end
  local held = not db.mountSwapOff and IsRiding(GetInventoryItemID("player", db.mountSlot)) and db.mountPrev
  for _, id in ipairs(list) do
    if id ~= worn and id ~= held and ns.FindInBags(id) and Left(id) <= READY then
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

-- Starts a mount swap of item id into slot. The game refuses gear swaps while
-- you cast or channel (mining, crafting, both of which also take you off the
-- mount), loot or are dead, so it waits for those to end and then goes at
-- once. Any other refusal is tried again at most once every RETRY seconds, so
-- it doesn't fill the screen with errors.
local function Swap(id, slot)
  local now = GetTime()
  if UnitIsDeadOrGhost("player") or UnitCastingInfo("player") or UnitChannelInfo("player")
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
-- mountPrev is put back, tried again until it takes (see Swap).
local function CheckMount()
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
    Swap(prev, slot)
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
