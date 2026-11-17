"""Pack the Blender renders into the atlas used by UI/Icons.lua."""
import argparse
from pathlib import Path

from PIL import Image, ImageDraw

from render_menu_icons import COLS, ICONS, PIXELS, ROWS, THEMES

CELL, COLUMNS, ATLAS = 36, 27, 1024


def build(render_dir):
    atlas = Image.new("RGBA", (ATLAS, ATLAS))
    for theme in range(len(THEMES)):
        with Image.open(render_dir / f"theme-{theme:02}.png") as sheet:
            assert sheet.size == (COLS*PIXELS, ROWS*PIXELS)
            assert sheet.mode == "RGBA"
            for index in range(len(ICONS)):
                x, y = index % COLS * PIXELS, index // COLS * PIXELS
                tile = sheet.crop((x,y,x+PIXELS,y+PIXELS))
                position = (index % COLUMNS * CELL, (theme*2 + index//COLUMNS) * CELL)
                atlas.paste(tile.resize((CELL,CELL), Image.Resampling.LANCZOS), position)
    return atlas


def preview(atlas, path):
    names = ("Character", "Professions", "Spells", "Talents", "Achievements", "Quests",
             "Guild", "Groups", "Collections", "Guide", "Map", "Housing", "Store", "Menu")
    labels = ("Character", "Professions", "Spellbook", "Talents", "Achievements", "Quest log",
              "Guild", "Group Finder", "Collections", "Adventure Guide", "World map", "Housing", "Shop", "Game menu")
    left, gap, row_height = 172, 77, 42
    width = left + gap*len(names) + 10
    board = Image.new("RGB", (width, 76 + row_height*len(THEMES)), "#141820")
    draw = ImageDraw.Draw(board)
    draw.text((14,12),"ForeverSuite  ·  Blender-rendered main menu icons",fill="#fff1d2",font_size=19)
    for col, label in enumerate(labels):
        draw.text((left+gap*col+gap/2,53),label,anchor="mm",fill="#acb9c7",font_size=10)
    for theme, (name, *_) in enumerate(THEMES):
        y = 69 + row_height*theme
        if theme%2==0:
            draw.rectangle((8,y-1,width-9,y+row_height-2),fill="#1d232e")
        draw.text((16,y+10),name,fill="#edf2f9",font_size=14)
        for col, icon in enumerate(names):
            index = ICONS.index(icon)
            x0 = index % COLUMNS * CELL
            y0 = (theme*2 + index//COLUMNS) * CELL
            tile = atlas.crop((x0,y0,x0+CELL,y0+CELL))
            board.paste(tile,(left+gap*col+(gap-CELL)//2,y+1),tile)
    board.save(path)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("render_dir", type=Path)
    parser.add_argument("--preview", type=Path)
    args = parser.parse_args()
    atlas = build(args.render_dir)
    root = Path(__file__).resolve().parents[1]
    atlas.save(root / "Assets" / "Menu" / "FantasyAtlas.tga")
    if args.preview:
        preview(atlas, args.preview)
