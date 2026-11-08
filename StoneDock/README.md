# StoneDock — Dark Stone

Version 0.11.1 adds Gulveig Bar as a separate selectable native layout with Celtic artwork, compact centered action rows and separate saved placement.

## Updating an existing layout

After reloading the UI, run `/stonedock align`. This updates dashboard controls while preserving your manual unit-frame and chat positions. Do not use the full Rebuild command unless you want those placements reset as well.

Open `/stonedock advanced` for action-bar position, bank separation, width, HUD position, HUD bar separation, and HUD scale. Choose **Apply** at the bottom of the current page to save its changes. **Revert edits** discards pending choices. Theme, activity, resource and other exclusive choices use dropdowns with a visible selected value.

Out-of-combat fading has separate switches and opacity sliders for the native dashboard/UI group and the curved HUD. Zero is fully transparent. Combat restores visibility immediately. Mouse-over can reveal the dashboard; turn that option off for uninterrupted invisibility. Open settings temporarily keep the controls visible. Fading changes alpha rather than hiding protected action buttons; transparent buttons remain clickable.

The dashboard group includes the managed action bars, minimap, unit frames, main chat, bags/menu controls, tracking bars, and stone artwork. It does not hide unrelated game windows such as inventory contents, quests, talents, or the world map.

A standalone World of Warcraft addon with original artwork and a dark stone dashboard.

## First use

1. Enable **StoneDock** in the game's AddOns list and enter the world.
2. Type `/stonedock`.
3. Open **Theme & layout** and choose **Create / activate layout**.

This creates an account Edit Mode layout called **StoneDock - Dark Stone**. Your existing layouts remain available. Installing the folder alone does not apply a layout.

## Included

- Original dark stone textures, recessed wells, silver trim, and rivets.
- Four native 12-button action bars arranged on either side of the default minimap.
- Default player, target, focus, party, and raid frame placement.
- Primary native chat window at the left; zone, clock, gold, inventory capacity, and performance at the right.
- Native bags, micro menu, cast bar, and tracking-bar placement.
- An optional curved player health/resource HUD. Enable it in the settings window or with `/stonedock hud`.
- Silver, violet, moss, and bronze accents; three panel heights; opacity control.
- Recessed menu and inventory-control drawers; opened inventory windows positioned above the dashboard.
- Separate HUD/dashboard fade controls and adjustable bar positions, widths, and separation.
- A diagnostic report and a native layout export for troubleshooting.

The composition adapts to the UI canvas without changing the global UI scale. The initial live check used a 3840 × 2160 display.

## What stays native

The action buttons, bindings, action pages, minimap, chat, unit frames, auras, cast bar, bags, menus, and tracking bars are Blizzard's. StoneDock does not hook their positioning routines or reparent protected frames. Placement is saved through the native Edit Mode API and remains editable there.

The optional HUD passes player health and resource values directly into native status bars. It does not compute percentages, make combat decisions, or inspect secret values. Its color is fixed: red for health and violet for the current primary resource.

## Return to your old layout

Type `/stonedock restore` or choose **Restore previous layout** in settings. This switches back, hides the artwork, and restores the original visibility settings for Action Bars 2–4. It keeps the StoneDock layout for future use.

StoneDock hides Action Bars 5–8 within its own layout so inherited extra rows do not overlap the dashboard. Their action assignments are kept. Action Bars 2–4 must be enabled globally for the four dashboard rows; the addon remembers their previous visibility when it enables them. Selecting another layout directly in Edit Mode hides the artwork, but use StoneDock's Restore button to also restore those visibility toggles.

Before disabling or removing the addon, use **Restore previous layout**. Otherwise the native StoneDock placement will remain selected without its artwork. Native layouts are not deleted on removal.

## Fine-tuning

**Open Blizzard Edit Mode** moves and resizes native elements using Blizzard's controls. StoneDock's artwork hides while editing. **Rebuild placement** realigns the StoneDock layout to its current panel height; it replaces any manual placement adjustments inside that layout only. Other layouts remain untouched.

Use **Compact**, **Standard**, or **Roomy** to change panel height, then rebuild placement. Blizzard's minimum and maximum frame sizes still apply. Raid layout and unusual aspect ratios may need individual adjustments.

