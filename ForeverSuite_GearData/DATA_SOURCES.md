# ForeverSuite Gear Catalog

Data from Efficient Games (https://efficient.games), licensed under CC BY 4.0.
[Original dataset and license](https://github.com/JIVESCORP/eg-link-output-wowf/blob/ea970da071079b32e56f349e09648ff0e314b351/LICENSE)

ForeverSuite adapts the original data into equipment-to-source links. It selects
recorded boss rolls, guaranteed and selectable quest rewards, and observed vendor
entries. It filters the links to weapon and armor slots and combines them with
item requirements available from the client tables. Game names belong to their
respective rights holders. The catalog includes no quest descriptions, prices,
drop percentages or player records.

The initial catalog uses live WoW Forever builds `1.60.1.70862`,
`1.60.1.70888`, and `1.60.1.70938`. The reference data covers 2,395 unique
items, including 87 items recorded from bosses in 10 instances. Availability
can vary by patch, faction, quest progress, vendor stock and difficulty. The
planner checks the required level reported by your game and scores only items
for which the game supplies readable stats. Check armor and weapon proficiency
and other requirements in the item tooltip. [Snapshot](https://github.com/JIVESCORP/eg-link-output-wowf/tree/ea970da071079b32e56f349e09648ff0e314b351/data/wowf)

## Rebuilding the catalog

1. Save the build `1.60.1.70938` exports as `Item.csv`, `ItemSparse.csv` and
   `Map.csv` in a local input directory. [Item CSV](https://wago.tools/db2/Item/csv?build=1.60.1.70938)
   [ItemSparse CSV](https://wago.tools/db2/ItemSparse/csv?build=1.60.1.70938)
   [Map CSV](https://wago.tools/db2/Map/csv?build=1.60.1.70938)
2. From the pinned snapshot linked above, save `encounters.json`, `loot.json`,
   `quests.enUS.json` and `vendors.json` for each listed build. Prefix each
   filename with the build and a hyphen, as in `1.60.1.70938-loot.json`.
3. Run `python work/build_gear_catalog.py PATH_TO_INPUTS` from the repository
   root. This regenerates `Catalog.lua`. Update the build list and revision in
   the generator together when refreshing the data.
