# WU - Warrior Utilities

A lightweight rage bar, range display, Battle Shout timer, debuff tracker and stance cooldown bar for warriors on **World of Warcraft: Forever**.

WU keeps your rage on screen with marks at the amounts you care about, shows how far your target is and what you can reach it with, shows how long your Battle Shout has left on the player frame, tracks Sunder Armor and Demoralizing Shout on your target, and tracks the key cooldowns for the stance you're in. The addon loads on warriors and druids, and settings are saved per character.

On druids you get the rage bar only: it shows in Bear Form and Dire Bear Form and hides in other forms (in Edit Mode it always shows so you can place it). The range display, Battle Shout timer, debuff tracker and cooldown bar are warriors only.

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
| Disable Marks | Hides all marks and the glow |
| Mark I / Mark II / Mark III | 0 to 99, 0 turns that mark off (default 30 / 60 / 0) |
| Hide Mark Values | |

Plus **Reset To Default** and **Reset To Default Position**.

- These settings are per character and the same in every Edit Mode layout.
- The position is per layout; copying, renaming or deleting a layout carries it along.
- Outside Edit Mode the bar can't be moved and clicks pass through it.
- The bar does not snap to the Edit Mode grid or to other frames.

## Range display (warriors only)

Shows how far your target is, in yards, colored by what you can do from there. Adapted from [Good Range](https://www.curseforge.com/wow/addons/good-range-target-distance-range-finder) by Andrii Zolotarenko (MIT).

| Color | Meaning |
| --- | --- |
| Green | Melee range (0 to 5 yd) |
| Blue | Charge, Intercept, Throw or Shoot range, while you can use it right now (enough rage, the right stance and weapon, off cooldown); the label names it |
| Red | Dead zone: too close for those, too far for melee |
| Grey | Out of range, or a friendly player (**FRIENDLY**: a warrior has no heals or buffs to reach them with) |

- The game only answers "in range or not" at fixed ranges (range-check items, interact distances and your own spells). WU checks the ones around the last reading many times a second and estimates the distance smoothly between them from how fast you and the target move.
- Answers the game hides in combat are skipped, never read. If none are left, the display turns grey and says **no data**. On friendly players in combat the game allows no item or interact checks, so expect **no data** there.
- It only reads range answers; it never casts or targets anything.

Set it up on the **Range** tab of the options page (`/wu`), which has three sub-tabs.

**Display**

| Setting | Notes |
| --- | --- |
| Show range display | Turns the whole feature on or off (default on) |
| Show out of combat | (default on) |
| Show on friendly players | Friendly NPCs never show (default off) |
| Show "yd" after the number | (default on) |
| Look | Tape (a sliding ruler), Label + Number, Label Only, Number Only (default Tape) |
| Font | Changa Bold, Skurri, Arial Narrow, 2002 Bold, Friz Quadrata, Nimrod, Morpheus (default Changa Bold) |
| Font size | 12 to 64 (default 32) |
| Opacity (%) | 10 to 100 (default 100); also used by the labels |
| Width, Height, Pixels per yard | Tape look only (default 130, 31 and 20) |

**Nameplate & Labels**

| Setting | Notes |
| --- | --- |
| Show on | Screen, Nameplate, Screen and Nameplate (default Screen). Nameplate uses the screen spot while the target has no nameplate |
| Height above nameplate | 0 to 60 (default 4) |
| Nameplate size (%) | 50 to 150 (default 100) |
| Focus label | A small label with the distance to your focus (default off). With nameplates on, it sits on the focus's nameplate |
| Mouseover label | A small label beside the cursor with the distance to the unit under it, when that isn't your target (default off) |
| Label size (%) | 50 to 200 (default 100) |

**Zones**

| Setting | Notes |
| --- | --- |
| Automatic zones | Zones follow what you can use right now (default on) |
| Melee (green) to, Dead zone (red) to, Ranged (blue) to | With automatic zones off: the zones run in a row from 0 yd, each ending where you set it, 0 to 50 (default 5, 8, 25). Set one to the same as the zone before it to leave it out |
| Colors | Melee, Ranged, Dead zone and Out of range colors. **Default** puts one back |

In Edit Mode, click **WU Range Display** to move the screen display, or **WU Range Focus** to move the focus label (positions are per Edit Mode layout). Each can be turned off there too. In Edit Mode they show sample values when there's nothing to measure.

## Battle Shout timer (warriors only)

Shown on Blizzard's player frame, behind your name. It hides and scales with the player frame.

- A bar empties as your Battle Shout runs down. It is hidden while you don't have the buff.
- A countdown at the right end of your name shows the time left.
- Your name flashes red while Battle Shout is missing in combat, and **Battle Shout Missing** shows above the player frame.
- The game tracks the buff itself through Blizzard's aura containers and draws the bar, countdown, flash and warning, so it all works in combat. It sees any Battle Shout on you, including another warrior's, and notices when it's cancelled or removed.
- It only attaches to Blizzard's player frame.

Set it up on the **Battle Shout** sub-tab under **CDM** on the options page (`/wu`):

| Setting | Notes |
| --- | --- |
| Show Battle Shout timer | Turns the whole timer on or off (default on) |
| Show countdown | The time left next to your name (default on) |
| Flash when missing in combat | (default on) |
| Show "Battle Shout Missing" text | The warning above the player frame (default on) |
| Text size | Size of that warning, 10 to 30 (default 14) |
| Bar color | Opens the color picker, with opacity. **Default** puts back orange |

## Debuff tracker (warriors only)

A row of icons for the debuffs you keep on an enemy target. It shows while you target something you can attack.

- **Sunder Armor**: the stack count (the game shows it from 2 stacks up) and the time left.
- **Demoralizing Shout**: the time left. **Demoralizing Roar** (druid) and **Curse of Weakness** (warlock) fill the same slot.
- A dimmed icon means that debuff is missing from the target. Every player's debuffs count, not just yours.
- The game tracks the debuffs itself through Blizzard's aura containers and draws the icons, stacks and countdowns, so it works in combat without the addon reading the target's debuffs.
- In Edit Mode, click **WU Debuffs** to move it, set **Icon Size** (24 to 64, default 36) and turn on **Only Show in Combat** (default off). Its position is per Edit Mode layout.

Set it up on the **Debuffs** sub-tab under **CDM** on the options page (`/wu`):

| Setting | Notes |
| --- | --- |
| Show debuff tracker | Turns the whole tracker on or off (default on) |
| Track Sunder Armor | (default on) |
| Track Demoralizing Shout | (default on) |
| Position | Where the countdown goes: Middle, Above the icon, Below the icon (default Middle) |
| Font | The countdown's font: Changa Bold, Skurri, Arial Narrow, 2002 Bold, Friz Quadrata, Nimrod, Morpheus (default Friz Quadrata) |
| Color | The countdown's color. **Default** puts back white |

## Audio alerts (warriors only)

In combat, WU says the name out loud when **Sunder Armor** or **Demoralizing Shout** is about to fall off your target, or when your **Battle Shout** is about to run out. Battle Shout also alerts when you enter combat without it.

- Each aura is tracked the way Ultimate Warrior does it. WU reads the target's debuffs (or your buffs) whenever the game allows, from any caster; when the target's list is hidden in combat it tries the same mob's nameplate. Anything the game hides is skipped, never read.
- While the list is hidden, your own casts time it: casting Sunder, Demoralizing Shout or Battle Shout restarts that timer. A Sunder that is dodged, parried or misses is taken back when you're solo (in a group the dodge could be someone else's attack).
- An empty list only ends a timer early once WU has seen that debuff on the target and you're solo; in groups and instances the game can return an empty list for a mob that has the debuff. Sunder is timed per target; Demoralizing Shout once, as it hits everything around you.
- Sunder and Demoralizing Shout only alert while you target an enemy.

