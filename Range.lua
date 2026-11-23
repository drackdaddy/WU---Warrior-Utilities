local _, ns = ...
local db, LEM = ns.db, ns.LibEditMode

--------------------------------------------------------------------------------
-- Range display (warriors only)
-- Adapted from Good Range by Andrii Zolotarenko (MIT, see
-- LICENSE-GoodRange.txt). Shows the distance to a living enemy target,
-- coloured by what the warrior can do from there: green melee (0-5 yd), blue
-- Charge, Intercept, Throw or Shoot while usable right now (enough rage, the
-- right stance and weapon, off cooldown), red a dead zone between them, grey
-- out of range.
-- How the distance is found: the game only answers "in range or not" for
-- items, interact distances and the player's own spells, each at a fixed
-- range. Those answers are range steps; the target lies between the largest
-- step reported out and the smallest reported in. Each tick checks only the
-- two steps around the last bracket, rescanning wider when an edge changes,
-- and the estimator (RangeEstimator.lua) turns the brackets into a smooth
-- distance between ticks. Answers the game hides in combat (secret values)
-- are skipped, never read; when no step answers the display says "no data".
-- It only reads range answers and never casts or targets anything.
-- Ticks run about 30 times a second while the display is up, 10 while the
-- player and target both stand still, and stop when the display is hidden.
-- Set up on the Range tab of the options page; moved in Edit Mode as "WU Range
-- Display" (see ns.AddEditModeFrame in Core.lua), where it always shows (faded
-- when turned off) with a sample distance when there is no target.
-- Events: PLAYER_TARGET_CHANGED, PLAYER_REGEN_DISABLED, PLAYER_REGEN_ENABLED,
--   SPELLS_CHANGED, GET_ITEM_INFO_RECEIVED, UNIT_INVENTORY_CHANGED (player)
-- SavedVariables: rangeOff, rangeOocOff, rangeLook, rangeTextFont, rangeSize,
--   rangeWidth, rangeHeight, rangeScale, rangeUnitOff, rangeOpacity,
--   rangeLayouts
--------------------------------------------------------------------------------
local Estimator = ns.Estimator
local TICK = 0.03 -- s between ticks
local IDLE_TICK, IDLE_SLOW = 0.1, 4 -- standing still: tick this often, scan this many times as rarely
local WINDOW_EVERY, FULL_EVERY, SCAN_MIN = 0.2, 0.5, 0.05 -- s between scans (see Measure)
local ZONE_EVERY = 0.25 -- s between zone refreshes (rage, stance and cooldowns change them)
local MELEE = 5
local MAX_STEP = 100 -- a spell reaching further ("anywhere") can't bound a bracket
local SAMPLE, SAMPLE_LABEL = 21.4, "21" -- shown in Edit Mode without a target
local DEFAULT_POS = { point = "CENTER", x = 0, y = 110 }

