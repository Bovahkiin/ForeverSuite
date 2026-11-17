"""Render the ForeverSuite icon sheets in Blender's background mode.

Run blender -b --factory-startup -t 8 --python work/render_menu_icons.py -- OUTPUT_DIR
Pass a theme index after OUTPUT_DIR to render just one sheet.
"""
import math
from pathlib import Path
import sys

ICONS = (
    "Character", "Professions", "Spells", "Talents", "Achievements", "Quests",
    "Guild", "Social", "Groups", "PVP", "Collections", "Guide", "Map", "Store",
    "Menu", "Help", "Legacy", "Housing", "Reputation", "Skills", "Currency",
    "Statistics", "Enemy", "Equipment", "Friendly", "Bags", "Vendor", "Gear",
    "UnitFrames", "ActionBars", "Nameplates", "Loot", "Buffs", "Cooldowns",
    "Combat", "AuctionHouse", "Chat", "QoL", "Bank", "Bindings", "Mail",
    "MinimapButtons", "GearAdvisor", "Pet", "Grid", "Star", "Potion", "Ammo",
    "Gem", "Junk", "Stock", "Keys", "Mounts", "Category",
)
# Plate shape, alloy, enamel, surface, sheet material. Gold, ruby, and silver
# retain their established meanings on every theme.
THEMES = (
    ("Legacy", "square", "9aa4b3", "539bcc", "263442", "e8d5ad"),
    ("Celestial Forge", "octagon", "d9a44e", "40cde5", "173b4d", "f5e1b0"),
    ("Titanium Signal", "corner", "acbcca", "2cacf2", "213746", "e0eff7"),
    ("Obsidian Arcana", "octagon", "a879cf", "ac56f6", "292037", "ecd5f5"),
    ("Verdant Relic", "leaf", "aa8b43", "75ba50", "273d28", "eee3b5"),
    ("Glacial Prism", "hex", "a9e7f7", "40c5ee", "1f4660", "e4f8fa"),
    ("Royal Aether", "arch", "e1b46d", "9d66e4", "35214a", "fff0cc"),
    ("Runestone", "tall", "c0a27d", "61a08c", "403632", "e8d6b5"),
    ("Astral Glass", "circle", "92c8ef", "329bde", "192c4a", "e0f3fa"),
    ("Ember Bastion", "shield", "db8756", "ff803b", "4b2622", "ffd5ac"),
    ("Cartographer", "paper", "93683c", "387e92", "755438", "f5deb3"),
    ("Azeroth Heritage", "crest", "d0a15a", "438baf", "322625", "eed7a5"),
)
COLS, ROWS, PIXELS = 9, 6, 80

CHARCOAL = "shadow"
PLATES = {}
MATERIALS = {}
offset = (0, 0)
spacing = 2.56


def cutbox(x, y, w, h, cut=.12):
    left, right, bottom, top = x-w/2, x+w/2, y-h/2, y+h/2
    return [(left+cut,bottom), (right-cut,bottom), (right,bottom+cut), (right,top-cut),
            (right-cut,top), (left+cut,top), (left,top-cut), (left,bottom+cut)]


def bevel(obj, width):
    if width:
        mod = obj.modifiers.new("Rounded metal edge", "BEVEL")
        mod.width = width
        mod.segments = 2
        mod = obj.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
        mod.keep_sharp = True
    return obj


def mesh(points, z, depth, name):
    n = len(points)
    area = sum(points[i][0]*points[(i+1)%n][1] - points[(i+1)%n][0]*points[i][1] for i in range(n))
    if area < 0:
        points = list(reversed(points))
    data = bpy.data.meshes.new(name)
    vertices = [(x,y,z+level) for level in (0,depth) for x,y in points]
    faces = [tuple(range(n-1,-1,-1)), tuple(range(n,2*n))]
    faces.extend((i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n))
    data.from_pydata(vertices, [], faces)
    data.update()
    return data


def poly(points, material, z=.25, depth=.12, edge=.035):
    data = mesh(points,z,depth,material)
    obj = bpy.data.objects.new(material,data)
    bpy.context.collection.objects.link(obj)
    obj.location = (*offset,0)
    data.materials.append(MATERIALS[material])
    return bevel(obj,edge)


