# ForeverSuite Profession Data

Data from Efficient Games (https://efficient.games), licensed under CC BY 4.0.
ForeverSuite adapts their observed trainer services into recipe and profession
rank references. A trainer's actual availability can depend on faction, quests,
specialization or the current build.
[Original trainer datasets](https://github.com/JIVESCORP/eg-link-output-wowf/tree/ea970da071079b32e56f349e09648ff0e314b351/data/wowf)
[License](https://github.com/JIVESCORP/eg-link-output-wowf/blob/ea970da071079b32e56f349e09648ff0e314b351/LICENSE)

Recipe names, skill-up thresholds, ingredients and rank spells use the
WoW Forever client tables for build `1.60.1.70938`. Game names belong to their
respective rights holders. When observed trainer requirements are missing,
routes use the client acquisition flag where available. For other recipes,
the estimated unlock uses the client minimum or 25 points below the yellow
threshold, whichever is higher. The planner labels those steps **Check source**.
The shopping list is a lower bound based on direct reagents and successful
skill-ups, and uses the currently stored alt stock only when enabled.

Gathering zones and rank steps marked **Guide reference** use factual references
from the WoW-Professions Forever guides. High-skill routes can change as live
locations are verified. [Profession guides](https://www.wow-professions.com/forever)
[Mining](https://www.wow-professions.com/forever/mining-leveling-guide)
[Herbalism](https://www.wow-professions.com/forever/herbalism-leveling-guide)
[Skinning](https://www.wow-professions.com/forever/skinning-leveling-guide)
[Fishing](https://www.wow-professions.com/forever/fishing-leveling-guide)

## Regenerate

Save the `SkillLine`, `SkillLineAbility`, `SpellName`, `SpellReagents`, and
`SpellEffect` CSV exports for the declared build in a local input directory.
[WoW Forever client table exports](https://wago.tools/db2/SkillLineAbility/csv?build=1.60.1.70938)

Save `data/index.json` from the pinned Efficient Games commit as
`trainer-index.json`. Save each listed `wowf` trainer export with a build
prefix such as `1.60.1.70938-trainers.json`. Run
`python work/build_profession_catalog.py PATH_TO_INPUTS` from the repository root.
