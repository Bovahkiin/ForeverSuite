## 0.8.12 hunter feeding and happiness

1. Update through WoWUp and reload outside combat. Summon your hunter pet and
   check its happiness icon and tooltip. Compare it with the native pet sheet.
2. Activate Feed Pet, then left-click suitable food in ForeverSuite inventory.
   Only that stack should be used; Item Options must not open.
3. Try unsuitable food: the client should explain the failure and the addon
   must not eat, equip, pick up or sell that item. Cancel the spell normally.
4. Feed the pet and check that its happiness icon updates. Dismiss and summon
   pets, and check that warlock pets do not receive a hunter happiness badge.
5. Verify ordinary left-click options, right-click use/equip, BoE confirmation
   and manual vendor sales still work. Check combat and saved pet positions.

## 0.8.11 compact pet placement

1. Reload outside combat and summon a pet. With default pet placement, it should
   appear smaller and left-aligned below your actual player frame.
2. Move and resize the player frame: the default pet should follow beneath it.
3. Move/resize the pet separately, reload and check that choice remains saved.
4. Enter combat, dismiss/summon a pet where possible and verify there are no
   blocked layout actions. Settings changes should apply after combat ends.

## 0.8.10 verification

1. /reload after installing. Check player/target/focus levels; summon, dismiss,
   revive and rename a hunter pet. The pet frame is in Move Frames, with a Pet
   toggle in Unit Frame settings. Test pet updates during combat.
2. Choose font family/size/weight in Text & Fonts, including one module override.
   Reload and restart, and check both stored choices and rendered text.
3. Check bagbar icons, counts, native bag clicks and selected theme/style.
4. Open /fs addons or Addon systems. With supported competing addons active,
   choose one arrow and check the guides continue while only one arrow displays.
   For nameplates, Apply and reload UI explicitly confirms the change. Verify
   dependency addons, saved settings and your per-character choice after login.
5. At a merchant, Sell item on ordinary unmarked gear. Check Never Sell, saved
   quantities and valuable-item protections explain a blocked sale in the popup.
6. Check Mounts side tabs and name area, wardrobe helm/shoulder/weapon icons,
   and profession rank fill at low, intermediate and maximum skill (40/75 should
   be about 53% filled). Increase skill and check animation/update.
7. Retest combat, hover/tab targeting, logout, equipment/BoE and profile layout
   persistence. No native action-button handlers or protected attributes changed.

## 0.8.9 independent action-bar art check

1. Reload after installation so old decorative children are discarded.
2. Verify borders, trays and empty slots follow bars at all game layout scales
   and positions. Check all four legacy styles and your selected theme.
3. Enter combat, hover buttons 1-12, tab-target, use abilities and change action
   slots. Check /fs errors for the previously reported SetShown blockage.
4. Hide/show extra bars and check that independent art follows visibility.
5. Verify keybinds, paging and original native clicks still work.

## 0.8.8 combat hover check

1. Run /reload after updating: old script hooks cannot be removed from a live
   UI instance by replacing files alone.
2. Enter combat and hover across filled and empty native action buttons,
   including slots 8-12. Tab-target and use actions. Check /fs errors.
3. Check native clicks, bindings, paging, tooltips and existing skin appearance.
4. If blocking persists, capture the taint origin: /console taintLog 1, /reload,
   reproduce the combat hover, then /console taintLog 0. Inspect Logs/taint.log.

## 0.8.7 inventory equipment check

1. Reload outside combat. Right-click compatible, already-bound gear in the
   ForeverSuite inventory; verify the correct copy equips once.
2. Right-click an unbound Bind-on-Equip item. Cancel the game's bind dialog:
   it must stay unbound in the bag. Repeat and accept only if you want to bind it.
3. Select equipment and click Use item; check the same behavior.
4. Verify Hearthstone/consumables still work. At a merchant, right-click must
   continue using protected selling rules, rather than equipping.

# In-game checks - 0.8.6

- Open /fs, search for a module and for one of its setting labels.
- Cycle the state filter, toggle a matching module and check the updated list.
- Check Enter on a unique result and Escape/Clear returning to your previous page.
- Check empty results, page controls, hover colors and disabled state labels.
- Repeat with your preferred theme and large text; confirm profiles stay accessible.
- Repeat the author-confirmed 0.8.5 reload/combat/logout checks as a regression check.

# In-game checks - 0.8.5

Author-confirmed results, 2026-11-08: reload preserves the intended layout, and
combat/logout work without the previously reported blocked-action warnings.
Keep the checks below for future releases and additional client configurations.

- Restore your preferred clock, waypoint, experience-bar and quest-tracker layout.
- Run /reload and check positions again once UI scaling has settled.
- Change resolution or UI scale and return; saved coordinates must not be
  overwritten by temporary viewport bounds.

# In-game checks - 0.8.4

- Change a frame position and scale, finish Move Frames, and run /reload.
  Confirm the active profile name, placement and scale remain the same.
- Repeat with a character-assigned profile; log out and back in, then switch
  profiles and return. Check the most recent edits rather than an old snapshot.
- After a fresh /reload, open and close the game menu, enter/leave combat,
  tab-target enemies, and check empty action buttons 11/12 and their containers.
- Try Logout and Exit Game only when ready to leave the session. The reported
  callback blocking is not certified fixed by the offline test environment.
- If blocking returns, run /fs errors and include the last blocked-action stack.

# In-game checks - 0.8.0

All code/offline work for the 20 additions and improvements 2-10 is complete.
Improvement 1 live combat/target verification remains open. Install under
_forever_/Interface/AddOns/ForeverSuite; use /fs tools to access the new features.

1. Try the category menu, search/favorites and settings undo. Check large fonts,
   small screens and Advanced pages. Existing setup/profile data should remain.
2. Export, preview/import into a new name, inspect backups and restore. Verify
   character assignment on a later login. Check retained private/history data.
3. Preview/apply text presets and palettes; test optional alert sounds/channels.
4. Save/remove an NPC rule and add a known readable spell ID for cast emphasis.
5. Enable keywords and opt-in chat capture, verify links/icons, copy/clear data,
   disable capture. No chat is sent automatically.
6. Verify guild stars/notes and optional recent group capture/clear controls.
7. Compare checklist carried counts. At a merchant manually inspect/buy back a
   selected item. Checklist goals never buy, sell or reserve items.
8. Check/reset loot and XP sessions, including level rollover and unknown prices.
9. Queue two saved pins, reorder/start/stop, reach one and verify advancement.
   Queue contents persist; start again after reload/profile changes. Direct
   guidance remains separate from terrain routing.
10. During normal play enter/leave combat and tab targets. Verify constant bar
    geometry, hotkeys/paging and absence of flashes. /fs audit records the last
    20 layout snapshots. /fs errors captures blocked actions; ordinary Lua
    errors need their own text. This live check cannot be replaced by mocks.

Previous test instructions:

# ForeverSuite in-game tests (current: v0.7.39)

