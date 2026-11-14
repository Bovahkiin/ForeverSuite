"""Render the Azeroth Heritage textures and the documentation preview."""
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
THEMES = ROOT / 'Assets' / 'Themes'
GOLD = '#d7aa67'
IVORY = '#f2e4ce'


def frame(button=False):
    size = 512
    image = Image.new('RGBA', (size, size))
    pixels = image.load()
    cut = 36 if button else 29
    for y in range(size):
        vertical = min(y, size - 1 - y)
        for x in range(size):
            horizontal = min(x, size - 1 - x)
            edge = min(horizontal, vertical, (horizontal + vertical - cut) * .7071)
            if edge < 0:
                continue
            grain = ((x * 17 + y * 41) ^ (x * 137 + y * 67)) % 7 - 3
            light = 11 if y < size / 2 else -9
            if edge < 4:
                color = (17, 12, 9)
            elif edge < 9:
                color = (104 + light, 75 + light, 43 + light)
            elif edge < 15:
                color = (187 + light, 140 + light, 79 + light)
            elif edge < 20:
                color = (98, 64, 34)
            elif edge < 23:
                color = (145, 105, 59)
            elif edge < 29:
                color = (23, 16, 15)
            elif edge < 34:
                color = (78, 54, 34)
            elif button:
                warmth = 16 * (1 - y / size) + 5 * math.sin(math.pi * y / size)
                bevel = max(0, 40 - edge)
                color = (51 + warmth + bevel, 23 + warmth / 2 + bevel, 25 + warmth / 2)
            else:
                light = 8 * (1 - y / size) + 5 * math.sin(math.pi * x / size)
                inset = min(4, max(0, 43 - edge))
                color = (23 + light - inset, 28 + light - inset, 34 + light - inset)
            pixels[x, y] = (*(round(channel + grain / 2) for channel in color), 255)

    if not button:
        draw = ImageDraw.Draw(image)
        for right, bottom in ((False, False), (True, False), (False, True), (True, True)):
            def corner(points):
                return [(size - 1 - x if right else x, size - 1 - y if bottom else y) for x, y in points]

            draw.line(corner([(38, 77), (38, 52), (52, 38), (77, 38)]), '#7c5b3f', width=4)
            draw.line(corner([(45, 70), (45, 55), (55, 45), (70, 45)]), '#5b4535', width=3)
            draw.polygon(corner([(44, 51), (51, 44), (58, 51), (51, 58)]), '#ba8c57')
            draw.polygon(corner([(46, 51), (51, 46), (56, 51), (51, 56)]), '#60999f')
    return image


def waypoint():
    image = Image.new('RGBA', (256, 256))
    draw = ImageDraw.Draw(image)
    outline = [(128, 22), (222, 185), (186, 177), (160, 158), (128, 229),
               (96, 158), (70, 177), (34, 185)]
    draw.polygon(outline, '#1c1110')
    draw.polygon([(128, 32), (209, 175), (185, 169), (156, 148), (128, 215),
                  (100, 148), (71, 169), (47, 175)], '#946139')
    draw.polygon([(128, 39), (198, 166), (181, 160), (149, 138), (128, 199),
                  (107, 138), (75, 160), (58, 166)], GOLD)
    draw.polygon([(128, 45), (128, 187), (111, 128), (73, 151)], '#f1d18d')
    draw.polygon([(128, 45), (184, 151), (145, 128), (128, 187)], '#ac794b')
    draw.polygon([(128, 79), (147, 125), (128, 164), (109, 125)], '#24353b')
    draw.polygon([(128, 93), (139, 125), (128, 150), (117, 125)], '#6ca4ad')
    draw.polygon([(128, 93), (128, 150), (117, 125)], '#afcfd0')
    return image


def nine_slice(texture, size, border):
    image = Image.new('RGBA', size)
    width, height = size
    cut = round(texture.width * .18)
    source = (0, cut, texture.width - cut, texture.width)
    x_edges, y_edges = (0, border, width - border, width), (0, border, height - border, height)
    for y in range(3):
        for x in range(3):
            piece = texture.crop((source[x], source[y], source[x + 1], source[y + 1]))
            piece = piece.resize((x_edges[x + 1] - x_edges[x], y_edges[y + 1] - y_edges[y]),
                                 Image.Resampling.LANCZOS)
            image.paste(piece, (x_edges[x], y_edges[y]))
    return image


def preview(panel, button, arrow):
    image = Image.new('RGBA', (1024, 640), '#101318')
    draw = ImageDraw.Draw(image)
    face = ROOT / 'Assets' / 'Arial-Bold.ttf'
    title = ImageFont.truetype(str(face), 60)
    label = ImageFont.truetype(str(face), 20)
    body = ImageFont.truetype(str(face), 23)

    draw.text((64, 53), 'ForeverSuite', fill=GOLD, font=label)
    draw.text((59, 89), 'Azeroth Heritage', fill=IVORY, font=title)
    draw.line((64, 187, 960, 187), fill='#8a6a45', width=2)
    image.alpha_composite(nine_slice(panel, (896, 325), 32), (64, 234))
    draw.text((101, 267), 'Quest objectives', fill=GOLD, font=body)
    draw.text((101, 322), 'Return to Valanaar', fill=IVORY, font=label)
    draw.text((101, 353), 'Speak with the quartermaster', fill='#bbc4cd', font=label)
    draw.line((101, 405, 455, 405), fill='#524434', width=2)
    for x, text in ((101, 'Quest Log'), (291, 'Open Map')):
        image.alpha_composite(nine_slice(button, (172, 54), 12), (x, 451))
        draw.text((x + 86, 478), text, fill=IVORY, font=label, anchor='mm')
    draw.line((550, 275, 550, 517), fill='#66523c', width=2)
    image.alpha_composite(arrow.resize((132, 132), Image.Resampling.LANCZOS), (683, 307))
    draw.text((749, 475), 'Waypoint', fill=IVORY, font=label, anchor='mm')
    return image


def main():
    panel, button, arrow = frame(), frame(button=True), waypoint()
    sample = preview(panel, button, arrow)
    sheet = Image.new('RGBA', (1024, 1024))
    sheet.paste(sample, (0, 0))
    for name, image in (('Panel', panel), ('Button', button), ('Arrow', arrow), ('Preview', sheet)):
        image.save(THEMES / f'11-{name}.tga')
    sample.convert('RGB').save(ROOT / '.previews' / '03-azeroth-heritage.png', optimize=True)


if __name__ == '__main__':
    main()