| Setting | Where | Notes |
| --- | --- | --- |
| Sunder Armor alert, Demoralizing Shout alert | CDM > Debuffs | (default on) |
| Battle Shout alert | CDM > Battle Shout | (default on) |
| Seconds left | Next to each alert | When it plays, 0 to 10 (default 5); 0 plays when it runs out |
| Voice | General | Five choices: your installed Windows text-to-speech voices first, then the Raid Warning, Ready Check and Alarm Clock sounds. **Test** plays it |
| Volume | General | High, Medium, Low (default High) |

## Cooldown bar (warriors only)

A row of icons for the stance you're in, each with the cooldown swipe and the time left. Switching stance swaps the bar. Abilities you haven't learned are left off.

| Stance | Abilities |
| --- | --- |
| Battle | Charge, Overpower, Thunder Clap, Mocking Blow, Mortal Strike, Sweeping Strikes, Retaliation, Victory Rush, Bloodrage |
| Defensive | Taunt, Shield Block, Revenge, Shield Slam, Shield Bash, Disarm, Last Stand, Shield Wall, Victory Rush, Bloodrage |
| Berserker | Intercept, Bloodthirst, Whirlwind, Reckless Swings, Pummel, Berserker Rage, Death Wish, Recklessness, Victory Rush, Bloodrage |

