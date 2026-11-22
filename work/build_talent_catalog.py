"""Build compact factual talent records and attributed guide allocations from cached sources.

No guide prose, calculator code or third-party addon code is bundled. Names,
node/spell IDs, ranks, prerequisites and build allocations are game facts.
Run prepare_talent_sources.py to refresh the public source cache first.
"""
import collections,datetime,html,json,re
from html.parser import HTMLParser
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]; CACHE=ROOT/'work/talent-research'
OUT=ROOT/'Modules/TalentAdvisor/Data';OUT.mkdir(parents=True,exist_ok=True)
VERSION=json.loads((CACHE/'icy-index.json').read_text())['latest']
CHECKED='2026-11-22'
def lua(v):
    if isinstance(v,str):return json.dumps(v,ensure_ascii=False)
    if v is True:return 'true'
    if v is False:return 'false'
    if v is None:return 'nil'
    if isinstance(v,(int,float)):return str(v)
    if isinstance(v,list):return '{'+','.join(map(lua,v))+'}'
    return '{'+','.join('['+lua(k)+']='+lua(x) for k,x in v.items())+'}'
def plain(s):return html.unescape(re.sub('<[^>]*>',' ',s)).strip()
class Page(HTMLParser):
    def __init__(self):super().__init__();self.heading='';self.capture=None;self.parts=[];self.builds=[];self.author='Icy Veins';self.modified=''
    def handle_starttag(self,tag,attrs):
        a=dict(attrs)
        if tag in ('h2','h3'):self.capture=tag;self.parts=[]
        if tag=='meta':
            if a.get('name')=='author':self.author=a.get('content',self.author)
            if a.get('property')=='article:modified_time':self.modified=a.get('content',CHECKED)[:10]
        if 'data-talentcalculator-pointsurl' in a:self.builds.append((self.heading,a))
    def handle_data(self,s):
        if self.capture:self.parts.append(s)
    def handle_endtag(self,tag):
        if tag==self.capture:self.heading=' '.join(self.parts).strip();self.capture=None
def nodes(data):
    result={}
    for gi,g in enumerate(data['talentGroups'],1):
        for index,t in enumerate(g['talents']):
            if not t:continue
            prerequisite=t.get('requiredTalent'); pre=g['talents'][prerequisite['index']]['nodeId'] if prerequisite else 0
            result[t['nodeId']]={'id':t['nodeId'],'name':t['name'],'icon':t['icon'],'code':t['urlId'],'group':gi,
                'row':index//4,'column':index%4,'max':t['maxRank'],'gate':t['requiredPoints'],
                'pre':pre,'preRank':prerequisite['rank'] if prerequisite else 0,'spells':sorted({r['id'] for r in t['ranks']})}
    return result
def legal_order(order,all_nodes):
    remaining=list(order); ranks=collections.Counter();spent=collections.Counter();out=[]
    while remaining:
        for i,nid in enumerate(remaining):
            n=all_nodes[nid]
            if ranks[nid]<n['max'] and spent[n['group']]>=n['gate'] and ranks[n['pre']]>=n['preRank']:
                out.append(nid);ranks[nid]+=1;spent[n['group']]+=1;remaining.pop(i);break
        else:return None
    return out
stats_names={'strength':'Strength','agility':'Agility','stamina':'Stamina','intellect':'Intellect','spirit':'Spirit',
 'attack power':'AttackPower','spell power':'SpellPower','healing power':'Healing','healing':'Healing',
 'hit chance':'HitRating','hit rating':'HitRating','critical strike':'CritRating','crit chance':'CritRating','crit':'CritRating',
 'haste':'HasteRating','armor':'Armor','defense':'DefenseRating','dodge':'DodgeRating','parry':'ParryRating','mp5':'ManaRegen','mana per 5':'ManaRegen'}
class StatWidgets(HTMLParser):
    def __init__(self):
        super().__init__();self.widgets=[];self.depth=0;self.name_depth=0;self.parts=[]
    def handle_starttag(self,tag,attrs):
        if tag!='div':return
        classes=dict(attrs).get('class','').split()
        if self.depth:self.depth+=1
        elif 'stat-priority-widget' in classes:self.depth=1;self.widgets.append([])
        if self.depth and 'stat-name' in classes:self.name_depth=self.depth;self.parts=[]
    def handle_data(self,value):
        if self.name_depth:self.parts.append(value)
    def handle_endtag(self,tag):
        if tag!='div' or not self.depth:return
        if self.name_depth==self.depth:
            self.widgets[-1].append(' '.join(''.join(self.parts).split()));self.name_depth=0
        self.depth-=1

def priorities(path,tank=False):
    if not path.exists():return []
    text=path.read_text(encoding='utf-8');at=text.find('id="stat-priority"')
    diagrams=StatWidgets();diagrams.feed(text)
    if diagrams.widgets:
        # Feral's second diagram is survival; never merge separate DPS/tank lists.
        index=1 if tank and 'feral-druid' in path.name and len(diagrams.widgets)>1 else 0
        return diagrams.widgets[index][:8]
    if at<0:at=text.find('id="the-stat-priority"')
    text=text[at if at>=0 else 0:]
    result=[]
    for block in re.findall(r'<ol\b[^>]*>(.*?)</ol>',text,re.S):
        candidate=[]
        for entry in re.findall(r'<li\b[^>]*>(.*?)</li>',block,re.S):
            label=plain(entry).lower()
            for needle,key in stats_names.items():
                if needle in label and key not in candidate:candidate.append(key);break
        if len(candidate)>=2:result=candidate;break
    return result
