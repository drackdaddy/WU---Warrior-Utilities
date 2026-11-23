local _, ns = ...
local db, LEM = ns.db, ns.LibEditMode

--------------------------------------------------------------------------------
-- Range display (warriors only)
-- Adapted from Good Range by Andrii Zolotarenko (MIT, see
-- LICENSE-GoodRange.txt). Shows the distance to the target, coloured by what
-- the warrior can do from there: green melee (0-5 yd), blue Charge, Intercept,
-- Throw or Shoot while usable right now (enough rage, the right stance and
-- weapon, off cooldown), red a dead zone between them, grey out of range. The
-- zones can instead be set by hand (Zones on the Range tab), and their colours
-- changed. Friendly players, when turned on, are grey all the way ("FRIENDLY"):
-- a warrior has no heals or buffs to reach them with.
-- Where it shows: on the screen (moved in Edit Mode as "WU Range Display"), on
-- the target's nameplate, or both. Nameplate only falls back to the screen
-- while the target has no nameplate. Optional small labels show the distance
-- to the focus (moved in Edit Mode as "WU Range Focus", or over the focus's
-- nameplate when nameplates are used) and to the unit under the mouse (beside
-- the cursor).
-- How the distance is found: the game only answers "in range or not" for
-- items, interact distances and the player's own spells, each at a fixed
-- range. Those answers are range steps; a unit lies between the largest step
-- reported out and the smallest reported in. Each tick checks only the two
-- steps around the last bracket, rescanning wider when an edge changes, and
-- the estimator (RangeEstimator.lua) turns the brackets into a smooth
-- distance. Answers the game hides in combat (secret values) are skipped,
-- never read; on friendly players in combat the game allows no item or
-- interact checks, so only spells answer. With no answer it says "no data".
-- It only reads range answers and never casts or targets anything.
-- Ticks run about 30 times a second while something is shown, 10 while the
-- player and every followed unit stand still, and stop when nothing is shown.
-- Debug commands (/wu range list | stats | clear, see ns.RangeCommand) print
-- the range steps and the estimate's measured error to the chat frame.
-- Events: PLAYER_TARGET_CHANGED, PLAYER_FOCUS_CHANGED, UPDATE_MOUSEOVER_UNIT,
--   NAME_PLATE_UNIT_ADDED, NAME_PLATE_UNIT_REMOVED, PLAYER_REGEN_DISABLED,
--   PLAYER_REGEN_ENABLED, SPELLS_CHANGED, GET_ITEM_INFO_RECEIVED,
--   UNIT_INVENTORY_CHANGED (player)
-- SavedVariables: rangeOff, rangeOocOff, rangeFriendlyOff, rangeLook,
--   rangeTextFont, rangeSize, rangeWidth, rangeHeight, rangeScale,
--   rangeUnitOff, rangeOpacity, rangeLayouts, rangePlace, rangePlateY,
--   rangePlateScale, rangeFocusOff, rangeMouseOff, rangeLabelScale,
--   rangeFocusLayouts, rangeAutoOff, rangeZone1, rangeZone2, rangeZone3,
--   rangeColorPrimary, rangeColorSecondary, rangeColorDead, rangeColorFar
--------------------------------------------------------------------------------
local Estimator, Tape, Label = ns.Estimator, ns.RangeTape, ns.RangeLabel
local TICK = 0.03 -- s between ticks
local IDLE_TICK, IDLE_SLOW = 0.1, 4 -- standing still: tick this often, scan this many times as rarely
local WINDOW_EVERY, FULL_EVERY, SCAN_MIN = 0.2, 0.5, 0.05 -- s between scans (see Measure)
local ZONE_EVERY = 0.25 -- s between zone refreshes (rage, stance and cooldowns change them)
local MELEE = 5
local MAX_STEP = 100 -- a spell reaching further ("anywhere") can't bound a bracket
local SAMPLE, SAMPLE_LABEL = 21.4, "21" -- shown in Edit Mode without a target
local DEFAULT_POS = { point = "CENTER", x = 0, y = 110 }
local FOCUS_POS = { point = "CENTER", x = 0, y = 66 }

