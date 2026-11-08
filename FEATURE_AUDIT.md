# Feature audit - 0.8.0

All 20 additions implemented; improvements 2-10 implemented/offline checked.
Improvement 1 has optimizations/diagnostics but still requires the live combat
and target test. Do not treat this as certification of the former flicker fix.
DELIVERY_STATUS.md maps all 30 entries to behavior and limitations.

New files: Core/Extensions.lua (codec/data/profiles/undo), Modules/Extensions.lua
(module rules, opt-in filters, sessions, queues, audit), UI/Workbench.lua (shared
tools/direct menu and pooled forms/copy windows). 66 Lua files compile/load.
242 scenario groups and all existing vendor/texture protections pass.

Limits: five backups, ten undo states, 20 keywords, 200 session chat messages,
100 recent members, 64 NPC rules, 50 queued pins, 20 checklists of 100 items,
256-character notes. Imports are size/node/depth bounded and never executed.
No native secure bar anchors/paging/handlers or game bindings are replaced.

Previous audits:

# ForeverSuite feature audit — v0.7.39

Ten choices: Celestial Forge, Titanium Signal, Obsidian Arcana, Verdant Relic,
Glacial Prism, Royal Aether, Runestone, Astral Glass, Ember Bastion, Cartographer.
Each is included in the first-run picker with a matching concept preview and a
real runtime panel/button/arrow set. Runtime assets and concept layouts are
separate: saved game positions are not replaced by the example composition.

First-run selection stages until finish; appearance-only mode stages until Apply
style. Cancel is non-mutating. Profile switching restores appearance; upgrades
retain Legacy until choosing one. Native bar anchors/actions/handlers are not
changed. Slice textures ignore native layout bounds. Font family/size choices
are preserved; light-theme contrast is restored when leaving that theme.

63 Lua files / 200 offline scenarios / 40 texture checks pass. Live visual,
combat and protected-action verification remains outstanding. ROADMAP.md still
contains future feature work outside this theme release.

Previous audit:

# ForeverSuite feature audit â€” v0.7.38

Live client observed locally: 1.60.1.70862, product wowf, _forever_ directory.
TOC remains Interface 16001. Event registration uses availability detection when
exposed, with per-event protected-call fallback. /fs status reports client data,
unsupported registrations and overlapping UI ownership without changing settings.
No global game APIs are replaced. No beta settings are migrated automatically.
62 Lua files load and 192 offline scenarios pass. No live gameplay test performed.

Previous audit:

# ForeverSuite feature audit - v0.7.37

Decoration attached to native layout owners is marked ignoreInLayout. This
covers action bar trays, slots, borders, feedback regions, native window chrome,
chat controls, menu/bag borders and nameplate canvases. A native-style bounds
fixture verifies that outward decoration does not grow its owner repeatedly;
native controls still contribute to the bounds. 189 offline scenarios pass.
Live combat overlap, target flicker and protected actions remain unverified.

Previous audit:

# ForeverSuite feature audit - v0.7.36

v0.7.36 supersedes the native-anchor approach in v0.7.32-35. Action Bars now
styles native bars without changing their position, scale, positioning flags,
systemInfo tables or native layout methods. Native bar IDs are excluded from
ForeverSuite Move Frames/Apply. Saved positions remain stored but inactive;
use Game action bar layout for actual position/size. Installer scale is preview
only. Style discovery updates native windows, chat or meters independently.
Only deferred module/unit-frame settings apply at combat completion. /fs errors
records the last ten ADDON_ACTION_BLOCKED/FORBIDDEN events without changing UI.
187 offline scenarios pass, including write-rejecting native layout tables,
native drift preservation, scoped discovery, deferred settings and diagnostics.
The actual failed function and live combat result remain unverified.

v0.7.35: six deterministic RGBA textures replace flat-colored tile/tray
backdrops. Gold has an octagonal layered bevel and mounted cyan gem; Floating
has clipped corners; Dock has cyan button rails and gold end caps. Texture
artwork and icon inset logic are shared by setup previews and actual bars.
Original icon points/crop restore on disable; only decorative texture anchors
change. Stable styling avoids repeated icon point writes and defers combat.
185 offline scenarios and asset format/color/alpha checks pass. Live game
rendering, cooldown overlays and combat behavior still require client checks.

