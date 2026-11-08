## 0.8.10

- Addon systems (/fs addons): choose supported navigation/nameplate providers.
- Unit Frames: Pet toggle and Move Frames target; player/target/focus/pet levels.
- Text & Fonts: scope retained, immediate active-profile save, startup reapply.
- Sell item: explicit unmarked-item sale at a merchant with protection feedback.

# Control Center improvements in 0.8.6

- Search above the module cards by name, feature or setting label. Multiple
  words must all match; punctuation is searched literally. Try "dps", "dismount"
  or "quest waypoint".
- Cycle All modules / Enabled only / Disabled only with the filter button.
  Module toggles update the result list immediately.
- Clear or Escape resets filters and returns to the page you were browsing.
  Enter opens settings when exactly one module matches.
- Muted icons and state text identify disabled modules. Hover uses the module's
  current accent palette. Settings remain available while the module is disabled.
- The close button uses the chosen theme. Search controls adapt to text size.

# New tools in 0.8.0

Open More tools / search in the Control Center, or `/fs tools`. Click Tools: …
to choose a category directly. The left arrow goes back one category. Search
filters rows; the three bottom buttons adapt to the selected category.

## Profiles and settings

- Profiles: select Export and Open / export. Select all and Ctrl+C copies it.
  For import, enter a destination profile name in the bottom field, select
  Import and open the paste window. Preview validates data; Apply stays disabled
  until validation succeeds. Editing invalidates the preview. Pasted text is
  never executed. The export/import limit is 200 KB.
- Select a saved profile and Use / restore. Backup rows restore previous versions.
  Select a profile and Assign login to use it for this character next time.
  Selecting the assignment row and Assign login clears the assignment.
- Settings: search by module or label. Open goes to the editor; Change cycles
  booleans/value lists; Favorite pins a setting. Complex values use their editor.
- Undo last setting or `/fs undo` restores a reversible preference change. It
  never reverses sales, purchases, loot, chat or game bindings. Combat and active
  merchant transactions block undo.
- Accessibility: choose readable text or a compact screen preset. Setup previews
  these before applying. Palettes change module accents and NPC health colors;
  names and labels remain visible.

## Notifications and communication

- Alerts: choose a category, sound and channel, then Test sound. Silent is the
  default. Volume follows the selected game channel. No game volume setting is
  changed. Repeated notifications have a ten-second cooldown.
- NPC rules: customize the normal Nameplates designer, then target an NPC and
  Save target. A numeric NPC ID can also be entered. Update saves the current
  design again. Remove returns that NPC to the global design.
- Important casts: add a spell ID. Matching readable casts receive an orange bar
  and ! label. Optional audio is in Alerts. No automatic cast/interrupt occurs.
- Chat keywords: add literal words/phrases of 2–64 characters; enable/disable or
  remove entries. Links/icons/color payloads stay intact. Audio is optional.
- Chat history: Start capture opts in. Copy history opens the latest 200 session
  messages as selectable text. Clear empties it. Nothing is sent to chat or copied
  to the system clipboard automatically.
- Guild notes: select a member to star/unstar or save a private note (256 chars).
  These never change public/officer guild notes. Search Show local guild notes
  to include them in the normal suite roster view.
- Recent groups: Start tracking opts in, including current party/raid members.
  Clear history deletes saved records; Forget member removes one.

## Inventory and progress

- Item checklists: Add opens name, item ID and quantity fields. A selected Bags
  item can prefill its ID. Counts cover carried items, not bank stock. Goals do
  not buy, sell or reserve anything; use Vendor keep-stock rules for protection.
- Buyback: visit a merchant, select an entry, Buy back. Availability, current
  price, money, cursor/repair state and combat are rechecked. Open merchant tools
  links to the existing Bags buyback/history tools.
- Loot session: own received/created quantities and known vendor value. Unknown
  prices remain separate. Reset clears counters, not saved loot history.
- Waypoint queue: select a saved pin and Start / add to append. Select a queue row
  and Start / add to begin. Move up reorders. Remove / stop removes a selected
  queue row and stops navigation. Arrival advances automatically. Contents are
  saved; start again after reload/profile changes. Guidance stays direct.
- Leveling session: observed gains, XP/hour and estimated minutes to level. This
  requires readable gains and ten seconds elapsed. Reset starts a new session.

## Client checks

Maintenance / `/fs audit` shows the last 20 combat/target layout snapshots and
API capabilities. `/fs status` shows build, unavailable events/APIs and overlapping
UI addons. Search Style game popup windows to restore native popup art without
disabling the corresponding module.

The live combat/flicker check is still open. During normal play enter/leave
combat and tab targets. Check bar positions/size, hotkeys/paging and UI flashes.
Record `/fs errors` if a blocked-action warning appears. Ordinary Lua errors
need their own error text. Offline checks cannot certify actual game rendering
or secure hardware actions.