## Commands

| Command | Action |
| --- | --- |
| `/stonedock` or `/sdock` | Open settings |
| `/stonedock install` | Create or activate the native layout |
| `/stonedock restore` | Switch back and restore bar visibility |
| `/stonedock rebuild` | Confirm replacement of StoneDock placement |
| `/stonedock align` | Align dashboard only; preserve unit-frame/chat edits |
| `/stonedock advanced` | Position, spacing, and separate fade controls |
| `/stonedock edit` | Open native Edit Mode |
| `/stonedock preview` | Toggle labelled artwork placement guides |
| `/stonedock hud` | Toggle the optional curved HUD |
| `/stonedock hudscale 1.0` | Set HUD size, from 0.6 to 1.4 |
| `/stonedock accent violet` | Choose silver, violet, green, or bronze |
| `/stonedock opacity 0.94` | Set opacity, from 0.4 to 1.0 |
| `/stonedock height 1.0` | Set panel height, from 0.8 to 1.2 |
| `/stonedock show` / `hide` | Enable or hide artwork |
| `/stonedock report` | Copy diagnostics |
| `/stonedock export` | Copy a native Edit Mode layout string |

Layout creation, rebuilding, activation, and restoration are refused during combat and while Edit Mode has an open editing session. Appearance changes do not alter protected frame geometry.

## Installation paths

Copy the **StoneDock** folder into the appropriate `Interface\AddOns` directory:

- Forever: `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\StoneDock`
- Midnight: `C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\StoneDock`

The ZIP contains one top-level StoneDock folder. Avoid an extra nested StoneDock folder. No other addon packages or library installations are needed.

The Forever manifest is `StoneDock_Camelot.toc` (interface 16001); the Midnight manifest is `StoneDock_Mainline.toc` (interface 120105). A bare Forever manifest is included as a fallback. Older Retail, Classic, and controller layouts are outside the current target.

## Status and limits

This is an initial playable build, not a complete recreation of every feature in the screenshots. It does not include animated full-body portraits, a replacement tooltip system, a damage-meter implementation, automated combat alerts, or a separate right-side chat window. The right panel is a status dashboard.

Midnight 12.1.5 build 70783 is used for live loading and layout checks. Forever 1.60.1 build 70755 is the inspected target; in-game Forever validation must wait for access after launch. Party/raid behavior in actual groups, combat restrictions, vehicles, class-specific bars, and long sessions still need broader gameplay testing.

The native layout has been designed against Blizzard UI reference files mirrored at https://github.com/Gethe/wow-ui-source/tree/forever/Interface/AddOns/Blizzard_EditMode and the corresponding generated API documentation. No Blizzard source files are bundled in this addon.


### 0.4.1: Compact utility row
Utility icons are 15% smaller, centered within Field Notes, with a 16-unit gap between equipped trinkets and consumables (normal spacing is 4). Empty categories and unequipped trinkets disappear; available items return automatically after bag/equipment changes outside combat. Cooldowns remain visible. Secure assignments and spacing stay fixed during combat and refresh afterward.

Right-click a visible consumable to override its selection. Hidden categories can still be configured with `/stonedock items bandage` (also `heal`, `resource`, `bufffood`, `buffpotion`, `alternate`, `food`, `drink`). Hearth travel choices remain accessible through `/stonedock hearth`.

The 0.4 series also adds five-wide native party/raid rows, player buffs above and debuffs below the player frame, assignable top rivets, per-spec consumable selection, and an owned-hearthstone travel menu. Raid rows are split around the map for 10/20/25/40 players. Manual player/target/focus and XP/reputation placements survive alignment and rebuilding; login alignment reapplies dock alignment automatically.


### 0.4.2: Stance and pet bar placement
Stance buttons sit over the left action bars, right-aligned; pet/possess buttons sit over the right action bars, left-aligned. Their placement follows action-well offsets and widths. Native auxiliary button padding is zero. The utility row now uses uniform 4-unit spacing, removing the extra trinket/consumable separation introduced in 0.4.1.


### 0.4.3: Upward item flyouts and item settings
Right-click any item-row button to expand an upward list of available items. Left-click an entry to use it; this does not change its default or inclusion rules. Equipped trinkets, consumables, and hearthstones share this behavior. Open flyouts outside combat; secure choices already open remain usable during combat.