v0.7.34: four action bar appearances reuse native buttons and secure actions;
only decorative tile and tray frames change. Guided setup stages choices in
a draft, previews bars, units, quests, chat, nameplates and navigation, and
applies six module enable flags plus bar style/scale at Finish. Existing saved
positions and other module preferences remain. Welcome shows version/creator,
opens the Patch Log and returns to setup. Completion/dismissal is per install,
excluded from profile snapshots. Existing nonempty databases skip automatic
setup; the Control Center and /fs setup can reopen it. Every step scales to
the viewport and reflows text. Combat and active vendor work block applying.
Live rendering and protected actions still require the game client.

v0.7.33: action bar position hooks check actual desired geometry and ignore
unchanged anchors/scales. Genuine drift coalesces into bar-only position repair,
without calling full SettingsChanged or SkinButton. Saved placement has priority
before any geometry write; scale applies before the final point. Empty-button
slots belong to the bar, follow native button anchors and ignore mouse input.
Their borders survive hidden buttons without changing secure visibility/actions,
and hide with the bar or module disable. Native unchanged anchors avoid repeat
runtime layout writes/detachment. 179 offline scenarios pass; live target/combat
flicker remains unverified.

v0.7.32: native action-bar runtime anchors/default-position state are synchronized
outside combat for managed bars, including Move Frames positions. Original
runtime anchor/default data restore on disable, and native layout reloads
reapply addon positions. No secure native methods or game save APIs are replaced.
Discovery polls structure/visibility changes; unchanged UI does not receive a
full style pass each second. The native combat layout reset path is simulated
in regression checks; actual client combat and flicker remain unverified.

Current viewport audit covers every module at maximum typography, a 1024x768
viewport, and inherited dashboard scales 0.65 and 1.4. Basic/advanced forms and
generic settings pagination stay contained; explicit help and edits retain
their relationships. Idle settings do not re-anchor continuously. Action bar
automatic positioning flags restore on disable; no secure methods are replaced.
Cast progress uses per-frame normalized values, without resetting an unchanged
range on health/power events. Native player cast bar alpha restores on disable.

Current settings audit: all module pages match their module card border color.
Custom forms share responsive two-column controls/help with separate header and
footer. Basic/advanced relationships retain their edit callbacks and contents;
generic settings retain pagination. Inventory uses typography-aware sidebar,
toolbar and item bounds; Character adjusts tabs/stats pagination; native map
text fitting is limited to navigation and detected search/count controls.
Six smaller modules gain real filtering/sorting/display options. Profiles,
normalization, combat guards, native restoration and all existing regressions
pass in 171 offline scenario groups. Live rendering remains unverified.


Typography layout audit: responsive suite Control Center/Profile controls,
generic settings and tool lists, font editor, About and quest tracker. Extreme
fonts are bounded to multiple lines; card details also have full hover tips.
Saved mover scale is respected. Native secure geometry is not globally reflowed.
All 165 offline scenario groups pass, including module ownership/restoration,
combat deferral, font inheritance and profile/reset regressions. This is not a
visual certification of every native or specialized module screen; those need
live checks with the actual client fonts, pools and UI scale.


Native map skin restricts generated X glyphs to the primary close control and
preserves helper controls/canvas actions. Achievement header geometry restores
on skin disable; targeted category background and statusbar edge suppression
preserve points, shield and progress data. Generic settings paginate twelve
options per page with fixed action/hint separation and opaque panel fill.
Native visual layout remains unverified in the running Forever client.

Animated minimap ant trail uses the active navigation vector, with view-radius
and rotation-aware projection, ellipse/rim bounds and at most 40 pooled dots.
Noninteractive child frames preserve minimap clicks and inherit its scale.
Five validated profile options control visibility, color, size, spacing and
opacity. Missing data, arrival, stop and disable clear stale dots. This is a
straight-line guide; no walkable terrain graph or pathfinder is included.

