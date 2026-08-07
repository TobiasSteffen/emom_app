#!/usr/bin/env python3
"""
Konvertiert Foto-artige Uebungs-Icons (orange Figur auf hellem Hintergrund,
z.B. aus einem Bildgenerator) in transparente 256x256-Glyphen im Stil der
uebrigen In-App-Icons (kettlebell.png, liegestuetz.png, ...).

Quelle:  docs/assets_source/*_source.{png,jpg}
Ausgabe: assets/icon/<name>.png (256x256, transparent)

Alpha wird aus der 'Buntheit' (max(R,G,B) - min(R,G,B)) pro Pixel abgeleitet:
Hintergrund und Schlagschatten sind neutral-grau (Buntheit ~0), die orange
Figur ist stark gesaettigt (Buntheit hoch). RGB wird fuer ALLE Pixel auf die
Akzentfarbe gesetzt, damit beim Verkleinern keine hellen Halo-Raender an den
Kanten entstehen (die App tintet das Icon ohnehin per BlendMode.srcIn, RGB
ist im Ergebnis also irrelevant — siehe EquipmentIconGrid).

Ausfuehren aus dem Projektroot:
    python docs/generate_exercise_glyphs.py
"""
import os
from PIL import Image

BASE = os.path.dirname(__file__)
SRC = os.path.join(BASE, 'assets_source')
DST = os.path.join(BASE, '..', 'assets', 'icon')

ORANGE = (255, 107, 0)
LOW, HIGH = 15, 140  # Buntheit-Rampe: darunter transparent, darueber opak

JOBS = [
    ('dehnen_source.jpg', 'dehnen.png'),
    ('kniebeuge_source.png', 'kniebeuge.png'),
    ('plank_source.png', 'plank.png'),
]


def colorfulness_alpha(im):
    im = im.convert('RGB')
    w, h = im.size
    px = im.load()
    out = Image.new('RGBA', (w, h))
    opx = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            c = max(r, g, b) - min(r, g, b)
            a = 0 if c <= LOW else 255 if c >= HIGH else int((c - LOW) * 255 / (HIGH - LOW))
            opx[x, y] = (*ORANGE, a)
    return out


def bbox_with_margin(im, margin_frac=0.12):
    bbox = im.getbbox()
    l, t, r, b = bbox
    side = int(max(r - l, b - t) * (1 + 2 * margin_frac))
    cx, cy = (l + r) / 2, (t + b) / 2
    half = side / 2
    return (cx - half, cy - half, cx + half, cy + half)


def process(src_name, dst_name, size=256):
    im = Image.open(os.path.join(SRC, src_name))
    glyph = colorfulness_alpha(im)
    l, t, r, b = bbox_with_margin(glyph)
    pad = int(max(glyph.width, glyph.height) * 0.5)
    canvas = Image.new('RGBA', (glyph.width + 2 * pad, glyph.height + 2 * pad), (0, 0, 0, 0))
    canvas.paste(glyph, (pad, pad), glyph)
    crop = canvas.crop((l + pad, t + pad, r + pad, b + pad))
    result = crop.resize((size, size), Image.LANCZOS)
    dst_path = os.path.join(DST, dst_name)
    result.save(dst_path)
    print(f'Erstellt: {dst_path}')


if __name__ == '__main__':
    for src_name, dst_name in JOBS:
        process(src_name, dst_name)
