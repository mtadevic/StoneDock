# Lazai Adept

A compact World of Warcraft dashboard built around Blizzard's native UI. Adept is now the only layout.

## Install and update

Replace the existing `Interface/AddOns/StoneDock` folder with the folder from the release ZIP. The folder name and SavedVariables names (`StoneDockDB` and `StoneDockCharDB`) are retained so existing installations keep their data. The addon appears as **Lazai Adept** in game. Keep your `WTF` folder and saved settings.

For this update, replace the whole addon folder to remove retired modules and artwork. Reload outside combat, then open `/la` or Escape > Settings > AddOns > Lazai Adept. `/lazaiadept` is also available. Choose **Activate Adept** on first use. The native Edit Mode layout remains named **Adept** to preserve its anchors. Other saved Blizzard layouts remain available through Edit Mode.

## Features

- Split action banks around a centered minimap, docked bag and micro-menu controls.
- Player, target, focus, pet and target-of-target cards; native auras and cast bars; party and raid frames above the cards.
- PvP, elite, relative-level difficulty and pet-happiness indicators.
- Health/resource halo, fading and resolution/UI-scale-aware placement.
- Ten-slot item bar: two reserved trinkets plus available consumable categories. Right-click for alternatives; empty categories hide outside combat.
- Journey and Expedition tabs, Company and Settings tabs, session statistics and readiness.
- Draggable informational enemy list with role-aware threat indicators; no clickable targeting.
- Opt-in usage recorder, diagnostics, current-character JSON export, supported TSM integration and economic observations.

## Commands

Use `/la` to open settings. Append one of these commands:

| Command | Purpose |
| --- | --- |
| `install` | Create or activate Adept |
| `align` | Align dock controls while retaining manual unit/chat positions |
| `restore` | Return to the previous native layout |
| `rebuild` | Rebuild placement using current settings |
| `edit` | Open Blizzard Edit Mode |
| `move` | Open positioning settings |
| `itemsmove` / `itemsmove reset` | Move or reset the item bar |
| `enemies test` | Preview the enemy panel; drag its top edge outside combat |
| `report` | Copy diagnostic and overlap information |
| `export` | Copy native layout information |
| `exportcharacter` | Copy current-character JSON |
| `record start`, `record stop`, `record export` | Record and export usage telemetry |
| `snapshot NAME`, `loadsnapshot NAME` | Save or restore a recovery snapshot |
| `profiles` | Open character/spec profiles and backups |

Settings use page-scoped Apply and Revert edits. Protected actions and placement changes wait until combat ends. Blizzard continues to manage native action assignments and keybindings.

## Data and troubleshooting

Usage recording is opt-in and bounded. It excludes chat, player names and typed input; explicit manual notes are included. Window visibility records do not establish intent or prove a click. Some third-party windows are not instrumented.

Character JSON covers the current character only. TSM prices and cached bank, auction and profession data depend on API availability. Missing values remain unavailable; open the relevant native windows to refresh snapshots. Economic observations retain supported vendor, trainer and disenchanting data.

Forever is the primary verification client. Automated mocks cover logic, restoration and scaling. Appearance and secure interactions require in-game confirmation.
