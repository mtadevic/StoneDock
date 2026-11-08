# StoneDock 0.11.3 — friends and family preview

StoneDock is a standalone addon that arranges Blizzard's UI and adds a dark stone dashboard.

1. Exit the game. Extract the ZIP into the client's `Interface/AddOns` directory: `_forever_/Interface/AddOns` for Forever or `_retail_/Interface/AddOns` for Midnight. Check that there is one `StoneDock` folder with the TOC files directly inside it.
2. Enable StoneDock in the character selection AddOns list. Log in, type `/stonedock`, open **Theme & layout**, and choose **Create / activate layout**. This creates a separate named Blizzard layout. To switch back, use `/stonedock restore`.
3. Open **Escape → Settings → AddOns → StoneDock** for options. The **Player, party & raid** page controls class colors for Blizzard's compact party and raid bars; it starts enabled. Right-click a consumable button to see alternatives. Use the item settings to pin, include or exclude items.

For an update, replace the addon folder only. Keep `WTF` and your saved settings. Reload out of combat. The package does not ship any character settings, bindings or action assignments.

The item row reads the current client's bag items. English tooltip matching recognizes recovery, food, stat potions, persistent buffs such as flasks/elixirs/stat scrolls, and utility effects such as movement, invisibility and temporary weapon treatments. Some items or other languages may need a manual include. Ranking uses recognized effect amounts, spec match and item metadata; it is not an exact optimizer across all effects. Only usable bag items are considered. Blizzard decides shared cooldowns, buff replacement, valid targets and where an item can be used. Items in a flyout are alternatives, not a guarantee that effects stack. Avoid enabling overlapping layout or consumable features in multiple addons during initial testing.

This is a preview, not a public compatibility claim. Before wider distribution, verify a fresh install and upgrade on both clients, a party roster change during combat, class colors on/off, and representative recovery, scroll, potion and utility items. For an issue, collect the client version, item link if applicable, and `/stonedock report` (review before sharing). See README.md for configuration details.

## Settings and expeditions

Settings use left-hand navigation, grouped controls, and dropdowns for choices such as theme, activity and resource. Selections stay pending until you choose **Apply** at the bottom. **Revert edits** discards changes on the current page. Pending edits remain when switching pages within the session; they are not saved through a reload. Actions such as starting an expedition or restoring a snapshot run when clicked.

For gathering, choose **Gathering & fishing**, enable it, choose an activity and resource, then **Apply** and **Start expedition**. The green active card identifies your target and destination. Command Center becomes an expedition card with collection count, route progress and **Next stop**, **Expedition**, and **End** controls. Ending a session returns the card to its ready state and clears its navigation pin. Fishing can also start automatically when you equip a pole.

## Card-style tools and blocked-action reports

Session, readiness, saved locations, quests, profiles and settings share the expedition's dark green cards and highlighted headings. Readiness cards distinguish Ready from Review and keep their action beside the details.

If the game reports a blocked interface action, use `/stonedock report`. StoneDock now records the addon named by the client, attempted function, combat state, time and available call context. The most recent eight distinct records are kept; consecutive repeats are counted together. Records may identify another addon and do not prove that StoneDock caused the problem. Actions that happened before this version cannot be reconstructed.

With Gathering enabled, equipping a fishing pole switches a general materials session into Fishing Mode; an explicit resource expedition keeps its target and route. Both keys assigned to Blizzard's Interact action cast Fishing while idle; a selected additional fishing key works alongside them. While channeling, Interact returns to its native behavior for the bobber. Unequipping the pole pauses fishing controls while retaining your expedition, catches and target. Combat changes remain deferred. Keybinding changes retain session catches and update the temporary shortcuts without changing your saved WoW bindings.

## Onyx Kintsugi theme

Choose **Theme & layout > Theme > Onyx Kintsugi**, then **Apply**. Satin-black onyx carries fine bronze-gold repaired seams, warm rivets, and matching card headings and borders. Selecting it also stages the Bronze accent; you can choose another accent before applying. Existing themes remain available and your chosen theme persists through reloads.

## Command Center and hotspot routes

