"""Build the offline profession reference from the WoW Forever client and trainer observations."""
import argparse
import csv
import json
from collections import defaultdict
from pathlib import Path


BUILD = '1.60.1.70938'
EG_REVISION = 'ea970da071079b32e56f349e09648ff0e314b351'
PROFESSIONS = (129, 164, 165, 171, 182, 185, 186, 197, 202, 333, 356, 393)
GATHERING = {182, 186, 356, 393}


def lua_string(value):
    return json.dumps(''.join(c for c in value if c >= ' ' and c not in '|\x7f'), ensure_ascii=False)


def lua_numbers(values):
    return '{' + ','.join(str(v) for v in values) + '}'


def build(inputs, output):
    def rows(table):
        with (inputs / f'{table}.csv').open(encoding='utf-8-sig', newline='') as stream:
            yield from csv.DictReader(stream)

    index = json.loads((inputs / 'trainer-index.json').read_text(encoding='utf-8-sig'))
    builds = sorted(b for b, fields in index['products']['wowf'].items() if fields.get('trainers'))
    if not builds or builds[-1] != BUILD:
        raise ValueError('Use the pinned trainer index for the declared client build')
    trainers, services = {}, defaultdict(dict)
    for version in builds:
        data = json.loads((inputs / f'{version}-trainers.json').read_text(encoding='utf-8-sig'))
        meta = data['meta']
        if meta['product'] != 'wowf' or meta['clientBuild'] != version or meta['license'] != 'CC BY 4.0':
            raise ValueError(f'Unexpected attribution or build in the trainer export for {version}')
        for npc, trainer in data['trainers'].items():
            if not trainer.get('tradeskill') or not trainer.get('name'):
                continue
            npc = int(npc)
            positions = [p for p in trainer.get('positions', []) if p.get('uiMap', 0) > 0 and
                         0 < p.get('mapX', 0) < 1 and 0 < p.get('mapY', 0) < 1]
            if positions or npc not in trainers:
                pos = positions[0] if positions else {}
                trainers[npc] = (trainer['name'], pos.get('uiMap', 0), pos.get('mapX', 0), pos.get('mapY', 0))
            for key, service in trainer.get('services', {}).items():
                spell = int(key)
                old = services[spell].get(npc, (0, 0))
                # A known recipe may be reported with a zero requirement by the trainer window.
                services[spell][npc] = (service.get('skillRank', 0) or old[0], service.get('level', 0) or old[1])

    names = {int(r['ID']): r['Name_lang'] for r in rows('SpellName')}
    ranks, recipes = defaultdict(dict), defaultdict(dict)
    for row in rows('SpellEffect'):
        if row['Effect'] != '118' or row['DifficultyID'] != '0':
            continue
        skill, spell = int(row['EffectMiscValue_0']), int(row['SpellID'])
        if skill not in PROFESSIONS or spell not in names:
            continue
        rank = float(row['EffectBasePointsF'])
        if rank in (1, 2, 3, 4):
            ranks[skill].setdefault(int(rank), []).append(spell)

    reagents = {}
    for row in rows('SpellReagents'):
        pairs = [(int(row[f'Reagent_{i}']), int(row[f'ReagentCount_{i}'])) for i in range(8)]
        if any(item < 0 or (item > 0 and quantity <= 0) for item, quantity in pairs):
            continue
        ingredients = [value for pair in pairs if pair[0] > 0 for value in pair]
        if ingredients:
            reagents[int(row['SpellID'])] = ingredients

    for row in rows('SkillLineAbility'):
        skill, spell = int(row['SkillLine']), int(row['Spell'])
        if skill not in PROFESSIONS or spell not in reagents or not names.get(spell):
            continue
        yellow, gray = int(row['TrivialSkillLineRankLow']), int(row['TrivialSkillLineRankHigh'])
        if gray<=1 or not 0<=yellow<=gray or row['ClassMask'] != '0' or row['RaceMasks_0'] != '0' or row['RaceMasks_1'] != '0':
            continue
        client_minimum = max(1, int(row['MinSkillLineRank']))
        observed = [v[0] for v in services.get(spell, {}).values() if v[0] > 0]
        automatic = row['AcquireMethod'] in ('1','2')
        learn = min(observed) if observed else client_minimum if automatic else max(client_minimum, yellow-25)
        proof = 2 if observed else 1 if automatic else 0
        if learn < min(gray, 300):
            recipes[skill][spell] = (learn, yellow, gray, max(1, int(row['NumSkillUps'])), proof)

    profession_names = {int(r['ID']): r['DisplayName_lang'] for r in rows('SkillLine') if int(r['ID']) in PROFESSIONS}
    used_trainers = set()
    body = []
    for skill, name in sorted(profession_names.items(), key=lambda pair: pair[1]):
        body.append(f'[{skill}]={{name={lua_string(name)},gathering={str(skill in GATHERING).lower()},ranks={{')
        for tier, spells in sorted(ranks[skill].items()):
            spell = min(spells, key=lambda spell: (-len(services.get(spell, {})), spell))
            records = services.get(spell, {})
            ids = sorted(records)
            used_trainers.update(ids)
            skill_rank = min((v[0] for v in records.values() if v[0] > 0), default=-1)
            character_level = min((v[1] for v in records.values() if v[1] > 0), default=0)
            body.append(f'[{tier}]={{{lua_string(names[spell])},{skill_rank},{character_level},{lua_numbers(ids)}}},')
        body.append('},recipes={')
        for spell, (learn, yellow, gray, points, proof) in sorted(recipes[skill].items()):
            ids = sorted(services.get(spell, {}))
            used_trainers.update(ids)
            body.append(f'{{{spell},{lua_string(names[spell])},{learn},{yellow},{gray},{points},{proof},'
                        f'{lua_numbers(reagents[spell])},{lua_numbers(ids)}}},')
        body.append('}},')
    lines = ['-- Generated by work/build_profession_catalog.py. See DATA_SOURCES.md.',
             f'-- Efficient Games {EG_REVISION}; WoW Forever client {BUILD}.',
             f'ForeverSuite.ProfessionCatalog={{build={lua_string(BUILD)},trainers={{']
    for npc in sorted(used_trainers):
        name, map_id, x, y = trainers[npc]
        lines.append(f'[{npc}]={{{lua_string(name)},{map_id},{x},{y}}},')
    lines.extend(['},professions={', *body, '}}'])
    output.write_text('\n'.join(lines)+'\n', encoding='utf-8', newline='\n')
    print(f'{sum(map(len, recipes.values())):,} recipes, {len(used_trainers)} observed trainers, {len(profession_names)} professions')
    for skill, name in sorted(profession_names.items(), key=lambda pair: pair[1]):
        coverage = {value for learn, _, gray, _, proof in recipes[skill].values() if proof
                    for value in range(learn, min(gray, 300))}
        print(f'{name}: {len(recipes[skill])} recipes, {len(coverage)}/299 skill points with supported recipe sources')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('inputs', type=Path)
    args = parser.parse_args()
    build(args.inputs, Path(__file__).resolve().parents[1] / 'ForeverSuite_ProfessionData' / 'Catalog.lua')
