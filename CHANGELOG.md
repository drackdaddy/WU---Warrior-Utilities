# Changelog

Changes in each version of WU - Warrior Utilities, newest first. The same list is in game: **Change Log** at the top right of the options page (`/wu`).

## 3.12.0 (2026-11-27)

### Added
- Vertical in Edit Mode for WU Trinket Bar and WU Gear Bar: shows the bar as a column instead of a row, with the swap list opening beside the slot.
- Show tooltips on the Trinket tab turns off the item tooltips on the trinket and gear bars and the swap list.
- The options window has a new look: a sidebar on the left lists every tab with its sub-tabs under it, and it comes in four themes, Standard (the game's own menu look), Arms (leather and bronze), Fury (blackened steel and blood red) and Protection (cold iron and blue), picked under Options window > Colors on the General tab.
- The trinket rotation now works in combat too: when your trinket goes on cooldown in a fight, the next one on the list is queued and shown on the slot (gold border and icon), and goes on when combat ends.
- Getting off your mount in combat now queues the swap back like a pick made in combat: the slot shows the gold border and your trinket's icon, and it goes on when combat ends.
- A swap waiting for combat to end now shows a small icon of the incoming item in the bottom left corner of the slot, along with the gold border.
- The Desert Rose as a riding trinket: it goes on when you mount in a sandy zone (Tanaris and Silithus), with Carrot on a Stick or Riding Crop elsewhere, and swaps as you ride in or out.

### Changed
- The mount option is now "Riding trinket when mounted".
- The options are now their own window instead of a page in Esc > Options > AddOns, so /wu and the minimap icon open them in combat too. Drag it to move it; /wu, the icon, Esc or the X close it.

### Removed
- The WU page in Esc > Options > AddOns (now its own window).

### Fixed
- After a swap back failed once, the riding trinket could stay on for good, as the addon forgot which trinket it had replaced. It now always remembers the trinket you wear in that slot off the mount.
- Mining, crafting or any other cast that took you off your mount made the swap back fail. It now waits until the cast and any loot window are done, then swaps at once.
- Getting off your mount in combat could fill the screen with "You can't do that right now" (the swap back was tried twice a second while you looted or swung) and sometimes left the riding trinket in the other slot, as the rotation took your own trinket first. The swap back now tries every 3 seconds, and the rotation leaves your trinket alone until it is back on.
- The trinket and gear bar tooltips, and the swap list's, now show in the game's usual tooltip spot instead of over the swap list.
- Getting off your mount didn't always put back the trinket the riding trinket replaced. It now keeps trying until the trinket is back, and the trinket rotation no longer takes that trinket while you ride.

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
- Border around the trinket and gear bars: none, thin line, dark panel, tooltip or gold.
- Right-click the minimap icon to unlock the trinket bars and drag them (out of combat), and again to lock them.
- Combat Text tab with a Mover sub-tab, adapted from SCT Mover by KidMoxie (MIT): sliders to lift or lower the game's damage numbers above your target (clear of nameplates), and draw the numbers near your character above other UI or move them anywhere, with sliders or by dragging a box with sample text.
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
