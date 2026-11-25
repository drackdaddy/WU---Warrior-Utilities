# Changelog

Changes in each version of WU - Warrior Utilities, newest first. The same list is in game: **Change Log** at the top right of the options page (`/wu`).

## 3.11.0 (2026-11-25)

### Added
- Debuff tracker: Sunder Armor (stacks and time left) and Demoralizing Shout (Demoralizing Roar and Curse of Weakness count too) on your target, from any caster. Moved in Edit Mode (WU Debuffs); set up on CDM > Debuffs.
- Debuff countdown position (middle, above or below the icon), font and color.
- Audio alerts when Sunder Armor or Demoralizing Shout is about to fall off your target, or Battle Shout is about to run out (or missing as combat starts). Each alert has its own switch and warning time.
- Alert voice (your installed Windows voices or game sounds) and volume (High, Medium, Low) on the General tab, with a Test button.
- Custom cooldown bar (CDM > Custom): track any spell or item, such as a trinket, by its ID. Moved in Edit Mode (WU Custom Bar).
- Appearance tab (CDM > Appearance): glow style (pulsing border, marching sparks, static border), color, speed, thickness and glow out of combat, and how icons look on cooldown (normal, greyed out, faded, hidden), with a preview.
- Each ability can have its own glow type.
- Trinket tab, adapted from Forever Trinket Menu by sk0lu (MIT): a trinket bar (click or a key to use, cooldowns), a list of the trinkets in your bags to swap in, picks made in combat put on when it ends, a trinket rotation per slot and your riding trinket while mounted.
- Usable gear bar (off by default) for other on-use gear: engineering helms, cloaks, rings and weapons, with the same swap list.
- This change log, from the Change Log button on the options page.

### Changed
- Battle Shout settings moved under CDM.
- The three stance tabs are now one Stances page with a stance dropdown.
- Abilities show as icons: click one to set it up, drag it to move it.

### Removed
- The top-level Battle Shout tab.
- The Battle, Defensive and Berserker sub-tabs (now the Stances page).
- The ability checkboxes and Up/Down buttons (now the icons).

### Fixed
- Victory Rush, Overpower and Revenge looked ready before their trigger. Icons now grey out whenever the game says they can't be used.

## 3.7.0 (2026-11-23)

### Added
- Range display adapted from Good Range by artand: distance to your target, colored by what you can reach it with, with Tape, Label + Number, Label Only and Number Only looks.
- Range on your target's nameplate, focus and mouseover labels, an option for friendly players, zones set by hand and /wu range debug commands.
- Minimap icon that opens the options.
- A glow switch for each ability on the cooldown bars.
- Cooldown icons grey out while you don't have the rage for them.

### Changed
- The stance tabs moved under a CDM tab.

### Removed
- The OUT OF RANGE melee warning (replaced by the range display).

## 3.6.2 (2026-11-23)

### Added
- A third rage mark. 0 turns a mark off, and the highest mark glows brightest.

## 3.6.1 (2026-11-18)

### Added
- Cooldown bar for each stance, with a ready glow and a tab per stance.
- Each stance's abilities can be reordered.
- Only Show in Combat in the cooldown bar's Edit Mode settings.
- Victory Rush on every stance's bar, and Reckless Swings on Berserker Stance's.

### Changed
- Icons only glow when the ability can be used (enough rage, Victory Rush's window).

## 3.6.0 (2026-11-17)

### Added
- Battle Shout timer on the player frame: a bar and countdown behind your name, drawn by the game so it works in combat.
- A red flash and a "Battle Shout Missing" warning (with a text size setting) while Battle Shout is missing in combat.
- Battle Shout bar color.

### Changed
- The General tab is in two columns so it fits the window.

### Removed
- The CDM tab and the Cooldown Manager layouts (WU-Fury).

### Fixed
- The missing-Battle-Shout flash stayed on after recasting it in combat.

## 3.5.8 (2026-10-28)

### Added
- OUT OF RANGE melee warning, set up in Edit Mode.

## 3.5.7 (2026-10-28)

### Fixed
- The CDM layout wasn't created for characters with only the default Cooldown Manager layout.

## 3.5.6 (2026-10-20)

### Added
- The rage bar works for druids in Bear Form and Dire Bear Form.

## 3.5.5 (2026-10-12)

### Added
- WU-Fury Cooldown Manager layout, with only its buffs, and a CDM tab with a section per layout.
- The General tab explains the addon, with slash commands and a Discord link to copy.

### Removed
- Unused textures and the options sync.

### Fixed
- The CDM tab pointed to Tracked Buffs in the wrong place (it is under the Buffs tab).

## 3.5.0 (2026-10-11)

### Added
- Border choice for the Rage style: eight borders or none.
- Molten cracks frame art for the Rage style.

### Removed
- The minimap compartment entry.

### Fixed
- New border textures weren't drawn correctly.
