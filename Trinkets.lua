local _, ns = ...
local db, LEM = ns.db, ns.LibEditMode

--------------------------------------------------------------------------------
-- Trinket and usable gear bars (warriors only)
-- Adapted from Forever Trinket Menu by sk0lu (MIT, see LICENSE-ForeverTrinketMenu.txt).
--   trinket bar  your two trinkets. Click (or the key bound in Esc > Key
--                Bindings > WU - Warrior Utilities) to use one; each shows its
--                cooldown and key.
--   gear bar     the other slots holding on-use gear (engineering helms,
--                cloaks, rings, weapons...), or that could from your bags.
--                Off by default.
--   swap list    hovering a slot lists the items in your bags that fit it
--                (and, for a trinket, the one in the other trinket slot).
--                Click one to put it on; Alt+click a trinket to add it to or
--                take it off that slot's rotation (see TrinketAuto.lua).
--   combat queue the game won't change gear in combat, so a pick made then
--                waits (gold border, with a small icon of the waiting item in
--                the bottom left corner) and goes on when combat ends.
-- The slot buttons are secure action buttons ("/use <slot>"): one click uses
-- the item once, and nothing ever uses one by itself. Secure buttons can't be
-- shown, hidden, moved or changed in combat, so the bars are laid out out of
-- combat only (a change in combat waits for it to end), and "only show in
-- combat" uses a state driver. Cooldowns go straight from the game to the
-- Cooldown widget, so they are never read. Each bar is moved and sized in
-- Edit Mode ("WU Trinket Bar", "WU Gear Bar"), or dragged while unlocked
-- (right-click the minimap icon; out of combat only, as moving the bars moves
-- secure buttons). A border style frames both bars.
-- Events: PLAYER_ENTERING_WORLD, PLAYER_REGEN_ENABLED, PLAYER_EQUIPMENT_CHANGED,
--   BAG_UPDATE_DELAYED, BAG_UPDATE_COOLDOWN, UPDATE_BINDINGS,
--   GET_ITEM_INFO_RECEIVED
-- SavedVariables: trinketOff, trinketMenuOff, trinketLayouts, trinketSize,
--   trinketCombatOnly, gearOff, gearLayouts, gearSize, gearCombatOnly,
--   trinketBorder
--------------------------------------------------------------------------------
local GEAR_SLOTS = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 16, 17, 18 } -- character sheet order
local EQUIP_LOC_SLOTS = { -- slots each kind of item goes in
  INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CHEST = { 5 },
  INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 },
  INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 },
  INVTYPE_CLOAK = { 15 }, INVTYPE_WEAPON = { 16, 17 }, INVTYPE_2HWEAPON = { 16 },
  INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_SHIELD = { 17 },
  INVTYPE_HOLDABLE = { 17 }, INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 },
}
local GAP = 4 -- pixels between buttons
local GOLD = { 1, 0.82, 0.2 }
local WHITE = "Interface\\Buttons\\WHITE8X8"
-- Border styles (see ns.LISTS.trinketBorder in Core.lua): pixels around the
-- buttons, the backdrop, and its edge and background colors.
local BORDERS = {
  thin = { pad = 2, edge = WHITE, size = 1, color = { 0, 0, 0, 1 } },
  panel = { pad = 4, edge = WHITE, size = 1, color = { 0.3, 0.3, 0.3, 1 }, bg = { 0, 0, 0, 0.6 } },
  tooltip = { pad = 6, edge = "Interface\\Tooltips\\UI-Tooltip-Border", size = 16, inset = 4,
    color = { 0.6, 0.6, 0.6, 1 }, bg = { 0, 0, 0, 0.8 } },
  gold = { pad = 3, edge = WHITE, size = 2, color = { GOLD[1], GOLD[2], GOLD[3], 1 } },
}
local queued = {} -- [slot] = item ID waiting for combat to end
local bars = {} -- trinket and gear: holder, settings prefix, buttons by slot, Place, border, mover
local menu, layoutWaiting, unlocked

--------------------------------------------------------------------------------
-- Items and swapping, shared with TrinketAuto.lua
--------------------------------------------------------------------------------

-- True when item id can go in slot.
local function Fits(id, slot)
  local loc = select(4, C_Item.GetItemInfoInstant(id))
  return tContains(EQUIP_LOC_SLOTS[loc] or {}, slot)