On a fresh SavedVariables setup, verify that Welcome appears once, Patch Log
returns to the same draft, and Appearance offers all ten numbered designs.
Select each and check its matching preview, then finish or cancel. Existing
players use /fs setup or Control Center > Appearance: 10 styles. Do not delete
SavedVariables merely to test first-run behavior; keep a backup/test account.

In the appearance-only picker, Cancel must preserve the existing style, enabled
modules and setup flags. Apply style must alter only appearance. Switch profiles,
/reload and reopen settings to verify persistence. Check Cartographer text on
light panels, settings at large fonts/small screens, module color labels and
window resizing. Design previews are concept compositions, not live UI captures.

Enter/leave combat, tab targets, page bars and use hotkeys for every theme. Native
bar size/positions and actions must remain unchanged. Verify the themed waypoint
rotates smoothly and disappears when navigation data is unavailable. Keep existing
merchant protections and chat/module preferences under observation. Capture
normal Lua errors separately from /fs errors (blocked actions only).

Previous test instructions:

# ForeverSuite in-game tests (current: v0.7.38)

Install in _forever_/Interface/AddOns/ForeverSuite and fully restart the client
if installing for the first time. Confirm version 0.7.38 in /fs status, client
1.60.1 and Interface 16001. Open /fs, setup, profiles and every module settings
page. If /fs status reports overlapping UI addons, choose which addon manages
each affected component before evaluating visuals. No settings are auto-disabled.
Verify bags/items, merchant protections, chat, nameplates, quests/navigation,
profession windows and combat action bar geometry. /fs errors records blocked
actions only; copy normal Lua error messages separately if the game reports one.

Previous tests:

# ForeverSuite in-game tests (current: v0.7.37)

## v0.7.37 Native layout decoration exclusion

Replace the addon folder and /reload outside combat. Do not keep the old UI
session: it retains old child frames. Select each bar style, enable extra bars
and leave some buttons empty. Enter/leave combat at least ten times, tab through
enemy targets and use hotkeys. Verify constant bar dimensions and separation,
stable window outlines, normal paging/bindings and no UI flashes. Open chat,
map, professions, social and damage meter windows before and after combat.
If placement was enlarged in the previous session, use the game's layout
controls once after reloading to restore the desired placement.
If an interface-action warning appears, record /fs errors immediately.

Previous test instructions:

# ForeverSuite in-game tests (current: v0.7.36)

## v0.7.36 Combat safety and scoped refresh

Replace the addon folder and /reload before testing; earlier versions changed
native runtime layout data, which remains in the old UI session. Use Action Bars
settings > Game action bar layout to position/size bars. Old ForeverSuite bar
positions are retained but no longer applied; setup size changes are preview
only. Check every style with extra bars and empty slots; enter/leave combat,
switch enemy targets, use hotkeys, change pages and use cooldowns. Watch both
bar placement and other UI elements for flashes. The game owns native geometry.

If the interface-action warning recurs, immediately type /fs errors and record
the reported addon and function. Test separately with only ForeverSuite enabled
to distinguish interaction with another addon. Diagnostics are session-only and
do not proactively change the UI. Earlier custom-position tests below document
past versions and no longer apply to native action bar placement.

## v0.7.35 Artwork parity with design examples

Compare all four setup previews with the applied bars. Floating should have
separate clipped-corner tiles, Dock cyan lower rails and gold end caps, and Gold
layered metallic bevels with cyan gems instead of plain gold boxes. Check icons
sit inside the rims and leave the gems visible; hotkeys, counts, cooldowns,
hover, action glow and drag-and-drop still work. Repeat on small and large bars,
extra bars, vertical bars, stance/pet bars and during combat. Disable Action Bars
outside combat and verify original icon geometry/crop and native artwork return.
Native secure button spacing remains controlled by the game; artwork creates
the visual separation without replacing protected button layout or handlers.

## v0.7.34 Welcome, setup and four bar styles

On a clean test install, verify welcome shows ForeverSuite, v0.7.34 and
Created by DeluxiZ. Open Patch Log and return to setup. Preview every style,
all sizes and each module toggle. Back preserves choices; Set up later and
Escape never apply a draft. Finish applies choices and keeps moved bar positions.
Reload: completed or dismissed setup must not reopen automatically. An existing
installation retains its settings; Guided setup and /fs setup reopen manually.
Test every step at maximum text size and a small screen resolution.

Cycle all four styles in Action Bars settings, save/load profiles, target
enemies and use hotkeys, action paging, extra bars and empty slots in combat.
Check the preview matches the actual decorative treatment. Disable Action Bars
outside combat to verify native appearance restores. Applying setup in combat
or during a vendor transaction must wait until the activity finishes. The
preview is illustrative; it does not render a full game scene or protected UI.

## v0.7.33 Target switching and empty slots

Check all twelve action slots retain visible borders with empty slots, both
before and during combat. Switch repeatedly between enemies, friendly targets
and no target; watch for bar/grid flashes or movement. Repeat with moved/resized
bars and a saved Profile. Use occupied buttons and hotkeys, switch action pages,
drag a spell into an empty slot using the native grid, and test extra bars.
Hide a bar in native settings: its empty-slot borders should also hide. Disable
Action Bars outside combat: all added empty-slot borders disappear and native
visibility/actions/appearance restore. These checks require the real client.

## v0.7.32 Combat overlap and remaining flicker

Enable extra bottom action bars, put a spell on them and move/resize each bar.
Enter combat, attack, switch targets, cast and toggle permitted bar visibility.
Verify all bars retain separate custom positions, native paging/bindings work,
and buttons remain usable. Leave combat, switch Profiles and repeat. Disable
Action Bars outside combat and verify native layout restoration. Load a game
Edit Mode layout outside combat and verify custom placement is reapplied.
Watch chat, map, unit frames and damage meter while idle and during actions.
Open new native windows, change map/quest pages and create a chat window: styling
must still appear. Repeat previous flicker triggers. Offline tests do not prove
live secure-path behavior or complete flicker elimination.

## v0.7.31 Viewports, combat and cast bars

Move and scale the Control Center, then open every module settings page.
Repeat basic/advanced options with fixed font 24 and multiplier 1.5, then reset.
Verify all edges remain visible, Vendor Junk selling has its own help, and
advanced fields retain unsaved values until Save. Switch settings pages.
Enter/leave combat with extra action bars visible and custom saved positions;
confirm they stay in place, actions/paging work and disabling restores native
positioning. Cast and channel repeatedly: one player cast bar, smooth fill,
correct delay/interruption/end. Disable Unit Frames outside combat and verify
the native cast bar returns. Repeat UI actions that previously caused flicker.
These live visual/secure-path checks cannot be proven by the offline mock.

## v0.7.30 Shared settings and additional options

Open every module from its card. Verify matching border colors, Back/title,
description, two-column controls/help, opaque background and no clipping.
Test Bags/Vendor basic and advanced modes, field labels, edits, Save and Back.
Repeat at fixed font 24, multiplier 1.5, then reset. Check Inventory categories,
counts, toolbar, item headers, pages, merchant actions and drag/drop; Character
tabs, title/level, stats pages, gear sets and restored native sizes on disable.
Check World/zone breadcrumbs and quest search/counter spacing; map clicks,
quest selection, zoom/pan and search must still work and restore on disable.