Waypoint direction animates each frame using live facing and exponential
shortest-angle interpolation. Position/status updates are throttled to 20 Hz;
frame-rate-independent turns avoid wrapping around the long side at +/-pi.
Missing data/arrival clears animation; changing quest/map initializes its new
direction. Rendering and performance still need live client verification.

The compact transparent waypoint contains only a custom arrow, title and
distance/status row. Its original seven-segment spearhead uses the selected
color plus gold edges and a dark shadow, rotated with player facing. Chevron
uses the same head; no raster assets are required. Font-aware height and
existing saved Move Frames placement/scale remain. Live rendering is unverified.

Central Text & Fonts settings provide font family, scaled/fixed size, weight,
outline and shadow, with global defaults and per-module overrides. Suite
frames, scoped settings, unit/nameplate canvases, native styled windows,
chat, action bars, minimap, clock/XP and damage meter have module ownership.
Defaults retain existing suite font roles; bold uses the bundled Arial Bold
face. Saved settings validate against known choices and switch with Profiles.
Base sizes prevent cumulative scaling. Native font/shadow restoration and
forbidden-frame exclusion remain; combat changes defer. Actual rendering and
large-text layout still require live checks; it does not change unstyled
native text or create arbitrary bold font variants.

Map now includes a configurable quest waypoint panel with 13 options and a
Move Frames target. Accepted quests select their next readable client location;
progress/completion refresh it, clicked quests can focus it, and turn-in/removal
can select the next nearest locatable quest. Manual saved pins take priority.
Explicit stop remains stopped until another accept/focus. Native map writes
defer during combat; disable clears only matching owned markers, preserving
external replacements. Profiles include options and placement. Cross-map
direction requires compatible world coordinates; missing data is explicit.
Direction is straight-line, with no terrain pathfinding or quest spawn database.
No running-game rendering or actual Forever quest availability is verified.

Nameplates now has an independent designer with an interactive example,
six draggable components and validated X/Y positions. Its 34 options cover
bar/text dimensions, health formats, alignment, visibility, class/threat and
configured colors, target scale/outline, other-plate opacity, cast icon/time
and aura type/ownership/count/size/spacing/cooldowns. Four presets retain
enemy/friendly visibility preferences. Settings and component positions
round-trip through Profiles. Preview drag uses effective screen scale and
stable starting coordinates; combat stops dragging and defers appearance
updates. Native targeting, V recovery and pooled-frame restoration remain.
The example uses explicit sample data; real-client rendering and API limits
still need validation. No Platynator dependency or copied assets are used.

The native profession crafting skin handles Frame-based rank bars with a
suite fill anchored to the game's actual fill bounds and a full-width trough.
Search/filter/reset controls use separate bounds. Known profession sidebar
tabs move inside the window and retain native selection, icons and tooltips;
scrollbar arrows/track/thumb use suite visuals. Progress values and filtering
are not changed; native geometry/art restore on disable. Missing optional
fields are skipped, and combat changes remain deferred. Actual client
rendering still needs verification. A workspace-only one-click launcher runs
the existing offline checks; it does not emulate WoW's rendering engine.

Chat side buttons now have suite panels/icons and an independent appearance
toggle. Only button decoration is stripped; counts, tooltips, notifications,
native actions and enabled states remain. Chat opens its settings directly
instead of a generic overview. Its typing action preserves the native draft.

Loot has 14 settings plus a confirmed history-clear control. History limits,
source, recording, view order/time/quality and roll-helper view/sorting/auto-open
are independent. Filters do not change pickup or delete filtered entries;
lowering storage limits trims old history. Uncached quality remains visible.
Native loot-window styling preserves slot actions and item icons. Fast loot
keeps Shift/combat pauses and manual binding confirmations; roll eligibility
and expiry are rechecked. No automatic Need, Greed or Pass is added.