def box(x,y,w,h,material,z=.25,depth=.12,angle=0,cut=.09):
    points = cutbox(0,0,w,h,min(cut,w*.28,h*.28))
    if angle:
        cos,sin = math.cos(angle),math.sin(angle)
        points = [(px*cos-py*sin,px*sin+py*cos) for px,py in points]
    return poly([(x+px,y+py) for px,py in points],material,z,depth)


def disc(x,y,r,material,z=.25,depth=.13,sides=28,squash=1):
    return poly([(x+r*math.cos(i*math.tau/sides),y+r*squash*math.sin(i*math.tau/sides))
                 for i in range(sides)],material,z,depth,min(.05,r*.25))


def stroke(points, material, width=.055, z=.42):
    data = bpy.data.curves.new(material, "CURVE")
    data.dimensions = "3D"
    data.bevel_depth = width
    data.bevel_resolution = 2
    spline = data.splines.new("POLY")
    spline.points.add(len(points)-1)
    for point,(x,y) in zip(spline.points,points):
        point.co = (x,y,z,1)
    obj = bpy.data.objects.new(material,data)
    bpy.context.collection.objects.link(obj)
    obj.location = (*offset,0)
    data.materials.append(MATERIALS[material])


def gem(x,y,r,material="enamel",z=.47):
    poly([(x-r,y),(x,y-r*1.25),(x+r,y),(x,y+r*1.25)],"alloy",z-.05,.10)
    poly([(x-r*.78,y),(x,y-r),(x+r*.78,y),(x,y+r)],material,z+.04,.10)
    poly([(x-r*.55,y),(x,y+r*.78),(x+r*.13,y+r*.16)],"silver",z+.13,.03,.006)


def stars(x,y,r,material="gold",z=.4):
    points = []
    for i in range(10):
        a = math.pi/2 + i*math.tau/10
        radius = r if i%2==0 else r*.46
        points.append((x+math.cos(a)*radius,y+math.sin(a)*radius))
    poly(points,material,z,.13)


def figure(x,y,scale, material):
    def point(a,b): return (x+a*scale,y+b*scale)
    poly([point(a,b) for a,b in [(-.60,-.72),(.60,-.72),(.51,-.36),(.31,-.17),
        (-.31,-.17),(-.51,-.36)]],material,.28,.21)
    disc(x,y+.28*scale,.34*scale,"paper",.34,.17)
    box(x,y-.47*scale,.27*scale,.17*scale,"alloy",.48,.06)


def helmet():
    poly([(-.83,.11),(-.68,.55),(-.30,.78),(.34,.78),(.69,.51),(.83,.07),
          (.64,-.57),(.32,-.75),(.14,-.39),(-.14,-.39),(-.32,-.75),(-.64,-.57)],"alloy",.24,.24,.075)
    poly([(-.61,.21),(-.46,.48),(0,.57),(.46,.48),(.61,.21),(.46,-.33),
          (.23,-.45),(0,-.16),(-.23,-.45),(-.46,-.33)],"shadow",.46,.045)
    box(0,.48,.30,.43,"enamel",.49,.12)
    stroke([(-.62,.17),(-.20,.12),(0,-.12),(.20,.12),(.62,.17)],"gold",.06,.53)
    gem(0,.60,.12,z=.60)


def hammer(gavel=False):
    box(-.23,-.23,.22,1.37,"leather",.23,.16,-.66)
    box(-.23,-.23,.12,.80,"gold",.40,.07,-.66)
    box(.36,.47,1.13,.45,"gold" if gavel else "alloy",.32,.27,-.66)
    box(.33,.45,.58,.34,"enamel",.58,.07,-.66)
    if gavel: box(.32,-.65,.91,.20,"alloy",.35,.16)