Set the bars up on the **Stances** sub-tab under **CDM** on the options page (`/wu`). Pick a stance from the **Stance** dropdown at the top to set up its bar:

| Setting | Notes |
| --- | --- |
| Show cooldown bar | Turns that stance's bar on or off (default on) |
| Glow when ready | Turns the ready glow off for that whole bar (default on) |
| Abilities | One icon per ability, in bar order (top left is leftmost); off icons show faded and a gold tick marks the ones that glow. **Click** an icon to select it, then set it up below the icons: **Show on bar**, **Glow when ready** and **Glow type** (the Appearance setting, or its own: Pulsing border, Marching sparks, Static border). **Drag** an icon onto another to move it |

- The glow only shows when you could cast the ability: it's off cooldown, you have the rage for it, and any trigger it needs has happened (Victory Rush after a kill, Overpower after a dodge, Revenge after a block, dodge or parry). It stays on during the global cooldown, so it doesn't blink after every ability.
- An icon greys out while you can't use it: not enough rage, or a trigger it needs hasn't happened (Victory Rush, Overpower, Revenge). The game answers that itself, so it works in combat too.
- The game draws the swipe and glow from the cooldown itself, so it works in combat without the addon reading cooldown times.
- In Edit Mode, click **WU Cooldown Bar** to move it, set **Icon Size** (24 to 64, default 36) and turn on **Only Show in Combat** (default off). Its position is per Edit Mode layout.
- The icons only display cooldowns; clicking them does nothing.

### Appearance