Profiles now have a fixed, always visible bar above cards and module settings.
Save current/new profiles, cycle choices and load directly. Existing profile
snapshots and shared startup preferences are preserved; combat/vendor guards
still apply. Profiles have no card or enable toggle.

Chat scrollbars use suite track/thumb/arrow visuals, with background bounds
including the original control. Native click/drag/value handlers and text
positions stay intact; disabling panel styling restores captured native art.

Control Center: all 21 cards now have unique accent colors across three pages.
The cards open their settings directly; only enable/disable buttons remain.

Chat, Social and Guild have separate enable/style states and settings (13,
8 and 9 respectively). Filters/details affect their searchable suite tools;
chat history/fading use available frame APIs and restore captured properties
on disable. Old Social settings migrate only to missing new module data.

The screenshot menu windows now have shared native-window styling: Contacts,
Professions, Spellbook, Achievements, World Map/Quest Log, Communities and
Appearances. Native content/actions remain in place; the map canvas and
appearance models are excluded from decorative stripping. Top-level loaded
windows join Move Frames. Actual rendering and interaction need live checks.

Reviewed the original roadmap on 2026-10-04; updated bags and quest navigation on 2026-10-05.
Character Info and backpack coexist for equipment dragging in v0.7.16. Secondary Character pages now fit inside their content panel, with external header/footer anchors corrected.
Bags now includes the sidebar layout, OneBag/MultiBag/recent views, saved
custom categories and responsive resizing. Recent quick-view copies never
enter sale plans twice.
The earlier version was 0.6.10. Every area below now has a functional first
implementation. Offline tests verify Lua syntax and simulated behavior;
real-client API access, protected actions and visual layout are not yet
verified in the running game. No feature is marked live-tested.