-- Range-check items by range in yd, from LibRangeCheck-3.0 (MIT) via Good
-- Range, for enemies and for friends: Classic items first, then later ones the
-- client may also know. Only items whose data the client has loaded are used.
local HARM_ITEMS = {
  [2] = { 168948, 194718 }, [3] = { 42732, 200469 }, [4] = { 129055 },
  [5] = { 8149, 15826, 16308, 17117, 22259 }, [6] = { 164766, 219525 },
  [7] = { 61323, 62899, 63350, 153249 }, [8] = { 33278, 34368, 35943, 37932 }, [9] = { 212453 },
  [10] = { 9606, 9618, 9619, 9620 }, [12] = { 208068 }, [15] = { 4559, 30651, 30652, 30653, 30654 },
  [20] = { 1191, 2012, 4388, 10645, 13892 }, [25] = { 13289, 24268, 31463, 32408 },
  [30] = { 835, 1404, 1434, 1444, 4479 }, [35] = { 1258, 1399, 1402, 8688, 18904, 24269, 24501, 35121 },
  [38] = { 140786 }, [40] = { 4945, 8348, 191414, 208773, 28767, 33581, 34255 },
  [45] = { 221316, 23836, 28369, 32698, 34691 }, [46] = { 202610 },
  [50] = { 116139, 129372, 134836, 147017 }, [55] = { 74637 }, [60] = { 32825, 34111, 34121, 37877 },
  [70] = { 41265, 202642 }, [75] = { 185949 }, [80] = { 35278, 35506, 42769, 49596 }, [90] = { 133925 },
  [100] = { 5418, 17162, 23715, 23718, 33119, 41058, 44212, 83134 },
}
local FRIEND_ITEMS = {
  [2] = { 168948, 194718 }, [3] = { 42732, 200469 }, [4] = { 129055 },
  [5] = { 1970, 8149, 15826, 16308, 16991 }, [6] = { 164766, 219525 },
  [7] = { 61323, 62899, 63350, 88589 }, [8] = { 33278, 34368, 35943, 37932 },
  [10] = { 17626, 17689, 21267, 23164, 22962 }, [12] = { 208068 }, [15] = { 1251, 2581, 3530, 3531 },
  [20] = { 12450, 12451, 12455, 12457, 17757, 21519, 22473, 23394 }, [25] = { 13289, 31463, 34979, 46885 },
  [30] = { 954, 955, 1180, 1181 }, [35] = { 18904, 24501, 35121, 41505 }, [38] = { 140786 },
  [40] = { 1713, 5205, 5323, 8346, 5232 }, [45] = { 221316, 28369, 32698, 34691, 49647 }, [46] = { 219320 },
  [50] = { 221315, 110009, 116139, 147006, 147007 }, [55] = { 74637 }, [60] = { 32825, 34111, 34121, 37877 },
  [70] = { 41265, 202642 }, [80] = { 35278, 35506, 42769, 50031 }, [90] = { 133925 },
  [100] = { 5418, 17162, 23715, 23718, 41058, 44212, 83134, 109082 },
}
-- CheckInteractDistance index -> range in yd (Tauren and Undead reach a little less).
local INTERACT = { [3] = 8, [4] = 28 }
local INTERACT_RACE = { Tauren = { [3] = 6, [4] = 25 }, Scourge = { [3] = 7, [4] = 27 } }

-- Automatic blue zones: badge, fallback range (used when the game reports
-- none) and the rank 1 spells that give it.
local ZONE_SPELLS = {
  { "CHARGE", 8, 25, { 100, 20252 } }, -- Charge, Intercept
  { "THROW", 8, 30, { 2764 } },
  { "SHOOT", 8, 30, { 2480, 7918, 7919 } }, -- Shoot Bow, Gun, Crossbow
}
-- Zones set by hand, in a row from 0 yd: the setting holding where each ends,
-- its kind and badge. A zone ending where the one before it ends is left out.
local OWN_ZONES = {
  { "rangeZone1", "primary", "MELEE" },
  { "rangeZone2", "dead", "DEAD ZONE" },
  { "rangeZone3", "secondary", "RANGED" },
}
-- A friendly player: grey all the way, as nothing of a warrior's reaches them.
local FRIEND_ONLY = { { 0, math.huge, "far", "FRIENDLY" } }

local holder, screenTape, plateTape, focusHolder, focusLabel, mouseLabel, ticker
local tapes -- { screenTape, plateTape }
local PlaceScreen, PlaceFocus -- move the screen display and focus label to their Edit Mode spots
local groups = {} -- range steps, ascending: { range, harmItem, friendItem, interact, spells, minSpells }
local known = {} -- spell name -> the spell ID the player knows
local loading = {} -- [item ID] = true: data asked for, not loaded yet
local info = {} -- spell ID -> C_Spell.GetSpellInfo, until the spells change
local secrets = { spell = 0, item = 0 } -- hidden answers counted, for /wu range list
local hostileSpans, spanKey = {}, nil -- the zones on enemies now: { from, to, kind, badge }
local targetHostile = true
local targetOn, focusOn, mouseOn -- which units are followed (see UpdateShown)
local plate -- the target's nameplate the nameplate display is on, if any
local idle -- the player and every followed unit stood still at the last tick
local clock, acc, zoneClock = 0, 0, 0
-- What the tapes slide towards (goal, goalLabel), how fast it moves on between
-- ticks, and what they show now.
local goal, goalLabel, goalRate, goalLo, goalHi, sinceTick, shown = nil, nil, 0, 0, nil, 0, nil
local noData = false

local function SpellInfo(id)
  if info[id] == nil then info[id] = C_Spell.GetSpellInfo(id) or false end
  return info[id] or nil
end

