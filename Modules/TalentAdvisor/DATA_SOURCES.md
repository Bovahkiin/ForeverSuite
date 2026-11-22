# Talent Advisor data

Checked on **2026-11-22**, using talent catalog version **70959-a8fe1dab**.
The catalog contains **467 talents** and **73 distinct build variants** across
Warrior, Paladin, Hunter, Rogue, Priest, Shaman, Mage, Warlock and Druid.

## Sources and attribution

- [Icy Veins — WoW Forever](https://www.icy-veins.com/wow-forever/): class,
  leveling, build and stat-reference pages. Each bundled guide allocation retains
  its author, source URL and the date it was checked in Build details.
- [Icy Veins talent catalog index](https://static.icy-veins.com/r2/icydb/wowf/talents/index.json):
  class node IDs, spell IDs, names, icons, ranks, layout and prerequisites.
  Historical catalog versions decode guide allocations before mapping them to
  the current node IDs. Every bundled allocation passes prerequisite validation.
- [WoW Forever trait API definitions](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/SharedTraitsDocumentation.lua):
  committed active-config and talent-node reads.
- [WoW Forever trainer interface](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_TrainerUI/Mainline/Blizzard_TrainerUI.lua):
  native trainer integration and service metadata.

The addon bundles compact factual records and allocations. It does not bundle
guide prose, website calculator code or another addon's implementation. Icons
use the game client's spell textures. ForeverSuite is independent of Icy Veins
and Blizzard Entertainment; neither endorses the addon or its recommendations.

## Coverage and limits

- The point route is a legal order for the guide's allocation, not a promise to
  reproduce every situational leveling choice from the article. Displayed levels
  are estimates based on readable earned points and one future point per level.
- The stat reference comes from the spec's PvE guide. Leveling and PvP can need
  different priorities. Separate Feral damage and survival lists stay separate;
  slash-separated labels do not express exact ratios or equivalence.
- The Gear Advisor link selects an existing starter scale for the build's role.
  A priority list alone cannot determine numeric weights. Caps, encounter
  mechanics, proc values, set bonuses and talent-specific damage simulations
  are not modeled. Explicit custom weights remain under the player's control.
- Advice pauses when staged changes, missing nodes, changed ranks or mismatched
  spell IDs make the live tree unsafe to compare. Install updated data when the
  client changes its trees. Talents are always learned or reset through the game.
- Community codes are data only, validated for class, catalog version,
  prerequisites and size. Imports do not execute Lua or replace same-name entries.
  A local review mark is not a community rating. The addon has no online build
  feed; copy codes through Discord or another channel.
- Personal builds and build profiles are stored in DataHub, up to 40 entries per
  library. Ordinary UI profile exports exclude the library and selected build
  identifiers; Talent Advisor's own Share action is explicit.
- Only the current class's records are expanded into runtime tables. Talent
  changes refresh a visible window through coalesced events; no ongoing ticker
  or network request runs in the addon.

Maintainers can refresh public source caches with
`work/prepare_talent_sources.py` and regenerate records with
`work/build_talent_catalog.py`. Review source coverage and run the addon checks
before publishing a catalog update.
