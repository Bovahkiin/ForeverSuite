# Current patch - 0.9.2

Add the Character Pet tab, live pet details, experience and happiness, separate
model rotation, large-font spacing and full-value tooltips.
Distribution through GitHub after the full suite and package checks pass.
Live pet rendering remains an in-game verification step after updating via WoWUp.
No direct changes to the installed game addon or saved profiles.

# Patch - 0.9.1

Fix minimap tray placement and collection conflicts; add gear comparison indicators.
Distribution through GitHub releases after the full suite passes.

# Patch - 0.9.0

Three new themed modules: Mail, Addon Buttons and Gear Advisor.
Beginner class advice is automatic; custom weights are optional.
Full-suite and package validation gate the GitHub release.

# Patch - 0.8.13

Fix the four error signatures captured in the local General.log.
Regression tests and release validation run before distribution.

# Patch - 0.8.12

Feed Pet takes priority over inventory options and targets the clicked stack.
Hunter pets display the client's real happiness icon and a feeding/diet tooltip.
The compact pet placement from 0.8.11 is included. Custom placements persist.
Local targeted checks pass; the GitHub release workflow gates publication on
the full suite. Distribution uses GitHub releases; the local game is not changed.

# Patch - 0.8.11

The default pet frame is smaller and follows the player's frame below it.
Saved custom pet positions/scales remain independent. No SavedVariables file
is edited; the new default applies whenever no custom pet placement exists.
Protected changes wait until combat ends. See VALIDATION.txt for checks.

# Patch - 0.8.10

Adds pet/level information, profile text persistence hardening, matching bag art,
supported addon-system choices, manual item sales and native-window corrections.
The prior 0.8.9 action-bar isolation architecture is retained. User reports no
further combat error so far, correct layout, and working equipment/BoE use.

Offline coverage: 288 scenario groups; see work/latest-test.txt. New features
still require live rendering/hardware-action checks. External provider adapters
are capability-checked, not a promise of compatibility with every addon/version.

# Patch - 0.8.9

Action-bar decoration is separated from native layout children and regions.
All styles remain; a read-only driver synchronizes the suite's art frames.
Theme sizing guards secret dimensions. Temporary diagnostic code was removed.
266 offline scenarios pass; actual combat taint verification is pending.
The captured logs/audit did not conclusively establish the first taint source.

# Patch - 0.8.8

Native action-button hover/leave/post-click callbacks are left unchanged by the
feedback layer. Other protected controls skip feedback hooks too. Skins remain.
263 offline scenarios pass. This targets the reported combat hover path but the
exact original taint source is not established; in-game confirmation is needed.

# Patch - 0.8.7

Inventory equipment now uses the native container-slot action on right-click or
Use item. The addon never accepts binding automatically. Consumables retain
their secure item action. Merchant selling and existing protections remain.
261 offline scenarios pass; actual equipping and bind dialogs need a game check.

# Patch - 0.8.6

Control Center improvements: literal multiword search across module/feature/
setting names, state filters, contextual result counts, keyboard shortcuts,
clear-to-previous-page navigation, module-colored hover and state labels,
disabled icon desaturation and a theme-matched close button.
258 offline scenarios cover these changes and existing modules. In-game visual
confirmation of the new dashboard remains pending.

# Patch - 0.8.5

Author confirmation, 2026-11-08: layout restoration now survives reload; combat
and logout are reported working without the earlier blocked-action warnings.
This supersedes the pending status below for those reported cases in the
author's setup. Broader in-game coverage remains part of future regression checks.

Saved positions remain unchanged during restoration, including when startup
temporarily reports a smaller UI viewport. Bounds are persisted only during
explicit moving/resizing. Display/UI scale events reapply the original layout.
252 offline scenarios pass. Live verification remains pending; desktop access
to WoW was denied by the automatic permissions check.

# Patch - 0.8.4

Current character-assigned profiles no longer reload stale saved snapshots over
live edits. PLAYER_LOGOUT updates the active snapshot before serialization.
Native menu/layout/coordination hooks queue corrections instead of mutating
frames inside the native callback. Native menu visibility/enabled writes have
been removed. The live logout/quit and combat taint checks remain open.
251 offline scenarios pass. Earlier delivery details follow below.

# Delivery status — ForeverSuite 0.8.0

All 20 additions below are implemented and offline checked. Improvements 2–10
are implemented/offline checked. Improvement 1 has optimizations and read-only
diagnostics; its live combat/target check remains open. Offline checks do not
prove that the previously reported game flicker has been fixed.

