# StoneDock 0.9.1 — friends and family preview

StoneDock is a standalone addon that arranges Blizzard's UI and adds a dark stone dashboard.

1. Exit the game. Extract the ZIP into the client's `Interface/AddOns` directory: `_forever_/Interface/AddOns` for Forever or `_retail_/Interface/AddOns` for Midnight. Check that there is one `StoneDock` folder with the TOC files directly inside it.
2. Enable StoneDock in the character selection AddOns list. Log in, type `/stonedock`, open **Theme & layout**, and choose **Create / activate layout**. This creates a separate named Blizzard layout. To switch back, use `/stonedock restore`.
3. Open **Escape → Settings → AddOns → StoneDock** for options. The **Player, party & raid** page controls class colors for Blizzard's compact party and raid bars; it starts enabled. Right-click a consumable button to see alternatives. Use the item settings to pin, include or exclude items.

For an update, replace the addon folder only. Keep `WTF` and your saved settings. Reload out of combat. The package does not ship any character settings, bindings or action assignments.

The item row reads the current client's bag items. English tooltip matching recognizes recovery, food, stat potions, persistent buffs such as flasks/elixirs/stat scrolls, and utility effects such as movement, invisibility and temporary weapon treatments. Some items or other languages may need a manual include. Ranking uses recognized effect amounts, spec match and item metadata; it is not an exact optimizer across all effects. Only usable bag items are considered. Blizzard decides shared cooldowns, buff replacement, valid targets and where an item can be used. Items in a flyout are alternatives, not a guarantee that effects stack. Avoid enabling overlapping layout or consumable features in multiple addons during initial testing.

This is a preview, not a public compatibility claim. Before wider distribution, verify a fresh install and upgrade on both clients, a party roster change during combat, class colors on/off, and representative recovery, scroll, potion and utility items. For an issue, collect the client version, item link if applicable, and `/stonedock report` (review before sharing). See README.md for configuration details.

## Settings and expeditions

Settings use left-hand navigation, grouped controls, and dropdowns for choices such as theme, activity and resource. Selections stay pending until you choose **Apply** at the bottom. **Revert edits** discards changes on the current page. Pending edits remain when switching pages within the session; they are not saved through a reload. Actions such as starting an expedition or restoring a snapshot run when clicked.

For gathering, choose **Gathering & fishing**, enable it, choose an activity and resource, then **Apply** and **Start expedition**. The green active card identifies your target and destination. Field Notes becomes an expedition card with collection count, route progress and **Next stop**, **Expedition**, and **End** controls. Ending a session restores the normal Field Notes rows. Fishing can also start automatically when you equip a pole.

## Card-style tools and blocked-action reports

Session, readiness, saved locations, quests, profiles and settings share the expedition's dark green cards and highlighted headings. Readiness cards distinguish Ready from Review and keep their action beside the details.

If the game reports a blocked interface action, use `/stonedock report`. StoneDock now records the addon named by the client, attempted function, combat state, time and available call context. The most recent eight distinct records are kept; consecutive repeats are counted together. Records may identify another addon and do not prove that StoneDock caused the problem. Actions that happened before this version cannot be reconstructed.
