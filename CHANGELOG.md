# 0.9.10 - 2026-11-11

- Apply ForeverSuite styling and placement before revealing Character Info,
  Spellbook and Talents when opening them outside combat.

# 0.9.9 - 2026-11-11

- Keep the Quick Tour text and buttons above the Control Center cards.
- Keep the tour highlight transparent and close it with the Control Center.
- Use English search examples in the README and the search help.

# 0.9.8 - 2026-11-11

- Start with recommended settings or pick your own layout, theme and text.
  The four-step setup uses one neutral preview with player, target, pet, chat
  and quest frames. Balanced is the existing Layout 1 preset.
- Module cards explain what each module does. Opening a card shows a separate
  basic settings screen with saved state and a direct Control Center return.
  More options opens the full settings on its own screen.
- A three-tip quick tour introduces settings, frame placement and profiles.
  Skip or dismiss it, or open it again from Control Center.
- Select a Move Frames handle to center it, place it below the player, or
  restore that frame. Saving confirms the active profile in chat.
- Help with layout brings saved frames on screen, previews Balanced and
  offers undo. Other addons explains waypoint and nameplate choices.
- Search for settings and common tasks in English or Dutch, including lost
  arrows, pet feeding, larger text and moving bags.

# 0.9.7 - 2026-11-09

- Give Control Center a scrollable middle area with fixed header, profiles and
  bottom actions. Add themed scrolling controls and mouse-wheel support.
- Fit the visible window to the viewport even with saved mover scale and large
  typography, without rewriting saved position/scale or shrinking chosen text.
- Reflow general action rows without overlap; reset scroll on search/page changes
  and clamp it after font, viewport and content changes.
- Render theme artwork on native-anchored flat decorations using fixed corner
  geometry. Keep restricted frame dimensions out of addon calculations.
- Apply guided setup themes through the shared theme setter, save the active
  profile immediately and display the selected theme in Control Center.

# 0.9.6 - 2026-11-08

- Keep native-anchored flat skins out of theme dimension calculations, so
  applying a setup theme cannot read restricted frame geometry.
- Add a fifth guided setup step: Layout 1, Compact, Classic and Keep current.
  Recommend Layout 1 only for new setups without saved mover placements.
- Add a neutral schematic preview with generic labels. No user screenshot,
  chat text, names, guild details or copied personal settings are distributed.
- Fit addon positions/scales to the current viewport; keep bars separated on
  smaller UI viewports and preserve custom placements when Keep current is used.
- Optionally create a separate named character game layout via copied public
  layout data and C_EditMode APIs. Never modify native action-button anchors,
  runtime systemInfo, flags, methods or secure action mappings directly.
- Preserve personal game layouts, check available slots/readiness and roll back
  on activation failure. Block layout commits in combat or vendor actions.
- Store the addon layout in the current profile and back up prior placements.
  Include the 0.9.5 fix for blank Welcome/text previews with disabled modules.

# 0.9.5 - 2026-11-08

- Keep Welcome and text/size preview examples visible independently of live
  module enabled flags. Disabling modules no longer empties the preset preview.
- Only the module-choice page filters examples by staged module choices.
  Explain the empty preview when all module choices are off.
- Preserve draft selections while moving between steps. All ten style images,
  bar-size previews and text presets remain available with live modules off;
  previewing never enables those modules or writes the staged preset.

# 0.9.4 - 2026-11-08

- Add Save and Save & close to Move Frames. Store the current layout in the
  active profile, with a visible confirmation and a new Cancel checkpoint.
- Fit the five mover controls to larger fonts and scale the toolbar to the
  available viewport width.
- Add Disable all modules to Control Center, including every module page.
  Preserve customization and profiles; Undo last setting restores prior choices.
  Block bulk disabling and explicit layout saves during combat/vendor actions.
- Update module captions directly before applying a module's state. Keep the
  visible label synchronized even if native button text is cached, module
  refresh fails, or another screen changes its enabled flag.

# 0.9.3 - 2026-11-08

- Defer the startup window until login handlers finish. Fall back to world
  entry or an addon loaded after login, and retry after combat if necessary.
- Do not infer completed setup from a nonempty or partial settings table.
  Only an explicitly saved completed/dismissed choice suppresses onboarding.
- Show setup before patch notes and handle startup once per session. Repeated
  world entries do not restart an active draft or reopen dismissed windows.
- Preserve manual setup and Patch Log navigation during delayed startup.
  Existing layouts, module settings, completed setup and dismissal persist.

# 0.9.2 - 2026-11-08

- Add a Pet sidebar tab to the custom Character window while an active pet is
  available, matching the Forever client's native sidebar structure.
- Show the pet model, level, health, power, armor, damage and attack speed.
  Add an experience bar and hunter happiness indicator with feeding guidance;
  show loyalty, available training points and diet when the client supplies them.
- Keep player and pet rotation independent. Update pet data without repeatedly
  resetting the model; handle pet dismissal during combat without changing
  protected equipment controls, and return to player stats after combat.
- Improve four-tab spacing and row pagination for larger fonts. Add full-text
  tooltips to character detail rows so long values remain readable.

# 0.9.1 - 2026-11-08

- Keep the addon-button tray next to its toggle, with above/below and left/right
  placement based on screen position. Drag the toggle directly or use Move
  Frames; its position is saved in the current profile without self-anchoring.
- Find nested minimap launchers and LibDBIcon-registered buttons with custom
  names. Native controls, map pins and protected buttons remain excluded.
- Detect active MinimapButtonButton/MBB collectors. Offer an explicit choice:
  use ForeverSuite and disable the other collector for this character + reload,
  or keep the other collector and turn off ForeverSuite's collection module.
- Add green up arrows, a gray dash and red down arrows for higher, equal and
  lower Gear Advisor scores in comparisons and item tooltips. Equal equipped
  items are shown correctly. Existing minimum-upgrade filters remain available.

# 0.9.0 - 2026-11-08

- Add a themed Mail module with searchable inbox, readable letters, expiry
  display and selected/all collection of attachments and money. Collection
  waits for server updates, skips COD/GM mail, and stops on full bags or errors.
- Add an Addon Buttons module: one minimap tray, adjustable icon size/spacing
  and columns, per-button exclusions, original click/tooltip behavior and
  restoration when disabled. Protected native controls remain unchanged.
- Add Gear Advisor with automatic class starter guides, simple build-role
  choices, bag comparisons, tooltip scores and optional custom stat weights.
  Advice works without editing weights. Estimates do not simulate procs,
  set bonuses or special Forever effects; verify equip requirements yourself.
- All three modules have their own dashboard cards, themed settings, profile
  support and shared typography. Existing combat fixes are retained.

# 0.8.13 - 2026-11-08