Open Control Center > More tools / search, or `/fs tools`. The tool-name button
opens a direct category menu. All ten Blender appearances remain available.

## 20 additions

| # | Addition | Where / behavior | Status |
|---|---|---|---|
| 1 | Profile export/import | Profiles: export, paste, Preview, Apply; no execution of pasted Lua | Implemented |
| 2 | Automatic backups | Before save/import/switch/restore; last five can be restored | Implemented |
| 3 | Character assignment | Profiles: select profile, Assign login; assignment row clears it | Implemented |
| 4 | Readable/compact presets | Setup step 3 previews text; finish applies the selected preset | Implemented |
| 5 | Settings search | Every module, named options and simple default fields; complex controls open their editor | Implemented |
| 6 | Favorite settings | Pin rows; Favorites persists per profile | Implemented |
| 7 | Undo | Ten reversible settings snapshots; no reversal of game transactions | Implemented |
| 8 | Accessible palettes | Module accents, NPC health colors and retained text labels | Implemented |
| 9 | Alert controls | Sound choice, mute, game audio channel, test and cooldown | Implemented |
| 10 | NPC rules | Save current nameplate design for target or numeric NPC ID | Implemented |
| 11 | Important casts | Readable spell IDs gain orange color and ! label | Implemented |
| 12 | Chat keywords | Literal highlights, preserved links/icons, optional sound | Implemented |
| 13 | Chat copying | Opt-in, last 200 session messages, selectable copy window | Implemented |
| 14 | Guild favorites/notes | Local stars and private notes; no public/officer-note writes | Implemented |
| 15 | Recent groups | Opt-in history, up to 100 members, clear/forget controls | Implemented |
| 16 | Item checklists | Named carried/missing item goals | Implemented |
| 17 | Manual buyback | Lists merchant items and rechecks current price/money on click | Implemented |
| 18 | Loot sessions | Own item quantities, known vendor value, unknown-price count | Implemented |
| 19 | Waypoint queue | Append pins, reorder, start/stop/remove; advance on arrival | Implemented |
| 20 | Leveling sessions | Observed XP/hour, time estimate, level rollover and reset | Implemented |

## 10 improvements

| # | Improvement | Evidence / limit | Status |
|---|---|---|---|
| 1 | Combat/target overlap and flicker | Fewer nameplate anchors, waypoint font/layout writes and unrelated unit-frame rebuilds; /fs audit records native bounds without correcting them | Live verification open |
| 2 | Settings fit | Existing all-module/Advanced viewport checks plus new tool/forms/copy dialogs at 1024×768, size 24 | Implemented, offline checked |
| 3 | Reversible native style/fallback | Search Style game popup windows; off restores native art/fonts. Maintenance identifies unloaded windows | Implemented, offline checked |
| 4 | Inventory work | Reuse Vendor plan for Bags; cooldown events update pooled cells | Implemented, offline checked |
| 5 | Client availability | Event validation, API diagnostics and modern/legacy chat-filter support | Implemented, offline checked |
| 6 | Inactive work/resources | Stop generic update scripts/subscriptions, optional group/XP events and chat filters; reuse modal frames | Implemented, offline checked |
| 7 | Bounded data | Limits on backups, undo, keywords, chat, groups, NPC rules, queues, checklists and notes; clear controls | Implemented, offline checked |
| 8 | Regression coverage | 242 scenarios, including import abuse, privacy, rollover, queues, event lifecycle and viewport checks | Implemented, offline checked |
| 9 | Consistent controls | Shared Tools layout, direct category menu, structured forms, module accents/help | Implemented, offline checked |
| 10 | Common strings | Shared FS.Text navigation/action labels in existing and new screens | Implemented, offline checked |

Existing secure post-hooks cannot generally be removed through WoW's API; they
remain guarded no-ops when inactive. Native secure bar anchors, paging, click
handlers and game bindings are not replaced by these features.

Session-only: chat copy buffer, loot/XP totals, audit and undo. Profile-stored:
configuration, guild notes/stars, recent groups, checklists/rules and queued pins.
Assignments/backups belong to the shared profile manager. Exports omit private
notes, recent groups, histories and profile-manager data. Imports retain current
private notes/group history/merchant history.

Sound volume follows SFX/Master/Dialog game settings; there is no per-alert gain
slider or global volume rewrite. Waypoints provide direct guidance, not road
pathfinding. Restricted spell/location data is skipped.
