local _, ns = ...
local db = ns.db

--------------------------------------------------------------------------------
-- Audio alerts (warriors only)
-- Speaks (or plays a sound) when Sunder Armor on the target, Demoralizing
-- Shout or the player's Battle Shout is about to run out, a set number of
-- seconds before it does (0 = when it runs out). Battle Shout also alerts
-- when the player enters combat without it. Alerts only play in combat, and
-- Sunder and Demoralizing Shout only while the player targets an enemy.
--
-- Each aura has a clock (when it runs out), set the way Ultimate Warrior does:
--   1. Read the aura list (the target's, or for Battle Shout the player's).
--      In combat the game may refuse (an error, caught with pcall) or hand
--      back secret values; both count as hidden and nothing is read from
--      them. When the target's list is hidden, the same mob's nameplate is
--      tried. A readable list sets the clock from the aura itself, from any
--      caster, and learns its real duration.
--   2. While the list is hidden, the player's own casts
--      (UNIT_SPELLCAST_SUCCEEDED, spell ID checked with issecretvalue)
--      restart the clock for the aura's full duration.
--   3. A Sunder the target dodged, parried or that missed (UNIT_COMBAT on
--      the target within moments of the cast) is taken back. In a group that
--      could be someone else's attack, so it is only believed when solo.
-- An empty list only ends a running clock once the list has shown that aura
-- on this target (so it is really readable) and the player is solo; in a
-- group or instance the game can hand back an empty list for a mob that has
-- the debuff. Sunder keeps a clock per target; Demoralizing Shout hits
-- everything around the player, so it keeps one.
--
-- The voice is one of Windows' text-to-speech voices (C_VoiceChat.SpeakText)
-- or a game sound (C_Sound.PlaySoundWithOptions), at the chosen volume.
-- Set up on the Battle Shout and Debuffs tabs under CDM on the options page.
-- Events: PLAYER_ENTERING_WORLD, PLAYER_REGEN_DISABLED, PLAYER_REGEN_ENABLED,
--   PLAYER_TARGET_CHANGED, UNIT_AURA, UNIT_SPELLCAST_SUCCEEDED, UNIT_COMBAT
-- SavedVariables: sunderAlertOff, demoAlertOff, shoutAlertOff, sunderAlertSec,
--   demoAlertSec, shoutAlertSec, alertVoice, alertVolume
--------------------------------------------------------------------------------

-- Each alert: settings prefix, what is said, the unit and filter its aura is
-- read with, the duration its clock starts with until the real one is seen,
-- whether a dodge can take its cast back (melee) and whether it keeps a clock
-- per target (byTarget, by GUID). Items without byTarget hold their clock
-- (expires, warned, seen, castAt) themselves.
local ITEMS = {
  { key = "sunder", say = "Sunder", unit = "target", filter = "HARMFUL", dur = 30, melee = true, byTarget = {} },
  { key = "demo", say = "Demo Shout", unit = "target", filter = "HARMFUL", dur = 45 },
  { key = "shout", say = "Battle Shout", unit = "player", filter = "HELPFUL", dur = 120 },
}
local SOUNDS = { -- game sounds offered after the installed voices: key, name, sound kit ID
  { "raid", "Raid Warning", 8959 }, { "ready", "Ready Check", 8960 }, { "alarm", "Alarm Clock", 12889 },
}
local VOLUME = { high = 1, medium = 0.6, low = 0.3 }
local INTERVAL = 0.2 -- seconds between checks in combat
local GRACE = 1 -- seconds a fresh cast's aura may take to show in the list
local MISS_WINDOW = 0.4 -- seconds between a cast and a miss that belong together
local MISSES = { DODGE = true, PARRY = true, MISS = true }
local ticker, lastMissAt, lastCast = nil, 0, nil

-- Returns the five voice choices, { key, name, tts = voiceID } or
-- { key, name, sound = soundKitID }: the installed text-to-speech voices
-- first, then game sounds. Used by the options page and PlayAlert.
function ns.AlertVoices()
  local list = {}
  for i, v in ipairs(C_VoiceChat.GetTtsVoices() or {}) do
    if #list == 5 then break end
    local name = v.name:gsub(" Desktop.*", ""):gsub("^Microsoft ", "")
    list[#list + 1] = { "tts" .. i, name .. " (voice)", tts = v.voiceID }
  end
  for _, s in ipairs(SOUNDS) do
    if #list < 5 then list[#list + 1] = { s[1], s[2] .. " (sound)", sound = s[3] } end
  end
  return list
end

-- Says text with the chosen voice and volume (the first choice if the saved
-- voice is no longer installed). Also used by the options page's Test button.
function ns.PlayAlert(text)
  local list, voice = ns.AlertVoices()
  for _, v in ipairs(list) do
    if v[1] == db.alertVoice then voice = v end
  end
  voice = voice or list[1]
  local volume = VOLUME[db.alertVolume]
  if voice.tts then
    C_VoiceChat.SpeakText(voice.tts, text, 0, volume * 100, true)
  else
    C_Sound.PlaySoundWithOptions({ soundKitID = voice.sound, volumeOverride = volume })
  end
end

-- The clock for item: its own, or for Sunder the current target's (nil
-- without a target). A hidden GUID shares one clock for every target.
local function Clock(item)
  if not item.byTarget then return item end
  local guid = UnitGUID("target")
  if not guid then return end
  if issecretvalue(guid) then guid = "target" end
  item.byTarget[guid] = item.byTarget[guid] or {}
  return item.byTarget[guid]
end