--------------------------------------------------------------------------------
-- Trackers: one per followed unit, with its last bracket and its estimate.
-- res[i] is step i's last answer, loIdx / hiIdx the steps at the bracket's
-- edges, lastLo / lastHi the bracket itself.
--------------------------------------------------------------------------------

-- Forgets tr's last bracket, so its next tick scans every step.
local function Forget(tr)
  wipe(tr.res)
  tr.loIdx, tr.hiIdx, tr.lastLo, tr.lastHi = nil, nil, 0, nil
  tr.nextWindow, tr.nextFull, tr.lastScan = 0, 0, -1
end

local function Tracker(unit)
  local tr = { unit = unit, est = Estimator.new(), res = {} }
  Forget(tr)
  return tr
end
local T, F, M = Tracker("target"), Tracker("focus"), Tracker("mouseover")
local trackers = { T, F, M }

--------------------------------------------------------------------------------
-- Range steps
--------------------------------------------------------------------------------

-- The step for range, created when missing.
local function Group(range)
  for _, g in ipairs(groups) do
    if g.range == range then return g end
  end
  local g = { range = range, spells = {} }
  groups[#groups + 1] = g
  return g
end

-- The first of ids whose item data is loaded; asks the client to load the rest
-- (when one arrives, GET_ITEM_INFO_RECEIVED rebuilds the steps).
local function PickItem(ids)
  for _, id in ipairs(ids) do
    if C_Item.IsItemDataCachedByID(id) and C_Item.GetItemInfo(id) then return id end
    loading[id] = true
    C_Item.RequestLoadItemDataByID(id)
  end
end

-- Rebuilds the range steps from the items, interact distances and the active
-- spells in the spellbook. A spell with a minimum range (Charge, Throw) says
-- "out" up close too, so it can't bound a bracket by its reach: its minimum is
-- a step of its own instead (see Check).
local function BuildSteps()
  wipe(groups)
  wipe(known)
  wipe(info)
  wipe(loading)
  for range, ids in pairs(HARM_ITEMS) do Group(range).harmItem = PickItem(ids) end
  for range, ids in pairs(FRIEND_ITEMS) do Group(range).friendItem = PickItem(ids) end
  for index, range in pairs(INTERACT_RACE[select(2, UnitRace("player"))] or INTERACT) do
    Group(range).interact = index
  end

  local bank = Enum.SpellBookSpellBank.Player
  for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
    local lineInfo = C_SpellBook.GetSpellBookSkillLineInfo(line)
    if lineInfo and not lineInfo.shouldHide then
      for i = lineInfo.itemIndexOffset + 1, lineInfo.itemIndexOffset + lineInfo.numSpellBookItems do
        local item = C_SpellBook.GetSpellBookItemInfo(i, bank)
        local s = item and item.itemType == Enum.SpellBookItemType.Spell and not item.isPassive
          and item.spellID and SpellInfo(item.spellID)
        if s then
          known[s.name] = item.spellID
          local min, max = s.minRange or 0, s.maxRange or 0
          if max > MAX_STEP then max = 0 end
          if max > 0 and min == 0 then table.insert(Group(max).spells, item.spellID) end
          if max > min and min > MELEE then
            local g = Group(min)
            g.minSpells = g.minSpells or {}
            table.insert(g.minSpells, { item.spellID, max })
          end
        end
      end
    end
  end

  for i = #groups, 1, -1 do
    local g = groups[i]
    if not g.harmItem and not g.friendItem and not g.interact and #g.spells == 0 and not g.minSpells then
      table.remove(groups, i)
    end
  end
  table.sort(groups, function(a, b) return a.range < b.range end)
  for _, tr in ipairs(trackers) do Forget(tr) end
end

local Check

-- True if any step above g, up to max yd, says the enemy unit is in range.
local function Within(g, max, unit)
  for _, o in ipairs(groups) do
    if o.range > g.range and o.range <= max and Check(o, unit, true) == true then return true end
  end
  return false
end

-- Step g's answer for unit: true (in), false (out) or nil (none), plus what
-- gave it and its ID (for /wu range list). hostile: unit is an enemy.
-- restricted: the game allows no item or interact checks now (a friend in
-- combat). A min-range spell answers first at its minimum: in range means past
-- the minimum; out of range means inside it if a step up to its reach says the
-- enemy is that close. Secret answers are counted and skipped.
function Check(g, unit, hostile, restricted)
  if hostile and g.minSpells then
    for _, m in ipairs(g.minSpells) do
      local v = C_Spell.IsSpellInRange(m[1], unit)
      if issecretvalue(v) then
        secrets.spell = secrets.spell + 1
      elseif v == true then
        return false, "min-range spell", m[1]
      elseif v == false and Within(g, m[2], unit) then
        return true, "min-range spell", m[1]
      end
    end
  end
  local item
  if hostile then item = g.harmItem else item = g.friendItem end
  if item and not restricted then
    local v = C_Item.IsItemInRange(item, unit)
    if issecretvalue(v) then
      secrets.item = secrets.item + 1
    else
      return v == true, "item", item
    end
  end
  if g.interact and not restricted then
    local v = CheckInteractDistance(unit, g.interact)
    if not issecretvalue(v) then return v and true or false, "interact", g.interact end
  end
  for _, id in ipairs(g.spells) do
    local v = C_Spell.IsSpellInRange(id, unit)
    if issecretvalue(v) then
      secrets.spell = secrets.spell + 1
    elseif v ~= nil then
      return v, "spell", id
    end
  end
end

-- Checks steps from..to for tr. Returns lo (the largest step out below hi), hi
-- (the smallest step in) and their indexes. The target's answers are kept on
-- the steps for /wu range list.
local function Scan(tr, hostile, restricted, from, to)
  local res, hi, hiI = tr.res, nil, nil
  for i = from, to do
    local g = groups[i]
    local r, why, id = Check(g, tr.unit, hostile, restricted)
    res[i] = r
    if tr == T then g.result, g.why, g.whyId = r, why, id end
    if r == true and not hi then hi, hiI = g.range, i end
  end
  local lo, loI = 0, nil
  for i = from, to do
    local r = groups[i].range
    if res[i] == false and (not hi or r < hi) and r > lo then lo, loI = r, i end
  end
  return lo, hi, loI, hiI
end

-- Scans the steps around tr's last bracket, or all of them every FULL_EVERY s
-- or when the answer could lie outside that window.
local function Rescan(tr, hostile, restricted)
  local n = #groups
  if clock < tr.nextFull and (tr.loIdx or tr.hiIdx) then
    local from, to = math.max(1, (tr.loIdx or 1) - 1), math.min(n, (tr.hiIdx or n) + 1)
    local lo, hi, loI, hiI = Scan(tr, hostile, restricted, from, to)
    if not ((not hi and to < n) or (hiI == from and from > 1) or (not loI and from > 1)) then
      tr.loIdx, tr.hiIdx = loI, hiI
      return lo, hi
    end
  end
  local lo, hi, loI, hiI = Scan(tr, hostile, restricted, 1, n)
  tr.loIdx, tr.hiIdx = loI, hiI
  tr.nextFull = clock + FULL_EVERY * (idle and IDLE_SLOW or 1)
  return lo, hi
end

-- tr's bracket now. Each tick checks only its two edge steps; the steps around
-- them are scanned when an edge changes and every WINDOW_EVERY s, but never
-- sooner than SCAN_MIN s after the last scan.
local function Measure(tr, hostile)
  local restricted = InCombatLockdown() and not hostile
  local unit = tr.unit
  if (tr.loIdx or tr.hiIdx) and clock < tr.nextWindow
      and (not tr.loIdx or Check(groups[tr.loIdx], unit, hostile, restricted) == false)
      and (not tr.hiIdx or Check(groups[tr.hiIdx], unit, hostile, restricted) == true) then
    return tr.lastLo, tr.lastHi
  end
  if clock - tr.lastScan < SCAN_MIN then return tr.lastLo, tr.lastHi end
  tr.lastScan, tr.nextWindow = clock, clock + WINDOW_EVERY * (idle and IDLE_SLOW or 1)
  tr.lastLo, tr.lastHi = Rescan(tr, hostile, restricted)
  return tr.lastLo, tr.lastHi
end

--------------------------------------------------------------------------------
-- Zones
--------------------------------------------------------------------------------

-- True unless the game says the spell can't be used now (secret counts as usable).
local function Usable(id)
  local ok = C_Spell.IsSpellUsable(id)
  return issecretvalue(ok) or ok
end

-- True when the spell is off cooldown (the global cooldown and secret count as ready).
local function Ready(id)
  local cd = C_Spell.GetSpellCooldown(id)
  if not cd or issecretvalue(cd.startTime) or issecretvalue(cd.duration) then return true end
  return cd.startTime == 0 or cd.duration <= 1.5 or cd.startTime + cd.duration - GetTime() <= 0.2
end

-- d in yd -> kind, badge, from spans. The first span that covers d wins; a gap
-- below the furthest reach is the dead zone, beyond it is out of range.
local function ZoneAt(d, spans)
  local reach = 0
  for _, s in ipairs(spans) do
    if d >= s[1] and d <= s[2] then return s[3], s[4] end
    if s[2] > reach then reach = s[2] end
  end
  if d < reach then return "dead", "DEAD ZONE" end
  return "far", "OUT OF RANGE"
end

-- The zones on enemies: melee, then whatever blue zone the warrior can use now.
local function AutoZones()
  local out, seen = { { 0, MELEE, "primary", "MELEE" } }, {}
  for _, z in ipairs(ZONE_SPELLS) do
    for _, base in ipairs(z[4]) do
      local b = SpellInfo(base)
      local id = b and known[b.name]
      if id and Usable(id) and Ready(id) then
        local s = SpellInfo(id)
        local min, max = z[2], z[3]
        if s and s.maxRange > MELEE then min, max = s.minRange, s.maxRange end
        local key = min .. "," .. max .. "," .. z[1]
        if not seen[key] then
          seen[key] = true
          out[#out + 1] = { min, max, "secondary", z[1] }
        end
      end
    end
  end
  return out
end

-- The zones set by hand (see OWN_ZONES).
local function OwnZones()
  local out, from = {}, 0
  for _, z in ipairs(OWN_ZONES) do
    local to = db[z[1]]
    if to > from then out[#out + 1] = { from, to, z[2], z[3] } end
    from = math.max(from, to)
  end
  return out
end

local function TargetZoneAt(d)
  return ZoneAt(d, targetHostile and hostileSpans or FRIEND_ONLY)
end

-- Hands the target's zones to both tapes, which restyles them.
local function SetTargetZones()
  for _, tp in ipairs(tapes) do tp:SetZones(TargetZoneAt) end
end

-- Rebuilds the enemy zones (automatic or set by hand) and restyles the tapes
-- when they changed.
local function RefreshZones()
  local new = db.rangeAutoOff and OwnZones() or AutoZones()
  local parts = {}
  for _, s in ipairs(new) do parts[#parts + 1] = table.concat(s, ",") end
  local key = table.concat(parts, ";")
  if key ~= spanKey then
    hostileSpans, spanKey = new, key
    SetTargetZones()
  end
end

--------------------------------------------------------------------------------
-- Showing and placing
--------------------------------------------------------------------------------

-- True when a is b (a secret answer counts as no).
local function Same(a, b)
  local v = UnitIsUnit(a, b)
  return not issecretvalue(v) and v
end

-- True when unit is an enemy (a secret answer counts as one).
local function Hostile(unit)
  local v = UnitCanAttack("player", unit)
  return issecretvalue(v) or v
end

-- True when unit is followed: alive, not the player, the combat setting
-- allows it, and an enemy or (when turned on) a friendly player. Friendly
-- NPCs never are.
local function Wanted(unit)
  if not UnitExists(unit) or UnitIsDeadOrGhost(unit) or Same(unit, "player") then return false end
  if db.rangeOocOff and not UnitAffectingCombat("player") then return false end
  if Hostile(unit) then return true end
  local player = UnitIsPlayer(unit)
  return not db.rangeFriendlyOff and (issecretvalue(player) or player)
end

-- The part of a nameplate to hang a display over: its health bar, or the name
-- when that sits above the bar. A nameplate addon's own frame (unitFrame) is
-- used when shown.
local function PlateAnchor(p)
  local uf = p.unitFrame and p.unitFrame:IsShown() and p.unitFrame or p.UnitFrame
  local bar = uf and uf.healthBar
  if not bar then return p end
  local name = uf.name
  if name and name:IsShown() then
    local bottom, top = name:GetBottom(), bar:GetTop()
    if bottom and top and not issecretvalue(bottom) and not issecretvalue(top) and bottom >= top - 1 then
      return name
    end
  end
  return bar
end

-- unit's nameplate and the part of it to anchor to, or nil.
local function Nameplate(unit)
  local p = C_NamePlate.GetNamePlateForUnit(unit)
  if not p then return end
  local ok, a = pcall(PlateAnchor, p)
  return p, ok and a or p
end

-- Puts the nameplate display on the target's nameplate and the focus label on
-- the focus's when nameplates are used, and shows the screen display where
-- it's wanted (always in Edit Mode, so it can be placed).
local function Place()
  local edit, plates = LEM:IsInEditMode(), db.rangePlace ~= "screen"
  local anchor
  plate, anchor = nil, nil
  if targetOn and plates then plate, anchor = Nameplate("target") end
  local pr = plateTape.root
  if plate then
    pr:ClearAllPoints()
    pr:SetPoint("BOTTOM", anchor, "TOP", 0, db.rangePlateY)
  end
  pr:SetShown(plate ~= nil)
  holder:SetShown(edit or targetOn and (db.rangePlace ~= "plate" or not plate))

  local fr = focusLabel.root
  local fp, fa
  if focusOn and plates then fp, fa = Nameplate("focus") end
  fr:ClearAllPoints()
  if fp and fp == plate then
    fr:SetPoint("BOTTOM", pr, "TOP", 0, 2)
  elseif fp then
    fr:SetPoint("BOTTOM", fa, "TOP", 0, db.rangePlateY)
  else
    fr:SetPoint("CENTER")
  end
  focusHolder:SetShown(edit or focusOn)
end

-- Nameplates come and go as units walk in and out of view: place again once
-- they settle.
local placePending
local function PlaceSoon()
  if placePending then return end
  placePending = true
  C_Timer.After(0, function()
    placePending = false
    Place()
  end)
end

-- Works out which units are followed, shows and places the displays, and runs
-- the ticker only while something shows.
local function UpdateShown()
  local on, edit = not db.rangeOff, LEM:IsInEditMode()
  targetOn = on and Wanted("target")
  focusOn = on and not db.rangeFocusOff and Wanted("focus")
  local wasMouse = mouseOn
  mouseOn = on and not db.rangeMouseOff and not Same("mouseover", "target") and Wanted("mouseover")
  if not mouseOn then
    mouseLabel.root:Hide()
  elseif not wasMouse then
    Forget(M)
    M.est:reset()
  end
  holder:SetAlpha(db.rangeOff and 0.4 or 1)
  focusHolder:SetAlpha((db.rangeOff or db.rangeFocusOff) and 0.4 or 1)
  if edit and not focusOn then focusLabel:Set("28", "primary") end -- a sample to place
  Place()
  ticker:SetShown(targetOn or focusOn or mouseOn or edit)
end

--------------------------------------------------------------------------------
-- Ticking and drawing
--------------------------------------------------------------------------------

-- A unit's speed in yd/s, or nil when the game hides it.
local function Speed(unit)
  local v = GetUnitSpeed(unit)
  if v == nil or issecretvalue(v) then return nil end
  return v
end

local function Standing(unit)
  return Speed(unit) == 0
end

-- The player's world position, or nil where the game hides it (instances).
local function PlayerPos()
  local y, x = UnitPosition("player")
  if not y or issecretvalue(y) or issecretvalue(x) then return nil end
  return x, y
end

-- One tick of tr: its bracket, then its estimate. dt: time moved since the
-- last tick; ps: the player's speed; px, py: the player's position.
-- Returns lo, hi, the estimate and whether a bracket edge was crossed.
local function Follow(tr, hostile, dt, ps, px, py)
  local lo, hi = Measure(tr, hostile)
  local ts = Speed(tr.unit)
  -- Combined speed; unknown unless both are known or only the player moves.
  local sp = ps and ts and ps + ts or ps and ps > 0.05 and ps or nil
  local crossed = tr.est:update(clock, dt, lo, hi, sp, px, py, not ts or ts < 0.1, ps)
  -- Inside a min-range spell's minimum: just under its edge at most.
  local g = hi and tr.hiIdx and groups[tr.hiIdx]
  if g and g.minSpells and g.range == hi then hi = hi - 0.05 end
  return lo, hi, tr.est:value(lo, hi), crossed
end

-- One tick of a label: whole yards ("12+" past the last step that answered,
-- never wider than "99+"), coloured by its own zones (the unit can be a friend
-- while the target is an enemy).
local function FollowLabel(tr, label, dt, ps, px, py)
  local hostile = Hostile(tr.unit)
  local lo, hi, b = Follow(tr, hostile, dt, ps, px, py)
  if not hi and lo == 0 then
    label:SetNoData()
  else
    local d = b or lo
    local text = d >= 99 and "99+" or b and tostring(math.floor(b)) or math.floor(lo) .. "+"
    label:Set(text, (ZoneAt(d, hostile and hostileSpans or FRIEND_ONLY)))
  end
end

-- One tick of everything followed. dt: time since the last tick; wasIdle:
-- everything stood still at the last tick.
local function Tick(dt, wasIdle)
  clock = clock + dt
  -- Woken by a move: it began since the last speed check, not over the whole wait.
  local moveDt = wasIdle and not idle and math.min(dt, TICK) or dt
  if wasIdle and not idle then
    for _, tr in ipairs(trackers) do
      tr.nextWindow = math.min(tr.nextWindow, clock + WINDOW_EVERY)
      tr.nextFull = math.min(tr.nextFull, clock + FULL_EVERY)
    end
  end
  -- A followed unit died or no longer fits the settings.
  if targetOn and not Wanted("target") or focusOn and not Wanted("focus")
      or mouseOn and not Wanted("mouseover") then
    UpdateShown()
  end
  zoneClock = zoneClock + dt
  if zoneClock >= ZONE_EVERY then
    zoneClock = 0
    RefreshZones()
  end

  local ps = Speed("player")
  if ps == nil then
    -- Speeds are hidden in instances: moving or not is enough to start and stop the estimate.
    local m = IsPlayerMoving()
    if not issecretvalue(m) then ps = m and Estimator.RUN or 0 end
  end
  local px, py = PlayerPos()
  if focusOn then FollowLabel(F, focusLabel, moveDt, ps, px, py) end
  if mouseOn then
    FollowLabel(M, mouseLabel, moveDt, ps, px, py)
    mouseLabel.root:Show() -- once it has a value
  end
  if not targetOn then return end

  local hostile = Hostile("target")
  if hostile ~= targetHostile then
    targetHostile = hostile
    SetTargetZones()
  end
  local lo, hi, b, crossed = Follow(T, hostile, moveDt, ps, px, py)
  local was = goal
  noData = not hi and lo == 0 -- "0+" would look like a reading
  if noData then
    shown = nil
  elseif b then
    goal, goalLabel = b, tostring(math.floor(b))
  else
    goal, goalLabel = lo, math.floor(lo) .. "+"
  end
  if not noData and goal >= 99 then goalLabel = "99+" end -- never wider than two digits
  -- How fast the estimate moves now, so drawing can carry it on until the next
  -- tick (not across a crossing, where it jumps).
  goalRate = b and was and b == goal and not crossed and (goal - was) / dt or 0
  goalLo, goalHi, sinceTick = lo, hi, 0
end

-- Every frame: the tapes glide towards the latest estimate.
local function Draw(elapsed)
  if not (holder:IsShown() or plateTape.root:IsShown()) then return end
  for _, tp in ipairs(tapes) do
    if noData ~= (tp.noData or false) then tp:SetNoData(noData) end
  end
  if noData then return end
  local g, label = goal, goalLabel
  if not g then g, label = SAMPLE, SAMPLE_LABEL end -- Edit Mode without a target
  local aim = g
  if goal and goalRate ~= 0 then
    sinceTick = sinceTick + elapsed
    aim = math.max(goalLo, g + goalRate * math.min(sinceTick, 2 * TICK))
    if goalHi and aim > goalHi then aim = goalHi end
  end
  if shown == aim then return end
  shown = shown and shown + (aim - shown) * math.min(1, elapsed * 14) or aim
  if math.abs(aim - shown) < 0.002 then shown = aim end
  if label == tostring(math.floor(g)) then label = tostring(math.floor(shown)) end
  for _, tp in ipairs(tapes) do tp:Draw(shown, label) end
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

-- Starts over for a new target.
local function NewTarget()
  T.est:reset()
  Forget(T)
  goal, shown, noData, goalRate = nil, nil, false, 0
  targetHostile = not UnitExists("target") or Hostile("target")
  SetTargetZones()
  UpdateShown()
end

-- Starts a label over for a new unit.
local function NewLabelUnit(tr, label)
  tr.est:reset()
  Forget(tr)
  label:Clear()
end

ns.On("PLAYER_TARGET_CHANGED", function() if holder then NewTarget() end end)
ns.On("PLAYER_FOCUS_CHANGED", function()
  if not holder then return end
  NewLabelUnit(F, focusLabel)
  UpdateShown()
end)
ns.On("UPDATE_MOUSEOVER_UNIT", function()
  if not holder then return end
  if mouseOn then
    mouseLabel.root:Hide()
    NewLabelUnit(M, mouseLabel)
  end
  UpdateShown()
end)
ns.On("PLAYER_REGEN_DISABLED", function() if holder then UpdateShown() end end)
ns.On("PLAYER_REGEN_ENABLED", function() if holder then UpdateShown() end end)
ns.On("NAME_PLATE_UNIT_ADDED", function() if holder and db.rangePlace ~= "screen" then PlaceSoon() end end)
ns.On("NAME_PLATE_UNIT_REMOVED", function() if holder and db.rangePlace ~= "screen" then PlaceSoon() end end)

local rebuildPending
-- Rebuilds the steps and zones a second after the first change, so a burst of
-- events rebuilds once.
local function RebuildSoon()
  if rebuildPending or not holder then return end
  rebuildPending = true
  C_Timer.After(1, function()
    rebuildPending = false
    BuildSteps()
    RefreshZones()
  end)
end

-- New spells, item data or a new ranged weapon can change the steps and zones.
ns.On("SPELLS_CHANGED", RebuildSoon)
ns.On("GET_ITEM_INFO_RECEIVED", function(id) if loading[id] then RebuildSoon() end end)
ns.On("UNIT_INVENTORY_CHANGED", RebuildSoon)

--------------------------------------------------------------------------------
-- Debug commands: /wu range list | stats | clear (called from Options.lua)
--------------------------------------------------------------------------------
local function Say(msg) print("|cffe6cc80WU Range|r " .. msg) end

-- Prints the range steps with the target's last answers, the hidden answers
-- counted so far and the enemy zones.
local function PrintList()
  RefreshZones()
  Say(("%d range steps. Hidden answers so far: spell %d, item %d. Own position: %s.")
    :format(#groups, secrets.spell, secrets.item, PlayerPos() and "yes" or "hidden"))
  local zones = {}
  for _, s in ipairs(hostileSpans) do zones[#zones + 1] = ("%s %g-%g"):format(s[4], s[1], s[2]) end
  Say("Zones (" .. (db.rangeAutoOff and "set by hand" or "automatic") .. "): " .. table.concat(zones, ", "))
  for _, g in ipairs(groups) do
    local have = {}
    if g.harmItem then have[#have + 1] = "enemy item " .. g.harmItem end
    if g.friendItem then have[#have + 1] = "friend item " .. g.friendItem end
    if g.interact then have[#have + 1] = "interact " .. g.interact end
    if #g.spells > 0 then have[#have + 1] = #g.spells .. " spells" end
    if g.minSpells then have[#have + 1] = #g.minSpells .. " min-range spells" end
    local r = g.result == true and "|cff4dff59in|r" or g.result == false and "|cffff4433out|r" or "-"
    local why = g.why and (g.whyId and g.why .. " " .. g.whyId or g.why) or ""
    print(("  %3d yd  %s  %s  %s"):format(g.range, r, table.concat(have, ", "), why))
  end
end

-- Handles "/wu range <cmd>".
function ns.RangeCommand(cmd)
  if cmd == "list" then
    PrintList()
  elseif cmd == "stats" then
    local s = T.est.stats
    if s.n == 0 then
      Say("no crossings timed yet. Run at a target until its distance step changes twice.")
    else
      Say(("%d crossings. Mean error: bracket middle %.2f yd, WU estimate %.2f yd (worst %.1f yd).")
        :format(s.n, s.midn > 0 and s.mid / s.midn or 0, s.err / s.n, s.worst))
    end
  elseif cmd == "clear" then
    T.est:clearStats()
    Say("stats cleared")
  else
    Say("/wu range list | stats | clear")
  end
end

--------------------------------------------------------------------------------
-- Settings and building
--------------------------------------------------------------------------------

-- Applies every range setting; used when built, after a setting changes on the
-- options page and after /wu reset.
function ns.RefreshRange()
  Tape.SetColors({
    primary = db.rangeColorPrimary, secondary = db.rangeColorSecondary,
    dead = db.rangeColorDead, far = db.rangeColorFar,
  })
  for _, tp in ipairs(tapes) do
    tp:SetLayout(db.rangeLook, db.rangeWidth, db.rangeHeight, db.rangeSize, db.rangeScale,
      db.rangeTextFont, not db.rangeUnitOff)
    tp:SetOpacity(db.rangeOpacity / 100)
  end
  plateTape.root:SetScale(db.rangePlateScale / 100)
  holder:SetSize(screenTape.root:GetSize())
  for _, l in ipairs({ focusLabel, mouseLabel }) do
    l:SetLayout(db.rangeLabelScale / 100, db.rangeTextFont, db.rangeOpacity / 100)
  end
  focusHolder:SetSize(focusLabel.root:GetSize())
  PlaceScreen()
  PlaceFocus()
  spanKey = nil -- restyle with the new colours and zones
  RefreshZones()
  UpdateShown()
end

function ns.BuildRange()
  holder = CreateFrame("Frame", nil, UIParent)
  holder:SetClampedToScreen(true)
  screenTape = Tape.New(holder)
  plateTape = Tape.New(UIParent)
  plateTape.root:Hide()
  tapes = { screenTape, plateTape }

  focusHolder = CreateFrame("Frame", nil, UIParent)
  focusHolder:SetClampedToScreen(true)
  focusLabel = Label.New(focusHolder)

  -- The mouseover label sits above and right of the pointer's tip.
  mouseLabel = Label.New(UIParent)
  local mr = mouseLabel.root
  mr:SetFrameStrata("TOOLTIP")
  mr:Hide()
  local cursorX, cursorY
  mr:SetScript("OnShow", function() cursorX = nil end)
  mr:SetScript("OnUpdate", function(self)
    if not UnitExists("mouseover") then
      UpdateShown()
      return
    end
    local x, y = GetCursorPosition()
    if x == cursorX and y == cursorY then return end
    cursorX, cursorY = x, y
    local scale = UIParent:GetEffectiveScale()
    self:ClearAllPoints()
    self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / scale + 14, y / scale + 4)
  end)

  ticker = CreateFrame("Frame", nil, UIParent)
  ticker:Hide()
  ticker:SetScript("OnUpdate", function(_, elapsed)
    if targetOn or focusOn or mouseOn then
      acc = acc + elapsed
      if acc >= TICK then
        local wasIdle = idle
        idle = Standing("player") and (not targetOn or Standing("target"))
          and (not focusOn or Standing("focus")) and (not mouseOn or Standing("mouseover"))
        if not (wasIdle and idle and acc < IDLE_TICK) then
          local dt = acc
          acc = 0
          Tick(dt, wasIdle)
        end
      end
    end
    Draw(elapsed)
  end)

  local Checkbox, Option = LEM.SettingType.Checkbox, ns.EditModeOption
  PlaceScreen = ns.AddEditModeFrame(holder, "rangeLayouts", DEFAULT_POS, "WU Range Display", {
    Option(Checkbox, "Disable Range Display", "rangeOff", UpdateShown),
  }, UpdateShown)
  PlaceFocus = ns.AddEditModeFrame(focusHolder, "rangeFocusLayouts", FOCUS_POS, "WU Range Focus", {
    Option(Checkbox, "Disable Focus Label", "rangeFocusOff", UpdateShown),
  }, UpdateShown)
  BuildSteps()
  ns.RefreshRange()
end