-- Range-check items by range in yd, from LibRangeCheck-3.0 (MIT) via Good
-- Range: Classic items first, then later ones the client may also know. Only
-- items whose data the client has loaded are used.
local ITEMS = {
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
-- CheckInteractDistance index -> range in yd (Tauren and Undead reach a little less).
local INTERACT = { [3] = 8, [4] = 28 }
local INTERACT_RACE = { Tauren = { [3] = 6, [4] = 25 }, Scourge = { [3] = 7, [4] = 27 } }

-- Blue zones: badge, fallback range (used when the game reports none) and the
-- rank 1 spells that give it.
local ZONE_SPELLS = {
  { "CHARGE", 8, 25, { 100, 20252 } }, -- Charge, Intercept
  { "THROW", 8, 30, { 2764 } },
  { "SHOOT", 8, 30, { 2480, 7918, 7919 } }, -- Shoot Bow, Gun, Crossbow
}

local holder, tape, ticker, PlacePosition
local groups = {} -- range steps, ascending: { range, item, interact, spells, minSpells }
local known = {} -- spell name -> the spell ID the player knows
local loading = {} -- [item ID] = true: data asked for, not loaded yet
local info = {} -- spell ID -> C_Spell.GetSpellInfo, until the spells change
local spans, spanKey = {}, "" -- the zones now: { from, to, kind, badge }
local est = Estimator.new()
local tracking -- a living enemy is targeted and the display is on
local idle -- the player and target both stood still at the last tick
local clock, acc, zoneClock = 0, 0, 0
-- The bracket: res[i] is step i's last answer, loIdx / hiIdx the steps at its
-- edges, lastLo / lastHi the bracket itself.
local res, loIdx, hiIdx, lastLo, lastHi = {}, nil, nil, 0, nil
local nextWindow, nextFull, lastScan = 0, 0, -1
-- What the display slides towards (goal, goalLabel), how fast it moves on
-- between ticks, and what it shows now.
local goal, goalLabel, goalRate, goalLo, goalHi, sinceTick, shown = nil, nil, 0, 0, nil, 0, nil
local noData = false

local function SpellInfo(id)
  if info[id] == nil then info[id] = C_Spell.GetSpellInfo(id) or false end
  return info[id] or nil
end

--------------------------------------------------------------------------------
-- Range steps
--------------------------------------------------------------------------------

-- Forgets the last bracket, so the next tick scans every step.
local function ForgetBracket()
  wipe(res)
  loIdx, hiIdx, nextWindow, nextFull, lastScan = nil, nil, 0, 0, -1
end

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
  for range, ids in pairs(ITEMS) do Group(range).item = PickItem(ids) end
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
    if not g.item and not g.interact and #g.spells == 0 and not g.minSpells then table.remove(groups, i) end
  end
  table.sort(groups, function(a, b) return a.range < b.range end)
  ForgetBracket()
end

local Check

-- True if any step above g, up to max yd, says the target is in range.
local function Within(g, max)
  for _, o in ipairs(groups) do
    if o.range > g.range and o.range <= max and Check(o) == true then return true end
  end
  return false
end

-- Step g's answer for the target: true (in), false (out) or nil (none). A
-- min-range spell answers first at its minimum: in range means past the
-- minimum; out of range means inside it if a step up to its reach says the
-- target is that close. Secret answers are skipped.
function Check(g)
  if g.minSpells then
    for _, m in ipairs(g.minSpells) do
      local v = C_Spell.IsSpellInRange(m[1], "target")
      if not issecretvalue(v) then
        if v == true then return false end
        if v == false and Within(g, m[2]) then return true end
      end
    end
  end
  if g.item then
    local v = C_Item.IsItemInRange(g.item, "target")
    if not issecretvalue(v) then return v == true end
  end
  if g.interact then
    local v = CheckInteractDistance("target", g.interact)
    if not issecretvalue(v) then return v and true or false end
  end
  for _, id in ipairs(g.spells) do
    local v = C_Spell.IsSpellInRange(id, "target")
    if not issecretvalue(v) and v ~= nil then return v end
  end
end

-- Checks steps from..to. Returns lo (the largest step out below hi), hi (the
-- smallest step in) and their indexes.
local function Scan(from, to)
  local hi, hiI
  for i = from, to do
    res[i] = Check(groups[i])
    if res[i] == true and not hi then hi, hiI = groups[i].range, i end
  end
  local lo, loI = 0, nil
  for i = from, to do
    local r = groups[i].range
    if res[i] == false and (not hi or r < hi) and r > lo then lo, loI = r, i end
  end
  return lo, hi, loI, hiI
end

-- Scans the steps around the last bracket, or all of them every FULL_EVERY s
-- or when the answer could lie outside that window.
local function Rescan()
  local n = #groups
  if clock < nextFull and (loIdx or hiIdx) then
    local from, to = math.max(1, (loIdx or 1) - 1), math.min(n, (hiIdx or n) + 1)
    local lo, hi, loI, hiI = Scan(from, to)
    if not ((not hi and to < n) or (hiI == from and from > 1) or (not loI and from > 1)) then
      loIdx, hiIdx = loI, hiI
      return lo, hi
    end
  end
  local lo, hi, loI, hiI = Scan(1, n)
  loIdx, hiIdx = loI, hiI
  nextFull = clock + FULL_EVERY * (idle and IDLE_SLOW or 1)
  return lo, hi
end

-- The bracket now. Each tick checks only its two edge steps; the steps around
-- them are scanned when an edge changes and every WINDOW_EVERY s, but never
-- sooner than SCAN_MIN s after the last scan.
local function Measure()
  if (loIdx or hiIdx) and clock < nextWindow
      and (not loIdx or Check(groups[loIdx]) == false)
      and (not hiIdx or Check(groups[hiIdx]) == true) then
    return lastLo, lastHi
  end
  if clock - lastScan < SCAN_MIN then return lastLo, lastHi end
  lastScan, nextWindow = clock, clock + WINDOW_EVERY * (idle and IDLE_SLOW or 1)
  lastLo, lastHi = Rescan()
  return lastLo, lastHi
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

-- d in yd -> kind, badge. The first span that covers d wins; a gap below the
-- furthest reach is the dead zone, beyond it is out of range.
local function ZoneAt(d)
  local reach = 0
  for _, s in ipairs(spans) do
    if d >= s[1] and d <= s[2] then return s[3], s[4] end
    if s[2] > reach then reach = s[2] end
  end
  if d < reach then return "dead", "DEAD ZONE" end
  return "far", "OUT OF RANGE"
end

-- Rebuilds the zones from what the warrior can use now and restyles the tape
-- when they changed.
local function RefreshZones()
  local new, seen = { { 0, MELEE, "primary", "MELEE" } }, {}
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
          new[#new + 1] = { min, max, "secondary", z[1] }
        end
      end
    end
  end
  local parts = {}
  for _, s in ipairs(new) do parts[#parts + 1] = table.concat(s, ",") end
  local key = table.concat(parts, ";")
  if key ~= spanKey then
    spans, spanKey = new, key
    tape:SetZones(ZoneAt)
  end
end

--------------------------------------------------------------------------------
-- Showing, ticking and drawing
--------------------------------------------------------------------------------

-- True while the target is a living enemy (a secret answer counts as one).
local function Wanted()
  if not UnitExists("target") or UnitIsDeadOrGhost("target") then return false end
  local hostile = UnitCanAttack("player", "target")
  return issecretvalue(hostile) or hostile
end

-- Shows the display while tracking, or always in Edit Mode (faded when off),
-- and runs the ticker only while it shows.
local function UpdateShown()
  tracking = not db.rangeOff and Wanted() and (not db.rangeOocOff or UnitAffectingCombat("player"))
  holder:SetShown(tracking or LEM:IsInEditMode())
  holder:SetAlpha(db.rangeOff and 0.4 or 1)
  ticker:SetShown(holder:IsShown())
end

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

-- One tick: the bracket, then the estimate. dt: time since the last tick;
-- wasIdle: both stood still at the last tick.
local function Tick(dt, wasIdle)
  clock = clock + dt
  -- Woken by a move: it began since the last speed check, not over the whole wait.
  local moveDt = wasIdle and not idle and math.min(dt, TICK) or dt
  if wasIdle and not idle then
    nextWindow = math.min(nextWindow, clock + WINDOW_EVERY)
    nextFull = math.min(nextFull, clock + FULL_EVERY)
  end
  if not Wanted() then
    UpdateShown() -- the target died
    return
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
  local lo, hi = Measure()
  local ts = Speed("target")
  -- Combined speed; unknown unless both are known or only the player moves.
  local sp = ps and ts and ps + ts or ps and ps > 0.05 and ps or nil
  local crossed = est:update(clock, moveDt, lo, hi, sp, px, py, not ts or ts < 0.1, ps)
  -- Inside a min-range spell's minimum: just under its edge at most.
  local g = hi and hiIdx and groups[hiIdx]
  if g and g.minSpells and g.range == hi then hi = hi - 0.05 end
  local b = est:value(lo, hi)

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

-- Every frame: the display glides towards the latest estimate.
local function Draw(elapsed)
  if noData ~= (tape.noData or false) then tape:SetNoData(noData) end
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
  tape:Draw(shown, label)
end

-- Starts over for a new target.
local function NewTarget()
  est:reset()
  goal, shown, noData, goalRate = nil, nil, false, 0
  ForgetBracket()
  RefreshZones()
  UpdateShown()
end

ns.On("PLAYER_TARGET_CHANGED", function() if holder then NewTarget() end end)
ns.On("PLAYER_REGEN_DISABLED", function() if holder then UpdateShown() end end)
ns.On("PLAYER_REGEN_ENABLED", function() if holder then UpdateShown() end end)

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

-- Applies every range setting; used when built, after a setting changes on the
-- options page and after /wu reset.
function ns.RefreshRange()
  tape:SetLayout(db.rangeLook, db.rangeWidth, db.rangeHeight, db.rangeSize, db.rangeScale,
    db.rangeTextFont, not db.rangeUnitOff)
  tape:SetOpacity(db.rangeOpacity / 100)
  holder:SetSize(tape.root:GetSize())
  PlacePosition()
  UpdateShown()
end

function ns.BuildRange()
  holder = CreateFrame("Frame", nil, UIParent)
  holder:SetClampedToScreen(true)
  tape = ns.RangeTape.New(holder)

  ticker = CreateFrame("Frame", nil, UIParent)
  ticker:Hide()
  ticker:SetScript("OnUpdate", function(_, elapsed)
    if tracking then
      acc = acc + elapsed
      if acc >= TICK then
        local wasIdle = idle
        idle = Standing("player") and Standing("target")
        if not (wasIdle and idle and acc < IDLE_TICK) then
          local dt = acc
          acc = 0
          Tick(dt, wasIdle)
        end
      end
    end
    Draw(elapsed)
  end)

  PlacePosition = ns.AddEditModeFrame(holder, "rangeLayouts", DEFAULT_POS, "WU Range Display", {
    ns.EditModeOption(LEM.SettingType.Checkbox, "Disable Range Display", "rangeOff", UpdateShown),
  }, UpdateShown)
  BuildSteps()
  RefreshZones()
  ns.RefreshRange()
end