-- The target's nameplate unit ("nameplateN"), or nil when it has none or the
-- game hides it.
local function TargetPlate()
  local ok, unit = pcall(function()
    local plate = C_NamePlate.GetNamePlateForUnit("target")
    return plate and plate.namePlateUnitToken
  end)
  if ok and type(unit) == "string" and not issecretvalue(unit) then return unit end
end

-- Looks for item's aura in unit's list: "found" and the aura, "absent", or
-- "hidden" when the game refuses or any answer is secret.
local function Scan(unit, item)
  for i = 1, 40 do
    local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, item.filter)
    if not ok or issecretvalue(a) then return "hidden" end
    if not a then return "absent" end
    if issecretvalue(a.spellId) then return "hidden" end
    if tContains(item.ranks, a.spellId) then return "found", a end
  end
  return "absent"
end

-- Reads item's aura (trying the target's nameplate when the target's list is
-- hidden) and moves its clock to match; see the header for the rules.
local function Read(item)
  if not UnitExists(item.unit) then return end
  local c = Clock(item)
  if not c then return end
  local state, a = Scan(item.unit, item)
  if state == "hidden" and item.unit == "target" then
    local plate = TargetPlate()
    if plate then state, a = Scan(plate, item) end
  end
  if state == "found" then
    local expires, duration = a.expirationTime, a.duration
    if issecretvalue(expires) or issecretvalue(duration) or expires == 0 then return end
    if expires ~= c.expires then c.expires, c.warned = expires, nil end
    if duration > 0 then item.dur = duration end
    c.seen = true
  elseif state == "absent" then
    local now = GetTime()
    local fresh = c.castAt and now - c.castAt < GRACE
    local running = c.expires and now < c.expires
    local trusted = c.seen and not (IsInGroup() or IsInInstance())
    if fresh then return end
    if not running then
      -- A missing Battle Shout counts as run out, so it alerts; a missing
      -- debuff that wasn't running just has no clock.
      if item.unit == "player" and c.expires ~= 0 then c.expires, c.warned = 0, nil
      elseif item.unit ~= "player" then c.expires = nil end
    elseif trusted then
      c.expires = now -- it really ended early: alert now
    end
  end
end

-- Plays each alert that is on once its clock reaches its warning time.
local function Check()
  local enemy = UnitCanAttack("player", "target")
  for _, item in ipairs(ITEMS) do
    if not db[item.key .. "AlertOff"] and (item.unit == "player" or enemy) then
      Read(item)
      local c = Clock(item)
      if c and c.expires and not c.warned and GetTime() >= c.expires - db[item.key .. "AlertSec"] then
        c.warned = true
        ns.PlayAlert(item.say)
      end
    end
  end
end

local function ReadAll()
  for _, item in ipairs(ITEMS) do Read(item) end
end

ns.On("PLAYER_ENTERING_WORLD", function()
  if not ticker then return end
  ReadAll()
  ticker:SetShown(UnitAffectingCombat("player"))
end)
-- A Battle Shout already warned about last fight warns again when the next
-- one starts without it.
ns.On("PLAYER_REGEN_DISABLED", function()
  if not ticker then return end
  ITEMS[3].warned = nil
  ticker:Show()
end)
ns.On("PLAYER_REGEN_ENABLED", function()
  if not ticker then return end
  ticker:Hide()
  wipe(ITEMS[1].byTarget)
  ReadAll()
end)
ns.On("PLAYER_TARGET_CHANGED", function()
  if not ticker then return end
  ITEMS[2].seen = nil -- Demoralizing Shout's one clock: seen is per target
  Read(ITEMS[1])
  Read(ITEMS[2])
end)
ns.On("UNIT_AURA", function()
  if ticker then Read(ITEMS[3]) end
end)

-- The player's own cast restarts that aura's clock. Ranks are matched by ID,
-- or by name in case the client reports another ID for a rank. A melee cast
-- keeps the clock's old state so a miss can put it back; a miss reported
-- just before the cast means it never landed.
ns.On("UNIT_SPELLCAST_SUCCEEDED", function(_, _, spellID)
  if not ticker or issecretvalue(spellID) then return end
  local name, now = C_Spell.GetSpellName(spellID), GetTime()
  for _, item in ipairs(ITEMS) do
    if tContains(item.ranks, spellID) or name and name == item.name then
      local c = Clock(item)
      local solo = not (IsInGroup() or IsInInstance())
      if c and not (item.melee and solo and now - lastMissAt < MISS_WINDOW) then
        if item.melee then lastCast = { c = c, at = now, expires = c.expires, warned = c.warned } end
        c.expires, c.warned, c.castAt = now + item.dur, nil, now
      end
    end
  end
end)

-- A dodge, parry or miss on the target right after a melee cast takes that
-- cast back (solo only: in a group it may be someone else's attack).
ns.On("UNIT_COMBAT", function(unit, action)
  if not ticker or unit ~= "target" or issecretvalue(action) or not MISSES[action] then return end
  if IsInGroup() or IsInInstance() then return end
  local now = GetTime()
  lastMissAt = now
  if lastCast and now - lastCast.at < MISS_WINDOW then
    local c = lastCast.c
    c.expires, c.warned, c.castAt = lastCast.expires, lastCast.warned, nil
    lastCast = nil
  end
end, "target")

function ns.BuildAlerts()
  for _, item in ipairs(ITEMS) do
    item.ranks = ns.RANKS[item.key]
    item.name = C_Spell.GetSpellName(item.ranks[1])
  end
  local elapsed = 0
  ticker = CreateFrame("Frame")
  ticker:Hide()
  ticker:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < INTERVAL then return end
    elapsed = 0
    Check()
  end)
end