Try the new choices in Cooldowns, Buffs, Combat, Auction House, Professions and
QoL with real data. Save two Profiles, change choices, switch back and reload.
Buff reminders should hide in combat only when selected. Shopping filters must
use the requested bank stock, without purchasing anything automatically. Missing
profession materials must filter only the material list; crafting stays native.
Native frame variants and actual font metrics require this live verification.


## v0.7.29 Typography layout audit

Set global Fixed size 24, multiplier 1.5, Bold. Cycle all Control Center pages,
save/use a long profile name, then open every module's settings and tools.
Check controls, row spacing, wrapping and footer bounds; inspect specialized
Bags/Vendor/Nameplates/native windows too, since their live text metrics cannot
be certified by offline mocks. Open Text & Fonts, Patch Log and Credits.
Check the quest tracker with long objectives, fold/unfold and multiple pages;
Log/Map and distances must fit and targets remain clickable. Reset typography,
switch saved profiles and reload. Repeat with module-specific overrides and a
saved Move Frames scale. Screens should shrink on reset without cumulative
growth. Check changes deferred during combat and applied afterward.


## v0.7.28 Map, achievements and settings layout

Open Map & Quest Log. Check top navigation/dropdowns and bottom quest-panel
toggle: there must be no extra suite-generated X on them. Close, maximize,
collapse/expand, navigate maps, zoom/pan and select quests/pins normally.
Open Achievements: title and total points/shield must sit within the header;
category parchment and old summary-bar decorative edges must be suppressed.
Check categories, summary, statistics, search and newly pooled rows, then
disable Action Bars styling to verify native art/geometry restores.
Open Map settings and cycle both pages. All nineteen options must be reachable
without overlaps, with hint and Open Map below and no dashboard text bleeding
through. Change options on both pages and reload/switch Profiles. Other generic
settings and both native windows still need live checks at your font/UI scale.

## v0.7.27 Minimap ant trail

Accept/focus a quest or select a saved pin. Dots must march toward that active
destination, inside the minimap rim. Walk, zoom, rotate the minimap, resize it
and check direction/spacing; player/quest icons and clicks must remain usable.
Change all five trail settings under Map. Save/switch Profiles and reload.
Stop navigation, arrive, hide the minimap, hide navigation in combat, or disable
Map: dots must clear. Missing/cross-instance location data must not invent a
trail. The guide points directly toward the target, including across obstacles.

## v0.7.26 Smooth waypoint arrow

Walk, strafe and rotate toward a waypoint: direction must animate continuously
without visible ten-Hz steps. Turn through a full circle and reverse rapidly;
the arrow must follow the short turn without spinning around the angle boundary.
Compare low/high FPS. Check switching quests/maps, arrival, unavailable facing,
combat hiding and reappearing: stale direction must clear. Verify compact style,
clicks, saved Move Frames position/scale and no noticeable performance regression.

## v0.7.25 Compact waypoint

Accept a locatable quest: only the cyan/gold spearhead, title and distance
should appear over the world, with no panel, border, quest icon or instruction.
Turn and check direction and the dark shadow. Try all arrow colors and Chevron.
Check arrival, unavailable location and cross-zone status in the second row.
Try Map text sizes and Text & Fonts overrides; rows must stay separate. Hide
the title/distance, move/resize in Move Frames, then reload and switch Profiles.
Position/scale must persist. Left-click opens the map, right-click stops.

## v0.7.24 Text & Fonts

Open `/fs` > Text & Fonts. Cycle All modules and each module (including
Profiles) and check its preview. Select each font, Normal/Bold, outline and
shadow. Bold must use Arial Bold. Try a size multiplier and fixed size 0/14/20;
check module headings, buttons, lists, counts, inputs and HUD text. Reopen and
refresh repeatedly: sizes must remain stable. Larger fonts may need a larger
module frame; check wrapping/clipping in real layouts and at your UI scale.

Change Chat independently, then Nameplates and Map/waypoint; other modules
must retain their own/global settings. Use global removes the override.
Check the minimap title, bottom clock, XP hover text, action bindings and
native Contacts/profession/map/damage-meter text. Native skins disabled must
retain original fonts and shadows even after another global typography edit.
Try newly pooled nameplates/list rows and reopened tool windows.

Save/switch Profiles, reload and reset preferences. Combat must block editor
actions; pending updates apply after combat without changing active plate
appearance early. Close/Control Center/Escape must not leave overlapping
editor windows. Test with other UI/font addons disabled first.


## v0.7.23 automatic quest waypoints

In `/fs` click Map; check all 14 settings (Coordinates plus 13 navigation
options) fit. Accept a quest with a client-provided location and confirm its
title/arrow/distance appear. Accept during combat; native map writes must wait
until combat ends. Turn in/remove it and check next-quest on/off behavior.
Progress an objective, then complete it: the destination should follow the
next waypoint and turn-in point. Delay or omit location data: show an honest
loading/unavailable state, retry when data arrives and never point to 0,0.

Rotate and move: arrow and distance must follow facing/position. Near the
arrival radius, show Arrived without completing the quest. Test other zones
and separate instances: use valid world coordinates or show destination zone
with no guessed direction. The arrow is straight-line guidance, not a route.
Click quest headings, left-click the arrow to open its map, right-click to
stop. Selecting a saved Map pin must override quests until cleared/selected.
Try six colors, Arrow/Chevron, text/scale/title/distance and combat visibility.
Move Frames must provide a stable resize grip and preserve position.

Toggle the native waypoint, navigation, Map and Quests. Own native markers
clear; replacing one in the game map must preserve that external marker on
disable. Check existing external markers survive passive login selection.
Save/switch Profiles and reload for appearance and placement. Existing quest
minimap/world-map icons and manual saved-map pins must continue to work.


## v0.7.22 nameplate designer

Open `/fs`, click Nameplates, then Open nameplate designer. Check all four
option groups and presets, the six component buttons and the interactive
sample. Drag each outlined component; X/Y values should follow the cursor
without jumping. Try different UI scales and reset a selected position.
Enter valid/invalid sizes and positions; invalid values must not be saved.
The example must stay inside its panel. It uses sample data, not a live unit.

With visible enemies, change sizes, fonts/outline, alignments, health formats,
colors, class/threat coloring, target outline/scale and other-plate opacity.
Check native targeting clicks still work. Watch a casting/channeling unit:
cast visibility, icon, time remaining and gray non-interruptible casts should
follow readable native information. Test Buffs/Debuffs, Only your auras,
counts, size, spacing and cooldown display; stale icons must clear.

Save current profile, load a different profile, return and reload; settings
and positions must persist. Presets must retain enemy/friendly visibility.
Entering combat must stop dragging and block designer edits. Pending settings
apply afterward. Press V off/on, move out of plate range and return, then
disable/re-enable Nameplates. Native visuals must restore on disable; old
pooled data must clear. Repeat with other nameplate addons disabled first.
The designer changes suite visuals; the game's targeting area and unit-based
placement remain native. Forbidden client plates may retain their own style.

