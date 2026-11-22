# Auction prices and disenchant estimates

Updated: 2026-11-22. Prices come only from auction results observed on the
player's client. No online price service, external account or uploader is used.

## Scanning

The full scan uses `C_AuctionHouse.ReplicateItems` and
`REPLICATE_ITEM_LIST_UPDATE`, then reads `GetReplicateItemInfo` in batches.
Reference: [Forever client API declarations](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/AuctionHouseDocumentation.lua).
It makes one replication request, not thousands of per-item search requests.
The local 15-minute request guard does not bypass a server cooldown.

Only the lowest positive buyout per item, its timestamp and price kind are kept.
Stack buyouts are divided by stack quantity. Bid-only auctions are excluded.
Browse-result minimums may be lowest-listing observations rather than confirmed
unit prices; they are labeled separately and cannot value disenchant materials.
Item variants with the same item ID share a price: this is a rough market
reference, not a valuation of a particular suffix or bonus roll.

Prices are grouped by realm and player faction. The current API integration
does not distinguish a neutral auctioneer's market from the faction market;
scan the market where you normally trade. These are historical observations,
not a guarantee that an auction is still listed or will sell.

Scans are atomic and bounded to 500,000 listings and 20,000 distinct priced
items. A failed, cancelled or oversized scan preserves the previous cache.
Completed scans merge observations; absent items retain their old timestamp.
Account data from a newer unsupported schema is never rewritten.

## Disenchanting

The small material-family model is independently authored from factual material
and quantity references, rather than copying another addon's implementation:

- [WoW Professions Forever disenchanting guide](https://www.wow-professions.com/forever/disenchanting-guide)
- [Everloot Forever disenchanting observations](https://everloot.app/tools/disenchanting)

Everloot describes its game-file bands as unconfirmed and its outcome chances
as player observations. Guide required-level brackets and item-level bands are
not interchangeable. ForeverSuite uses item-level families and a broad
approximate possible-value range, without adopting sampled probabilities or
claiming an expected average. The low endpoint is the cheapest modeled outcome;
the high endpoint is the most valuable modeled outcome. This is not a promise
that every item in the band has exactly these results.

Coverage: standard uncommon and rare weapons/armor, item levels 5–99. Uncommon
families include dust, essence and applicable shard outcomes. High-level rares
include a possible Nexus Crystal. Epics, non-equipment, quest-bound items,
fishing poles, unsupported levels and explicit cannot-disenchant tooltips do
not receive a numeric estimate. Item-specific exceptions may still exist.

Every modeled material must have a cached **per-item** price. Missing prices
produce an unknown result. The oldest underlying material observation is shown.
Materials' market values are before fees, deposits or transaction costs; random
outcomes and special item rules can change actual results. The addon never
casts Disenchant or sells an item based on this estimate.