end

-- True when item id has a "Use:" effect.
function ns.HasUse(id)
  return id ~= nil and C_Item.GetItemSpell(id) ~= nil
end

-- Calls fn(id, bag, bagSlot) for every item in the bags.
local function EachBagItem(fn)
  for bag = 0, NUM_BAG_SLOTS do
    for i = 1, C_Container.GetContainerNumSlots(bag) do
      local id = C_Container.GetContainerItemID(bag, i)
      if id then fn(id, bag, i) end
    end
  end
end

-- Bag and slot of item id, or nil when it isn't in the bags.
function ns.FindInBags(id)
  local found, slot
  EachBagItem(function(i, bag, s)
    if i == id and not found then found, slot = bag, s end
  end)
  return found, slot
end

-- Seconds left on a cooldown (0 when ready or only on the global cooldown),
-- or nil while the game hides it.
function ns.CooldownLeft(start, duration)
  if issecretvalue(start) or issecretvalue(duration) then return end
  if not start or start == 0 or duration <= 1.5 then return 0 end
  return math.max(0, start + duration - GetTime())
end

local Refresh -- redraws the bars; set below

-- Puts item id into slot, from the bags or from the other slot it is worn
-- in. In combat it waits for combat to end. An item that would become bound
-- is only put on when the player picked it (byHand), through the game's own
-- question; automatic swaps skip it. If the game refuses, the item goes back.
-- Nothing happens while either item is still moving from the last swap.
function ns.Equip(id, slot, byHand)
  if UnitAffectingCombat("player") then
    queued[slot] = id
    Refresh()
    return
  end
  queued[slot] = nil
  if CursorHasItem() or IsInventoryItemLocked(slot) or GetInventoryItemID("player", slot) == id then return end
  local bag, bagSlot = ns.FindInBags(id)
  if bag then
    if C_Container.GetContainerItemInfo(bag, bagSlot).isLocked then return end
    if not C_Item.IsBound(ItemLocation:CreateFromBagAndSlot(bag, bagSlot)) then
      if byHand then C_Item.EquipItemByName(id, slot) end
      return
    end
    C_Container.PickupContainerItem(bag, bagSlot)
  else
    local worn = (slot == 13 and 14) or (slot == 14 and 13) or (slot == 11 and 12) or (slot == 12 and 11)
    if not worn or GetInventoryItemID("player", worn) ~= id then return end
    PickupInventoryItem(worn)
  end
  PickupInventoryItem(slot)
  if CursorHasItem() then ClearCursor() end
end

