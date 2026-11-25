local _, ns = ...
local db, LEM = ns.db, ns.LibEditMode

--------------------------------------------------------------------------------
-- Custom bar (warriors only)
-- A row of icons for cooldowns the player picks on the Custom tab under CDM:
-- spells by spell ID and items (such as trinkets) by item ID, in the order
-- set there. Each icon shows Blizzard's cooldown swipe and countdown. The
-- icons and their look come from CooldownLook.lua, which never reads
-- cooldown times: spells get the ready glow (unless turned off for that
-- entry) and the on-cooldown look; items only the swipe, as the game gives
-- no duration object for them. The icons have no mouse input and never cast
-- or use anything.
-- Moved and set up in Edit Mode as "WU Custom Bar" (icon size, only show in
-- combat). In Edit Mode it always shows, faded when off or empty, so it can
-- be placed.
-- Events: PLAYER_ENTERING_WORLD, PLAYER_REGEN_DISABLED, PLAYER_REGEN_ENABLED,
--   SPELL_UPDATE_COOLDOWN, BAG_UPDATE_COOLDOWN, ITEM_DATA_LOAD_RESULT
-- SavedVariables: customOff, customList (entries: kind ("spell" or "item"),
--   id, off (left off the bar), noGlow, glowStyle (its own glow type)),
--   customLayouts, customSize, customCombatOnly
--------------------------------------------------------------------------------
local GAP = 4 -- pixels between icons
local DEFAULT_POS = { point = "CENTER", x = 0, y = -305 }
ns.CUSTOM_MAX = 12 -- most entries the list holds
local holder, PlacePosition
local icons, count = {}, 0 -- icon frames (reused) and how many are in use

-- Name and icon of a custom entry ({ kind = "spell" or "item", id }); either
-- can be nil while an item's data hasn't loaded. Used by the bar and the
-- options page.
function ns.CustomInfo(e)
  if e.kind == "item" then
    return C_Item.GetItemNameByID(e.id), C_Item.GetItemIconByID(e.id)
  end
  return C_Spell.GetSpellName(e.id), C_Spell.GetSpellTexture(e.id)
end

-- Hands each icon's cooldown to its swipe and glow (see CooldownLook.lua).
local function UpdateCooldowns()
  for i = 1, count do ns.UpdateIconCooldown(icons[i]) end
end

-- Lays out an icon per entry, sizes the bar to fit and shows or hides it.
local function Update()
  if not holder then return end -- not built (druids)
  count = 0
  for _, e in ipairs(db.customList) do
    if not e.off then
      local _, tex = ns.CustomInfo(e)
      tex = tex or 134400 -- question mark until an item's data loads
      count = count + 1
      icons[count] = icons[count] or ns.NewCooldownIcon(holder)
      local f = icons[count]
      f.spell = e.kind == "spell" and e.id or nil
      f.item = e.kind == "item" and e.id or nil
      ns.SetIconGlow(f, f.spell ~= nil and not e.noGlow, e.glowStyle)
      f.tex:SetTexture(tex)
      f.cdGrey.tex:SetTexture(tex)
      f.noRage.tex:SetTexture(tex)
      f:SetSize(db.customSize, db.customSize)
      f:ClearAllPoints()
      f:SetPoint("LEFT", (count - 1) * (db.customSize + GAP), 0)
      f:Show()
    end
  end
  for i = count + 1, #icons do icons[i]:Hide() end

  local n = math.max(count, 1) -- keeps one icon's room in Edit Mode
  holder:SetSize(n * db.customSize + (n - 1) * GAP, db.customSize)
  holder:SetShown(LEM:IsInEditMode() or not db.customOff and count > 0
    and (not db.customCombatOnly or UnitAffectingCombat("player")))
  holder:SetAlpha((db.customOff or count == 0) and 0.4 or 1)
  UpdateCooldowns()
end

ns.On("PLAYER_ENTERING_WORLD", Update)
ns.On("PLAYER_REGEN_DISABLED", Update)
ns.On("PLAYER_REGEN_ENABLED", Update)
ns.On("ITEM_DATA_LOAD_RESULT", Update)
local function Cooldowns() if holder and holder:IsShown() then UpdateCooldowns() end end
ns.On("SPELL_UPDATE_COOLDOWN", Cooldowns)
ns.On("BAG_UPDATE_COOLDOWN", Cooldowns)

-- Applies every custom bar setting; used when built, after a change on the
-- options page and after /wu reset.
function ns.RefreshCustom()
  PlacePosition()
  Update()
end

function ns.BuildCustomBar()
  holder = CreateFrame("Frame", nil, UIParent)
  holder:SetClampedToScreen(true)
  local T, Option = LEM.SettingType, ns.EditModeOption
  PlacePosition = ns.AddEditModeFrame(holder, "customLayouts", DEFAULT_POS, "WU Custom Bar", {
    Option(T.Slider, "Icon Size", "customSize", Update, nil, { minValue = 24, maxValue = 64, valueStep = 2 }),
    Option(T.Checkbox, "Only Show in Combat", "customCombatOnly", Update),
  }, Update)
  ns.RefreshCustom()
end