def book():
    poly([(-.92,.64),(-.42,.68),(0,.49),(.43,.68),(.92,.64),(.87,-.61),
          (.40,-.59),(0,-.77),(-.40,-.59),(-.87,-.61)],"leather",.22,.18,.06)
    for side in (-1,1):
        poly([(side*x,y) for x,y in [(0,.45),(.42,.61),(.79,.57),(.75,-.47),(.34,-.46),(0,-.64)]],"paper",.40,.12)
        for y in (.24,.02,-.19):
            stroke([(side*.22,y-.07),(side*.34,y),(side*.60,y-.02)],"ink",.031,.535)
    gem(0,-.17,.19,z=.54)


def tree():
    stroke([(0,-.64),(0,-.10),(-.60,.49)],"alloy",.12,.36)
    stroke([(0,-.10),(.60,.49)],"alloy",.12,.36)
    for x,y,r in ((0,-.65,.22),(-.61,.47,.24),(.61,.47,.24),(0,-.10,.18)):
        gem(x,y,r,z=.38)


def trophy():
    for side in (-1,1):
        stroke([(side*.43,.57),(side*.81,.54),(side*.75,.22),(side*.43,.08)],"gold",.085,.40)
    poly([(-.50,.64),(.50,.64),(.44,.17),(.27,-.10),(0,-.21),(-.27,-.10),(-.44,.17)],"gold",.25,.23,.08)
    box(0,-.36,.22,.52,"alloy",.26,.18)
    box(0,-.65,.91,.26,"leather",.24,.18)
    gem(0,.27,.18,z=.51)


def scroll():
    box(0,0,1.08,1.39,"paper",.28,.14,angle=-.12)
    box(.06,.64,1.28,.20,"gold",.36,.15,angle=-.12)
    box(-.08,-.64,1.26,.18,"paper",.37,.16,angle=-.12)
    box(-.17,.17,.12,.47,"ink",.45,.07,angle=-.12)
    disc(-.13,-.18,.080,"ink",.46,.07,sides=12)
    disc(.42,-.40,.23,"ruby",.44,.15)
    disc(.42,-.40,.10,"gold",.59,.05,sides=12)


def banner(kind="enamel"):
    box(-.65,0,.15,1.65,"alloy",.24,.18)
    disc(-.65,.78,.12,"gold",.39,.09)
    poly([(-.58,.58),(.63,.58),(.54,.02),(.67,-.37),(.07,-.28),(-.58,-.42)],kind,.28,.14)
    stroke([(-.46,.45),(.41,.45),(.38,.04),(.48,-.18),(.07,-.13),(-.45,-.26)],"gold",.045,.43)
    gem(.04,.15,.19,z=.47)


def bubble(two=False):
    if two:
        poly([(-.12,.34),(.65,.45),(.91,.24),(.91,-.39),(.36,-.39),(.20,-.66),
              (.20,-.39),(-.12,-.33)],"alloy",.24,.15)
    poly([(-.89,.68),(.32,.68),(.58,.43),(.58,-.14),(-.28,-.14),(-.58,-.54),
          (-.58,-.14),(-.89,-.10)],"enamel",.38,.21,.06)
    for x in (-.56,-.15,.25): disc(x,.26,.085,"silver",.59,.08,sides=12)


def sword(angle, scale=1):
    def points(coords):
        c,s=math.cos(angle),math.sin(angle)
        return [((x*c-y*s)*scale,(x*s+y*c)*scale) for x,y in coords]
    poly(points([(-.16,-.19),(.16,-.19),(.16,.58),(0,.91),(-.16,.58)]),"silver",.35,.15)
    poly(points([(-.32,-.26),(.32,-.26),(.32,-.13),(-.32,-.13)]),"gold",.50,.12)
    poly(points([(-.10,-.77),(.10,-.77),(.10,-.20),(-.10,-.20)]),"leather",.31,.17)
    poly(points([(-.16,-.79),(.16,-.79),(.13,-.64),(-.13,-.64)]),"gold",.47,.10)


def chest(kind="leather"):
    box(0,-.20,1.64,.94,kind,.23,.23,.0,.12)
    poly([(-.88,.11),(-.72,.56),(-.48,.68),(.48,.68),(.72,.56),(.88,.11)],kind,.40,.16,.06)
    for x in (-.56,.56):
        box(x,.01,.16,1.25,"alloy",.54,.10)
    box(0,.01,1.61,.12,"gold",.54,.10)
    box(0,-.09,.34,.40,"gold",.65,.10)
    disc(0,-.08,.059,"shadow",.76,.045,sides=12)