## v0.7.22 profession crafting layout

Open the profession overview and select Skinning, then another profession
with recipes. Check the cyan rank fill and full trough, centered skill text,
matching search/filter heights, filter arrow and readable reset X when filters
are active. Search and filter a recipe; clear filters and check the recipe
list returns. Empty Skinning results are not proof of a layout or data bug.
Scroll, click arrows and drag the thumb. Switch professions using the smaller
suite-framed right tabs; hover tooltips and selected borders must still work.
Check tabs fit without covering rank text or recipe details at your resolution.
Resize/move with Move Frames, reopen, and reload. Disable Professions to check
original art and control geometry return, then re-enable. Repeat after combat.

Offline checks can run from the source workspace using `work/Test-Addon.cmd`.
For visual checks, leave WoW running, replace addon files and use `/reload`.

## v0.7.21 chat buttons and expanded Loot settings

Check the Contacts/count, Channels/speaker and Chat Menu buttons beside chat.
They should have suite backgrounds, border color/opacity and recognizable
icons. Hover/click menus, inspect changing contact counts/notifications and
disabled states. Turn Style chat buttons off/on independently of panels and
Social; original decoration must restore when the option or Chat is disabled.
Repeat after combat and chat docking changes. Open Chat must go directly to
settings; Start typing in chat should activate the native input and preserve
any unsent draft. Check all 13 settings fit above the bottom action.

Open Loot settings and check all 14 options fit with Clear history and Open
Loot available. Test recording off/on, Everyone/You, history limits, quality,
timestamps and oldest/newest order. Hiding/filtering history must not erase it;
lowering its limit intentionally trims older entries. Uncached linked items
remain visible until quality is known. Clear history needs two clicks within
five seconds. Reload to verify saved preferences/history.

With a consenting group, check active-roll visibility, name/time sorting,
quantities/countdowns, optional helper opening outside combat and manual
Need/Greed/Pass. Expired/cancelled/unavailable choices must not roll. No choice
should happen automatically. Loot-window styling must retain slot clicks,
icons and binding confirmations and restore on disable. Fast loot must remain
off by default and pause with Shift or combat. Display filters must never
change which slots Fast loot picks up.

## v0.7.20 profiles and chat scrollbar

Browse every Control Center page and open module settings. Profiles must stay
above the cards on every page, with no profile card or enable button. Enter a
new name, Save profile, change a setting, then save with the name field empty
to update it. Choose another profile and Use profile; switch back and reload
to verify settings and layout. Combat and active vendor actions block changes.
Check the bar and settings fit at your resolution and Control Center scale.

Scroll chat history, click both arrows, drag the thumb and return to the bottom.
Check there are no brown track/arrow textures outside the chat panel. Change
Chat opacity/border, including None, then disable panel styling and the Chat
module separately. Native scrollbar art and actions must return. Repeat with
another chat window and after combat, resizing and moving the chat frame.

## v0.7.19 separate Chat, Social and Guild

Check all three cards and their settings. Disable Social while leaving Chat
and Guild enabled, then disable Guild while leaving the others enabled;
verify only the intended window/list is affected. Change Chat font, outline,
opacity, border, tab/input styling, timestamps/format, fade/delay and history.
Check new chat windows inherit settings and disable restores original art,
fonts, timestamp CVar and supported history/fade properties. Smaller history
limits retain fewer messages. Test during combat and after combat ends.
Check friend/member search, online filters, sorting, optional notes/details
and whisper preparation. A player without a guild sees a clear empty state.

## v0.7.18 Control Center cards

Browse all three pages. Check each module's distinct title, rail and border
color, with matching hover/click feedback. Check there are no Settings
buttons and the Enabled/Disabled toggle sits at the right edge. Click each
card to open settings, including disabled modules. Use the toggle to change
only enable state, then return to the same module page.

## v0.7.17 native menu windows

1. Open Contacts, Professions, Spellbook, Achievements, Map & Quest Log,
   Guild & Communities and Appearances. Check dark backgrounds, cyan borders,
   gold header accents, suite menu icons and readable fonts; no native frame
   art should reappear on hover or when switching pages.
2. Check Friends/Recent Allies/Raid tabs, Add Friend, disabled Send Message,
   spell paging/dragging, profession flyouts, progress and unlearn confirmation,
   achievement filters, guild/community navigation and appearance filters.
3. Pan and zoom the world map and click native/suite quest pins. Verify map
   tiles, pins, quest tracking and appearance model previews remain visible.
4. Open each window, then use Move Frames to move/resize it. Save, close and
   reopen. Verify saved placement and normal close/escape behavior.
5. Turn off Social, Guild, Professions, Action Bars and Map individually. Verify
   original art/fonts return to their windows. Re-enable and check the suite
   style returns. Enter combat before opening a newly loaded window; verify
   cosmetic changes wait until combat ends without blocking game actions.

Copy the updated ForeverSuite folder into your Forever Interface/AddOns
folder, replacing the previous version. The work folder is not needed in the game.
Use `/console scriptErrors 1`, then `/reload`, then `/fs`.

## v0.7.16 resizing

- Open Move Frames. Drag the +/- corner grip for Main Menu, bags bar, action bars, unit frames and module windows. Confirm immediate resizing without moving the frame center.
- Check the displayed percentage and 60%-140% limits. Done and reload must preserve the size; Cancel must restore the prior size and position.
- Start resizing and enter combat; Move Frames must close and stop changing the frame.

## Character tab layout

- Reputation and Skills: confirm the list is left and selected details are right; descriptions and checkboxes must not cover the list.
- PvP: verify the main ranking area and reward details remain in separate columns.
- Statistics: scroll down and up through all sections; newly appearing rows must have the same font size and no clipped text.


- Open Reputation and select multiple factions. The name, standing, description and checkboxes must stay above the footer and below the character header.
- Switch through Skills, Player vs. Player, Currency and Statistics. Scroll their lists and check that native actions still work and no text or controls cross into the header or tabs.
- Return to Character and repeat the tab changes; no old page should remain visible.

## v0.7.16 equipment dragging

Open Character Info, then backpack; repeat in the opposite order. Both should
remain visible. Drag compatible armor from a bag onto its gear slot; verify
it equips, the previous item returns to the bags, and both displays refresh.
Close either window independently. Check the combat restriction and that
Control Center/Patch Log still close both inventory and Character Info.

## v0.7.2 quest navigation, overlaps and nameplates