Use `/stonedock items` for Item Settings, with category tabs, per-spec defaults, Include, Exclude, and Auto controls. `/stonedock items hearth` opens travel settings directly. Excluded items are omitted from flyouts and automatic selection. Items on cooldown remain listed; the native game action enforces usability. Autographed Hearthstone Card (118427) is explicitly rejected even if previously discovered. Card/deck lookalikes are no longer discovered by name.

The stance/pet bar placement from 0.4.2 applies once automatically after reload/login, outside combat and Edit Mode; manual player/target/focus and XP/reputation anchors are preserved.


### 0.4.4: Script timeout hotfix
Fixed a re-entry window in first-login auxiliary-bar alignment: layout-update callbacks now see the pass as already claimed before any native save starts. Active-layout visibility checks no longer deep-copy all saved layouts, and unit decoration performs that check once per refresh rather than once per member. Table copying now handles shared/cyclic tables safely. Regression tests simulate synchronous callbacks during a native layout save.


### 0.4.5: Icon flyouts and auxiliary bar fitting
Item flyouts now display a compact six-column icon grid with native item tooltips and cooldown overlays. Right-clicking the same source icon toggles its flyout closed; any left mouse release closes it after the clicked action runs (outside combat). Item settings remain separate. The stance bar is fitted by its visible icons to the right edge of the left action well; pet/possess bars fit to the left edge of the right well. A one-time guarded login placement reapplies these anchors, retaining manual unit/status-bar placements.


### 0.4.6: Tighter action rows and larger auxiliary icons
Main action-row center spacing is reduced from 46 to 37 design units. Stance, pet and possess icons use native 60% scaling (approximately half the visible main-button size). Precision alignment now uses the main row's visible outer edges and seats auxiliary icons 4 design units above its visible top. Stance is right-aligned on the left bank; pet/possess are left-aligned on the right bank. Guarded login migration reapplies the update once.


### 0.4.7: Native AddOns settings entry
Open Escape > Settings > AddOns > StoneDock for appearance/layout, bars/HUD/fading, unit/group frames, and item settings. These buttons open the same controls used by slash commands. Older clients without modern Settings registration use the legacy AddOns category API when available.


### 0.4.8: Utility row anchored to the bag drawer
Equipped trinkets stay aligned at the bag drawer's left edge; consumables and travel items stay aligned at its right edge and expand left. Both sides use a small matching inset. Missing categories remain hidden, and inventory changes no longer recenter either bank.


### 0.5.0: Profiles, snapshots, useful Field Notes and positioning
Open Escape > Settings > AddOns > StoneDock for the new sections, or use:
- `/stonedock profiles`: character/spec preferences, named snapshots, restore/undo and native Edit Mode export. HUD, fade-HUD, native unit/aura/status placements, pet options, group sizing and item preferences are local to the character/spec. Stone appearance and action-bank geometry remain shared account-wide. Profiles switch outside combat/Edit Mode; snapshots are character-local and also capture shared appearance. An Initial layout recovery snapshot is created on first activation. Save up to 20 named snapshots; reusing a name updates it. Native exports contain Blizzard layout data, not StoneDock preferences.
- `/stonedock move`: one positioning panel with draggable player/target/focus/pet, HUD, group and action-bank handles. Grid spacing is 8 design units; nearby native frame edges snap. Width, separation and pet controls are in the same panel. Done retains the changes; Cancel restores the opening snapshot. Combat closes the editor. A free-dragged pet frame turns off automatic docking; re-enable Keep pet frame docked to attach it beside the player.
- `/stonedock snapshot NAME` and `/stonedock loadsnapshot NAME`: save or restore a named snapshot outside combat/Edit Mode.

Field Notes now shows clickable location/map, bag usage/inventory, lowest equipment durability/equipment, gold/currencies, local clock/calendar, FPS/latency/diagnostics, and active spec/profiles. Tooltips provide coordinates when available, exact coin amounts, repair counts and separate home/world latency. Low durability is highlighted. Drawer and item rows stay in place below the information area. Panel-opening shortcuts wait until combat ends.