The right panel is now Command Center. Its bordered top strip keeps durability, gold, local time and FPS/latency visible. Use **Expedition** for gathering setup or **Command menu** for readiness, session statistics, saved locations, quests, profiles and settings. Buttons sit above the item bars, and the expedition card remains visible below them.

Combat, weapon changes and zone transitions pause an expedition instead of ending it. Target, counts, route order and current area are retained. Fishing controls resume when safe and a pole is equipped. Use **End** to finish; only the expedition's own current pin is removed, preserving a replacement waypoint you set yourself.

Routes group nearby spawn reports within a 125-yard seed radius and mark their center as a gathering hotspot. Planning selects up to 24 nearby areas, favors your initial facing direction, and smooths crossing detours and sharp reversals. Entering a 100-yard radius advances to the next area; if all remaining centers are already nearby, the card indicates that you should search the current area rather than cycling pins in place. These are node-based loops, not terrain-aware pathfinding.

Stone panels remain visible in Blizzard Edit Mode as placement references. Dashboard shortcut controls stop accepting mouse input while editing so native frame handles remain usable. Native docking remains paused until Edit Mode closes.

The right panel matches the chat panel height and has no heading. Durability, gold, time and performance share one compact line. Expedition and Command menu buttons sit on the normal clickable UI layer. The expedition summary is compact; hover for full details. On very short layouts, the Expedition button displays the active resource instead of overlapping the item row.


## Gulveig Bar - alternate layout

Open **Theme & layout**, choose **Layout > Gulveig Bar**, then **Apply**. The original StoneDock dashboard remains a separate Blizzard layout; choose **StoneDock dashboard** to return. Switching requires leaving combat and Edit Mode. Your selected native layout is detected again at login. Each design keeps separate character/spec unit, aura and tracking placement.

Gulveig Bar uses original Celtic metalwork with green tips around three centered native action rows: **6 / 8 / 6 visible buttons**, with smaller top and bottom rows for a stepped silhouette. These use native action bars 1, 2 and 3. Existing action assignments and keybindings are preserved; slots beyond the visible counts remain assigned but are not shown in this compact design. Adjust the native bar counts in Edit Mode if you need more visible actions. Bars 4-8 are hidden within this layout.

Player and target frames flank the character, the player's cast bar sits underneath, and the minimap moves to the bottom right. XP and reputation sit beneath the action bank. Chat and the consumable row remain at the lower left. The bag-button and character-menu bars are hidden only while Gulveig is active; inventory keybindings and Escape settings remain available. Both native bars return when leaving this layout. The dashboard's right Command Center card is omitted in this design; its tools remain accessible through `/stonedock`. Existing theme choices continue to style chat and the utility drawers. The ornamental artwork remains visible in Edit Mode.

This first version follows the reference composition and uses native unit frames; it does not replace Blizzard's portrait art or class resource displays. Native frames and artwork need an in-game visual check at your preferred scale.

On first login, new users see a layout chooser with StoneDock dashboard and Gulveig Bar. **Use this layout** creates/activates the selection. **Decide later** leaves the current UI alone and asks again next login. The chooser waits until combat and Edit Mode finish; a failed save leaves it open. Existing users keep their chosen layout without seeing onboarding again.

Gulveig refinement: the action rows, ornamental surround and tracking-bar width are reduced to 80% of the initial size. Translucent black row backgrounds and a matching Celtic chat border replace the remaining stone trim. Existing player/target placement is preserved; login realigns the resized action assembly once.

The Gulveig chat border follows ChatFrame1 directly as it moves or resizes; its dark fill is inset inside the artwork. The action bank uses overlapping opaque black interior fills beneath the metal seams, independent of artwork opacity and still following dashboard fading. The middle row now has eight buttons. Legacy generated far-edge player/target anchors migrate inward; other manual placements remain intact.

Gulveig button counts are stored as native integer counts, bypassing display-slider quantization. The chat border has wider text margins and the item row anchors above the live chat window. Diagnostics include saved counts for the three native rows. Login applies the revised geometry once, including scale-normalized legacy unit anchors.
