# WU - Warrior Utilities

A lightweight rage bar, out of range warning, Battle Shout timer and stance cooldown bar for warriors on **World of Warcraft: Forever**.

WU keeps your rage on screen with marks at the amounts you care about, warns you when your target is out of melee range, shows how long your Battle Shout has left on the player frame, and tracks the key cooldowns for the stance you're in. The addon loads on warriors and druids, and settings are saved per character.

On druids you get the rage bar only: it shows in Bear Form and Dire Bear Form and hides in other forms (in Edit Mode it always shows so you can place it). The range warning, Battle Shout timer and cooldown bar are warriors only.

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

## Out of range warning (warriors only)

Flashes **OUT OF RANGE** while you have a living enemy targeted that is out of melee range (Heroic Strike range). In Edit Mode, click **WU Range Warning** to move it and open its panel:

| Setting | Notes |
| --- | --- |
| Disable Range Warning | Turns the warning off (it shows faded in Edit Mode so you can turn it back on) |
| Font | Friz Quadrata, Arial Narrow, Morpheus, Skurri (default Friz Quadrata) |
| Font Size | 16 to 64 (default 32) |
| Flash | Pulse, Blink, Steady (no flash) (default Pulse) |
| Flash Speed | Slow, Normal, Fast (default Normal) |

Its position is per Edit Mode layout, like the rage bar's.

## Battle Shout timer (warriors only)

Shown on Blizzard's player frame, behind your name. It hides and scales with the player frame.

- A bar empties as your Battle Shout runs down. It is hidden while you don't have the buff.
- A countdown at the right end of your name shows the time left.
- Your name flashes red while Battle Shout is missing in combat, and **Battle Shout Missing** shows above the player frame.
- The game tracks the buff itself through Blizzard's aura containers and draws the bar, countdown, flash and warning, so it all works in combat. It sees any Battle Shout on you, including another warrior's, and notices when it's cancelled or removed.
- It only attaches to Blizzard's player frame.

Set it up on the **Battle Shout** tab of the options page (`/wu`):

| Setting | Notes |
| --- | --- |
| Show Battle Shout timer | Turns the whole timer on or off (default on) |
| Show countdown | The time left next to your name (default on) |
| Flash when missing in combat | (default on) |
| Show "Battle Shout Missing" text | The warning above the player frame (default on) |
| Text size | Size of that warning, 10 to 30 (default 14) |
| Bar color | Opens the color picker, with opacity. **Default** puts back orange |

## Cooldown bar (warriors only)

A row of icons for the stance you're in, each with the cooldown swipe and the time left. Switching stance swaps the bar. Abilities you haven't learned are left off.

| Stance | Abilities |
| --- | --- |
| Battle | Charge, Overpower, Thunder Clap, Mocking Blow, Mortal Strike, Sweeping Strikes, Retaliation, Bloodrage |
| Defensive | Taunt, Shield Block, Revenge, Shield Slam, Shield Bash, Disarm, Last Stand, Shield Wall, Bloodrage |
| Berserker | Intercept, Bloodthirst, Whirlwind, Pummel, Berserker Rage, Death Wish, Recklessness, Bloodrage |

Each stance has its own tab on the options page (`/wu`):

| Setting | Notes |
| --- | --- |
| Show cooldown bar | Turns that stance's bar on or off (default on) |
| Glow when ready | A pulsing gold border on each ability that is off cooldown (default on) |
| Abilities | One checkbox per ability (all on by default) |

- The glow also stays on during the global cooldown, so it doesn't blink after every ability. It shows cooldown only: Overpower and Revenge glow when off cooldown even if they can't be used yet.
- The game draws the swipe and glow from the cooldown itself, so it works in combat without the addon reading cooldown times.
- In Edit Mode, click **WU Cooldown Bar** to move it and set **Icon Size** (24 to 64, default 36). Its position is per Edit Mode layout.
- The icons only display cooldowns; clicking them does nothing.

## Options

**Esc > Options > AddOns > WU - Warrior Utilities**. `/wu` opens the same page.

- **General** — how to use the addon, the slash commands and a Discord link to copy
- **Battle Shout** (warriors only) — the Battle Shout timer settings
- **Battle**, **Defensive**, **Berserker** (warriors only) — each stance's cooldown bar

## Slash commands

| Command | Action |
| --- | --- |
| `/wu` | Open options |
| `/wu 30 60` | Set marks |
| `/wu reset` | Reset all settings (including the Battle Shout timer and cooldown bar settings) and bar, range warning and cooldown bar positions in every layout to default |

`/wuutil` is an alias.

## Files

| File | Contents |
| --- | --- |
| `Libs\LibEditMode` | LibEditMode by p3lim (Edit Mode support), embedded unmodified; see its `LICENSE.txt` |
| `Core.lua` | Settings, shared Edit Mode helpers and event dispatch |
| `RageBar.lua` | Rage bar, marks, glow, styles, borders, size, Edit Mode position and settings |
| `RangeWarning.lua` | Out of range warning and its Edit Mode settings |
| `ShoutTimer.lua` | Battle Shout timer on the player frame |
| `CooldownBar.lua` | Cooldown bar for each stance and its Edit Mode settings |
| `Options.lua` | Options page in Esc > Options > AddOns (including the stance tabs), slash commands |

## Glow

- **Mark I:** bar glow at the first mark.
- **Mark II:** brighter glow at the second mark.
- Marks are a percent of max rage (100 for warriors).
- Rage bar styles: **Modern** (flat), **Classic** (vanilla gold frame), **Rage** (fiery fill with a choice of eight borders, or none).

## Disclaimer

This addon was made with the assistance of Claude AI.