1. Open the spellbook from its real button and key binding. Check menu clearance. Switch between it, Character, Patch Log, Control Center, quests and world map: previous windows should close without flicker or overlaps.
2. Check that the native top XP strip is hidden and the custom XP bar appears beneath the action bar. Move it in Move Frames. Disable Action Bars outside combat, then during combat, and verify native visuals/input return after combat ends.
3. Accept quests with multiple objectives. Check card titles, progress, completion colors and distance. Fold/unfold cards; hover titles for all objectives. Scroll every quest page and enable nearest-first/hide-completed settings.
4. Check client-provided quest locations on the minimap and world map. Test zoom, rotating minimap, walking, zone changes, turn-in markers and multiple quests in one area. Grouped markers should show a count and cycle quests on repeated clicks. A pin represents a client objective area, not every individual enemy spawn.
5. Toggle map icons and disable Quests; all custom pins must disappear. Test a location with no coordinate API: no errors or guessed pins. Test map/focus clicks in combat: no protected-action popup.
6. Press V off/on repeatedly while targeting different enemies, moving and entering/leaving combat. Custom plates must return without the native visuals. Test Friendly settings separately. Reload after a toggle to check the saved enemy preference.

## v0.7.1 inventory layout checks

1. Open bags with the normal bag key. Check the category sidebar, search, grouped rows, item counts, free space and money. No native bag should flicker outside combat.
2. Switch All Items, OneBag, MultiBag and Recent Items. Search and select a category. Scroll both sidebar and content to reach all entries/pages.
3. Loot an item. Check the recent quick-view copy and the normal category copy. Review NEW by hovering; the recent copy should remain. Hide/show recent, then wait ten minutes to check expiry. Vendor preview quantities and proceeds must never double.
4. Add a category with an item selected. It should receive that assignment unless Favorites, a quest or sale eligibility has priority. Check assignments in More item options and after reload.
5. Drag the title and resize grip. Items should reflow immediately. Check minimum/maximum size, narrow layout, many categories, merchant controls, pagination and reload persistence.
6. Right-click Hearthstone, drag an item, mark junk and review a sale. Verify secure use, Never sell, reserves, sale summary and cancellation still work. Check bags alongside the bank and in Move Frames.

## 1. Gray junk and protected items

Open your bags. Eligible gray items should have a green pulsing border.
Open Overview and select Show All Items. Click Always Keep on one gray item.
Its glow and sale eligibility should disappear. Remove Keep in Rules to
restore eligibility. Check that quest items are excluded with a reason.

## 2. Add your own junk

Choose an inexpensive non-quest white item you are happy to sell.
In Overview -> Show All Items, click Mark as Junk on its row. It should
appear in the eligible list and glow in your default bags in Manual mode.
Alternatively, drag an item into the Rules input and click Save as Junk.

Open Rules -> Highlight Effect. Try green/gold/cyan, pulse off/on and
intensity 0.5. The change should appear immediately on eligible icons.

## 3. Preserve part of one stack

Use one stack of 20 inexpensive items. Keep a normal bag slot free.
Load that item in Rules, set Keep at least to 12 and Restock to to 0,
then click Save as Junk. Its glow should be amber with x8.
At a merchant, click Sell 8 on that row. Twelve should remain.
The visit report should show the value of eight sold items and zero
slots freed for this partial-stack sale.

## 4. Selling modes

In Settings, the mode button cycles Manual -> Auto Junk -> Custom Rules.
Manual should not sell anything until you click Sell.
Auto Junk should sell eligible gray items at a new merchant visit but
leave your custom white junk alone. Custom Rules should include it.
Always Keep and quantity reserves should still apply in every mode.

## 5. Repair and supplies

Test Repair with personal funds. Set the repair limit below the quoted
cost and enable Confirm repairs above limit: no repair should happen
before clicking Confirm Repair. Test guild options if your client/guild
supports guild repairs; otherwise a reason should be shown.

Choose a cheap supply sold by the merchant. In Rules set Restock to
to your desired quantity, then Save Stock Only. Set a small restock
budget in Settings and click Save Budgets. Supplies -> Restock Now
should buy within the target, merchant stock, budget and money reserve.
Bundle sizes can leave a shortfall rather than exceed your target.

## 6. Buy back, stop and persistence

Sell an inexpensive item, open Buy Back and recover it while it remains
available. Use Always Keep first if you want to avoid future auto-sales.
Close the merchant and verify the report includes the buyback cost.

Click Stop during a batch or close the merchant. Remaining transactions
should stop; one already-issued operation can still finish.
Use `/reload` and check that rules, budgets, highlight settings and
history persist. The existing minimap button and `/fs` should still work.

If an error appears, capture its full text and the action that triggered
it. Also note whether you use the default bags or another bag addon.

## 9. Bags & Stock (v0.3)

1. `/fs bags` opens one carried-bag window. Right-clicking the minimap button
   does the same. Escape closes it; moving the window persists after `/reload`.
2. Search a name, item ID and a literal special character. Clear the search.
   Try every category and all four View orders. Next/Previous must work with
   more than 48 slots. Check free slots against the native bags.
3. Select a cheap white item, Mark Junk, then Always Keep. Glow/eligibility
   must update in both Bags and Vendor. Check Auto Junk excludes custom white
   junk, while Manual and Custom Rules include it. Quest/rare protection still applies.
4. Set keep 20 on a junk stack of 30. Preview must show only 10 eligible.
   At a merchant, right-click the item or Sell Selected. Only 10 should sell.
   Keep sufficient normal-bag space for the temporary partial stack.
5. Save a restock target greater than Held. Stock must show the missing amount.
   Move all copies out of your carried bags: Stock must still show the rule
   with Held 0 and the full target missing. Restore the item afterward.
6. Outside combat, drag a cheap item to an empty slot and swap two items.
   Confirm actual bag/slot coordinates in the tooltip. Try Sort Bags after searching/filtering: All must show named category
   sections again. Item counts and actual slot locations must stay unchanged.
7. Enter combat: viewing/searching must work; item actions must
   stop with an explanation. Visual Sort Bags remains available. Test item use on a harmless consumable outside combat.
8. Open Junk Preview away from a merchant. It must show eligible
   stacks and the same header totals; selling is only available at a merchant. Change a Vendor rule
   while Bags is open and confirm the bag labels update immediately.

Use `/console scriptErrors 1` for this pass. Report any error's full text
and the action that caused it. Offline checks do not confirm real-client
layout, restricted API behavior or interactions with other bag addons.

## 10. Skin, automatic categories and embedded tools (v0.3.1)

1. Check dark panels, cyan accents, item selection borders and category headings.
   Each heading belongs to the item row below it, including continued pages.
2. Select an ordinary item and cycle Category to Materials. All copies should
   move into Materials immediately and stay there after `/reload`. Automatic
   restores detection. Marking an eligible item Junk takes priority.
3. Loot or move an item: its category section updates without clicking Sort Bags.
   Sort Bags clears search/filter and restores category ordering, including in combat.
4. Bag Settings: change glow, selling mode and stock/repair automation from Bags.
   Enter multiple gold budgets before saving; edits must survive inventory refreshes.
5. At a merchant, Bags opens by default. Repair above the chosen limit should
   offer Confirm Repair in the same bag. Confirm once, then verify the cost.
6. Tools -> Buyback: sell a cheap item then buy it back there. Close the merchant
   and check Tools -> History. Test multiple pages if there are enough entries.
7. Copy Assets with the addon and restart the client for the addon-list metadata.
   Verify its custom icon and short tooltip. Check the same icon on the minimap
   and window headers. Never copy the development work folder.