def dial(kind):
    disc(0,0,.83,"alloy",.23,.21)
    disc(0,0,.68,"shadow",.44,.06)
    for i in range(4):
        a=i*math.pi/2
        disc(math.cos(a)*.55,math.sin(a)*.55,.047,"gold",.51,.06,sides=10)
    if kind=="compass":
        poly([(-.48,-.54),(-.14,.13),(.51,.62),(.19,-.12)],"silver",.53,.12)
        poly([(-.16,.12),(.51,.62),(.19,-.12)],"enamel",.66,.06)
    elif kind=="clock":
        stroke([(0,.38),(0,0),(.28,-.15)],"silver",.067,.57)
        disc(0,0,.10,"gold",.58,.06)
    else:
        stroke([(-.27,.29),(-.15,.53),(.18,.53),(.32,.36),(.20,.11),(0,-.02),(0,-.23)],"paper",.073,.55)
        disc(0,-.44,.075,"gold",.56,.06,sides=12)


def map_icon():
    for points,material in (
        ([(-.90,-.64),(-.31,-.40),(-.31,.64),(-.90,.39)],"paper"),
        ([(-.31,-.40),(.30,-.58),(.30,.44),(-.31,.64)],"paperShade"),
        ([(.30,-.58),(.88,-.34),(.88,.70),(.30,.44)],"paper"),
    ):
        poly(points,material,.26,.18,.025)
    stroke([(-.66,-.31),(-.49,-.03),(-.13,-.09),(.16,.09),(.47,.06)],"ink",.053,.47)
    poly([(.12,.29),(.09,.49),(.21,.64),(.47,.66),(.63,.54),(.62,.35),(.37,-.13)],"ruby",.48,.14)
    disc(.37,.47,.107,"gold",.63,.08,sides=12)


def bag(store=False):
    if store:
        stroke([(-.37,.37),(-.37,.64),(-.23,.76),(.23,.76),(.37,.64),(.37,.37)],"gold",.09,.30)
        poly([(-.72,.42),(.72,.42),(.61,-.70),(-.61,-.70)],"paper",.31,.20)
        box(0,-.51,1.22,.20,"leather",.52,.09)
        gem(0,-.05,.22,z=.54)
    else:
        stroke([(-.31,.49),(-.28,.76),(.28,.76),(.31,.49)],"gold",.09,.30)
        box(0,-.06,1.45,1.42,"leather",.26,.22,cut=.25)
        box(0,.18,1.37,.68,"enamel",.48,.13,cut=.17)
        box(0,-.19,.28,.40,"gold",.61,.10)
        box(0,-.50,.86,.23,"paperShade",.49,.07)


def gear():
    points = []
    for i in range(32):
        angle = i*math.tau/32
        r = .84 if i%4 in (0,1) else .64
        points.append((r*math.cos(angle),r*math.sin(angle)))
    poly(points,"alloy",.25,.24)
    disc(0,0,.46,"enamel",.48,.09)
    disc(0,0,.33,"shadow",.57,.055)
    box(0,0,.45,.11,"silver",.63,.04)


def house(bank=False):
    box(0,-.30,1.42,.94,"paperShade" if bank else "leather",.23,.17)
    poly([(-.88,.32),(0,.82),(.88,.32),(.72,.18),(-.72,.18)],"alloy" if bank else "ruby",.35,.20)
    if bank:
        for x in (-.43,0,.43): box(x,-.20,.17,.65,"paper",.43,.13)
        box(0,-.65,1.62,.23,"gold",.43,.12)
    else:
        box(0,-.40,.50,.72,"shadow",.40,.10)
        box(-.52,-.18,.18,.24,"enamel",.42,.12)
        box(.52,-.18,.18,.24,"enamel",.42,.12)
        disc(.14,-.42,.047,"gold",.52,.06,sides=12)


