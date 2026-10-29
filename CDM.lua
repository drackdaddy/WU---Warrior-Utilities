local _, ns = ...
local db = ns.db

--------------------------------------------------------------------------------
-- Cooldown Manager layouts
-- Adds a WU layout (see CDM_LAYOUTS) to Blizzard's Cooldown Manager holding
-- only its buffs, in their sections with the listed alerts, and makes it the
-- active layout. Other layouts are left as they are. The Cooldown Manager plays the alerts itself, so they
-- work in combat without the addon reading hidden aura data. Runs only from
-- the CDM tab buttons, out of combat; the tab reloads the UI afterwards so the
-- Cooldown Manager loads the new data.
--
-- The layout data is one undocumented string holding all of the character's
-- layouts: "<version>|" + base64 of compressed CBOR. Decoded, it is
--   [1] format version, [2] { [tag] = active layout id },
--   [3] { [tag] = { [layout id] = layout } }, [4] { [layout id] = name }
-- where tag is Blizzard's class-and-spec tag (11 for Warrior), and each
-- layout is [2] { [category] = { cooldown IDs } },
-- [3] { [cooldown ID] = { { type, event, sound } } } (alerts).
-- With no layouts saved yet, [3] and [4] are missing, and a character that
-- has only ever used Blizzard's default layout has no data string at all; it
-- then starts from an empty set in format FORMAT. Other layout fields are
-- Blizzard's (field 4 is read as spell IDs), so a new layout only gets [2]
-- and [3]. Because the format is undocumented, this only writes when the
-- version is the one it was built against, and the first Create saves the
-- original string for Restore when there were layouts to restore.
-- Events: none
-- SavedVariables: cdmBackup (layout data from before the first Create, or false)
--------------------------------------------------------------------------------
local V, E = C_CooldownViewer, C_EncodingUtil
local FORMAT = 5
local TRACKED = Enum.CooldownViewerCategory.TrackedBuff

-- Where each category is found in the Cooldown Manager settings, for the CDM
-- tab: { tab, section }.
ns.CDM_PLACES = {
  [TRACKED] = { "Buffs", "Tracked Buffs" },
}

-- Spells to track. Each set holds every rank's spell ID; the name from the
-- first ID (in the client's language) also matches a rank missing from the
-- list.
local function SpellSet(...)
  local set = { id = (...) }
  for i = 1, select("#", ...) do set[select(i, ...)] = true end
  return set
end

-- Layouts the CDM tab offers, each with a Create button. name is the layout
-- name; replaces is an older name for the same layout, renamed on Create.
-- buffs are the only entries in the layout, listed in their category in this
-- order. Each alert is { type, event, sound, text } as the Cooldown Manager
-- saves it when set by hand (up to 3 per buff); text is only shown on the CDM
-- tab.
ns.CDM_LAYOUTS = {
  {
    name = "WU-Fury",
    replaces = "WU",
    buffs = {
      { -- Battle Shout
        spells = SpellSet(6673, 5242, 6192, 11549, 11550, 11551, 25289, 27578),
        category = TRACKED,
        alerts = {},
      },
      { -- Demoralizing Shout
        spells = SpellSet(1160, 6190, 11554, 11555, 11556),
        category = TRACKED,
        alerts = {},
      },
      { -- Sunder Armor
        spells = SpellSet(7386, 7405, 8380, 11596, 11597),
        category = TRACKED,
        -- Sound (1), On Aura Removed (6), Text to Speech (0).
        alerts = { { 1, 6, 0, text = "On Aura Removed: Text to Speech" } },
      },
    },
  },
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

-- Cooldown IDs of buffs (each found in its own category), in buffs order, or
-- nil when any is missing. Matched by spell so a renumbered cooldown ID still
-- works.
local function BuffIDs(buffs)
  local ids = {}
  for i, buff in ipairs(buffs) do
    for _, id in ipairs(V.GetCooldownViewerCategorySet(buff.category, true) or {}) do
      local info = V.GetCooldownViewerCooldownInfo(id)
      if info and IsSpell(info.spellID, buff.spells) then ids[i] = id end
    end
    if not ids[i] then return end
  end
  return ids
end

-- Writes layout def (one of CDM_LAYOUTS) as a new layout with only its buffs,
-- replacing an earlier copy of it, and makes it active. Returns true, or false and a reason; nothing is
-- written on false.
function ns.CreateCDMLayout(def)
  if InCombatLockdown() then return false, "Leave combat first." end
  local data = V.GetLayoutData()
  local prefix, t
  if data == nil or data == "" then
    prefix, t = FORMAT .. "|", { FORMAT }
  else
    prefix, t = Decode(data)
    if not prefix then return false, "Unknown Cooldown Manager data format. Nothing was changed." end
  end
  local ids = BuffIDs(def.buffs)
  if not ids then return false, "A spell is missing from the Cooldown Manager. Nothing was changed." end

  -- Layouts are filed under the current class-and-spec tag. Missing lists
  -- are created; a backup is only worth keeping when layouts already exist.
  local key = CooldownViewerUtil.GetCurrentClassAndSpecTag()
  local hadLayouts = next(t[3] or {}) ~= nil
  t[2], t[3], t[4] = t[2] or {}, t[3] or {}, t[4] or {}
  t[3][key] = t[3][key] or {}

  -- Reuse the id of the layout with this name, else of one with its old name,
  -- else the next id not used by any layout or name.
  local layouts, names, id, maxID = t[3][key], t[4], nil, 0
  for _, byID in ipairs({ layouts, names }) do
    for lid in pairs(byID) do
      if type(lid) == "number" then maxID = math.max(maxID, lid) end
    end
  end
  for lid in pairs(layouts) do
    if names[lid] == def.name then
      id = lid
    elseif names[lid] == def.replaces then
      id = id or lid
    end
  end
  id = id or maxID + 1

  -- A blank layout listing only the buffs, each in its category in def
  -- order, with their alerts.
  local layout = { [2] = {}, [3] = {} }
  for i, buff in ipairs(def.buffs) do
    layout[2][buff.category] = layout[2][buff.category] or {}
    table.insert(layout[2][buff.category], ids[i])
    if #buff.alerts > 0 then
      -- Only the three saved fields; text is for the CDM tab.
      local alerts = {}
      for j, a in ipairs(buff.alerts) do alerts[j] = { a[1], a[2], a[3] } end
      layout[3][ids[i]] = alerts
    end
  end
  layouts[id] = layout
  names[id] = def.name
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