| Area | Present before this review | Added in v0.7.0 | Actual scope / client limits |
| --- | --- | --- | --- |
| Core | SavedVariables, /fs, minimap, switches, patch log, credits | Named profiles; paged cards for 20 modules; /fs only | Profile save/switch, isolated settings/layout/item-rule snapshots; startup patch-log preferences shared. Switch/reset blocked during combat or vendor actions. |
| Unit Frames | Player and target, portraits, health/power/casts | Focus, four party members, forty raid members | Secure unit targeting and menus, class colors, grouped layout/movement. Party hides in raids. Raid has compact health/power; its cast bars stay hidden. |
| Action Bars | Native action handling, paging, binding/stance/pet behavior, suite skins | Dedicated binding editor | Main/extra/stance/pet key bindings, modifiers, cancel and current-set saving. Combat changes blocked. |
| Nameplates | Custom health/cast/debuffs, size/visibility, class colors | Current-target outline and threat labels; v0.7.22 adds a 34-option designer, six draggable components and four presets | Only public readable threat values are interpreted; secret values produce no label. Designs save in Profiles. Nameplates remain anchored to units and excluded from Move Frames; live visuals still need checking. |
| Bags / Bank | Categories, search/sort, favorites/Hearthstone, ammo, rules/glow/cooldowns | Separate custom bank, character/account tabs, search/categories/paging | Reads purchased bank-tab IDs; click/drag moves items after rechecking slot identity/lock state. Bank and inventory stay side by side. Bank data never enters a vendor sale plan. |
| Map | Native menu entry | Coordinates, saved pins/waypoints, map-canvas pins, exploration, instance info | Exploration is a count of explored regions, not a made-up completion percentage. Instance information covers current difficulty and saved boss lockouts. Map APIs may be unavailable inside instances. |
| Quests | Native menu entry | Objective overview, compact tracker, optional accept/turn-in | Tracker now has three quest cards per page, progress/focus/collapse/map actions, distance sorting and all quests through paging. Custom map/minimap pins use client POIs/waypoints, cluster overlaps, and hide on unavailable coordinates; no bundled Questie spawn database. Shift/combat pause automation. Reward-choice quests stay manual. Native tracker restores on disable. |
| Loot | Native client looting | Fast loot, configurable history (25-500 messages), filters, active-roll helper and loot-window skin | Fast loot is opt-in; Shift/combat pauses and binding dialogs remain. Filters are for display; uncached qualities remain visible. Need/Greed eligibility and roll expiry are rechecked; failed rolls stay selected. |
| Vendor | Review/proceeds, protected and partial-stack sales, repair/restock/history/buyback | Existing safety checks retained | Defaults remain manual; sales revalidate before sending. |
| Buffs | Native client buff UI | Buff/debuff overview, missing-buff reminders, weapon enchants | Reminders use user-entered spell IDs. No automatic buff casting. |
| Cooldowns | Bag/item cooldowns and unit casts | Own-spell manager with Interrupt/Defensive/General grouping | Seed known class cooldowns once; add/remove spell IDs, ready filter, durations/charges where readable. It does not infer other players' hidden cooldowns. |
| Combat | Native combat log | Damage/healing/deaths/interrupts/dispels reports | Uses Forever C_DamageMeter current/overall data after combat. Native reset requires a second click. No C_CombatLogSecure access or secret-value bypass. Readable-log fallback is for other compatible clients. |
| Gear | Durability, Character stats/slots/sets/titles | Per-slot item levels and arithmetic mean | Mean includes occupied readable slots except shirt/tabard; it is labeled separately from a Blizzard weighted average. |
| Professions | Native profession entry | Recipe and material overview | C_TradeSkillUI enumeration/schematics and guarded legacy fallback. Requires an open profession/data source. Crafting remains in the game window. Alternative reagents are labeled Choose one. |
| Auction House | Native auction UI | Loaded-result price observations and shopping list | Realm/faction scoped, dated observations. Legacy stacks and commodity/item search results use per-item prices; browse minimums are labeled lowest listing. No full-market crawl or automatic purchases. |
| Chat | Native chat, previously styled through Social | Separate configurable panel/tab/input style, text, opacity/border, timestamps, fading and history | Captured properties/art/fonts restore on disable; chat APIs apply only where available. Scrollbar handlers and text positions remain native. |
| Social | Native contacts entry | Friend search, independent online filter/sorting/details and whisper preparation | List preferences affect suite tools. Contacts styling has its own option. Whisper opens an input; it does not send a message. |
| Guild | Native guild/community entry | Separate member search, online filter/sorting/details, whisper preparation and window styling | Public member notes only. Lists need available roster data; no-guild state is explicit. Native actions remain available. |
| Leveling/QoL | Bag/vendor convenience | XP/rested progress, explicit invite and dismount tools | Invite only on the user's click. Optional mounted-error dismount is off by default and never runs in combat or flight. |
| Skins/UI | Shared font/colors/icons/grid, own Character page | Opaque new tools windows, selection/search/paging/return navigation | All new windows appear in Move Frames. Bank/inventory are a deliberate side-by-side pair; other suite windows remain exclusive. Live visual validation still needed. |

## What remains to verify

Run IN_GAME_TEST.md in Forever 1.60.1. In particular: native group-frame
suppression, purchased bank-tab IDs and cursor transfers, quest dialogue,
roll eligibility, profession enumeration/materials, observed auction prices,
key capture, map canvas pins, and the damage meter after a real fight.
Restricted or unavailable APIs show an unavailable state rather than
invented data. These baselines do not include automated purchases, a full
market database, dungeon strategy guides, or remote cooldown inference.

## Primary client API references

- [Forever BankFrame source](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_UIPanels_Game/Camelot/BankFrame.lua)
- [Damage Meter API](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/DamageMeterDocumentation.lua)
- [Damage Meter metric/session usage](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_DamageMeter/DamageMeterSessionWindow.lua)
- [Threat/unit API](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua)
- [Quest Log API](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestLogDocumentation.lua)
- [Map exploration API](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/MapExplorationDocumentation.lua)
- [Auction House API](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/AuctionHouseDocumentation.lua)

Visual pass v0.7.16: shared bars/menu/bags/gear panels, unit portrait rims and values, minimap header/rim, quest completion marks, native chat/meter styling and XP rested/hover presentation.