def medal(kind):
    poly([(-.62,.54),(-.25,.70),(.08,-.42),(-.49,-.71)],"ruby",.23,.14)
    poly([(.62,.54),(.25,.70),(-.08,-.42),(.49,-.71)],"enamel",.24,.15)
    disc(0,-.14,.52,"gold",.40,.23)
    if kind=="legacy":
        box(0,-.10,.61,.35,"shadow",.64,.09)
        box(0,-.14,.24,.10,"paper",.74,.05)
    else:
        stars(0,-.12,.34,"silver",.64)


def graph(kind):
    box(0,0,1.66,1.43,"alloy",.20,.17,cut=.16)
    box(0,0,1.42,1.20,"shadow",.37,.10)
    if kind=="bars":
        for index,height in enumerate((.35,.63,.94)):
            box(-.43+index*.43,-.43+height/2,.24,height,("gold","silver","enamel")[index],.47,.16)
    elif kind=="pulse":
        stroke([(-.58,-.13),(-.28,-.13),(-.09,.39),(.15,-.43),(.38,.10),(.60,.10)],"enamel",.068,.54)
    else:
        stroke([(-.55,-.37),(-.10,-.02),(.17,-.12),(.51,.41),(.20,.41)],"gold",.077,.57)
        stroke([(.51,.41),(.51,.10)],"gold",.077,.57)


def controls(kind):
    box(0,0,1.66,1.36,"alloy",.20,.19,cut=.14)
    box(0,0,1.42,1.15,"shadow",.39,.05)
    if kind=="skills":
        for y,x in ((.33,-.26),(0,.25),(-.33,-.06)):
            box(0,y,1.10,.085,"silver",.46,.05)
            disc(x,y,.13,"enamel",.52,.12,sides=14)
    elif kind=="keys":
        for y in (.24,-.06):
            for x in (-.47,-.16,.16,.47): box(x,y,.20,.18,"paper",.47,.09)
        box(0,-.36,.68,.14,"gold",.47,.09)
    else:
        for i,(x,y) in enumerate([(-.37,.30),(.37,.30),(-.37,-.30),(.37,-.30)]):
            box(x,y,.55,.43,("enamel","gold","paper","enamel")[i],.49,.14)


def armor():
    poly([(-.84,.51),(-.48,.72),(-.15,.46),(.15,.46),(.48,.72),(.84,.51),
          (.65,.06),(.47,.19),(.40,-.65),(0,-.78),(-.40,-.65),(-.47,.19),(-.65,.06)],"alloy",.24,.24,.08)
    poly([(-.43,.36),(.43,.36),(.37,-.49),(0,-.65),(-.37,-.49)],"enamel",.48,.10)
    stroke([(-.44,.22),(0,.04),(.44,.22)],"gold",.057,.62)
    gem(0,-.21,.20,z=.62)


def bars(nameplate=False):
    for y in ((.22,) if nameplate else (.32,-.30)):
        box(0,y,1.62,.40,"alloy",.25,.22)
        box(-.19,y,.99,.23,"enamel" if not nameplate else "ruby",.47,.10)
    if nameplate: poly([(-.27,-.25),(.27,-.25),(0,-.63)],"gold",.32,.17)


def coins():
    for x,y in [(-.36,-.33),(.29,-.22),(.24,.38)]:
        disc(x,y,.49,"gold",.24+(y+.35)*.16,.23)
    stroke([(.24,.66),(.24,.10)],"leather",.055,.60)


def envelope():
    box(0,0,1.65,1.14,"paper",.25,.20,cut=.12)
    poly([(-.76,.49),(.76,.49),(0,-.09)],"paperShade",.45,.09)
    stroke([(-.73,.43),(0,-.10),(.73,.43)],"gold",.042,.55)
    disc(0,-.14,.21,"ruby",.53,.14)
    disc(0,-.14,.067,"gold",.67,.06,12)


def pet():
    poly([(-.61,-.32),(-.28,.08),(0,.18),(.28,.08),(.61,-.32),(.55,-.60),
          (.27,-.67),(0,-.54),(-.27,-.67),(-.55,-.60)],"enamel",.26,.21,.09)
    for x,y in [(-.55,.24),(-.19,.52),(.19,.52),(.55,.24)]:
        disc(x,y,.16,"gold",.34,.16,squash=1.30)