-- The items that can go in slot: from the bags, and for a ring or trinket the
-- one worn in the other slot. Each: id, and where it is worn (or nil).
local function Choices(slot)
  local list, seen = {}, {}
  local other = (slot == 13 and 14) or (slot == 14 and 13) or (slot == 11 and 12) or (slot == 12 and 11)
  if other and GetInventoryItemID("player", other) then
    local id = GetInventoryItemID("player", other)
    list[1], seen[id] = { id = id, worn = other }, true
  end
  EachBagItem(function(id)
    if not seen[id] and Fits(id, slot) then
      list[#list + 1], seen[id] = { id = id }, true
    end
  end)
  return list
end

-- The item whose swap into slot waits for combat to end, or nil.
function ns.QueuedItem(slot)
  return queued[slot]
end

-- Equips whatever is waiting for combat to end; used when it ends.
local function Flush()
  for slot, id in pairs(queued) do ns.Equip(id, slot) end
end

--------------------------------------------------------------------------------
-- Swap list
--------------------------------------------------------------------------------
local MENU_COLS = 4

-- Shows the swap list for slot button b, one icon per item that fits, or
-- hides it when there are none. Hidden once the mouse leaves both.
local function ShowMenu(b)
  local list = Choices(b.slot)
  if db.trinketMenuOff or #list == 0 then
    menu:Hide()
    return
  end
  local size = b:GetWidth()
  for i, item in ipairs(list) do
    local m = menu.items[i]
    if not m then
      m = CreateFrame("Button", nil, menu)
      m.icon = m:CreateTexture(nil, "ARTWORK")
      m.icon:SetAllPoints()
      m.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      m:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
      m.rank = m:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
      m.rank:SetPoint("TOPLEFT", 2, -2)
      m:SetScript("OnClick", function(self)
        if IsAltKeyDown() and (menu.slot == 13 or menu.slot == 14) then
          ns.ToggleRotation(menu.slot, self.id)
          ShowMenu(menu.owner)
        else
          ns.Equip(self.id, menu.slot, true)
          menu:Hide()
        end
      end)
      m:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(self.id)
        if menu.slot == 13 or menu.slot == 14 then
          GameTooltip:AddLine("Alt+click: add to or take off this slot's rotation.", 0.8, 0.8, 0.8, true)
        end
        GameTooltip:Show()
      end)
      m:SetScript("OnLeave", GameTooltip_Hide)
      menu.items[i] = m
    end
    m.id = item.id
    m.icon:SetTexture(C_Item.GetItemIconByID(item.id))
    local rank = (b.slot == 13 or b.slot == 14) and tIndexOf(db.trinketQueue[b.slot], item.id)
    m.rank:SetText(rank or "")
    m:SetSize(size, size)
    m:ClearAllPoints()
    m:SetPoint("TOPLEFT", 4 + ((i - 1) % MENU_COLS) * (size + GAP), -4 - math.floor((i - 1) / MENU_COLS) * (size + GAP))
    m:Show()
  end
  for i = #list + 1, #menu.items do menu.items[i]:Hide() end
  local cols, rows = math.min(#list, MENU_COLS), math.ceil(#list / MENU_COLS)
  menu:SetSize(8 + cols * size + (cols - 1) * GAP, 8 + rows * size + (rows - 1) * GAP)
  menu:ClearAllPoints()
  menu:SetPoint("BOTTOMLEFT", b, "TOPLEFT", -4, 2)
  menu.slot, menu.owner = b.slot, b
  menu:Show()
end

--------------------------------------------------------------------------------
-- Bars
--------------------------------------------------------------------------------

-- Secure button that uses the item in slot on a left click or its key, with
-- its icon, cooldown, key and, while a swap waits for combat, a gold border
-- with the waiting item's icon in the bottom left corner.
-- Hovering it opens the swap list. Named, so a key can be bound to it.
local function SlotButton(bar, slot)
  local b = CreateFrame("Button", "WUSlot" .. slot, bar.holder, "SecureActionButtonTemplate")
  b:RegisterForClicks("AnyUp", "AnyDown")
  b:SetAttribute("*type1", "macro")
  b:SetAttribute("*macrotext1", "/use " .. slot)
  b.slot = slot
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetAllPoints()
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
  b.cd:SetAllPoints()
  b.cd:SetHideCountdownNumbers(false)
  b.key = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray")
  b.key:SetPoint("TOPRIGHT", -2, -3)
  b.queued = CreateFrame("Frame", nil, b, "BackdropTemplate")
  b.queued:SetPoint("TOPLEFT", -2, 2)
  b.queued:SetPoint("BOTTOMRIGHT", 2, -2)
  b.queued:SetBackdrop({ edgeFile = WHITE, edgeSize = 2 })
  b.queued:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 1)
  b.queued:SetFrameLevel(b.cd:GetFrameLevel() + 2)
  b.queued.icon = b.queued:CreateTexture(nil, "OVERLAY")
  b.queued.icon:SetPoint("BOTTOMLEFT", 3, 3)
  b.queued.icon:SetPoint("TOPRIGHT", b, "CENTER")
  b.queued.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetInventoryItem("player", self.slot)
    GameTooltip:Show()
    ShowMenu(self)
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)
  bar.buttons[slot] = b
  return b
end

