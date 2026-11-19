"""Render small, hollow minimap frames using the existing Blender theme palette.

blender --background --factory-startup --threads 4 --python work/render_minimap_frames.py
Only the selected 256px texture is used by the addon at runtime.
"""
import math
from pathlib import Path
import sys
import bpy
sys.path.insert(0,str(Path(__file__).resolve().parent))
import render_menu_icons as icons

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'Assets' / 'Minimap'
icons.bpy = bpy


def band(outer, inner, z, material, name='Hollow frame'):
    count = len(outer)
    vertices = [(x, y, z + h) for h in (0, .055) for loop in (outer, inner) for x, y in loop]
    faces = []
    for i in range(count):
        j = (i + 1) % count
        faces.extend(((i, j, count+j, count+i),
                      (2*count+i, 3*count+i, 3*count+j, 2*count+j),
                      (i, 2*count+i, 2*count+j, j),
                      (count+i, count+j, 3*count+j, 3*count+i)))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(icons.MATERIALS[material])
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    icons.bevel(obj, .006)
    return obj


def ring(radius, width, z, material):
    points = 128
    def loop(r):
        return [(math.cos(i*math.tau/points)*r, math.sin(i*math.tau/points)*r) for i in range(points)]
    return band(loop(radius), loop(radius-width), z, material)


def marker(angle, radius, width, length, material, leaf=False):
    ca, sa = math.cos(angle), math.sin(angle)
    if leaf:
        points = [(0, -length), (width, -.3*length), (.65*width, .45*length),
                  (0, length), (-.65*width, .45*length), (-width, -.3*length)]
    else:
        points = [(0, -length), (width, 0), (0, length), (-width, 0)]
    points = [(ca*(radius+y)-sa*x, sa*(radius+y)+ca*x) for x,y in points]
    mesh = icons.mesh(points, .09, .03, 'Cardinal detail')
    mesh.materials.append(icons.MATERIALS[material])
    obj = bpy.data.objects.new('Cardinal detail', mesh)
    bpy.context.collection.objects.link(obj)
    icons.bevel(obj, .004)


def round_frame(index):
    ring(1.035, .088 if index in (3, 6, 7, 9, 11) else .065, 0, 'plate')
    ring(1.035, .017 if index != 8 else .009, .03, 'alloy')
    ring(.968, .009 if index != 8 else .006, .04, 'enamel')
    counts = (8, 4, 12, 8, 4, 6, 4, 12, 8, 8, 16, 8)
    for i in range(counts[index]):
        angle = i*math.tau/counts[index] + math.pi/2
        cardinal = i % max(1, counts[index]//4) == 0
        width = .019 if cardinal else .009
        length = .035 if cardinal else .016
        if index == 4:
            width, length = .020, .045
        if index == 8:
            width, length = .009, .016
        marker(angle, 1.002, width, length, 'alloy', leaf=index == 4)
        if cardinal and index not in (2, 7, 8, 10):
            marker(angle, 1.003, width*.48, length*.5, 'enamel', leaf=index == 4)
    if index in (1, 3, 6, 11):
        marker(math.pi/2, 1.010, .034, .045, 'alloy')
        marker(math.pi/2, 1.013, .016, .027, 'enamel')


def dark_fantasy_frame():
    icons.material('iron', '26252a', .72, .48, .04)
    icons.material('bronze', '80705b', .6, .42, .09)
    icons.material('blood', '9e2830', .2, .37, .12)
    band(icons.cutbox(0,0,2.08,2.08,.055), icons.cutbox(0,0,1.91,1.91,.016), 0, 'iron')
    band(icons.cutbox(0,0,2.075,2.075,.055), icons.cutbox(0,0,2.052,2.052,.05), .04, 'bronze')
    band(icons.cutbox(0,0,1.935,1.935,.02), icons.cutbox(0,0,1.918,1.918,.018), .045, 'bronze')
    for angle in (math.pi/4, 3*math.pi/4, 5*math.pi/4, 7*math.pi/4):
        marker(angle, 1.405, .024, .030, 'bronze')
    marker(math.pi/2, 1.005, .050, .055, 'iron')
    marker(math.pi/2, 1.006, .022, .035, 'blood')


def scene_for(index):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    icons.MATERIALS.clear()
    icons.theme_materials(index)
    scene = bpy.context.scene
    data = bpy.data.cameras.new('Minimap camera')
    data.type = 'ORTHO'; data.ortho_scale = 2.18
    camera = bpy.data.objects.new('Minimap camera', data)
    bpy.context.collection.objects.link(camera)
    camera.location = (0,0,12); scene.camera = camera
    for label,energy,rotation,color in (
        ('Warm key', 2.1, (.35,-.4,-.1), (1,.92,.82)),
        ('Cool fill', .8, (-.35,.3,.2), (.78,.9,1))):
        light = bpy.data.lights.new(label,'SUN'); light.energy=energy; light.angle=.15; light.color=color
        obj = bpy.data.objects.new(label,light); bpy.context.collection.objects.link(obj); obj.rotation_euler=rotation
    scene.world=bpy.data.worlds.new('Studio'); scene.world.use_nodes=True
    scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.35,.4,.47,1)
    scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.45
    scene.render.engine='CYCLES'; scene.cycles.samples=24; scene.cycles.max_bounces=3
    scene.render.film_transparent=True
    scene.render.resolution_x=256; scene.render.resolution_y=256; scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='TARGA_RAW'; scene.render.image_settings.color_mode='RGBA'
    scene.view_settings.view_transform='Standard'
    return scene


OUT.mkdir(parents=True,exist_ok=True)
for index in range(len(icons.THEMES)+1):
    scene=scene_for(min(index,len(icons.THEMES)-1))
    if index == len(icons.THEMES):
        dark_fantasy_frame(); name='Dark-Fantasy.tga'
    else:
        round_frame(index); name=f'{index:02d}-Round.tga'
    scene.render.filepath=str(OUT/name)
    bpy.ops.render.render(write_still=True)
    print('Rendered minimap frame:',name,flush=True)
