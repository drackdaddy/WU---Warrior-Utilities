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
-- In combat the game hides auras from addons, so this never reads them then.
-- Instead it keeps its own clock, as Warcry does: the player's own casts
-- (UNIT_SPELLCAST_SUCCEEDED, whose spell ID is checked with issecretvalue)
-- restart that aura's clock for its full duration. Out of combat, when the
-- game does show the aura, the clock is set from it, which also catches
-- another player's Sunder or Battle Shout and learns each aura's real
-- duration. So in combat the clock can't see another warrior's Sunder or
-- Battle Shout, or a Sunder that was dodged or parried. Sunder keeps a clock
-- per target; Demoralizing Shout hits everything around the player, so it
-- keeps one.
--
-- The voice is one of Windows' text-to-speech voices (C_VoiceChat.SpeakText)
-- or a game sound (C_Sound.PlaySoundWithOptions), at the chosen volume.
-- Set up on the Battle Shout and Debuffs tabs under CDM on the options page.
-- Events: PLAYER_ENTERING_WORLD, PLAYER_REGEN_DISABLED, PLAYER_REGEN_ENABLED,
--   PLAYER_TARGET_CHANGED, UNIT_AURA, UNIT_SPELLCAST_SUCCEEDED
-- SavedVariables: sunderAlertOff, demoAlertOff, shoutAlertOff, sunderAlertSec,
--   demoAlertSec, shoutAlertSec, alertVoice, alertVolume
--------------------------------------------------------------------------------

-- Each alert: settings prefix, what is said, the unit and filter its aura is
-- read with, the duration its clock starts with until the real one is seen,
-- and whether it keeps a clock per target (byTarget, by GUID). Items without
-- byTarget hold their clock (expires, warned) themselves.
local ITEMS = {
  { key = "sunder", say = "Sunder", unit = "target", filter = "HARMFUL", dur = 30, byTarget = {} },
  { key = "demo", say = "Demo Shout", unit = "target", filter = "HARMFUL", dur = 45 },
  { key = "shout", say = "Battle Shout", unit = "player", filter = "HELPFUL", dur = 120 },
}
local SOUNDS = { -- game sounds offered after the installed voices: key, name, sound kit ID
  { "raid", "Raid Warning", 8959 }, { "ready", "Ready Check", 8960 }, { "alarm", "Alarm Clock", 12889 },
}
local VOLUME = { high = 1, medium = 0.6, low = 0.3 }
local INTERVAL = 0.2 -- seconds between checks in combat
local ticker

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

-- Out of combat only: sets item's clock from its aura when the game shows it.
-- A missing Battle Shout counts as run out, so entering combat without it
-- alerts; a missing debuff just stops its clock.
local function Sync(item)
  if UnitAffectingCombat("player") or not UnitExists(item.unit) then return end
  local c = Clock(item)
  if not c then return end
  local a = C_UnitAuras.GetAuraDataBySpellName(item.unit, item.name, item.filter)
  if issecretvalue(a) then return end
  c.warned = nil
  if not a then
    c.expires = item.unit == "player" and 0 or nil
    return
  end
  local expires, duration = a.expirationTime, a.duration
  if issecretvalue(expires) or issecretvalue(duration) or expires == 0 then return end
  c.expires = expires
  if duration > 0 then item.dur = duration end
end

local function SyncAll()
  for _, item in ipairs(ITEMS) do Sync(item) end
end

-- Plays each alert that is on once its clock reaches its warning time.
local function Check()
  local enemy = UnitCanAttack("player", "target")
  for _, item in ipairs(ITEMS) do
    local c = not db[item.key .. "AlertOff"] and (item.unit == "player" or enemy) and Clock(item)
    if c and c.expires and not c.warned and GetTime() >= c.expires - db[item.key .. "AlertSec"] then
      c.warned = true
      ns.PlayAlert(item.say)
    end
  end
end

ns.On("PLAYER_ENTERING_WORLD", function()
  if ticker then
    SyncAll()
    ticker:SetShown(UnitAffectingCombat("player"))
  end
end)
ns.On("PLAYER_REGEN_DISABLED", function()
  if ticker then ticker:Show() end
end)
ns.On("PLAYER_REGEN_ENABLED", function()
  if not ticker then return end
  ticker:Hide()
  wipe(ITEMS[1].byTarget)
  SyncAll()
end)
ns.On("PLAYER_TARGET_CHANGED", function()
  if not ticker then return end
  Sync(ITEMS[1])
  Sync(ITEMS[2])
end)
ns.On("UNIT_AURA", function()
  if ticker then Sync(ITEMS[3]) end
end)

-- The player's own cast restarts that aura's clock. Ranks are matched by ID,
-- or by name in case the client reports another ID for a rank.
ns.On("UNIT_SPELLCAST_SUCCEEDED", function(_, _, spellID)
  if not ticker or issecretvalue(spellID) then return end
  local name = C_Spell.GetSpellName(spellID)
  for _, item in ipairs(ITEMS) do
    if tContains(item.ranks, spellID) or name == item.name then
      local c = Clock(item)
      if c then c.expires, c.warned = GetTime() + item.dur, nil end
    end
  end
end)

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