- Stop repeated nameplate aura errors when the client restricts aura access.
  Restricted aura icons are cleared and return when their data is available.
- Ignore target-of-target unit events that the nameplate lookup does not support.
- Render native-anchored decorative borders without calculating secret sizes.
- Fix module settings layout errors when opening configuration panels.

# 0.8.12 - 2026-11-08

- Fix Feed Pet: left-clicking a bag item with an active item-targeting spell
  now targets that exact stack instead of opening Item Options. WoW validates
  food suitability and reports invalid targets. Ordinary item clicks are unchanged.
- Revalidate item identity/locks and preserve vendor, cursor and combat guards;
  never fall through to equipping, selling or picking up an invalid spell target.
- Add the real hunter-pet happiness indicator: green Happy, yellow Content,
  red Unhappy, with feeding advice, readable damage modifier and food types in
  the tooltip. Hide unavailable/restricted data and non-hunter pet happiness.
- Retain the smaller pet frame (75% of the player's scale) beneath the player
  by default, while preserving custom pet placement and size.
- Add an optional direct-publish checkbox to the GitHub release button. The
  default remains a draft; direct publishing only occurs after all checks pass.

# 0.8.11 - 2026-11-08

- Make the default pet frame 75% of the player's frame size and align it
  below the player's frame, leaving room for the player cast bar.
- Follow the player's moved/resized frame while the pet uses default placement.
- Preserve explicit Move Frames pet positions and sizes and legacy custom
  coordinates. Independent pet movement continues to work.
- Keep protected placement changes outside combat. Add three regressions for
  following the player, persisted custom placement and combat deferral.

# 0.8.10 - 2026-11-08

- Add a movable, optional pet unit frame with name, portrait, level, health,
  power and casting information. Secure unit watches handle pet visibility.
- Show player, target and focus levels beside the name and reserve text space.
- Commit text choices directly to the active saved profile, remember the font
  editor scope and reapply typography after startup profile selection.
- Match bag-button borders and tray to the selected action-bar style/theme using
  independent artwork, retaining native bag icons, clicks and counts.
- Add per-character Addon systems choices for supported navigation and nameplate
  providers. Recognized navigation adapters: RestedXP, Zygor and TomTom. Guide
  addons stay active while only their arrows are switched. Nameplate selection
  enables/disables supported addons for this character and explicitly reloads UI.
- Keep those choices separate from UI profile imports/undo. Unsupported arrow APIs
  are reported without saving a choice; failed changes roll back prior flags.
- Restore wardrobe category atlas icons, skin collection side tabs and leave the
  mount-name hit area unframed. Preserve the mount model's original position.
- Share the native profession progress mask so the cyan fill follows skill ratio
  and the game's animation rather than always appearing full.
- Manual Sell item now sells eligible unmarked items without marking them junk.
  Retain Never Sell, quest, valuable-item and saved-quantity protections. Prevent
  stale selections from falling through to another junk item; show blocked
  reasons inside Item Options, including after stack splitting.

# 0.8.9 - 2026-11-08

- Move action-button borders, empty-slot artwork and native action-bar trays
  under UIParent, outside native bar/button child and region lists.
- Follow native visibility, opacity, strata and position with a read-only
  decoration driver. Change only suite-owned art frames during combat.
- Avoid Backdrop data on these decorations; skip theme corner calculations
  when the client returns secret dimensions.
- Remove temporary action-bar diagnostics. The captured audit showed no direct
  field taint among the inspected native fields; the log still blocked at wipe
  inside UpdateShownButtons. Independent art avoids the native layout subtree.
- Add three regressions for hierarchy isolation, secret dimensions and combat
  visibility/opacity. Retain all styles and inventory equipment fixes.
- 266 offline scenarios pass. Actual combat taint behavior remains subject to
  in-game verification; the original taint origin is not conclusively established.

# 0.8.8 - 2026-11-08

- Remove automatic decorative hover/leave/post-click hook registration from
  native action buttons and other protected controls. Their native hover path
  can call UpdateAction and UpdateShownButtons during combat.
- Keep action bar skins and themes; retain feedback on suite-owned buttons.
- Add regressions checking original native script identity, decorative border
  availability and exclusion of other protected controls from input hooks.
- This removes an addon interaction at the reported call path; the original
  taint source is not proven by the blocked-action stack alone. In-game
  combat hover validation remains required after a full UI reload.

# 0.8.7 - 2026-11-08

- Route bag equipment right-clicks and Use item clicks through the exact native
  container slot instead of the general secure item action.
- Keep bind-on-equip confirmation owned by the client; never auto-accept binding.
- Preserve secure consumable use and merchant selling, GUID validation, locked
  item checks, cursor/targeting checks and combat guards.
- Add three regression groups covering exact-copy equipment use, simulated
  binding accept/cancel, and invalid/stale/blocked item actions.

# 0.8.6 - 2026-11-08

- Search module names, feature descriptions, setting labels and useful aliases
  directly in the Control Center. Searches are literal and support multiple words.
- Filter all/enabled/disabled modules, show result counts, disable unavailable
  page buttons and explain empty results. Clear returns to the previous full-list page.
- Enter opens a unique result; Escape clears filters. Search state is kept only
  for the current UI session and does not change profile data or undo history.
- Add subtle per-module hover accents, clearer state label colors, muted disabled
  icons, toggle tooltips and a theme-matched close button. Adapt controls to typography.
- Name release archives with the -forever suffix required by WowUp's GitHub provider.
- Record author confirmation that 0.8.5 reload/combat/logout cases now work.

# 0.8.5 - 2026-11-08

- Keep saved coordinates unchanged when temporarily constraining visuals during
  startup. The client initially reports a smaller viewport before UI scaling settles.
- Reapply the saved layout on display-size and UI-scale changes; persist bounds
  only for explicit dragging/resizing, not during restoration.
- Add a regression with clock, XP bar, waypoint and quest tracker restored from
  a 1365x768 startup viewport into a 2133x1200 UI viewport.

# 0.8.4 - 2026-11-08

- Keep live edits when a character's assigned profile is already active on reload;
  snapshot the active profile on PLAYER_LOGOUT before SavedVariables are written.
- Reapply custom frame positions after entering the world.
- Defer menu geometry/artwork, bag dividers, layout hooks and window coordination
  outside native update stacks; coalesce window updates to the latest opened frame.
- Stop redundant native microbutton visibility/enabled writes and guard direct
  action-bar styling entry points during combat.
- Record the most recent local blocked-action stack for /fs errors. These changes
  require live logout/quit and combat testing; offline checks cannot reproduce taint.

# 0.8.3 - 2026-11-08

- Finish world-map chrome: breadcrumb back, modern overlay dropdowns, filter reset,
  quest settings, scrollbars and ornamental separators use addon styling.
- Preserve map tiles, pins and native control handlers; restore original art
  when native-window styling or the Map module is disabled.

# 0.8.2 - 2026-11-08

- Center the Move Frames grid and snapping on the same screen origin.
- Reuse grid lines and update their symmetric positions when the viewport changes.
- Convert saved positions when scaling so resizing retains the physical center;
  clamp moved/resized frames to the viewport outside combat.

# 0.8.1 - 2026-11-08

- Move the addon menu below an overlapping visible damage meter outside combat;
  retain separate placements and allow manual dragging in Move Frames.
- Center coordinate text with symmetric margins under the minimap.
- Keep opaque theme panels off player and target portrait borders.
- Use the selected theme's button borders and accent colors for chat controls.

# 0.8.0 - 2026-11-08

- Implement all 20 roadmap additions with a shared More tools window, direct
  category menu, structured forms and existing-module integration.
- Add bounded non-executable profile imports, preview/apply, five backups,
  character assignment, settings search/favorites and ten-step settings undo.
- Add staged readable/compact presets, accessible palettes, muted/channel
  alerts, NPC/cast rules, literal keyword filtering, opt-in chat copying,
  guild notes/stars, recent groups, checklists and guarded manual buyback.
- Add loot/XP session statistics and saved waypoint queues advancing on arrival.
- Add reversible native popup styling, API capabilities, modern/legacy chat
  filters, pooled modals, data bounds and inactive event/update lifecycle.
- Reuse inventory plans and cell cooldowns; reduce redundant nameplate anchors,
  waypoint font/layout writes and unrelated unit-frame rebuilds. Read-only
  /fs audit supports live diagnosis without correcting secure geometry.
- Keep the previous 200 checks; 42 new regression groups pass (242 total).
  Live combat/flicker verification, actual rendering and secure actions remain
  open, as recorded in DELIVERY_STATUS.md.

# v0.7.39 — 2026-11-07

- Add all ten Blender concepts as first-run appearance choices, each with its own
  staged design preview. Keep four setup steps and fit the full window to screen.
- Add a reusable appearance picker in the Control Center, preserving setup flags,
  module choices and gameplay geometry. Cancel keeps the active profile unchanged.
- Ship 40 uncompressed RGBA textures: panels, buttons, waypoint arrows and design
  previews. Use fixed-corner nine-slices, excluded from native layout measurement.
- Store appearance per profile. Preserve Legacy for upgrades; restore original
  artwork when using a legacy profile. Light-theme text restores on style changes.
- Add staging, cancellation, secure-button preservation, profile, combat, slice,
  text-contrast and waypoint tests. 63 Lua files / 200 offline scenarios pass.
  Actual game rendering, combat behavior and secure actions remain unverified.

# v0.7.38 â€” 2026-11-07

- Prepare the live release for Interface 16001 and the _forever_ install folder.
  The interface number remains unchanged; no new API incompatibility was reported.
- Check client event validity and catch rejected event registration per event.
  Preserve registration of supported events throughout the suite.
- Add /fs status for client version/build/interface, unavailable events and loaded
  Baganator/Chattynator/Platynator ownership overlap. Do not alter other addons.
- Add client detection, rejected-event recovery and overlap diagnostic tests.
  62 loaded Lua files and 192 offline scenarios pass. Live play remains untested.

# v0.7.37

- Exclude addon decoration from native ResizeLayout child/region measurements.
  Outward trays and empty-slot borders previously participated in those bounds
  and could recursively expand the native layout during client refreshes.
- Apply ignoreInLayout to native window chrome, chat controls, menu/bag borders,
  nameplate canvases and feedback textures. Native controls remain measurable.
- Add a regression using native child/region filtering that reproduces recursive
  growth before exclusion and verifies stable dimensions across 20 cycles.
  189 offline scenarios pass. Live combat overlap and flicker remain unverified.

# v0.7.36

- Remove writes to native action-bar positioning flags and Edit Mode systemInfo,
  native manager calls, anchor hooks and corrective position queues. Stop moving
  or scaling native bars, including through Move Frames and old saved positions.
  Game action bar layout now owns protected geometry; all four skins remain.
  Old positions remain stored but inactive. Setup size choices are preview-only.
- Limit native discovery to affected windows/chat/meters. Combat completion
  applies only deferred settings instead of rebuilding every module and unit
  watch; action bar skins are not rebuilt after unchanged combat cycles.
- Record the last ten blocked/forbidden addon actions this session. /fs errors
  prints the addon and failed function for diagnosing any remaining warning.
- Replace obsolete custom-native-anchor checks with write-rejecting native data,
  unchanged client geometry and scoped-refresh checks. 187 offline scenarios pass.
  A reload is required; live combat, rendering and taint still need verification.

# v0.7.35

- Replace basic colored rectangles with six dedicated action bar textures.
  Minimal uses cyan rims; Floating clipped corners; Compact dock a metal tray,
  gold end caps and cyan button rails; Gold & cyan layered octagonal gold bevels
  and mounted cyan gems. Empty slots use a subtle brushed background.
- Share artwork and icon inset rendering between the installer and actual bars.
  Icons leave space for decorative rims. Restore original icon points/crop on
  disable; retain native secure button geometry, scripts and action behavior.
- Add artwork parity, restoration, unchanged-anchor and combat checks, plus
  RGBA/TGA dimension/alpha/color validation. 185 offline scenario groups pass.
  Client rendering and overlay layering still need live verification.

# v0.7.34

- Add Minimal, Floating, Compact dock and Gold & cyan action bar styles, with
  independent decorative trays/tiles and profile persistence.
- Add first-use guided setup: welcome, style, bar size and six module toggles.
  The welcome page displays ForeverSuite, version, creator DeluxiZ and Patch Log.
  Patch Log returns to the same draft. Illustrative previews update on selection;
  only Apply & finish commits changes. Saved bar positions are retained.
- Add Guided setup to the Control Center, Action Bars settings and /fs setup.
  Existing installations retain preferences and skip automatic setup. Setup
  completion/dismissal is independent of profiles. Combat/vendor work blocks
  applying, and every step reflows and scales within the viewport.
- Add offline checks for styles/actions/profiles, migration, staged changes,
  welcome/Patch Log navigation, viewport bounds and startup precedence.
  Actual rendering and secure hardware actions still require client testing.

# v0.7.33

- Restore empty action-slot borders using noninteractive frames parented to
  each bar, independently of hidden native buttons. Slots follow existing
  native button anchors; no protected button is forced to show. Disable and
  bar visibility correctly hide these added visual borders.
- Position hooks compare desired anchors/scales before scheduling work.
  Actual drift coalesces into bar-only geometry repair instead of rebuilding
  every action bar, menu and bag control through SettingsChanged.
- Apply saved placement directly, without first jumping to default positions.
  Set native scale before the final anchor. Unchanged native runtime anchors
  avoid repeated writes and frame-manager detachment.
- 179 offline scenarios pass, including repeated target-style position writes,
  saved-placement stability and empty secure-button visibility in combat.
  Live target-switch flicker and visual rendering still require client testing.

# v0.7.32

- Fix the remaining combat bar-overlap path: native Edit Mode still resets
  bars to its old layout anchor when skipAutomaticPositioning is set. Managed
  bars now receive custom runtime position state/anchors outside combat, and
  leave the native frame manager. Saved Move Frames placements synchronize too.
  Native methods remain intact; original runtime layout data restore on disable.
- Native layout updates reapply addon placement. Frame registration follows
  replacement native frame objects instead of holding obsolete references.
- Stop full UI restyling every second while idle. Poll for newly created or
  shown native windows/rows instead; clock updates continue. Module toggles
  update styling immediately outside combat.
- 177 offline scenarios pass, including the native old-layout reset path and
  idle/discovery/combat polling. Actual client combat/taint and visual flicker
  still require in-game verification.

# v0.7.31

- Every module settings panel fits a centered screen viewport independently of
  dashboard position and inherited scale. Paging, advanced edits and large
  typography remain contained. Explicit header/help references prevent mixed
  descriptions, including Vendor Junk selling.
- Managed action bars opt out of native automatic positioning before combat;
  original flags restore on disable. Native secure methods, visibility,
  bindings and paging remain untouched. Bar refreshes only reapply bar layouts.
- Repeated styling no longer rebuilds unchanged HUD backdrops/fonts or saved
  layout anchors. Settings reflow when their content or viewport changes.
- Unit cast bars update normalized progress each frame with immediate fill,
  preserve unchanged ranges across unit updates and expire at their end time.
  Native player cast bar aliases are suppressed/restored with Unit Frames.
- 175 offline scenarios pass. Combat positioning, flicker and cast smoothness
  still require verification in the actual WoW Forever client.

# v0.7.30

- All Control Center settings use their module card color, opaque panel and
  consistent Back/title/description/two-column form. Existing help, edits,
  advanced controls and actions remain available; typography reflows the form.
- Inventory widens category/count space, wraps labels, uses a two-row toolbar
  at large sizes and reserves item/footer space without changing saved size.
- Character tabs use concise captions, wider panels at large sizes and fewer
  stats per page; title/level and footer spacing follow text height.
- Native map breadcrumb text fits fixed controls; detected search/count fields
  are separated, retaining native actions and restoring geometry on disable.
- Additional settings: Cooldowns group/order/charges/learned filters; Buffs
  aura/enchant/duration visibility and reminder size/combat visibility; Combat
  metric/session/rates/self-only/row limit; Auction House shopping/stock/date/
  sorting filters; Professions counts/order/missing materials; QoL summaries.
- 171 offline scenario groups pass, including saved settings/Profiles, real
  option effects, all settings colors, large layouts and restoration. Actual
  client rendering, specialized native variants and secure clicks need live QA.

# v0.7.29

- Control Center cards, Profiles, navigation and footer adapt to actual font sizes.
  Redundant card hints are hidden; full card descriptions remain in hover tips.
- Generic settings and tool windows, typography editor and About windows reflow
  text/controls and fit the screen. Saved tool/Control Center scale is preserved.
- Quest tracker grows with typography: multiline titles/objectives, wider Log,
  Map and distance columns, measured card heights and separate footer.
- 165 offline scenario groups pass, covering all modules, font inheritance,
  maximum size, repeated application, resets, Profiles and combat deferral.
  Live client rendering and secure interactions still require in-game checks.

# v0.7.28

- Restrict generated world-map close glyphs to the primary close control; keep
  helper controls native and give the quest panel toggle a directional glyph.
- Contain achievement title/points/shield in its header and suppress remaining
  category backgrounds and summary-bar decorative edges with native restoration.
- Paginate generic settings above twelve options so Map's nineteen options stay
  within the panel, clear of hint/open/footer controls; use an opaque panel fill.
- 162 offline scenario groups pass; actual screenshot layouts need live checks.

# v0.7.27

- Animated minimap ant trail follows the active quest or manual waypoint.
- Five Map options: enable, color, dot size, spacing and opacity, saved in Profiles.
- Projection respects view radius, minimap dimensions and rotation, with
  bounded dot pooling and rim clipping; dots never capture mouse input.
- Clears on arrival, stop, disable, hidden minimap or unavailable direction.
  Direct guidance uses known destination coordinates, without terrain routing.
- 159 offline scenario groups pass; live rendering remains unverified.

# v0.7.26

- Animate waypoint direction every frame instead of stepping ten times a second.
- Smooth the shortest angular turn with frame-rate-independent interpolation;
  live facing remains responsive while position/status refresh at 20 Hz.
- Clear stale direction on arrival, hidden HUD or unavailable data, and reset
  smoothly when changing quests/maps. Existing compact style/options remain.
- 59 Lua files and 157 offline scenario groups pass; game rendering remains unverified.

# v0.7.25

- Waypoint HUD now shows only arrow, quest title and distance on a transparent
  frame, removing the large panel, border, quest icon and instruction row.
- Original code-drawn spearhead combines the selected arrow color with gold
  edges and a dark shadow; Chevron retains the matching compact head.
- Arrival and missing-location messages share the distance row. Height follows
  the selected font size; existing movement, scaling, navigation and clicks remain.
- 59 Lua files and 156 offline scenario groups pass. Live visuals need a game check.

# v0.7.24

- Add Text & Fonts to the Control Center with a scoped preview and six controls: font family, size multiplier, fixed size, weight, outline and shadow. All modules inherit global settings and can have independent overrides, including Chat, Nameplates, waypoint/Map and Profiles.
- Include native font families and the bundled Arial Bold face. Bold selects the actual bold face instead of pretending every font has one; Default preserves existing suite choices. Keep original size roles unless fixed size is selected.
- Track base sizes to prevent repeated growth, discover module-owned frames and style newly created text. Preserve native restoration and original shadow offsets when a skin is disabled. Skip forbidden frames; defer combat changes and include typography in profile save/load/reset.
- Passed 59 Lua loads and 156 offline scenario groups. Font rendering and large-text layout still require live verification.

# v0.7.23

- Add automatic quest waypoint selection on acceptance, objective/turn-in location refresh, clicked quest focus and configurable next-quest selection after turn-in/removal. Retry delayed quest data; display missing-location status without invented coordinates.
- Add a suite waypoint panel with code-drawn arrow/chevron, distance/title/status, six colors, text/scale/arrival controls, combat visibility and optional native map waypoint. Add 13 waypoint options to Map settings; preserve manual saved-pin priority and explicit stop behavior.
- Add Move Frames positioning/resizing and Profiles persistence. Defer native map writes during combat, retain externally replaced pins and clear only owned native markers. Calculate same-world direction across maps when available; otherwise display the destination zone. No terrain routing or automatic quest completion is added.
- Passed 58 Lua loads and 150 offline scenario groups. Game rendering and live quest-location availability still require verification.

# v0.7.22

- Add a native ForeverSuite Nameplate Designer with an interactive sample, six draggable components, validated position fields and 34 options across Bars, Text, Colors and Auras. Retain real unit targeting and V off/on recovery.
- Add ForeverSuite, Compact, Large and Minimal presets, automatic settings persistence and Save current profile. Profiles include designs and component positions; presets retain enemy/friendly visibility. Defer appearance changes during combat and stop active dragging.
- Fix profession rank Frames whose native fill was stripped as background art. Add a cyan visual following the real fill rectangle and a framed full-width trough, preserving native progress/text updates.
- Separate profession Search, Filter and reset bounds; show a filter caret and reset glyph. Restore captured dimensions/anchors when Professions is disabled.
- Style and seat known overview/skill sidebar tabs inside the window, preserving native icons, selection and tooltips. Add profession scrollbar track/thumb/arrows without replacing scroll handlers. Include legacy CraftFrame in native window handling.
- Add a source-workspace one-click offline test launcher and explain what offline checks can verify versus in-game rendering.
- Passed 57 Lua loads and 144 offline scenario groups. Live visual verification remains required.

# v0.7.21

- Style the chat Contacts/count, Channels and Menu buttons with dark panels, configured borders/opacity and suite icons. Draw custom speaker/speech-bubble glyphs and preserve native actions, tooltips, counts, notifications and disabled states. Add an independent Style chat buttons option.
- Replace the generic Chat overview with direct settings navigation. Start typing in chat activates native input and preserves existing drafts. Keep the expanded Chat/Loot settings above the footer.
- Expand Loot to 14 settings for loot-window styling, history recording/limits/source/display/quality/time/order, active-roll display/sorting/countdowns/quantities and optional helper opening outside combat. Add two-click history clearing; keep display filtering separate from pickup.
- Retain manual Need/Greed/Pass, expiry and eligibility checks, binding confirmations and Shift/combat pauses for Fast loot. Rejected roll calls retain their active selection.
- Passed 55 Lua loads and 134 offline scenario groups. Live appearance and game interaction still need verification.

# v0.7.20

- Move Profiles into a fixed bar above all module pages and settings. Save or update the current profile, select a saved profile and load directly; remove its module card and enable toggle.
- Keep existing profile snapshots, shared patch-log preferences and combat/vendor guards. Shift cards and settings to leave clear space below the profile bar.
- Style chat scrollbar tracks, thumbs, arrows and return-to-bottom controls using chat colors/opacity. Extend the background around their native bounds without moving text or changing scroll handlers. Restore original art on disable.
- Make the Chat timestamps checkbox explicitly turn timestamps off while enabled; restore the prior game preference when the whole Chat module is disabled.
- Passed 55 Lua loads and 130 offline scenario groups. The new profile workflow and both modern/classic scrollbar paths pass; live visual confirmation remains required.

# v0.7.19

- Split Chat, Social and Guild into separately enabled modules with independent cards, styles and settings.
- Add 12 Chat options, 8 Social options and 9 Guild options. Friend/member display options affect their searchable suite tools; native game actions remain intact.
- Move chat styling/timestamps to Chat and Guild & Communities styling to Guild. Restore native chat properties on disable and defer changes during combat.
- Migrate legacy Social timestamps, guild online filtering and enable states only when the new module data is absent. Add validated preset settings with automatic persistence.
- Passed 55 Lua loads and 128 offline scenario groups covering independence, migration, chat restoration/deferred changes, filtering/sorting/details and whisper preparation.

# v0.7.18

- Give all 20 Control Center cards a distinct accent color, including modules on pages 2 and 3. Titles, rails, borders, hover and click effects use the module's color.
- Remove the redundant Settings buttons. Clicking the module card opens settings; enable/disable toggles remain and are aligned at the right edge.
- Update Control Center guidance and the current-version patch log. All 125 existing offline scenario groups pass with settings navigation through the cards.

# v0.7.17

- Add a shared native-window skin for Contacts, Professions Book/crafting, Spellbook, Achievements, Map & Quest Log, Guild & Communities and Appearances.
- Replace decorative art with dark panels, cyan borders, gold accents, shared fonts and suite menu icons. Native controls receive hover/click feedback and readable navigation glyphs.
- Preserve native callbacks, enabled states, spell/item icons, skill progress, map canvas/pins and model content. Restore captured art/fonts when the associated module is disabled; skip forbidden and widget subtrees and defer combat changes.
- Register loaded top-level windows with Move Frames and include Professions Book and Communities in window coordination. Nested wardrobe tabs keep their containing journal open.
- Passed 53 Lua loads and 125 offline scenario groups. Live visual and hardware-action validation remains required.

# v0.7.16

- Use local `date("*t")` for the clock instead of server `GetGameTime()`. The clock continues updating during combat.
- Recognize coordinate-only FontStrings under the minimap, in addition to Ellesmere's exported label. Suppress re-enabling through SetAlpha and restore captured alpha when suite coordinates or Map are disabled. Preserve other labels and third-party settings/files.
- Passed 52 Lua loads and 119 offline scenario groups, including differing local/server times, duplicate detection and visibility restoration. Live confirmation remains required.

# v0.7.15

- Centered the zone title with a bundled bold Arial font.
- Hide EllesmereUIMinimap's exported coordinate label only while the suite Map coordinates are enabled. Restore its original alpha when the module or coordinate option is disabled; no third-party files/settings are modified.
- Passed 52 Lua loads and 118 offline scenario groups. Live visual confirmation remains required.

# v0.7.14

- Centered the minimap zone title and gave it heavier lettering.

# v0.7.13

- Replaced the minimap-header time with a standalone 72x28 clock at bottom center, using a readable 16-point outlined font, dark background, cyan border and gold accent.
- Zone text uses the header width. Clock has its own Move Frames handle and shares Map enable/disable behavior.
- Passed 52 Lua loads and 117 offline scenario groups. Live visual confirmation remains required.

# v0.7.12

- Registered the native MinimapCluster (Minimap fallback) in Move Frames with its standard visible resize grip. Cluster children move/scale together.
- Reapply saved minimap scale when the client resets it. The default suite coordinate panel follows minimap scale; independently saved coordinate placement remains unchanged.
- Passed 52 Lua loads and 116 offline scenario groups, including resize, native scale reset, Cancel and combat stop. Live visual confirmation remains required.
- The extra coordinate line in the screenshot is not generated by the suite's single coordinate panel; its source is not established.

# v0.7.11

- Handle native damage-meter Header as a texture rather than a frame. Replace its gold artwork with a dark suite header and add compact metric/settings/minimize controls with custom glyphs.
- Remove padded button plates from meter rows and resize areas. Keep native click, dropdown, minimize, row drill-down and resize behavior.
- Chat tabs and input plates now fit their owners; native tab and edit-field textures are hidden and restored on module disable.
- Passed 52 Lua loads and 115 offline scenario groups. Live visual and click testing remains required.

# v0.7.10

- Replaced the misaligned legacy minimap border texture with a transparent suite ring anchored to both edges of Minimap. Hide and restore modern compass/header components and native clock to prevent duplicate art and text.
- Main Menu width follows the number of visible buttons, removing the unused background extension.
- Bag background no longer spans over the separately parented Gear button. Restore explicit readable Gear caption colors.
- Hide/restore native chat-tab textures and apply matching damage-meter button backplates while preserving handlers and values.
- Passed 52 Lua loads and 113 offline scenario groups. Live visual confirmation remains required.

# v0.7.9

- Added shared dark panels, turquoise accents and small gold details to action bars, the Main Menu, chat and the native damage meter. Native clicks, cooldowns, bindings, meter data and class colors remain intact.
- Unit frames have gold portrait rims, subtle bar sheen, outlined names/health values and readable power values.
- XP defaults below the main action bar and follows its placement/scale. Text appears on hover; a purple rested segment stops at the next level. Saved XP placement takes precedence.
- Minimap receives a matching border and a compact zone/time header while coordinates and quest pins remain available.
- Quest cards have a lighter background, gold header accent and completion checkmarks. Bag icons stay original; the default bag and gear controls share a panel. Independently moved gear remains separate.
- Native art and fonts are restored when the associated module is disabled. Styling updates defer during combat.
- Passed 52 Lua loads and 112 offline scenario groups. Live visual and combat checks remain required.

# v0.7.8

- Fixed frames jumping during grip resizing: capture the center once when resizing starts and reuse it for every scale update. Drag-start no longer resets an already active resize.
- Includes the Skills/PvP layout and progress-bar improvements from v0.7.7.
- Passed 51 Lua loads and 108 offline scenario groups, including a changing handle-center regression during resizing. Live confirmation remains required.

# v0.7.7

- Skills and PvP use the 732x416 viewport at native scale instead of shrinking a taller canvas. List and detail columns have their own suite frames.
- Skill/PvP status bars use the suite texture and turquoise color while retaining live values and actions. Original bar styling is restored when Character Info is disabled.
- Passed 51 Lua loads and 108 offline scenario groups. These layouts still require visual in-game confirmation.

# v0.7.6

- Added a visible corner resize grip to every Move Frames handle, including Main Menu. Drag outward to enlarge and inward to shrink; the frame updates immediately and the handle displays its scale percentage.
- Resizing preserves placement and saves scale, with 60%-140% bounds. Cancel restores the prior layout; entering combat stops resizing.
- Passed 51 Lua loads and 107 offline scenario groups.

# v0.7.5

- Corrected the previous Character-page layout fix: native left and right pane anchors now map to separate hosts instead of collapsing onto the same full-width page.
- Preserved the fixed-width detail column for Reputation, Skills and PvP. Font sizes fit native row heights instead of being enlarged by scale compensation.
- Apply the same font and skin to newly created scrolling rows, including Statistics.
- Passed 51 Lua loads and 106 offline scenario groups. Live visual confirmation remains required.

# v0.7.4

- Fixed Character Info secondary-page anchors that placed details in the header and controls over the bottom tabs. Pages now fit a clipped content panel while retaining their native actions and readable text.
- Character Info and backpack remain open together for dragging gear onto equipment slots.
- Passed 51 Lua loads and 105 offline scenario groups. Visual layout and actual equipment swaps still require in-game testing.

# v0.7.3

- Allow Character Info and backpack to coexist in both opening orders for bag-to-equipment dragging. Closing one leaves the other open; other dialogs keep their normal exclusive behavior.
- Verified bag pickup reaches the native Character gear-slot drop handler and stays blocked in combat. Passed 51 Lua loads and 104 offline scenario groups; live gear swaps still require in-game testing.

# v0.7.2

- Replaced the plain quest tracker with fantasy-icon quest cards, objective progress, completion colors, distance sorting, focus, collapse, map actions and paging for every quest.
- Added custom minimap/world-map markers from client quest POIs/next waypoints. Pins support minimap radius, map dimensions, rotation, rim placement, grouped overlaps and quest cycling; unavailable locations are not fabricated.
- Prevented native windows and suite dialogs overlapping when switching. Moved the spellbook below the main menu and replaced native XP strips with a custom movable XP bar below the action bar. Native bars/input restore on disable after combat.
- Fixed V off/on nameplate recovery with CVar-change refresh and pooled plate OnShow recovery. Normal target/threat refreshes no longer reapply visibility CVars.
- Passed all 51 Lua file loads and 103 offline scenario groups. The new visuals, protected actions and real Forever POI availability require in-game testing.

# v0.7.1

- Redesigned inventory around a category sidebar, grouped item rows, header search and fixed money/free-space footer in the ForeverSuite skin.
- Added OneBag, MultiBag and Recent Items views. A hideable recent quick-view row duplicates visuals without doubling counts or vendor sale plans; recent items expire after ten minutes in the current session.
- Added up to 12 saved custom categories, immediate assignment for a selected item, validation and sidebar scrolling.
- Added a live resize grip with responsive columns and saved dimensions. Window position, scale, Favorites, secure right-click item use and junk review remain available.
- Passed Lua 5.1 loading of all 48 addon files and 97 offline scenario groups. Live game layout and protected actions still need client testing.

# v0.7.0

- Audited the original roadmap; FEATURE_AUDIT.md records implementation scope and live-client limitations.
- Added named profiles with isolated settings/layout snapshots, automatic save on switching, shared patch-log preferences, and combat/vendor-action guards.
- Added secure focus, party and raid frames, group visibility, grouped movement and native frame suppression/restoration. Added nameplate target outlines and readable threat labels.
- Added a key-binding editor for main/extra/stance/pet actions, modifier capture, Escape cancellation and immediate saving to the active game binding set.
- Added a custom categorized bank with search, paging, character/account tab enumeration and revalidated click/drag transfers. Bank and inventory remain side by side; sale plans still read carried items only.
- Gear displays item levels and mean occupied equipment-slot level, excluding cosmetic shirt/tabard slots.
- Added Map coordinates/pins/exploration/lockouts, Quests objectives/tracker/optional dialogue, Loot history/fast loot/roll choices, Buffs/reminders/enchants, and own-spell Cooldowns with interrupt/defensive categories.
- Added Combat reports backed by Forever's Damage Meter API. Readable reports wait until combat ends; native reset requires two clicks. Kept a guarded readable-log fallback for clients that expose it.
- Added Professions recipe/material overview, Auction House loaded-result observations and shopping list, Social friend/guild tools and timestamps, and Leveling/QoL progress/invite/dismount tools.
- Expanded Control Center to 20 module cards over three pages. New tools share opaque suite windows, search, paging, selection feedback, return navigation, movement and the existing font.
- /fs is the sole slash entry and always opens the Control Center. Reset refuses combat and active vendor transactions. Native UI restoration waits until combat ends when needed.
- Updated the current-version-only startup patch log, addon author and compact description.
- Validation: 47 Lua files compile/load in TOC order; 92 offline scenario groups pass. New real-client functionality and visual placement still require in-game testing.

# v0.6.10

- Disabled mouse input on hidden native Character panels and their descendants, preventing old equipment slots from showing tooltips. Native attempts to re-enable hidden hit areas are suppressed; original mouse states restore on disable or when mounting another page.
- Empty gear slots use their corresponding client equipment-slot textures, desaturated. Removed truncated empty-slot labels. Equipped slots display full-color item icons; clearing a slot restores its grey placeholder.
- Current patch log updated. 32 Lua files compile/load; 68 offline scenario groups pass.

# v0.6.9

- Rebuilt the Character page as an opaque ForeverSuite interface: 20 custom equipment slots, player model, own stats panel and illustrated controls for Character Stats, Equipment Manager and Titles.
- Slots support tooltips, modified item clicks, left-click/drag pickup and placement, secure right-click use, stack counts and cooldowns. Equipment movement is blocked in combat.
- Equipment Manager lists sets, equips through a secure button, creates named sets from current gear without silently overwriting an existing name, and confirms deletion. Titles lists known titles and supports removing a title.
- Fixed the actual native navigation mismatch: Camelot tabs use a custom OnMouseUp handler. Our six own buttons now call the same public page entry point directly. Other native page data is mounted in the custom shell, retaining functionality and suite skins.
- Hides the original Character panels instead of leaving the stock stats, slots and sidebar under a partial skin. Disabling restores original native panels and size.
- Patch Log and Credits are opaque and replace the Control Center while open; closing their button returns to it. Main suite windows close other suite windows; junk review returns to the previous inventory/vendor screen.
- The current-version patch log is updated. Offline tests cover 32 Lua files and 67 scenario groups. Real client equipment actions and complete visual layout still need in-game verification.

# v0.6.8

- Replaced Character tab click proxies with the actual native tabs. Original page handlers and disabled states are retained.
- Six footer tabs retain their custom placement when native tab layout updates. Disabling restores original parents, positions, sizes and mouse state.
- Styled native Character controls, suppressed stock state textures and removed additional background/border artwork. Equipment icons, model and page content remain intact.
- Current-version startup patch log updated.
- 30 Lua files compile/load; 65 offline scenario groups pass. Native page clicks and full visual layout require in-game testing.

# v0.6.7

- Compact startup patch log shows only the current version's changes, with no history or paging controls.
- Don't show again saves a startup preference; manually opening Patch Log always works. Uncheck it to enable startup display again.
- Added Control Center footer buttons in order: Reset settings, Patch Log, Move Frames, Credits, Reload UI.
- Credits: Created by DeluxiZ. Made with help from AI.
- 30 Lua files compile/load; 64 offline scenario groups pass.

# v0.6.6

- Forever uses separate Spellbook and Talent buttons. Suppressed the unused combined PlayerSpells button to remove the duplicate route.
- Retained one Spellbook button and the separate Talent button, including its native disabled/grey state.
- 29 Lua files load and 63 offline scenario groups pass.

# v0.6.5

- Native menu buttons now live in the suite menu container, avoiding the stock micro-menu layout fighting their placement.
- Fixed uniform 36px button size, 41px spacing and scale; client layout/size changes are corrected immediately outside combat and deferred safely during combat.
- Native button texture alpha remains suppressed through hover, pressed and animation state changes. Suite icons and click effects remain visible.
- Native click handlers stay intact. Disabling restores each button's parent, position, size, scale and texture alpha.
- 29 Lua files compile/load and 62 offline scenario groups pass. Visual hover and menu behavior require a game test.

# v0.6.4

- Removed nameplates and their preview from Move Frames, including the settings button. Legacy saved offsets are discarded.
- Nameplates stay centered on each native unit plate; independent size setting from 60% to 140%.
- Separate enemy, friendly-player and friendly-NPC toggles. Default: enemies only. Client visibility settings defer during combat and restore when the module is disabled.
- 29 Lua files load; 61 offline scenario groups pass.

# v0.6.3

- Main menu icons now skin the actual native hardware-click buttons directly. Removed secure scripted-click forwarding, which can be rejected by the client for restricted native buttons.
- Retained native click handlers, disabled states, tooltips and the suite icon/click-effect styling. Disabling restores original button sizes, points, artwork and mouse state.
- Every subsequent addition or fix increments the addon version in Core/Init.lua and ForeverSuite.toc and gets a changelog entry.
- Includes the recent icon-free nameplates, bold grid centerlines, live frame dragging, and Gear placement beside the fully skinned bag bar.
- 29 Lua files compile/load; 60 offline scenario groups pass. Native menu clicks still need an in-game check after copying the update.

# v0.6.2

- Removed the decorative nameplate icon and expanded the health bar into its space, including the Move Frames preview.

- Character Info: six illustrated tabs, dark panels and a shared clean font. Native equipment, models and page actions remain available.
- Shared Arial Narrow font across suite windows, HUD labels and native action labels.
- Rich fantasy icon atlas with gold click flashes. Secure main-menu proxies keep native buttons in their original containers.
- Bag bar sits bottom-right with suite borders and original bag icons. Native action slot artwork and main bar decoration are hidden when enabled.
- Move Frames in the Control Center: grid snapping, draggable handles, mouse-wheel sizing, saved positions, Cancel and Reset. Moving stops in combat.
- Custom nameplates replace native visuals with suite health bars, icons, cast/channel bars and debuffs. Player bars use class colors; hostile NPC bars are red. Native target clicks remain available.
- Nameplate preview in Move Frames controls the shared offset and scale. Pooled native frames restore when removed or disabled; forbidden client frames are skipped.
- Lua 5.1 syntax/startup: 29 files; 58 offline scenario groups pass. Live protected actions and visual placement still require in-game testing.

# Changelog

## 0.6.1 - 2026-10-04

- Add compact secure player/target frames with mirrored portraits, health/power and cast/channel bars.
- Use class colors for players, red for hostile creatures, amber for neutral and green for friendly creatures.
- Add a dark/cyan skin and central layout for native action bars, retaining native actions and paging.
- Move the main menu to the top-left with 16 original cyan/gold icon assets, hover/press feedback and notification indicators.
- Add native nameplate skins with the same health colors; forbidden plates are skipped.
- Add three Settings cards, size controls and movement handles; protected changes defer until combat ends.
- Preserve SavedVariables and allow module disable to restore native visuals.
- All 26 Lua files compile; 55 offline scenario groups pass. Real-client checks remain required.

## 0.6.0 - 2026-10-04

- Add Gear & Durability with an equipment overview, low durability warnings and module settings.
- Repairs use Vendor funds, limits and confirmation without leaving the Gear overview.
- Add item cooldowns and NEW loot markers to Bags; hovering acknowledges new items.
- Manual Sell junk actions open a paginated review with quantities and expected proceeds.
- Changed sale plans require confirmation again; newly arrived junk is excluded from a confirmed batch.
- Preserve automatic selling when explicitly enabled in Vendor settings.
- All 20 Lua files compile and 47 offline scenario groups pass.

## 0.5.5 - 2026-10-04

- Group advanced Bags controls under Junk highlights and Bag opening and display.
- Place highlight color beside brightness below the highlight toggles.
- Place merchant opening alongside native replacement and empty-space options.
- Preserve values and saving behavior; all 41 offline scenarios pass.

## 0.5.4 - 2026-10-04

- Add Ammo detection for projectile-class arrows and bullets.
- Map all 21 client item classes to suitable automatic categories.
- Retain numeric subclass IDs to classify miscellaneous reagents, pets, mounts, holiday items and mount equipment.
- Add category filters and manual assignments for the new groups.
- Expand category heading pool and use a compact two-column filter menu.
- Preserve Favorites, quest/sale priority and all transaction protections.
- Pass 41 offline scenario groups, including all classes and layout boundaries.

## 0.5.3 - 2026-10-04

- Add a fixed Favorites category above all other inventory categories.
- Tag Hearthstone (6948) as a favorite by default.
- Add Add to Favorites/Remove favorite item actions and a Favorite tooltip line.
- Save item-ID favorites, including explicit removal of the default favorite.
- Keep favorite grouping independent of sale protections and junk rules.
- Pass 40 offline scenario groups.

## 0.5.2 - 2026-10-04

- Use SecureActionButtonTemplate for right-click item use and the Use item button.
- Remove direct insecure bag-item use calls that can block Hearthstone casting.
- Revalidate exact bag/slot identity before clicks; suppress secure item actions at merchants, for stale/locked items and while the cursor or transactions are busy.
- Preserve template click handling and keep merchant sales on the quantity-aware Vendor route.
- Hide inventory securely during combat and defer protected inventory updates until combat ends.
- Show Always Keep once in the item tooltip.
- Pass 39 offline scenario groups, including secure click attributes and combat guards.

## 0.5.1 - 2026-10-04

- Replace the large inventory dashboard with a compact bottom-right bag in ForeverSuite style.
- Use 38px square items, 12 columns, collapsible categories and content-driven height.
- Move selected-item actions into a separate popup; keep settings in the Control Center.
- Add saved inventory size choices (70/85/100/115 percent), dragging and Reset position.
- Suppress native carried frames synchronously to avoid a visible deferred hide cycle.
- Honor the outermost bag API intent, including OpenBackpack calling ToggleBackpack.
- Use container bag IDs rather than frame IDs and support individual OpenBag/CloseBag.
- Check immediate suppression, repeated native re-show, compact geometry and persisted preferences.

## 0.5.0 - 2026-10-04

- Connect normal backpack/bag controls to the skinned, automatically categorized Bags window outside combat.
- Keep native bags available during combat, when Bags is disabled, or when replacement is turned off.
- Simplify Bags with a category filter, hidden empty spaces, selection-based actions and More options.
- Show sell, repair and shopping actions only at a merchant; hide unnecessary pagination.
- Make Control Center cards and Settings buttons open the correct module settings, including disabled modules.
- Separate basic Bags/Vendor preferences and move detailed controls into Advanced settings.
- Add Back to Control Center navigation and a dark/gold Vendor skin.
- Preserve item rules and protection checks; migrate old empty-slot display preferences once.
- Verify 18 Lua files and 37 offline scenario groups, including native bag redirection.

## 0.4.0 - 2026-10-04

- Make /fs the central Control Center with settings inside one window.
- Add distinct Bags/Vendor module cards, themed icons, hover and click effects.
- Add persistent module enable/disable controls, preserving item rules.
- Add Open buttons and a direct Reload UI button at the bottom.
- Keep legacy commands as optional macro shortcuts; simplify welcome/help text.

## 0.3.1 - 2026-10-04

- Make Sort Bags restore visibly grouped categories independently of native sorting.
- Automatically group inventory under named sections; allow saved item-ID categories.
- Add a flat dark/cyan bag skin and screen-size scaling.
- Add bag settings for shared Vendor rules, glow, automation and budgets.
- Add sell, repair confirmation, restock, buyback and visit history inside Bags.
- Open Bags at merchants by default with a configurable preference.
- Add a custom logo to the addon list, minimap and suite windows.
- Shorten addon-list notes to one plain English sentence.

## 0.3.0 - 2026-10-04

- Add /fs bags, core settings shortcut and right-click minimap access.
- Add combined carried-bag grid, pagination, literal search and category filters.
- Add visual ordering and client bag sorting, free capacity and empty-slot placement.
- Share Vendor junk glow, Always Keep and stock reserves with bag item controls.
- Add absent-item Stock overview, editable keep quantities and restock targets.
- Add eligible sale preview away from merchants and safe selected partial-stack sales.
- Revalidate moved items and block item actions in combat or during Vendor operations.
- Upgrade settings to schema 3 while preserving existing Vendor rules.

## 0.2.0 - 2026-10-04

- Add Vendor & Junk Rules through /fs vendor and core settings.
- Add manual, automatic gray-junk and custom-rule sale modes.
- Add explicit item-ID junk rules, Always Keep and carried-stock reserves.
- Add per-item stock targets, gold-only restocking and per-visit budgets.
- Add personal/guild repair choices, repair limits and quote confirmation.
- Add live merchant buyback and confirmed visit reports/history.
- Add configurable pulsing junk borders to Overview and Blizzard bag icons.
- Distinguish partial-stack eligibility with amber and a quantity label.
- Add integration APIs for future module protections and third-party bag buttons.
- Preserve existing core settings and force English for legacy language preferences.

## 0.1.0

- Add core, SavedVariables, slash commands, settings window and minimap button.
- Use English-only UI.
