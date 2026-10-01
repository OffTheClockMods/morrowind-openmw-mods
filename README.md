# The Elder Scrolls III: Morrowind (OpenMW) Mods by Off the Clock

Source code of the Off the Clock mods for **The Elder Scrolls III: Morrowind (OpenMW)**: OpenMW Lua mods (OpenMW 0.50 or newer).

## The mods

| Mod | What it does | Version | Download |
|---|---|---|---|
| **Infinite Arrows and Bolts (OpenMW)** (`Src/InfiniteArrowsBolts`) | Infinite arrows and bolts for OpenMW: fired arrows, bolts and thrown weapons come straight back, so you never run out of ammo (unlimited arrows). Any ammo, enchanted or modded. Selling or dropping ammo works as normal. In-game settings menu. OpenMW 0.50+, pure Lua. | 1.0.0 | not released yet |
| **No Weapon and Armor Wear (OpenMW)** (`Src/NoWeaponArmorWear`) | No weapon and armor wear for OpenMW: weapons, armor and shields keep their condition, no repair trips (also known as no durability loss). Or pick any wear from 0 to 1000 percent per kind; lockpicks and probes optional. In-game settings menu, nothing saved. OpenMW 0.50+, pure Lua. | 1.0.0 | not released yet |
| **Skill Gain Multiplier (OpenMW)** (`Src/SkillGainMultiplier`) | Skill Gain Multiplier for OpenMW: faster (or slower) skill leveling from use, x0 to x100. One slider for all skills, one per specialization and one per skill, in the in-game settings menu. Books and trainers unchanged, nothing saved. OpenMW 0.50+, pure Lua. | 1.0.0 | not released yet |

Download the mods from the pages above. This repository is the source code, so you can see exactly what each mod does.

## Install and build

Nothing to compile: each mod is an OpenMW Lua script (`.omwscripts` + `scripts/`). Players should install from the
mod pages above. To run one from this source, add its folder as a `data=` line in `openmw.cfg` and its
`.omwscripts` file as a `content=` line (or use the OpenMW launcher's Data Files tab).

**Offline tests** (no game needed, Lua 5.4): `lua Src/tests/run_tests.lua`

## What the mods do and don't do

- **Only what the mod page says.** Single player; nothing affects other players or online modes.
- **Settings at the game's own values by default**, with wide ranges and a short note beside each setting.
- **Honest side effects**: each mod page and README says what it changes (saves, achievements, cheat flags).

## Bugs and ideas

Open an [issue](https://github.com/OffTheClockMods/morrowind-openmw-mods/issues). Please include the mod and version, the game version, what you did and what happened, and
the log lines that mention the mod.

## Licence

[MIT](LICENSE). You may learn from, reuse and adapt this code; keep the copyright notice. A friendly request (not a
licence term): please don't re-upload our mods. Link to our pages instead, so players always get the current version.

Written with AI coding help (Claude). Every release passes our offline tests and an automated in-game check before
it is published; we also play-test the mods by hand.

The Elder Scrolls III: Morrowind (OpenMW) is a trademark of its owner (Bethesda Softworks). This project is not affiliated with or endorsed by them.