-- The slots bar shows: the trinkets, or the gear slots holding (or able to
-- hold, from the bags) an item with a "Use:" effect. A weapon slot brings the
-- other with it, so a set can be swapped.
local function BarSlots(bar)
  if bar.key == "trinket" then return { 13, 14 } end
  local usable = {}
  for _, slot in ipairs(GEAR_SLOTS) do
    if ns.HasUse(GetInventoryItemID("player", slot)) then usable[slot] = true end
  end
  EachBagItem(function(id)
    if ns.HasUse(id) then
      for _, slot in ipairs(EQUIP_LOC_SLOTS[select(4, C_Item.GetItemInfoInstant(id))] or {}) do
        if slot ~= 13 and slot ~= 14 then usable[slot] = true end
      end
    end
  end)
  if usable[16] or usable[17] then usable[16], usable[17] = true, true end
  local slots = {}
  for _, slot in ipairs(GEAR_SLOTS) do
    if usable[slot] then slots[#slots + 1] = slot end
  end
  return slots
end

-- Lays out bar's buttons and sets when it shows. Secure frames can't change
-- in combat, so then it waits for combat to end. In Edit Mode it always
-- shows (faded when off) so it can be placed.
local function Layout(bar)
  if InCombatLockdown() then
    layoutWaiting = true
    return
  end
  local size, slots = db[bar.key .. "Size"], BarSlots(bar)
  for _, b in pairs(bar.buttons) do b:Hide() end
  for i, slot in ipairs(slots) do
    local b = bar.buttons[slot] or SlotButton(bar, slot)
    b:SetSize(size, size)
    b:ClearAllPoints()
    b:SetPoint("LEFT", (i - 1) * (size + GAP), 0)
    b:Show()
  end
  local n = math.max(#slots, 1)
  bar.holder:SetSize(n * size + (n - 1) * GAP, size)
  local off, edit = db[bar.key .. "Off"], LEM:IsInEditMode()
  UnregisterStateDriver(bar.holder, "visibility")
  if edit or not off and not db[bar.key .. "CombatOnly"] then
    bar.holder:Show()
  elseif off then
    bar.holder:Hide()
  else
    RegisterStateDriver(bar.holder, "visibility", "[combat] show; hide")
  end
  bar.holder:SetAlpha(edit and off and 0.4 or 1)
end

-- Redraws every shown button: icon (empty slots greyed), cooldown, bound key
-- and the item whose swap waits, if any. Doesn't touch secure attributes or layout.
Refresh = function()
  for _, bar in ipairs(bars) do
    for slot, b in pairs(bar.buttons) do
      b.icon:SetTexture(GetInventoryItemTexture("player", slot) or 136528)
      b.icon:SetDesaturated(not GetInventoryItemID("player", slot))
      local start, duration = GetInventoryItemCooldown("player", slot)
      b.cd:SetCooldown(start, duration)
      b.key:SetText(GetBindingText(GetBindingKey("CLICK WUSlot" .. slot .. ":LeftButton") or "", true))
      b.queued:SetShown(queued[slot] ~= nil)
      if queued[slot] then b.queued.icon:SetTexture(C_Item.GetItemIconByID(queued[slot])) end
    end
  end
end

local function LayoutAll()
  for _, bar in ipairs(bars) do Layout(bar) end
  Refresh()
end

ns.On("PLAYER_ENTERING_WORLD", function() if menu then LayoutAll() end end)
ns.On("PLAYER_REGEN_DISABLED", function()
  if not unlocked then return end
  unlocked = nil
  for _, bar in ipairs(bars) do
    bar.holder:StopMovingOrSizing()
    bar.mover:Hide()
  end
end)
ns.On("PLAYER_REGEN_ENABLED", function()
  if not menu then return end
  Flush()
  if layoutWaiting then
    layoutWaiting = nil
    LayoutAll()
  end
end)
ns.On("PLAYER_EQUIPMENT_CHANGED", function() if menu then LayoutAll() end end)
ns.On("BAG_UPDATE_DELAYED", function() if menu then LayoutAll() end end)
ns.On("GET_ITEM_INFO_RECEIVED", function() if menu then LayoutAll() end end)
ns.On("BAG_UPDATE_COOLDOWN", function() if menu then Refresh() end end)
ns.On("UPDATE_BINDINGS", function() if menu then Refresh() end end)

-- Applies every trinket and gear bar setting; used when built, after a
-- change on the options page and after /wu reset.
-- Frames bar in the chosen border style, or none.
local function Border(bar)
  local b = BORDERS[db.trinketBorder]
  bar.border:SetShown(b ~= nil)
  if not b then return end
  bar.border:SetPoint("TOPLEFT", -b.pad, b.pad)
  bar.border:SetPoint("BOTTOMRIGHT", b.pad, -b.pad)
  local inset = b.inset or 0
  bar.border:SetBackdrop({ bgFile = WHITE, edgeFile = b.edge, edgeSize = b.size,
    insets = { left = inset, right = inset, top = inset, bottom = inset } })
  bar.border:SetBackdropBorderColor(unpack(b.color))
  bar.border:SetBackdropColor(unpack(b.bg or { 0, 0, 0, 0 }))
end

-- Lets the bars be dragged (unlocked) or not, out of combat only: moving them
-- moves secure buttons. While unlocked a cover over each bar takes the mouse,
-- so a click moves it instead of using an item. A dropped bar's spot is
-- saved for the active Edit Mode layout, as if moved there. Used by the
-- minimap icon's right-click; combat starting locks them.
function ns.ToggleTrinketLock()
  if InCombatLockdown() then
    print("WU - Warrior Utilities: the trinket bars can't be moved in combat.")
    return
  end
  unlocked = not unlocked
  for _, bar in ipairs(bars) do bar.mover:SetShown(unlocked) end
  print("WU - Warrior Utilities: trinket bars " .. (unlocked and "unlocked: drag them to move them." or "locked."))
end

-- Moving the bars moves secure buttons, so in combat it waits.
function ns.RefreshTrinkets()
  for _, bar in ipairs(bars) do Border(bar) end
  if InCombatLockdown() then
    layoutWaiting = true
    return
  end
  for _, bar in ipairs(bars) do bar.Place() end
  LayoutAll()
end

function ns.BuildTrinkets()
  menu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  menu:SetFrameStrata("DIALOG")
  menu:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
  menu:SetBackdropColor(0, 0, 0, 0.85)
  menu:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
  menu:Hide()
  menu.items = {}
  menu:SetScript("OnUpdate", function(self)
    if not self:IsMouseOver() and not (self.owner and self.owner:IsMouseOver()) then self:Hide() end
  end)

  local T, Option = LEM.SettingType, ns.EditModeOption
  for _, info in ipairs({
    { key = "trinket", name = "WU Trinket Bar", y = -350 },
    { key = "gear", name = "WU Gear Bar", y = -395 },
  }) do
    local bar = { key = info.key, buttons = {} }
    bar.holder = CreateFrame("Frame", nil, UIParent)
    bar.holder:SetClampedToScreen(true)
    bar.holder:SetMovable(true)
    bar.border = CreateFrame("Frame", nil, bar.holder, "BackdropTemplate")
    bar.border:SetFrameLevel(math.max(bar.holder:GetFrameLevel() - 1, 0))
    bar.mover = CreateFrame("Frame", nil, bar.holder)
    bar.mover:SetAllPoints()
    bar.mover:SetFrameLevel(bar.holder:GetFrameLevel() + 20)
    bar.mover:EnableMouse(true)
    bar.mover:RegisterForDrag("LeftButton")
    bar.mover:Hide()
    local shade = bar.mover:CreateTexture(nil, "OVERLAY")
    shade:SetAllPoints()
    shade:SetColorTexture(0.2, 0.6, 1, 0.35)
    local holder, key = bar.holder, info.key
    bar.mover:SetScript("OnDragStart", function() holder:StartMoving() end)
    bar.mover:SetScript("OnDragStop", function()
      holder:StopMovingOrSizing()
      local layout = LEM:GetActiveLayoutName()
      local x, y = holder:GetCenter()
      local cx, cy = UIParent:GetCenter()
      if layout then db[key .. "Layouts"][layout] = { point = "CENTER", x = x - cx, y = y - cy } end
      bar.Place()
    end)
    local function Apply() LayoutAll() end
    bar.Place = ns.AddEditModeFrame(bar.holder, info.key .. "Layouts", { point = "CENTER", x = 0, y = info.y },
      info.name, {
        Option(T.Slider, "Icon Size", info.key .. "Size", Apply, nil, { minValue = 24, maxValue = 64, valueStep = 2 }),
        Option(T.Checkbox, "Only Show in Combat", info.key .. "CombatOnly", Apply),
      }, Apply)
    bars[#bars + 1] = bar
  end
  ns.RefreshTrinkets()
end

BINDING_HEADER_WU = "WU - Warrior Utilities"
_G["BINDING_NAME_CLICK WUSlot13:LeftButton"] = "Use Trinket 1"
_G["BINDING_NAME_CLICK WUSlot14:LeftButton"] = "Use Trinket 2"
