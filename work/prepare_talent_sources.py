"""Cache public Forever talent facts and guide build codes, never runtime web access."""
import json,re,urllib.request
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'work/talent-research';OUT.mkdir(exist_ok=True)
BASE='https://www.icy-veins.com'
CLASSES=('warrior','paladin','hunter','rogue','priest','shaman','mage','warlock','druid')
def fetch(url,name,refresh=False):
    path=OUT/name
    if refresh or not path.exists():
        req=urllib.request.Request(url,headers={'User-Agent':'ForeverSuite-development'})
        try: path.write_bytes(urllib.request.urlopen(req,timeout=40).read())
        except urllib.error.HTTPError as e:
            print('Unavailable',e.code,url,flush=True);return ''
    return path.read_text(encoding='utf-8')
index=json.loads(fetch('https://static.icy-veins.com/r2/icydb/wowf/talents/index.json','icy-index.json',True))
latest=index['latest']; print('Current talent version',latest,flush=True)
links=set()
for slug in CLASSES:
    fetch(f'https://static.icy-veins.com/r2/icydb/wowf/talents/{latest}/{slug}.json',f'icy-{slug}.json',True)
    page=fetch(f'{BASE}/wow-forever/{slug}-class-overview/',f'overview-{slug}.html',True)
    for path in re.findall(r'href=[\"\'](?:https?:)?(?://www.icy-veins.com)?(/wow-forever/[^\"\'?#]+)[\"\']',page):
        path=path.rstrip('/')
        if path.endswith('-leveling'): links.add(path)
        if path.endswith('-pve-guide'):
            links.add(path[:-6]+'-spec-builds-talents')
            links.add(path[:-6]+'-stat-priority')
def guide(path):
    slug=path.rsplit('/',1)[1]
    text=fetch(BASE+path,'guide-'+slug+'.html',True)
    print(slug,len(text),flush=True)
    return slug,text
with ThreadPoolExecutor(max_workers=4) as pool: pages=list(pool.map(guide,sorted(links)))
versions=set()
for slug,text in pages:
    for className,version in re.findall(r'data-talentcalculator-class="([a-z]+)"[\s\S]*?data-talentcalculator-pointsurl="[^\"]+~(\d+-[a-f0-9]+)"',text):
        versions.add((className,version))
for cls,version in sorted(versions):
    fetch(f'https://static.icy-veins.com/r2/icydb/wowf/talents/{version}/{cls}.json',f'data-{cls}-{version}.json')
print('Pages',len(pages),'historical class versions',len(versions),flush=True)
for path in ('Mainline/Blizzard_TrainerUI.lua','Mainline/Blizzard_TrainerUI_Camelot.lua','Mainline/Blizzard_TrainerUI.xml'):
    fetch('https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_TrainerUI/'+path,path.rsplit('/',1)[1])
