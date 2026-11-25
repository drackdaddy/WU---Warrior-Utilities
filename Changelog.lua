local _, ns = ...

--------------------------------------------------------------------------------
-- Change log
-- Every version's changes, newest first, shown by the Change Log button on
-- the options page (see Options.lua). Addons can't read files from disk in
-- game, so the history lives here; CHANGELOG.md in the repo has the same
-- text. Add a new version at the top of both on each release.
-- Each version: version, date (YYYY-MM-DD) and its added, changed, removed
-- and fixed lists (any may be left out).
--------------------------------------------------------------------------------
ns.CHANGELOG = {
  { version = "3.11.1", date = "2026-11-25",
    fixed = {
      "Getting off your mount didn't always put back the trinket the riding trinket replaced. It now keeps trying until the trinket is back, and the trinket rotation no longer takes that trinket while you ride.",
    },
  },
  { version = "3.11.0", date = "2026-11-25",
    added = {
      "Debuff tracker: Sunder Armor (stacks and time left) and Demoralizing Shout (Demoralizing Roar and Curse of Weakness count too) on your target, from any caster. Moved in Edit Mode (WU Debuffs); set up on CDM > Debuffs.",
      "Debuff countdown position (middle, above or below the icon), font and color.",
      "Audio alerts when Sunder Armor or Demoralizing Shout is about to fall off your target, or Battle Shout is about to run out (or missing as combat starts). Each alert has its own switch and warning time.",
      "Alert voice (your installed Windows voices or game sounds) and volume (High, Medium, Low) on the General tab, with a Test button.",
      "Custom cooldown bar (CDM > Custom): track any spell or item, such as a trinket, by its ID. Moved in Edit Mode (WU Custom Bar).",
      "Appearance tab (CDM > Appearance): glow style (pulsing border, marching sparks, static border), color, speed, thickness and glow out of combat, and how icons look on cooldown (normal, greyed out, faded, hidden), with a preview.",
      "Each ability can have its own glow type.",
      "Trinket tab, adapted from Forever Trinket Menu by sk0lu (MIT): a trinket bar (click or a key to use, cooldowns), a list of the trinkets in your bags to swap in, picks made in combat put on when it ends, a trinket rotation per slot and your riding trinket while mounted.",
      "Usable gear bar (off by default) for other on-use gear: engineering helms, cloaks, rings and weapons, with the same swap list.",
      "Border around the trinket and gear bars: none, thin line, dark panel, tooltip or gold.",
      "Right-click the minimap icon to unlock the trinket bars and drag them (out of combat), and again to lock them.",
      "Combat Text tab with a Mover sub-tab, adapted from SCT Mover by KidMoxie (MIT): sliders to lift or lower the game's damage numbers above your target (clear of nameplates), and draw the numbers near your character above other UI or move them anywhere, with sliders or by dragging a box with sample text.",
      "This change log, from the Change Log button on the options page.",
    },
    changed = {
      "Battle Shout settings moved under CDM.",
      "The three stance tabs are now one Stances page with a stance dropdown.",
      "Abilities show as icons: click one to set it up, drag it to move it.",
    },
    removed = {
      "The top-level Battle Shout tab.",
      "The Battle, Defensive and Berserker sub-tabs (now the Stances page).",
      "The ability checkboxes and Up/Down buttons (now the icons).",
    },
    fixed = {
      "Victory Rush, Overpower and Revenge looked ready before their trigger. Icons now grey out whenever the game says they can't be used.",
    },
  },
  { version = "3.7.0", date = "2026-11-23",
    added = {
      "Range display adapted from Good Range by artand: distance to your target, colored by what you can reach it with, with Tape, Label + Number, Label Only and Number Only looks.",
      "Range on your target's nameplate, focus and mouseover labels, an option for friendly players, zones set by hand and /wu range debug commands.",
      "Minimap icon that opens the options.",
      "A glow switch for each ability on the cooldown bars.",
      "Cooldown icons grey out while you don't have the rage for them.",
    },
    changed = {
      "The stance tabs moved under a CDM tab.",
    },
    removed = {
      "The OUT OF RANGE melee warning (replaced by the range display).",
    },
  },
  { version = "3.6.2", date = "2026-11-23",
    added = {
      "A third rage mark. 0 turns a mark off, and the highest mark glows brightest.",
    },
  },
  { version = "3.6.1", date = "2026-11-18",
    added = {
      "Cooldown bar for each stance, with a ready glow and a tab per stance.",
      "Each stance's abilities can be reordered.",
      "Only Show in Combat in the cooldown bar's Edit Mode settings.",
      "Victory Rush on every stance's bar, and Reckless Swings on Berserker Stance's.",
    },
    changed = {
      "Icons only glow when the ability can be used (enough rage, Victory Rush's window).",
    },
  },
  { version = "3.6.0", date = "2026-11-17",
    added = {
      "Battle Shout timer on the player frame: a bar and countdown behind your name, drawn by the game so it works in combat.",
      "A red flash and a \"Battle Shout Missing\" warning (with a text size setting) while Battle Shout is missing in combat.",
      "Battle Shout bar color.",
    },
    changed = {
      "The General tab is in two columns so it fits the window.",
    },
    removed = {
      "The CDM tab and the Cooldown Manager layouts (WU-Fury).",
    },
    fixed = {
      "The missing-Battle-Shout flash stayed on after recasting it in combat.",
    },
  },
  { version = "3.5.8", date = "2026-10-28",
    added = {
      "OUT OF RANGE melee warning, set up in Edit Mode.",
    },
  },
  { version = "3.5.7", date = "2026-10-28",
    fixed = {
      "The CDM layout wasn't created for characters with only the default Cooldown Manager layout.",
    },
  },
  { version = "3.5.6", date = "2026-10-20",
    added = {
      "The rage bar works for druids in Bear Form and Dire Bear Form.",
    },
  },
  { version = "3.5.5", date = "2026-10-12",
    added = {
      "WU-Fury Cooldown Manager layout, with only its buffs, and a CDM tab with a section per layout.",
      "The General tab explains the addon, with slash commands and a Discord link to copy.",
    },
    removed = {
      "Unused textures and the options sync.",
    },
    fixed = {
      "The CDM tab pointed to Tracked Buffs in the wrong place (it is under the Buffs tab).",
    },
  },
  { version = "3.5.0", date = "2026-10-11",
    added = {
      "Border choice for the Rage style: eight borders or none.",
      "Molten cracks frame art for the Rage style.",
    },
    removed = {
      "The minimap compartment entry.",
    },
    fixed = {
      "New border textures weren't drawn correctly.",
    },
  },
}