def arrows(enemy=False):
    for y in (-.29,.27):
        s = -1 if enemy else 1
        poly([(-.62,y), (0,y+.35*s),(.62,y),(.42,y-.19*s),(0,y+.03*s),(-.42,y-.19*s)],
             "ruby" if enemy else "enamel",.25,.20)


def heart():
    poly([(0,-.72),(-.73,-.10),(-.80,.36),(-.50,.61),(-.21,.59),(0,.38),(.21,.59),
          (.50,.61),(.80,.36),(.73,-.10)],"ruby",.28,.23,.075)
    stroke([(-.45,.17),(-.24,.26),(-.10,.08),(.08,.32),(.27,.03),(.45,.15)],"silver",.043,.55)


def vendor():
    box(0,-.38,1.55,.52,"leather",.22,.22)
    box(0,-.31,1.32,.20,"gold",.45,.11)
    for i in range(5):
        box((i-2)*.29,.37,.27,.55,"enamel" if i%2==0 else "paper",.28,.21,cut=.05)
    box(0,.67,1.57,.14,"alloy",.45,.13)


def stock():
    poly([(-.74,.38),(0,.76),(.74,.38),(0,.03)],"paperShade",.34,.22)
    poly([(-.74,.38),(0,.03),(0,-.79),(-.74,-.39)],"alloy",.34,.22)
    poly([(0,.03),(.74,.38),(.74,-.39),(0,-.79)],"enamel",.34,.22)
    stroke([(-.24,.65),(.49,.25),(.49,-.13)],"gold",.075,.59)


def potion():
    poly([(-.23,.70),(.23,.70),(.24,.28),(.57,.03),(.65,-.36),(.36,-.74),(-.36,-.74),
          (-.65,-.36),(-.57,.03),(-.24,.28)],"alloy",.24,.20,.07)
    disc(0,-.26,.50,"enamel",.43,.16,squash=.85)
    box(0,.63,.63,.23,"gold",.43,.13)
    disc(-.21,-.10,.10,"silver",.59,.055,12)


def key():
    disc(-.36,.33,.41,"gold",.27,.20)
    disc(-.36,.33,.21,"shadow",.48,.07)
    box(.20,-.21,.22,1.18,"gold",.28,.20,-.78)
    box(.43,-.47,.33,.13,"alloy",.49,.14,-.78)


def horse():
    poly([(-.69,-.69),(.63,-.69),(.52,-.27),(.24,.06),(.48,.25),(.40,.48),(.12,.59),
          (-.14,.80),(-.20,.44),(-.59,.20),(-.74,-.17),(-.48,-.36),(-.20,-.15),
          (-.35,-.41)],"paperShade",.27,.23,.04)
    stroke([(.03,.49),(.23,.28),(.23,.08),(.46,-.31)],"gold",.065,.52)
    disc(-.19,.26,.073,"enamel",.54,.08,14)


def folder():
    poly([(-.83,.50),(-.29,.50),(-.06,.32),(.84,.32),(.83,-.59),(-.82,-.59)],"gold",.22,.20)
    poly([(-.74,.15),(.86,.15),(.72,-.58),(-.83,-.58)],"paperShade",.43,.15)
    box(.08,-.17,.63,.18,"paper",.59,.06)


def junk():
    box(0,-.24,1.17,.99,"alloy",.25,.22,cut=.19)
    box(0,.36,1.49,.23,"gold",.47,.15)
    box(0,.59,.42,.20,"alloy",.37,.14)
    for x in (-.28,0,.28): box(x,-.20,.087,.55,"shadow",.49,.05)


def ammo():
    stroke([(-.63,-.63),(.62,.62)],"leather",.082,.34)
    poly([(.22,.62),(.72,.75),(.61,.20),(.47,.39)],"silver",.43,.16)
    poly([(-.72,-.55),(-.56,-.65),(-.30,-.32),(-.52,-.28)],"enamel",.43,.13)