The new skin and logo still need visual verification in the actual client.

## 11. Central Control Center (v0.4)

1. Type `/fs`. Check the branded dark dashboard, watermark and cyan header.
   Bags and Vendor cards have different icons and cyan/gold accents.
2. Hover each card and click it: a brief colored flash should play and the
   settings should appear inside the same window. Other module windows close
   when the dashboard opens. Close returns to general settings.
3. Disable Bags. Its Open button should stop working; right-click minimap and
   merchants should no longer open Bags. Enable it again and verify access.
4. Disable Vendor. Automation, sales and junk glow must stop. Saved junk and
   stock rules must remain intact. Re-enable and verify those rules return.
5. Edit budgets and glow from the central settings without opening Bags.
   Reload UI at the bottom should reload immediately and preserve changes.
6. Click Open on a module: the dashboard closes and that module opens.
   `/fs` returns to the dashboard, so no extra command needs to be remembered.


## 12. Simplified module settings and native bags (v0.5.0)

Use this checklist for the current version. Earlier sections document older
labels and layouts; Settings now replaces Open on the Control Center cards.

1. Update the addon, enable script errors and reload. The welcome should show
   v0.5.0 successfully loaded and Type /fs to manage your modules.
2. Press the usual bag key and click the backpack icon outside combat. Each
   should open the skinned ForeverSuite bag once; repeat to close it. Check
   combined and separate native bag preferences. Bank windows stay native.
3. Loot items of several types. Category headings update automatically. Verify
   all quantities/free spaces; search/filter and Organize must work without
   changing the actual inventory slots.
4. Initially, empty spaces, advanced item rules and unnecessary pagination
   should be hidden. Select an item: basic actions appear. More item options
   reveals quantity/category controls. More options can show empty spaces.
5. Visit a merchant: Sell junk, Repair gear and Buy supplies appear in Bags.
   Test a cheap partial-stack sale with a saved keep amount; reserved items
   must remain. Away from the merchant these actions disappear.
6. Type /fs. Clicking module cards must open the correct
   settings. Bags shows opening/highlight options; Vendor shows selling and
   automation. Advanced settings reveals only that module's detailed options.
7. Use Back to Control Center in Bags and Vendor. Use Back to bags inside
   embedded bag settings/tools. Settings inside Vendor opens central Vendor
   settings. Only one main ForeverSuite window should be visible at a time.
8. Disable either module and check its actions stop while its settings remain
   accessible. Existing junk/keep/shopping rules must survive re-enabling.
9. Turn off Use ForeverSuite bags: native bag controls remain usable. Re-enable
   it and test again. Enter combat: native bags stay available and ForeverSuite
   item actions are blocked. Exit combat and check normal opening resumes.
10. Check Vendor's dark/gold skin, clear Junk page and merchant-only actions.
    Save an advanced budget, reload and verify both that budget and bag rules.
    Use the Control Center Reload UI button to finish.

Report the full error text and action if an error appears. The bag-key hooks,
combat fallback and visuals require this actual-client test.


## 13. Compact bottom-right inventory and flicker fix (v0.5.1)

1. Update all addon files and reload. Press the normal bag key repeatedly and
   click the backpack icon. Only the compact ForeverSuite inventory should
   appear, without native bag flashing. Test separate and combined native
   preferences. Open a merchant twice: opening should not act like a toggle.
2. Inventory starts at the bottom-right (unless previously moved). It grows
   with the items shown. Cells are small squares, under cyan category headings.
   Clicking a heading collapses/expands that group without changing any items.
3. Drag the title bar. More options -> Inventory size cycles 70/85/100/115%.
   Reload and verify the saved size and position. Reset position returns to
   the bottom-right. Popups should stay on screen at each size.
4. Click an item: options appear next to the bag, without expanding it into
   a large dashboard. Close the popup. More options -> Settings opens the
   Control Center. Use the Control Center button to return to module cards.
5. Check free slots, gold, search, filters, full inventory pagination, junk
   glow, merchant actions and a safe partial-stack sale. Native bank bags
   remain usable. Combat and disabled/replacement-off native fallback still work.

Offline simulation passes; real-client flicker, frame layout and keybindings
need this in-game verification.


## 14. Secure Hearthstone use and tooltip fix (v0.5.2)

1. Update all files and reload to clear any old tainted UI state. Outside combat
   and away from a merchant, right-click Hearthstone. It should cast normally,
   with no blocked-addon dialog. Repeat with the separate Use item button.
2. Test an ordinary usable consumable and equipment item. Left-click only
   opens item options; right-click uses/equips. An item marked Never sell can
   still be used. Its tooltip must show Always Keep only once.
3. At a merchant, right-click still sells only the allowed quantity. Hearthstone,
   Never sell items and reserved quantities must not be sold. No secure item-use
   action is bound at a merchant; the Use item button is hidden.
4. Move or remove a selected item, then check the selection and action update.
   Locked/stale slots, a held cursor and active transactions cannot use a
   previously bound item by mistake.
5. Enter combat with the inventory open. It should hide securely, without a
   blocked-addon message. Native bags remain available. Exit combat and reopen
   ForeverSuite; current item slots and secure use must work again.

Offline tests verify configuration and safety guards, not actual protected
Hearthstone execution. This real-client check is required for confirmation.


## 15. Favorites (v0.5.3)

Check Favorites above the other inventory sections. Hearthstone starts there.
Select another item and use Add to Favorites; all copies should move into
Favorites. Remove it and check normal category detection returns. Use the
Favorites filter, then return to All. Remove the Hearthstone favorite and
reload: it must remain removed. Favorites (0) remains visible above the other
sections when empty. Junk rules and Never sell protections remain unchanged.


## 16. Ammo and complete class mapping (v0.5.4)

Check unmarked arrows/bullets in Ammo. A favorite still appears in Favorites;
an eligible junk item appears in Ready to sell. Check recipes, spare bags,
keys, gems and crafting materials in their matching groups. Open the two-column
filter, select Ammo, then return to All. Check category assignment and new loot
updates. Verify a mixed inventory spans pages without missing items. Other is
the fallback for miscellaneous or unrecognized types. If a specific item is
misclassified, record its item ID and the observed/expected category.

## 15. v0.6.0: loot, sale review and Gear

- Use Hearthstone or a potion outside combat. Its bag icon should show the cooldown; expired cooldowns and recycled cells must clear it.
- Obtain a new item, open Bags and check NEW. Hover it to clear the marker. Toggle both display options in advanced Bag settings.
- At a merchant, choose Sell junk. Check item names, eligible quantities, expected proceeds and pages when there are more than seven items. Protected items must be excluded and reserved quantities retained.
- Cancel: nothing is sold. Reopen the review, change a junk/keep rule or item quantity, then confirm. It must request another review before selling the updated list.
- Confirm an unchanged list. The visit report should reflect successful sales. Newly acquired junk must not be added to that batch. Close the merchant or enter combat: confirmation must not issue a sale.
- Automatic selling remains automatic when explicitly enabled; use manual mode to test review.
- Open Gear from its small button and Settings from its Control Center card. Check equipped items, empty slots, durability, warnings and back navigation.
- Test repairing below and above the Vendor limit. Above-limit confirmation must stay in Gear; funds, reserves and guild permissions must match Vendor settings.
- Disable Gear, reload and verify settings persist. Inspect the three module cards and settings panels for overlap at your UI scale.