The update does not assign action slots, keybindings, currencies or equipment. Native placement updates preserve unrelated named layouts.


### 0.5.1: Weathered stone texture
Dock and drawer backgrounds now use an original charcoal/olive-gray weathered stone texture inspired by the supplied material reference. Appearance settings include Weathered stone and Original stone buttons. Existing rivets and trim stay readable; action wells are shaded more deeply than side panels. Texture choice is shared with the account's stone appearance and included in snapshots. The original texture remains available.


### 0.5.2: Runtime optimization and loop audit
- Dynamic item flyouts, item settings, profiles/snapshots, rivet menus, positioning handles and raid previews reuse existing frames and texture/font regions. Reopening no longer grows a new native frame tree.
- Raid/item/panel jobs keep their coalescing guard throughout execution, preventing callbacks from scheduling themselves. Native layout saves reject nested writes and release the write lock on failure. Aura/profile jobs and bag placement also release their guards after errors.
- Only item-data completions requested by StoneDock trigger a refresh. Failed or duplicate loads cannot repeatedly request and rescan themselves; a real inventory change permits a fresh attempt.
- Ordinary panel refreshes reuse hearth discovery. Hidden item rows skip cooldown polling. Inventory/durability summaries update after relevant events, while the clock, location, FPS and latency still refresh normally.
- Periodic fading tasks stop when disabled or in combat; cooldown and Field Notes tasks stop when their UI is hidden. They restart once when needed.
- Fading caches the active-layout result and discovered frame set, invalidated on native layout/addon events. HUD-only fading does not scan the dashboard for mouseover. Unchanged combat alpha is not written repeatedly.
- Read-only layout lookup copies only the active layout; full layout assembly avoids duplicate copies. Matching profile and pet layouts do not issue native saves.

Regression checks include queued native event/timer fan-out, 100-event bursts, synchronous callback re-entry, injected failures, 30 menu/editor/raid-preview cycles, and 100 fading refreshes. These are mock-client stress tests plus Lua 5.1 compilation, not a measured in-game FPS benchmark.


### 0.6.0: One settings window, Master Modules, and five new tools
All configuration now lives in one movable window with left-side navigation. Open `/stonedock` or Escape > Settings > AddOns > StoneDock > Open StoneDock settings. Old commands and rivet shortcuts select the matching tab. Escape or the window's close button closes the whole settings UI.

Master Modules provides checkboxes for the dashboard, Field Notes, curved HUD, item buttons, trim/group arrangement, raid splitting, pet docking, aura arrangement, utility docking, fading, rivets, profiles/snapshots, positioning, and each new tool. Toggle modules outside combat. Disabling native placement automation retains your existing saved layout; disabling pet docking detaches the pet anchor in place, and aura arrangement restores its recorded pre-feature positions when available. The original layout remains selectable in Blizzard Edit Mode.

Five new tools:
1. Session tracker: elapsed time (including AFK), earned/spent/net gold, gold/hour, XP gained/hour and quest turn-ins. Reset is explicit. A recent reload resumes the saved session; re-enabling the module starts a fresh session. Its display timer runs only while its tab is visible.
2. Readiness checklist: lowest durability, ordinary bag space, trinket slots and spec-appropriate consumables. Click a review row to inspect gear, bags or item settings. Amber is a suggestion, not an instruction to buy something.
3. Waypoint desk: set or clear a native navigation pin, copy your current coordinates, and save up to 12 named current-location bookmarks per character. A bookmark click sets navigation; it never teleports or moves your character. Unsupported maps/clients show an availability message.
4. Quest notebook: tracked quests and objective progress, with shortcuts to native quest details. Updates only rebuild the visible notebook and are coalesced. It does not abandon, accept or turn in quests.
5. Field Notes customization: show/hide each information row, compact remaining rows and assign click shortcuts. Right-click a Field Notes row to configure it. Click an action selector to cycle actions, or restore all defaults.

Commands: `/stonedock modules`, `session`, `readiness`, `waypoints`, `quests`, and `notes`. All configuration tabs and lists reuse their controls. The new modules do not sell items, spend gold, change bindings or send messages.