SHAPES = {
    "Character": helmet, "Professions": hammer, "Spells": book, "Talents": tree,
    "Achievements": trophy, "Quests": scroll, "Guild": banner,
    "Social": lambda: bubble(True),
    "Groups": lambda: (figure(.32,.12,.78,"alloy"), figure(-.30,-.13,.90,"enamel")),
    "PVP": lambda: (sword(-.76),sword(.76)), "Collections": chest,
    "Guide": lambda: dial("compass"), "Map": map_icon, "Store": lambda: bag(True),
    "Menu": gear, "Help": lambda: dial("help"), "Legacy": lambda: medal("legacy"),
    "Housing": house, "Reputation": lambda: medal("reputation"),
    "Skills": lambda: controls("skills"), "Currency": coins,
    "Statistics": lambda: graph("bars"), "Enemy": lambda: arrows(True),
    "Equipment": lambda: chest("enamel"), "Friendly": heart, "Bags": bag,
    "Vendor": vendor, "Gear": armor, "UnitFrames": lambda: graph("pulse"),
    "ActionBars": lambda: controls("slots"), "Nameplates": lambda: bars(True),
    "Loot": lambda: (chest("ruby"),stars(.55,.55,.35,"gold",.75)),
    "Buffs": arrows, "Cooldowns": lambda: dial("clock"),
    "Combat": lambda: (poly([(-.57,.56),(.57,.56),(.52,-.25),(0,-.76),(-.52,-.25)],"ruby"),
                       sword(.74,.91)),
    "AuctionHouse": lambda: hammer(True), "Chat": bubble, "QoL": lambda: graph("rise"),
    "Bank": lambda: house(True), "Bindings": lambda: controls("keys"),
    "Mail": envelope, "MinimapButtons": lambda: dial_grid(), "GearAdvisor": lambda: gear_advisor(),
    "Pet": pet, "Grid": lambda: controls("slots"), "Star": lambda: stars(0,0,.82),
    "Potion": potion, "Ammo": ammo, "Gem": lambda: gem(0,0,.68,z=.29),
    "Junk": junk, "Stock": stock, "Keys": key, "Mounts": horse, "Category": folder,
}


def dial_grid():
    disc(0,0,.83,"alloy",.23,.22)
    disc(0,0,.67,"shadow",.45,.06)
    for x in (-.24,.24):
        for y in (-.24,.24): box(x,y,.31,.31,"enamel",.51,.14,cut=.06)


def gear_advisor():
    box(0,0,1.55,1.48,"alloy",.23,.20,cut=.13)
    box(0,0,1.32,1.25,"shadow",.44,.08,cut=.13)
    poly([(-.17,-.43),(.17,-.43),(.17,.06),(.49,.06),(0,.54),(-.49,.06),(-.17,.06)],
         "enamel",.54,.15)


def plate_outline(shape):
    if shape=="circle":
        return [(1.04*math.cos(i*math.tau/48),1.04*math.sin(i*math.tau/48)) for i in range(48)]
    if shape=="hex":
        return [(-.70,-1.0),(.70,-1.0),(1.11,0),(.70,1.0),(-.70,1.0),(-1.11,0)]
    if shape=="arch":
        return [(-1.03,-1.04),(1.03,-1.04),(1.03,.48),(.61,.86),(0,1.09),(-.61,.86),(-1.03,.48)]
    if shape=="shield":
        return [(0,-1.10),(.67,-.83),(1.05,-.45),(1.05,1.03),(-1.05,1.03),(-1.05,-.45),(-.67,-.83)]
    if shape=="paper":
        return [(-1.05,-1.02),(1.05,-1.02),(1.05,.63),(.66,1.04),(-1.05,1.04)]
    if shape=="crest":
        return [(-.63,-1.05),(.63,-1.05),(1.04,-.66),(1.12,.60),(.68,1.03),(-.68,1.03),(-1.12,.60),(-1.04,-.66)]
    width,height,cut = {"leaf":(2.16,2.10,.40),"tall":(2.02,2.19,.28),
                        "octagon":(2.14,2.14,.42),"corner":(2.14,2.14,.14),
                        "square":(2.14,2.14,.08)}[shape]
    return cutbox(0,0,width,height,cut)


def color(value):
    channels = [int(value[i:i+2],16)/255 for i in (0,2,4)]
    return tuple(v/12.92 if v < .04045 else ((v+.055)/1.055)**2.4 for v in channels)