## 16. v0.6.2: combat UI and top-left main menu

Start with other action bar, unit frame and nameplate addons disabled. Copy the entire updated addon, including Assets/Menu, and reload.

- Check six module cards in /fs. Settings panels must fit below the cards at your UI scale, with Back and Reload UI accessible.
- Verify player left and target right of the central action bar. Portraits should mirror; health values, percentages and power should update.
- Target a friendly player, an enemy player and an enemy creature. Players use their class color; hostile creatures use red. Check a neutral creature (amber) and a friendly creature (green).
- Change targets and clear the target while fighting. The custom target frame must appear/disappear correctly without blocked-action errors.
- Left-click a frame to select its unit, right-click for its native menu; test spell targeting and normal keybindings in and out of combat.
- Cast and channel a spell; check both cast bars. Interrupt a target cast, switch targets and verify the old cast disappears.
- Test health and power changes, death and resurrection. Where the client restricts numerical data, bars should still display without Lua errors.
- Move player and target independently using Settings > Move frames, including with no target selected. Done returns to settings. Change Size and reload to verify persistence.
- Change size or disable a protected module while in combat. Changes should apply when combat ends; movement handles must close on entering combat.
- Verify all action buttons, keybindings, drag/drop, tooltips, cooldowns, page up/down, stance/form paging, pet and possess controls. Enable bottom/side bars using game settings and check their layout.
- Test combat, stance changes and any vehicle/override interface your character can access. Native action behavior must remain intact.
- Main menu buttons must be top-left, with cyan/gold icons and working native tooltips/clicks. Check Character, Spellbook/Talents, Quests and Game Menu; available buttons vary by client/features.
- Check disabled menu buttons are gray and unavailable; notifications should show an amber dot. Toggle Menu in top-left off and on to check native restoration.
- Press V for enemy nameplates. Check creature/player colors, health/cast/debuff updates, clicks and reused plates after moving out of range. Friendly forbidden plates may retain Blizzard visuals.
- Disable Unit Frames, Action Bars and Nameplates independently. Native graphics/placement should return. Re-enable and reload; saved preferences should persist.
- Confirm Bags, junk review, Vendor and Gear still work after the combat UI changes.

## v0.6.2 visual and protected-action checks

1. Replace the complete addon folder, including UI/Fonts.lua, UI/Layout.lua,
   Modules/Character and Assets/Menu/FantasyAtlas.tga, then reload.
2. Open each top-left main-menu icon twice. Each native window should open
   once and close normally without flickering or moving the bag bar.
3. Open all six Character tabs; check the model, equipment tooltips/actions,
   reputation, skills, PvP, currencies and statistics. Confirm the shared font.
4. Check bag buttons bottom-right retain original icons. Check action slots,
   empty slots, paging, cooldowns and keybindings without stock decoration.
5. Press V: enemy nameplates should have red custom bars, class-colored
   players, suite icons, cast bars and debuffs. Click a plate to target it.
   Move away and return to test pooled plates. Disable/re-enable Nameplates
   and confirm native/custom visuals restore correctly without duplicates.
6. `/fs` > Move Frames: drag and scroll handles, test snapping, Done, Cancel,
   Reset and saved placement after reload. Move the Nameplates preview and
   confirm all live plates use the same offset/scale. Entering combat ends
   move mode; no protected-action popup should occur.
7. Recheck the Hearthstone right-click, junk review quantities/proceeds and
   protected items after the UI changes. Report any Lua error or blocked action.

Offline simulations cannot establish real-client protected-action behavior.

## v0.6.3 main menu regression

Click each top-left menu icon directly and confirm its window opens once,
then closes normally. Test disabled buttons and keyboard shortcuts, and
check after entering/leaving combat. Disable Action Bars and confirm native
menu positions, artwork and button sizes return. This version uses native
hardware-click buttons rather than forwarding a scripted click.

## v0.6.4 nameplates

Confirm Move Frames has no Nameplates handle and Nameplates settings has no
Move Frames button. Test size from 60% to 140%, enemy-only defaults and both
friendly-type toggles. Plates must stay attached to their units. During
combat, visibility CVar changes wait until combat ends. Disable the module
and confirm the original client visibility settings and visuals return.

## v0.6.5 main menu layout

Check every menu icon remains the same size in one straight row after
hovering, clicking, opening/closing native windows and a reload. Stock icons
must never appear on hover/press. Move the Main Menu handle and confirm all
buttons follow together. Disable Action Bars to check native restoration.

## v0.6.7 patch log and credits

Reload: verify a compact patch log for v0.6.7 appears and shows only this
version's changes. Check Don't show again and reload: it must stay hidden.
Open Patch Log manually from the Control Center; uncheck the option to
restore startup display. Footer order: Reset settings, Patch Log, Move
Frames, Credits, Reload UI. Credits should show DeluxiZ and AI assistance;
no patch-log checkbox or history controls should appear in Credits.

## v0.6.8 Character Info

Click each of the six footer tabs. Each should select its native page once,
with no blocked-action message or stock tab layout returning. Check model
controls, gear tooltips/equipping, stats and scrolling. Hover native controls:
stock normal/pushed/highlight artwork must remain hidden. Disable Character
and confirm native tab positions and artwork return. Re-enable and reload.

## v0.6.9 full Character page and window switching

1. Check the current patch log shows 0.6.9 only. Open Control Center,
   Patch Log and Credits in both directions: they must not overlap.
2. Open Character with C or the menu icon. Confirm the old slots, stats,
   stone sidebar, portrait tabs and model controls are hidden. Our frame
   should show a clean model, own gear slots and own right-side panels.
3. Click every bottom tab. Reputation/Skills/PvP/Currency/Statistics must
   open their page; Character must return to the own gear/stats view.
4. Test an equipped item's tooltip, Shift-click, left-click pickup, drag
   placement and right-click use. Check ammo counts, trinket cooldowns and
   equipment model changes. Do not accept a blocked-action popup as success.
5. Check Character Stats values and paging. Equipment Manager: create a new
   named set, reject duplicate names, select/equip it, and confirm deletion.
6. Titles: choose a known title and then No title. Check all three side
   buttons and their own icons. In combat equipment edits/page changes are
   deferred or refused while secure item use retains client restrictions.
7. Disable/re-enable Character and check native panel restoration. Test
   dragging, scale and reload; check opening Bags/Gear/Vendor/Control Center
   replaces the previous suite window. Junk review must return to its source.

This is offline-validated; full client visuals and protected actions cannot
be established by the simulator.

## v0.6.10 slot hover and placeholders