The **Appearance** sub-tab under **CDM** sets how the icons on every cooldown bar look (each stance's bar and the custom bar), with a preview of an icon that is ready and one on cooldown:

| Setting | Notes |
| --- | --- |
| Glow | Pulsing border, Marching sparks (bright dashes running around the edge) or Static border (default Pulsing border). An ability can have its own on the Stances and Custom tabs |
| Glow color | **Default** puts back gold |
| Speed | Slow, Medium, Fast (default Medium); not for the static border |
| Thickness | 1 to 4 (default 2) |
| Glow out of combat | Off: the glow only shows in combat (default on) |
| While on cooldown: Icon | Normal, Greyed out, Faded, Hidden (default Normal). Hidden icons keep their place on the bar |

- Every effect is drawn by the game from the cooldown itself, so it all works in combat. Items on the custom bar only show their cooldown swipe.

## Custom bar (warriors only)

A bar for any cooldowns you want to watch, such as trinkets. Set it up on the **Custom** sub-tab under **CDM** (`/wu`):

- Type a spell ID or an item ID (for trinkets and other usable items) and press **Add**. A number can be both a spell and an item, so WU picks, in order: an item you have equipped or in your bags, a spell you know, any item, any spell. The row shows which it picked. You can find IDs on Wowhead: it's the number in the page's address.
- Up to 12 entries, shown as icons in bar order (top left is leftmost). **Click** an icon to select it, then set it up below the icons: **Show on bar**, **Glow when ready** and **Glow type** (spells only; items can't glow), or **Remove** it. **Drag** an icon onto another to move it. The bar's icons use the look set on the **Appearance** sub-tab.
- **Show custom bar** turns it on or off (default on).
- Each icon shows the game's cooldown swipe and countdown, so it works in combat without the addon reading cooldown times. The icons only display cooldowns; clicking them does nothing.
- In Edit Mode, click **WU Custom Bar** to move it, set **Icon Size** (24 to 64, default 36) and turn on **Only Show in Combat** (default off). Its position is per Edit Mode layout.

## Trinket bar (warriors only)

Adapted from [Forever Trinket Menu](https://www.curseforge.com/wow/addons/forever-trinket-menu) by sk0lu (MIT). Set it up on the **Trinket** tab of the options page (`/wu`).

- **Trinket bar**: your two trinkets. Click one, or its key (**Esc > Key Bindings > WU - Warrior Utilities**: Use Trinket 1 and 2), to use it. Each shows its cooldown and key.
- **Swap list**: hover a slot to see the items in your bags that fit it (for a trinket, also the one in the other slot); click one to put it on. In combat the game won't change gear, so the pick waits (gold border, with a small icon of the incoming item in the bottom left corner) and goes on when combat ends.
- **Usable gear bar** (off by default): the same for your other gear with a "Use:" effect, worn or in your bags (engineering helms, cloaks, rings, weapons).
- **Rotation**: **Alt+click** a trinket in the swap list to add it to that slot's list (or take it off). With **Rotate Trinket 1/2** on, when the trinket you wear is on cooldown, the first ready one on the list goes on; in combat it is queued, shown on the slot, and goes on when combat ends. One with 30 seconds or less left counts as ready, as putting a trinket on starts a 30 second cooldown anyway. A ready trinket stays on until you use it, and one without a "Use:" effect is left alone. Drag icons on the Trinket tab to change the order; **Remove selected** takes one off.
- **Mount**: with **Riding trinket when mounted** on, your riding trinket goes in the chosen slot when you mount: The Desert Rose in sandy zones (Tanaris and Silithus), otherwise Carrot on a Stick or Riding Crop. Riding into or out of a sandy zone swaps between them, and the trinket it replaced goes back when you get off. Getting off in combat queues the swap back, shown on the slot like a pick made in combat.
- The buttons only use an item when you click them; nothing is ever used or cast for you. In Edit Mode, **WU Trinket Bar** and **WU Gear Bar** each have **Icon Size** and **Only Show in Combat**.
- **Moving**: in Edit Mode, or **right-click the minimap icon** to unlock the bars (they turn blue) and drag them; right-click again to lock. Out of combat only; combat starting locks them. The spot is saved for your current Edit Mode layout.

| Setting | Notes |
| --- | --- |
| Show trinket bar | (default on) |
| Show the list on hover | The swap list (default on) |
| Show usable gear bar | (default off) |
| Bar border | Around both bars: None, Thin line, Dark panel, Tooltip, Gold (default None) |
| Riding trinket when mounted | (default off); **Put it in** Trinket 1 or Trinket 2 (default Trinket 2) |
| Rotate Trinket 1, Rotate Trinket 2 | (default off) |

## Combat text (warriors only)

Adapted from [SCT Mover](https://github.com/dbspringer/sct-mover) by KidMoxie (MIT). It moves the game's own combat text; it doesn't draw its own. Set it up on the **Mover** sub-tab under **Combat Text** (`/wu`).

- **Target text**: the numbers above your target (damage you deal, heals, misses). **Target height** (a slider, -40 to 40, default 0) lifts or lowers them, for example clear of nameplates; **Reset height** puts them back. It's a game setting, so it stays even with WU off.
- **Self text**: the numbers near your character (damage you take, heals you get). **Show above other UI elements** draws them on top. The **Horizontal** and **Vertical** sliders move them, or click **Move** for a box with sample text where they start: drag it, then **Done**. **Reset position** puts them back. Not in combat. Greyed out while self text is off in the game's options.
- In Forever, an addon that writes to the game's combat text frame breaks it (the amounts are secret values), so WU only moves it with an animation, and draws the sample text itself.

## Options

**Esc > Options > AddOns > WU - Warrior Utilities**. `/wu` or the minimap icon opens the same page.

**Change Log** at the top right shows what changed in each version (new, changed, removed, fixed); pick a version from the **Version** dropdown or show all. The same list is in `CHANGELOG.md`.

The minimap icon opens the options when clicked; on warriors, right-clicking it unlocks or locks the trinket bars for dragging. Drag the icon to move it around the minimap's edge. **Show minimap icon** on the General tab hides it (default on).

- **General** — how to use the addon, the minimap icon switch, the slash commands, a Discord link to copy and the audio alert voice and volume (warriors)
- **Range** (warriors only) — the range display settings, in Display, Nameplate & Labels and Zones sub-tabs
- **Combat Text** (warriors only) — moving the game's combat text, on the **Mover** sub-tab
- **Trinket** (warriors only) — the trinket and usable gear bars, rotation and mount swap
- **CDM** (warriors only) — each stance's cooldown bar on **Stances**, the Battle Shout timer and its alert on **Battle Shout**, the debuff tracker and debuff alerts on **Debuffs**, the custom bar on **Custom**, and the cooldown icons' look on **Appearance**

## Slash commands

| Command | Action |
| --- | --- |
| `/wu` | Open options |
| `/wu 30 60 90` | Set marks (0 turns one off; with only two numbers Mark III is left as is) |
| `/wu range list` | Warriors: prints the range steps, the target's last answer at each, hidden answers counted and the zones |
| `/wu range stats` | Warriors: the estimate's measured error at each step crossing, against the middle of the step |
| `/wu range clear` | Warriors: clears those stats |
| `/wu reset` | Reset all settings (including the Battle Shout timer, debuff tracker and cooldown bar settings) and bar, range display, debuff tracker and cooldown bar positions in every layout to default |

`/wuutil` is an alias.

## Files

| File | Contents |
| --- | --- |
| `Libs\LibEditMode` | LibEditMode by p3lim (Edit Mode support), embedded unmodified; see its `LICENSE.txt` |
| `Core.lua` | Settings, shared aura container and Edit Mode helpers, event dispatch |
| `RageBar.lua` | Rage bar, marks, glow, styles, borders, size, Edit Mode position and settings |
| `RangeEstimator.lua` | Range display: turns range check answers into a smooth distance (from Good Range) |
| `RangeTape.lua` | Range display: the tape's looks and the focus and mouseover label (from Good Range) |
| `Range.lua` | Range display: range checks, zones, nameplate, focus and mouseover, Edit Mode positions and the `/wu range` commands |
| `ShoutTimer.lua` | Battle Shout timer on the player frame |
| `Debuffs.lua` | Sunder Armor and Demoralizing Shout tracker on the target and its Edit Mode settings |
| `Alerts.lua` | Audio alerts for Sunder Armor, Demoralizing Shout and Battle Shout |
| `CooldownLook.lua` | Cooldown icons shared by the cooldown bars: ready glow styles, on-cooldown look |
| `CooldownBar.lua` | Cooldown bar for each stance and its Edit Mode settings |
| `CustomBar.lua` | Custom cooldown bar for spells and items picked by ID, and its Edit Mode settings |
| `Changelog.lua` | Every version's changes, shown by the options page's Change Log button (the same as `CHANGELOG.md`) |
| `Trinkets.lua` | Trinket and usable gear bars, swap list and combat queue (from Forever Trinket Menu) |
| `TrinketAuto.lua` | Trinket rotation and mount swap (from Forever Trinket Menu) |
| `Bindings.xml` | Key bindings for Use Trinket 1 and 2 |
| `CombatText.lua` | Moving the game's target and self combat text (from SCT Mover) |
| `Minimap.lua` | Minimap icon that opens the options |
| `Options.lua` | Options page in Esc > Options > AddOns (including the CDM sub-tabs), slash commands |

## Glow

- Each mark you pass adds more glow; the highest mark gets the brightest glow, whichever slot it is in.
- A mark set to 0 is off and adds no glow.
- Marks are a percent of max rage (100 for warriors).
- Rage bar styles: **Modern** (flat), **Classic** (vanilla gold frame), **Rage** (fiery fill with a choice of eight borders, or none).

## Credits

- The trinket bar, swap list, rotation and mount swap are adapted from Forever Trinket Menu by sk0lu, MIT license; see `LICENSE-ForeverTrinketMenu.txt`.
- Combat text moving is adapted from SCT Mover by KidMoxie (Derek Springer), MIT license; see `LICENSE-SCTMover.txt`.
- The range display is adapted from Good Range by Andrii Zolotarenko, MIT license; see `LICENSE-GoodRange.txt`. Its range-check item list comes from LibRangeCheck-3.0 (MIT).
- The Changa Bold font in `Assets` is by The Changa Project Authors, SIL Open Font License 1.1; see `Assets/OFL-Changa.txt`.

## Disclaimer

This addon was made with the assistance of Claude AI.
