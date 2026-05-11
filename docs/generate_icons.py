#!/usr/bin/env python3
"""
Generiert die In-App-Icons für die EMOM App.
Ausgabe: assets/icon/kettlebell.png und assets/icon/steelmace.png (256x256, transparent)
         assets/icon/icon.png (1024x1024, dunkler Hintergrund, App-Launcher-Quelle)

Ausführen aus dem Projektroot:
    python docs/generate_icons.py
"""
import zlib, struct, math, os

def make_png(filepath, W, H, bg_rgba, fg_rgba, draw_fn):
    img = bytearray(bg_rgba * W * H)

    def set_px(x, y):
        if 0 <= x < W and 0 <= y < H:
            i = (y * W + x) * 4
            img[i:i+4] = fg_rgba

    def fill_row(row, x1, x2):
        x1, x2 = max(0, x1), min(W, x2)
        if x1 < x2:
            row[x1*4:x2*4] = fg_rgba * (x2 - x1)

    draw_fn(W, H, img, set_px, fill_row)

    def chunk(tag, data):
        c = tag + data
        return struct.pack('>I', len(data)) + c + struct.pack('>I', zlib.crc32(c) & 0xffffffff)

    rows = bytearray()
    for y in range(H):
        rows += b'\x00' + bytes(img[y*W*4:(y+1)*W*4])

    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    with open(filepath, 'wb') as f:
        f.write(b'\x89PNG\r\n\x1a\n')
        f.write(chunk(b'IHDR', struct.pack('>IIBBBBB', W, H, 8, 6, 0, 0, 0)))
        f.write(chunk(b'IDAT', zlib.compress(bytes(rows), 6)))
        f.write(chunk(b'IEND', b''))
    print(f'Erstellt: {filepath}')


def draw_kettlebell(W, H, img, set_px, fill_row):
    """Kettlebell: Kugel unten, Bügel oben (skaliert auf W×H)."""
    s = W / 256
    ball_cx, ball_cy, ball_r = int(128*s), int(182*s), int(68*s)
    arch_cx, arch_cy         = int(128*s), int(82*s)
    arch_or, arch_ir         = int(46*s),  int(26*s)

    for y in range(H):
        row = bytearray(img[y*W*4:(y+1)*W*4])
        # Ball
        dy = y - ball_cy
        if abs(dy) <= ball_r:
            dx = int(math.sqrt(ball_r**2 - dy**2))
            fill_row(row, ball_cx - dx, ball_cx + dx + 1)
        # Bügel-Arch (obere Hälfte)
        if y <= arch_cy:
            dy_a = y - arch_cy
            d_max2 = arch_or**2 - dy_a**2
            if d_max2 >= 0:
                x_max = int(math.sqrt(d_max2))
                d_min2 = arch_ir**2 - dy_a**2
                x_min = int(math.sqrt(max(0, d_min2))) if d_min2 >= 0 else 0
                fill_row(row, arch_cx - x_max, arch_cx - x_min)
                fill_row(row, arch_cx + x_min, arch_cx + x_max + 1)
        # Schenkel
        if arch_cy <= y <= ball_cy:
            fill_row(row, arch_cx - arch_or, arch_cx - arch_ir)
            fill_row(row, arch_cx + arch_ir, arch_cx + arch_or + 1)
        img[y*W*4:(y+1)*W*4] = row


def draw_steelmace(W, H, img, set_px, fill_row):
    """Steel Mace: große Kugel oben-rechts, diagonaler Stiel, Griff unten-links."""
    s = W / 256
    ball_cx, ball_cy, ball_r = int(182*s), int(66*s),  int(46*s)
    tip_cx,  tip_cy          = int(44*s),  int(208*s)
    handle_half_w = max(1, int(9*s))
    grip_r        = max(1, int(13*s))

    dx = tip_cx - ball_cx
    dy = tip_cy - ball_cy
    length = math.sqrt(dx**2 + dy**2)
    ax, ay   = dx/length, dy/length
    px_v, py_v = -ay, ax

    for y in range(H):
        for x in range(W):
            if (x-ball_cx)**2 + (y-ball_cy)**2 <= ball_r**2:
                set_px(x, y); continue
            rx, ry  = x - ball_cx, y - ball_cy
            proj_a  = rx*ax + ry*ay
            proj_p  = rx*px_v + ry*py_v
            if ball_r <= proj_a <= length and abs(proj_p) <= handle_half_w:
                set_px(x, y); continue
            if (x-tip_cx)**2 + (y-tip_cy)**2 <= grip_r**2:
                set_px(x, y)


BASE = os.path.join(os.path.dirname(__file__), '..', 'assets', 'icon')
ORANGE = bytes([255, 107, 0, 255])
DARK   = bytes([13,  13, 13, 255])
TRANSP = bytes([0,   0,  0,  0  ])

# In-App-Icons (256×256, transparent)
make_png(os.path.join(BASE, 'kettlebell.png'), 256, 256, TRANSP, ORANGE, draw_kettlebell)
make_png(os.path.join(BASE, 'steelmace.png'), 256, 256, TRANSP, ORANGE, draw_steelmace)

# App-Launcher-Icon (1024×1024, dunkler Hintergrund)
make_png(os.path.join(BASE, 'icon.png'),      1024, 1024, DARK,  ORANGE, draw_kettlebell)
