local _, ns = ...
local db = ns.db

--------------------------------------------------------------------------------
-- Cooldown Manager layout
-- Adds a layout named "WU" to Blizzard's Cooldown Manager with Battle Shout,
-- Demoralizing Shout and Sunder Armor first in Tracked Buffs, gives Sunder
-- Armor a text-to-speech alert when it falls off, and makes it the active
-- layout. The Cooldown Manager plays that alert itself, so it works in combat
-- without the addon reading hidden aura data. Runs only from the CDM tab
-- buttons, out of combat; the tab reloads the UI afterwards so the Cooldown
-- Manager loads the new data.
--
-- The layout data is one undocumented string holding all of the character's
-- layouts: "<version>|" + base64 of compressed CBOR. Decoded, it is
--   [1] format version, [2] { [tag] = active layout id },
--   [3] { [tag] = { [layout id] = layout } }, [4] { [layout id] = name }
-- where tag is Blizzard's class-and-spec tag (11 for Warrior), and each
-- layout is [2] { [category] = { cooldown IDs } },
-- [3] { [cooldown ID] = { { type, event, sound } } } (alerts).
-- With no layouts saved yet, [3] and [4] are missing. Other layout fields are
-- Blizzard's (field 4 is read as spell IDs), so this never adds fields to a
-- layout. Because the format is undocumented, this only writes when the
-- version is the one it was built against, copies the active layout (if any)
-- so nothing else in it changes, and saves the original string for Restore
-- when there were layouts to restore.
-- Events: none
-- SavedVariables: cdmBackup (layout data from before the first Create, or false)
--------------------------------------------------------------------------------
local V, E = C_CooldownViewer, C_EncodingUtil
local FORMAT, NAME = 5, "WU"
local TRACKED = Enum.CooldownViewerCategory.TrackedBuff
-- Sunder Armor alert as the Cooldown Manager saves it when set by hand:
-- Sound (1), On Aura Removed (6), Text to Speech (0).
local SUNDER_ALERT = { 1, 6, 0 }

-- Spells to track, in Tracked Buffs order. Each set holds every rank's spell
-- ID; the name from the first ID (in the client's language) also matches a
-- rank missing from the list.
local function SpellSet(...)
  local set = { id = (...) }
  for i = 1, select("#", ...) do set[select(i, ...)] = true end
  return set
end

local SPELLS = {
  SpellSet(6673, 5242, 6192, 11549, 11550, 11551, 25289, 27578), -- Battle Shout
  SpellSet(1160, 6190, 11554, 11555, 11556), -- Demoralizing Shout
  SpellSet(7386, 7405, 8380, 11596, 11597), -- Sunder Armor
}

-- True when spell ID id belongs to set.
local function IsSpell(id, set)
  if set[id] then return true end
  local name = C_Spell.GetSpellName(set.id)
  return name ~= nil and C_Spell.GetSpellName(id) == name
end

-- Returns prefix, table for a layout data string, or nil when it can't be
-- read or is not format FORMAT.
local function Decode(data)
  local prefix, b64 = (data or ""):match("^(%d+|)(.+)$")
  if not prefix then return end
  local ok, t = pcall(function()
    return E.DeserializeCBOR(E.DecompressString(E.DecodeBase64(b64)))
  end)
  if ok and type(t) == "table" and t[1] == FORMAT then return prefix, t end
end

local function Encode(prefix, t)
  return prefix .. E.EncodeBase64(E.CompressString(E.SerializeCBOR(t)))
end

-- Cooldown IDs of SPELLS in Tracked Buffs, in SPELLS order, or nil when any is
-- missing. Matched by spell so a renumbered cooldown ID still works.
local function TrackedIDs()
  local ids = {}
  for _, id in ipairs(V.GetCooldownViewerCategorySet(TRACKED, true) or {}) do
    local info = V.GetCooldownViewerCooldownInfo(id)
    for i, set in ipairs(SPELLS) do
      if info and IsSpell(info.spellID, set) then ids[i] = id end
    end
  end
  for i in ipairs(SPELLS) do
    if not ids[i] then return end
  end
  return ids
end

-- Writes the WU layout (replacing an earlier WU layout) and makes it active.
-- Returns true, or false and a reason; nothing is written on false.
function ns.CreateCDMLayout()
  if InCombatLockdown() then return false, "Leave combat first." end
  local data = V.GetLayoutData()
  local prefix, t = Decode(data)
  if not prefix then return false, "Unknown Cooldown Manager data format. Nothing was changed." end
  local ids = TrackedIDs()
  if not ids then return false, "A spell is missing from the Cooldown Manager. Nothing was changed." end

  -- Layouts are filed under the current class-and-spec tag. Missing lists
  -- are created; a backup is only worth keeping when layouts already exist.
  local key = CooldownViewerUtil.GetCurrentClassAndSpecTag()
  local hadLayouts = next(t[3] or {}) ~= nil
  t[2], t[3], t[4] = t[2] or {}, t[3] or {}, t[4] or {}
  t[3][key] = t[3][key] or {}

  -- Reuse the WU layout's id if it exists, else the next id not used by any
  -- layout or name.
  local layouts, names, id, maxID = t[3][key], t[4], nil, 0
  for _, byID in ipairs({ layouts, names }) do
    for lid in pairs(byID) do
      if type(lid) == "number" then maxID = math.max(maxID, lid) end
    end
  end
  for lid in pairs(layouts) do
    if names[lid] == NAME then id = lid end
  end
  id = id or maxID + 1

  -- Copy of the active layout, with the three spells moved to the front of
  -- Tracked Buffs (out of every other category, including "not displayed")
  -- and Sunder Armor's alerts replaced by SUNDER_ALERT. With no active layout
  -- the copy starts empty and lists only the three spells.
  local layout = CopyTable(layouts[t[2][key]] or {})
  layout[2] = layout[2] or {}
  local want = {}
  for _, cid in ipairs(ids) do want[cid] = true end
  for _, list in pairs(layout[2]) do
    for i = #list, 1, -1 do
      if want[list[i]] then table.remove(list, i) end
    end
  end
  local list = layout[2][TRACKED] or {}
  for i, cid in ipairs(ids) do table.insert(list, i, cid) end
  layout[2][TRACKED] = list
  layout[3] = layout[3] or {}
  layout[3][ids[3]] = { CopyTable(SUNDER_ALERT) }
  layouts[id] = layout
  names[id] = NAME
  t[2][key] = id

  -- Only write data that reads back cleanly.
  local ok, new = pcall(Encode, prefix, t)
  if not ok or not Decode(new) then return false, "Could not build the layout. Nothing was changed." end
  if hadLayouts then db.cdmBackup = db.cdmBackup or data end
  V.SetLayoutData(new)
  return true
end

-- Puts back the layout data saved before the first Create and clears the
-- backup. Returns true, or false and a reason.
function ns.RestoreCDMLayout()
  if InCombatLockdown() then return false, "Leave combat first." end
  if not db.cdmBackup then return false, "No backup saved." end
  V.SetLayoutData(db.cdmBackup)
  db.cdmBackup = false
  return true
end