### 0.6.1: Expanded curved player HUD
The default clear space between the arcs increases from 144 to 208 design units. Only the old untouched default is migrated; custom spacing remains intact. The HUD gains recessed tracks with muted metallic rims, optional quarter markers and HEALTH/resource labels, native resource colors, a red/class health-color selector, and independent height/thickness controls.

The Curved player HUD tab in unified settings includes Compact, Comfortable and Airy presets, plus position, height, width and scale sliders. Combat fading remains separately configurable. Shapes and labels are decorative: vitals still flow directly into native status bars with no health/resource comparisons or arithmetic. The HUD listens only while enabled/visible, updates the affected bar for each unit event, and introduces no polling timer. Controls reuse the existing frame pool.

### 0.6.2: Forever layout compatibility
New unit-frame defaults sit above the action banks near the map. Only exact old generated far-edge anchors migrate; custom positions and native settings remain intact, including character profiles. Bag and micro-menu sizes fit both drawer width and height. A single login alignment migration applies these adjustments.

Forever's 1,192-unit native tracking bars require an additional container-width fit because their native slider minimum is larger than our groove. The fit resizes native bar contents and dividers, skips combat/Edit Mode, guards callback reentry, and performs no repeated writes when dimensions are unchanged. Other clients retain their native tracking behavior. Disabling utility docking restores the recorded width when it is still managed by StoneDock.

### 0.6.3: Tracking and drawer clearance
Party/raid rows reserve additional space for tracking-bar trim and the bottom power/aura strip. Forever gets a taller micro-menu drawer so its gold-framed buttons can be larger. Bag and consumable positions follow drawer geometry, with Field Notes spacing and minimum panel height keeping the controls separate at compact densities. Login reapplies the drawer layout once; manual player/target/focus and tracking anchors remain preserved.

### 0.6.4: Stable native party anchor
The native PartyFrame layout now records the same top-left groove anchor, cell dimensions and horizontal orientation used by the compact party row. Previously only the compact child was seated there; native parent layout updates could move it back to the old higher anchor during combat. Full creation, dashboard alignment, unit settings and old character-profile restores now agree. Parent layout notifications coalesce into the existing guarded out-of-combat job. No protected positions are changed in combat. Reload outside combat once to migrate the saved native party anchor.


## Gulveig Bar - alternate layout

Open **Theme & layout**, choose **Layout > Gulveig Bar**, then **Apply**. The original StoneDock dashboard remains a separate Blizzard layout; choose **StoneDock dashboard** to return. Switching requires leaving combat and Edit Mode. Your selected native layout is detected again at login. Each design keeps separate character/spec unit, aura and tracking placement.

Gulveig Bar uses original Celtic metalwork with green tips around three centered native action rows: **six visible buttons per row**, with smaller top and bottom rows for a stepped silhouette (Blizzard's supported minimum is six). These use native action bars 1, 2 and 3. Existing action assignments and keybindings are preserved; slots beyond the visible counts remain assigned but are not shown in this compact design. Adjust the native bar counts in Edit Mode if you need more visible actions. Bars 4-8 are hidden within this layout.

Player and target frames flank the character, the player's cast bar sits underneath, and the minimap moves to the bottom right. XP and reputation sit beneath the action bank. Chat and the consumable row remain at the lower left. The bag-button and character-menu bars are hidden only while Gulveig is active; inventory keybindings and Escape settings remain available. Both native bars return when leaving this layout. The dashboard's right Command Center card is omitted in this design; its tools remain accessible through `/stonedock`. Existing theme choices continue to style chat and the utility drawers. The ornamental artwork remains visible in Edit Mode.

This first version follows the reference composition and uses native unit frames; it does not replace Blizzard's portrait art or class resource displays. Native frames and artwork need an in-game visual check at your preferred scale.

On first login, new users see a layout chooser with StoneDock dashboard and Gulveig Bar. **Use this layout** creates/activates the selection. **Decide later** leaves the current UI alone and asks again next login. The chooser waits until combat and Edit Mode finish; a failed save leaves it open. Existing users keep their chosen layout without seeing onboarding again.

Gulveig refinement: the action rows, ornamental surround and tracking-bar width are reduced to 80% of the initial size. Translucent black row backgrounds and a matching Celtic chat border replace the remaining stone trim. Existing player/target placement is preserved; login realigns the resized action assembly once.