Hover each new gear slot and verify its tooltip anchors to that slot. Hover
the old native slot positions: no old tooltips should appear. Empty slots
show the matching grey equipment icon without truncated labels. Equip and
remove gear to check normal item icons switch back to grey placeholders.
Disable Character to confirm native tooltips work again, then re-enable.


## v0.7.0 roadmap expansion

1. Copy TOC, Assets, Core, Localization, UI and Modules together. Reload and verify v0.7.0 and the compact current patch log. /fs always opens Control Center; no other slash entry is needed.
2. Page through all 21 module cards. Open each Settings panel, return, disable/re-enable it, and open its tool window. Windows should be opaque and exclusive; Close/Control Center should work. Search, select, page and move/resize the new windows through Move Frames. Reload to check saved placement.
3. Profiles: save Travel, change bag size/layout and save Raid. Switch between them, edit and switch back. Item rules and module toggles should follow the chosen profile; startup patch-log preference remains shared. Switching/resetting in combat or during a sale must be refused.
4. Focus/party/raid: set focus, join a party, then a raid. Confirm unit targeting, class colors, health/power/casts, group visibility and no native frames showing behind. Party hides in raids. Move/scale the group headers, toggle each group off, and verify native restoration. Change a setting in combat and confirm it applies afterward.
5. Nameplates: select different enemies and verify only the target has a gold outline. Generate threat with another player; labels should follow readable values and clear on recycled plates. There must be no decorative icon or Move Frames handle.
6. Key Bindings: select an unused action and bind a key with Ctrl/Shift/Alt. Verify the action in game, reload, and check the key persists. Escape/closing/combat should cancel capture and restore keyboard input. A key can replace its existing assignment, so use a spare key for this test.
7. Bank: visit a banker. Confirm your purchased character tabs, then account tabs if available. Inventory and bank should appear beside each other. Search and page categories; pick up/drag an item into an empty bank space and back to bags. Close/open, move both windows and disable replacement to verify native bank restoration. Bank contents must never be listed for vendor sale.
8. Gear: verify per-slot item levels and Mean equipped ilvl. It is the arithmetic mean of readable occupied slots, excluding shirt/tabard, not a claim to Blizzard's weighted value.
9. Map: verify coordinates outdoors, save a named pin, select Waypoint, open the world map, change maps/zoom and return to see the correct saved marker. Remove it. Compare explored-region counts and instance lockouts with game data. Unavailable instance coordinates must not crash.
10. Quests: verify objectives and the compact first-four-quest tracker. Toggle it off to restore native tracking. Opt into dialogue automation, hold Shift to pause it, test a no-choice completion and a multiple-choice reward. Reward choices must stay manual. Turn automation off after testing if preferred.
11. Loot: fast loot stays off until enabled. Test Shift pause and a bind-confirmation item. Check history stays at 100 messages. Select an active loot roll and test valid Need/Greed/Pass; expired/ineligible rolls must not send choices.
12. Buffs: read helpful/harmful effects and weapon enchants. Add a known buff spell ID, remove the buff, confirm a missing reminder, apply it and confirm the reminder clears. Remove the reminder and reload.
13. Cooldowns: enter a known spell ID, Track, change its group and use it normally. Verify remaining duration/charges/Ready state, ready filter and Remove. No hidden cooldown values should cause an error.
14. Combat: complete a fight, then inspect Current/Overall and cycle damage, healing, deaths, interrupts and dispels. Compare with the game's Damage Meter. Reports should say they update after combat while fighting. First Reset asks for a second click; the second clears native recorded sessions.
15. Professions: open a real profession and read learned recipes/craftable counts. Select a recipe, compare required/owned materials with the game and test an alternative reagent slot if one exists. Back restores recipes. Crafting remains in the game's window.
16. Auction House: browse an item/commodity and record loaded results. Compare stack division/unit price and lowest-listing labels. Add an item ID and quantity to shopping; remove it. Reload and check dated realm/faction observations persist. Turn recording off; fresh results must not overwrite prices. No purchase should happen automatically.
17. Social and Guild: verify their separate friend/member entries, filters, sorting and optional details. Whisper should only prepare your message. Chat: test timestamps on/off and module disable restoration. QoL: check XP/rested progress, invite a consenting test character by button, and test safe dismount outside combat/flight. No invite should happen from just opening the window.
18. Repeat junk preview/sale protections with favorites, Always Keep, reserved quantities and a partial stack. New modules must not weaken vendor safeguards.

Record the actual client build and any error text when reporting a failure.
Offline tests do not replace these in-game checks.

## Skills and PvP layout check

Check Skills and PvP after reloading: readable text, framed columns, turquoise skill bars, scrolling through all skills, and selected skill details. Confirm PvP rank and rewards remain visible at the lowest and highest available ranks. Disable Character Info and check native progress bar styling is restored.

## v0.7.16 full UI style

- Reload and inspect action/menu backgrounds, native action clicks/bindings/cooldowns and hover/click feedback. Empty slots should remain subdued.
- Check class-colored player health, red enemy health, outlined HP values, power values and gold portrait rims.
- Move and resize the main bar; the unsaved XP bar should follow. Hover XP for text and tooltip; check rested progress does not cross the next-level boundary. A saved XP position must remain independent.
- Check minimap border, zone/time header, coordinates, zoom buttons and quest pins.
- Complete and collapse a quest: completion checkmark and controls should remain within the card.
- Test chat input, links, tabs and scrolling; test native damage-meter selectors, session rows, drill-down, scrolling and resizing.
- Bag icons must remain original; default gear button shares the strip. A moved gear button must stay at its saved position.
- Disable Social, Map, Combat and Action Bars individually and verify original art/fonts return where applicable. Re-enable and enter combat to check no blocked-action or Lua errors.

## v0.7.16 screenshot corrections

- Confirm one centered minimap rim and one zone/time header. Disable Map and verify the native compass/header/clock return.
- Main Menu background must end just after its final visible icon.
- Gear caption must remain readable beside the bag bar, with independently moved gear preserved.
- Chat tabs and damage-meter buttons must retain native clicks and disabled behavior with the suite styling.

## v0.7.16 meter and chat

Verify dark meter header, one compact border per header control, readable metric/session labels and native dropdown/settings/minimize clicks. Meter rows and resize grip must retain native interaction without extra padded boxes. Check chat tabs, focus the input box, type/send a message, switch tabs, then disable Social/Combat to confirm original art restores.

## v0.7.16 minimap resize

Open Move Frames and find Minimap. Drag its corner, then its handle; check the rim, header, buttons, pins and coordinates. Done and reload must keep the placement and scale. Cancel restores the prior layout. A separately positioned Coordinates frame should remain independent.

## v0.7.16 clock

Verify time appears only at bottom center in the suite frame. Move/resize Clock through Move Frames, reload and confirm saved placement. Map disable should hide the custom clock and restore the native clock.

## v0.7.16 local time and coordinates

Compare Clock against Windows local time, wait for a minute change and repeat during combat. Confirm only one coordinate pair under Minimap after reload, zone changes and minimap hover. Toggle Map > Show coordinates off and verify the other addon label restores; turn it back on and confirm duplicate labels hide again.
