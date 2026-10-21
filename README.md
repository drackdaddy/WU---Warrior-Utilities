# WU - Warrior Utilities

A lightweight rage bar and Cooldown Manager setup (Optional) for warriors on **World of Warcraft: Forever**.

WU keeps your rage on screen with marks at the amounts you care about. Sets up Blizzard's Cooldown Manager (Optional) so Battle Shout, Demoralizing Shout and Sunder Armor are tracked right where you need them. The addon loads on warriors and druids, and settings are saved per character.

On druids you get the rage bar only: it shows in Bear Form and Dire Bear Form and hides in other forms (in Edit Mode it always shows so you can place it). The CDM tab is warriors only.

## Install

1. Unzip the addon zip.
2. Delete any older `WU - Warrior Utilities` folder from `Interface\AddOns`.
3. Copy the `WU - Warrior Utilities` folder into
   `World of Warcraft\_classic_beta_\Interface\AddOns`.
4. Restart WoW or `/reload`.
5. Log in on a warrior or druid (the addon stays off on other classes).

Settings are saved per character.

## Rage bar in Edit Mode

Open Edit Mode (**Esc > Edit Mode**) and drag the bar, or click it and use the arrow keys (**Shift** moves 10). Clicking the bar opens its Edit Mode panel:

| Setting | Notes |
| --- | --- |
| Disable Rage Bar | Hides the bar (it shows faded in Edit Mode so you can turn it back on) |
| Only Show in Combat | |
| Bar Size (%) | 50 to 200 |
| Style | Modern, Classic, Rage (default Rage) |
| Border | Rage style only: Iron, Riveted Plate, Spiked, Bloodied Bronze, Chain Link, Molten Cracks, Lava Rock, Blade Ends, None (default Molten Cracks) |
| Color | Red, Blue, Yellow, Green (default Red) |
| Disable Marks | Hides both marks and the glow |
| Mark I / Mark II | 1 to 99 (default 30 / 60) |
| Hide Mark Values | |

Plus **Reset To Default** and **Reset To Default Position**.

- These settings are per character and the same in every Edit Mode layout.
- The position is per layout; copying, renaming or deleting a layout carries it along.
- Outside Edit Mode the bar can't be moved and clicks pass through it.
- The bar does not snap to the Edit Mode grid or to other frames.

## Options

**Esc > Options > AddOns > WU - Warrior Utilities**. `/wu` opens the same page.

- **General** — how to use the addon, the slash commands and a Discord link to copy
- **CDM** (warriors only) — one section per WU layout (where each buff goes and its alerts) with a Create button, and Restore Backup

## CDM (Blizzard's Cooldown Manager)

**Create WU-Fury** adds a new Cooldown Manager layout named `WU-Fury` that holds only the buffs below. Your other layouts aren't changed. WU-Fury becomes the active layout, and the UI reloads.

| Tab | Section | Buff | Alerts |
| --- | --- | --- | --- |
| Buffs | Tracked Buffs | Battle Shout | None |
| Buffs | Tracked Buffs | Demoralizing Shout | None |
| Buffs | Tracked Buffs | Sunder Armor | On Aura Removed: Text to Speech |

- The buffs are listed in their section in this order. A buff can have up to 3 alerts.
- The Cooldown Manager plays the alerts itself, so they work in combat.
- The Cooldown Manager has no "seconds remaining" alert, so there is no warning before Sunder falls off.
- Pressing Create again rebuilds the WU-Fury layout instead of adding another one.
- A layout named `WU` made by an older version is renamed to `WU-Fury` the first time you press Create.
- Out of combat only.

The first Create saves your previous layouts. **Restore Backup** puts them back (Cooldown Manager changes made since then are lost) and reloads the UI. If you had no layouts, there is nothing to back up and no backup is saved.

> The Cooldown Manager's saved data format is not documented by Blizzard. If a patch changes it, Create refuses and changes nothing.

## Slash commands

| Command | Action |
| --- | --- |
| `/wu` | Open options |
| `/wu 30 60` | Set marks |
| `/wu reset` | Reset all settings and bar positions in every layout to default (keeps the Cooldown Manager backup) |

`/wuutil` is an alias.

## Files

| File | Contents |
| --- | --- |
| `Libs\LibEditMode` | LibEditMode by p3lim (Edit Mode support), embedded unmodified; see its `LICENSE.txt` |
| `Core.lua` | Settings and event dispatch |
| `RageBar.lua` | Rage bar, marks, glow, styles, borders, size, Edit Mode position and settings |
| `CDM.lua` | WU Cooldown Manager layouts (create, restore) |
| `Options.lua` | Options page in Esc > Options > AddOns, slash commands |

## Glow

- **Mark I:** bar glow at the first mark.
- **Mark II:** brighter glow at the second mark.
- Marks are a percent of max rage (100 for warriors).
- Rage bar styles: **Modern** (flat), **Classic** (vanilla gold frame), **Rage** (fiery fill with a choice of eight borders, or none).

## Disclaimer

This addon was made with the assistance of Claude AI.