count=0;skipped=[]
for cls in ('warrior','paladin','hunter','rogue','priest','shaman','mage','warlock','druid'):
    raw=json.loads((CACHE/f'icy-{cls}.json').read_text(encoding='utf-8')); all_nodes=nodes(raw)
    builds=[];seen=set()
    for file in sorted(CACHE.glob('guide-*.html')):
        slug=file.stem[6:]
        if '-stat-priority' in slug or not (f'-{cls}-' in slug or slug.endswith('-'+cls+'-leveling')):continue
        text=file.read_text(encoding='utf-8');page=Page();page.feed(text)
        # Prefer structured author metadata; do not copy explanatory article text.
        match=re.search(r'"author"\s*:\s*\{[^}]*"name"\s*:\s*"([^"]+)"',text)
        if match:page.author=html.unescape(match.group(1))
        for heading,attrs in page.builds:
            code=attrs['data-talentcalculator-pointsurl']; old_version=code.split('~',1)[1] if '~' in code else VERSION
            src=CACHE/f'data-{cls}-{old_version}.json'
            old_nodes=nodes(json.loads(src.read_text(encoding='utf-8'))) if src.exists() else all_nodes
            by_code={n['code']:nid for nid,n in old_nodes.items()}
            encoded=code.split('~',1)[0].removeprefix('#tc-')
            if not encoded or any(c not in by_code or by_code[c] not in all_nodes for c in encoded):skipped.append((slug,'missing node'));continue
            order=[by_code[c] for c in encoded]
            if len(order)>51:skipped.append((slug,'too many points'));continue
            safe=legal_order(order,all_nodes)
            if safe is None:skipped.append((slug,'invalid prerequisites'));continue
            key=(tuple(sorted(collections.Counter(safe).items())),slug.endswith('-leveling'))
            if key in seen:continue
            seen.add(key)
            spec=slug.split('-'+cls,1)[0].replace('-',' ').title()
            goal='Leveling' if slug.endswith('-leveling') else 'PvP' if 'pvp' in heading.lower() else 'Dungeons' if 'solo' in heading.lower() or 'dungeon' in heading.lower() else 'Raids' if 'raid' in heading.lower() else 'PvE'
            scale='Tank' if 'tank' in slug or spec=='Protection' else 'Healer' if 'healer' in slug or spec in ('Holy','Restoration','Discipline') else 'Strength' if cls in ('warrior','paladin') else 'Agility' if cls in ('rogue','hunter') or spec=='Feral' else 'Caster'
            if cls=='shaman' and spec=='Enhancement':scale='Strength'
            if cls=='druid' and spec=='Feral':scale='Tank' if 'bear' in heading.lower() or 'tank' in heading.lower() else 'Agility'
            variant=sum(b['spec']==spec and b['goal']==goal for b in builds)+1
            name=f'{spec} {goal}'+(f' {variant}' if variant>1 else '')
            statfile=CACHE/('guide-'+slug.replace('-spec-builds-talents','-stat-priority')+'.html')
            if goal=='Leveling':statfile=next(CACHE.glob('guide-'+slug.removesuffix('-leveling')+'-*-stat-priority.html'),statfile)
            stats=priorities(statfile,scale=='Tank')
            article=' '.join(plain(text).split())
            optional={nid:True for nid in set(safe) if re.search(re.escape(all_nodes[nid]['name'])+r'\s+is\s+(?:always\s+|entirely\s+)?optional\b',article,re.I)}
            builds.append({'id':f'guide-{cls}-{len(builds)+1}','name':name,'class':cls.upper(),'spec':spec,'goal':goal,'scale':scale,
                'version':VERSION,'order':safe,'optional':optional,'origin':'guide','author':page.author,'source':'https://www.icy-veins.com/wow-forever/'+slug,
                'checked':CHECKED,'updated':page.modified,'priority':stats,'orderKind':'Legal point order from guide allocation'})
    assert builds,cls
    data={'version':VERSION,'checked':CHECKED,'class':cls.upper(),'classID':raw['classId'],
        'groups':[g['name'] for g in raw['talentGroups']],'nodes':all_nodes,'builds':builds}
    (OUT/f'{cls.upper()}.lua').write_text('local _,FS=...\nFS.TalentCatalogLoaders.'+cls.upper()+'=function() return '+lua(data)+' end\n',encoding='utf-8',newline='\n')
    count+=len(builds);print(cls,len(all_nodes),'talents',len(builds),'builds')
print('TOTAL',count,'builds; excluded',len(skipped),'incompatible or incomplete source allocations')
for item in skipped:print('EXCLUDED',*item)
(CACHE/'catalog-report.json').write_text(json.dumps({'version':VERSION,'checked':CHECKED,'builds':count,'excluded':skipped},indent=2))
