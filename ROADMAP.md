# ForeverSuite 0.8.0 — delivery overview

All 20 additions are implemented and offline tested. Improvements 2–10 are
implemented/offline checked. Improvement 1 has optimizations and diagnostics,
but its live combat/target verification remains open.

See DELIVERY_STATUS.md for each item's status and NEW_TOOLS.md for instructions.

## Archived original proposal

The following describes the original plan made for 0.7.38, before implementation.
Build them in small releases after verifying the live-client baseline. Preserve
secure game actions and existing settings. Each addition needs functional tests
and a usable settings page, with the owning module's existing accent color.

## 20 additions

1. Profiles: validated text export/import with a preview before applying.
2. Profiles: automatic backup before importing or replacing a profile.
3. Profiles: optional character-to-profile assignment.
4. Setup: readable-text and compact-screen presets with previews.
5. Control Center: search settings across all modules.
6. Control Center: pin frequently used settings in a favorites view.
7. Settings: undo the most recent reversible setting change.
8. Appearance: color-vision-friendly palettes with labels as well as colors.
9. Alerts: choose sound and volume behavior per supported notification.
10. Nameplates: per-NPC appearance rules using NPC IDs.
11. Nameplates: emphasize selected enemy spell casts where client data permits.
12. Chat: configurable keyword highlights with an optional sound cooldown.
13. Chat: select and copy a bounded section of readable chat history.
14. Guild: local favorite-member list and private notes.
15. Social: optional recent-group-member history with clear/remove controls.
16. Bags: named item checklists showing carried/missing quantities.
17. Vendor: a manual buyback shortcut after a sale, when the merchant supports it.
18. Loot: session summary with item counts and known vendor value.
19. Map: reorderable queue of saved waypoints, advancing on arrival.
20. Leveling: session XP/hour and estimated time to level from observed XP gains.

## 10 improvements

1. Verify combat transitions and target switching in the live client; resolve any
   remaining overlap or flicker before extending action bar behavior.
2. Fit every settings page at large fonts and small screens, including Advanced.
3. Make native-window styling reversible and show a clear fallback when a client
   window or API is unavailable.
4. Reuse bag rows and avoid complete inventory rebuilds for unrelated events.
5. Audit API/event availability against the live client, with useful diagnostics.
6. Remove redundant event handlers, timers and hooks when modules are inactive.
7. Bound saved history and caches; provide clear-data controls where appropriate.
8. Extend the offline harness with real layout/event behavior; retain an explicit
   live checklist for secure actions that mocks cannot verify.
9. Standardize control types, help text, spacing and module accent colors.
10. Consolidate scattered UI strings so labels and instructions stay consistent.

Suggested order: live stability; consistent settings and diagnostics; profiles
and accessibility; module-specific additions. Never present direct waypoint
guidance as terrain-aware pathfinding or restricted combat data as readable.