def material(name, value, metal, rough, emission=.08):
    mat = MATERIALS.get(name)
    if mat is None:
        mat = MATERIALS[name] = bpy.data.materials.new(name)
        mat.use_nodes = True
    rgb = (*color(value),1)
    mat.diffuse_color = rgb
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = rgb
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Emission Color"].default_value = rgb
    bsdf.inputs["Emission Strength"].default_value = emission


def theme_materials(index):
    _,shape,alloy,enamel,surface,paper = THEMES[index]
    material("alloy",alloy,.57,.30,.20)
    material("enamel",enamel,.24,.28,.17)
    material("plate",surface,.24,.49,.05)
    material("paper",paper,.04,.58,.13)
    material("paperShade",paper,.14,.64,.04)
    return shape


def set_plates(shape):
    outline = plate_outline(shape)
    definitions = [
        ("rim", "alloy", outline, -.01, .105),
        ("face", "plate", [(x*.90,y*.90) for x,y in outline], .075, .085),
    ]
    for key, mat, points,z,depth in definitions:
        data = mesh(points,z,depth,f"{shape} {key}")
        data.materials.append(MATERIALS[mat])
        for tile_offset,parts in PLATES.items():
            obj = parts.get(key)
            if obj is None:
                obj = bpy.data.objects.new(key,data)
                bpy.context.collection.objects.link(obj)
                obj.location = (*tile_offset,0)
                parts[key] = bevel(obj,.042)
            else:
                old = obj.data
                obj.data = data
                if old.users == 0:
                    bpy.data.meshes.remove(old)


def prepare_scene():
    global offset
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    theme_materials(0)
    for name,value,metal,rough,emission in [
        ("gold","dfac4b",.50,.29,.22), ("silver","d1dfee",.56,.27,.22),
        ("leather","855536",.08,.48,.11), ("shadow","181924",.05,.57,.04),
        ("ruby","a53141",.24,.34,.22), ("ink","57382c",.10,.57,.04),
    ]:
        material(name,value,metal,rough,emission)
    for i,name in enumerate(ICONS):
        offset = ((i%COLS-(COLS-1)/2)*spacing, ((ROWS-1)/2-i//COLS)*spacing)
        PLATES[offset] = {}
        SHAPES[name]()
    camera_data = bpy.data.cameras.new("Icon camera")
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = COLS*spacing
    camera = bpy.data.objects.new("Icon camera",camera_data)
    bpy.context.collection.objects.link(camera)
    camera.location = (0,0,28)
    scene.camera = camera
    for name,energy,rotation,light_color in [
        ("Warm key",2.0,(.42,-.43,-.15),(1,.92,.81)),
        ("Cool fill",.85,(-.45,.35,.25),(.77,.88,1)),
    ]:
        data = bpy.data.lights.new(name,"SUN")
        data.energy = energy
        data.angle = .15
        data.color = light_color
        light = bpy.data.objects.new(name,data)
        bpy.context.collection.objects.link(light)
        light.rotation_euler = rotation
    scene.world = bpy.data.worlds.new("Studio environment")
    scene.world.use_nodes = True
    world = scene.world.node_tree.nodes.get("Background")
    world.inputs["Color"].default_value = (.39,.44,.51,1)
    world.inputs["Strength"].default_value = .48
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 16
    scene.cycles.use_denoising = False
    scene.cycles.max_bounces = 3
    scene.render.use_persistent_data = True
    scene.render.film_transparent = True
    scene.render.resolution_x = COLS*PIXELS
    scene.render.resolution_y = ROWS*PIXELS
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    return scene


if __name__ == "__main__":
    import bpy

    args = sys.argv[sys.argv.index("--")+1:]
    destination = Path(args[0]).resolve()
    destination.mkdir(parents=True, exist_ok=True)
    scene = prepare_scene()
    for index in [int(args[1])] if len(args)>1 else range(len(THEMES)):
        set_plates(theme_materials(index))
        scene.render.filepath = str(destination / f"theme-{index:02}.png")
        bpy.ops.render.render(write_still=True)
