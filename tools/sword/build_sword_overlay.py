"""Builds the sword overlay layers that are composited onto Goku at runtime.

Reference: Future Trunks' sword moves in Dragon Ball Z: The Legacy of Goku II
(spriters-resource sheet "Future Trunks", 32x32 cells, rows down/left/right/up):
  * horizontal sweep  - cols 33-35: sword raised behind the head, a wide
    elliptical sweep in front of the body, low follow-through.
  * thrust            - cols 15-17: blade levelled at chest height and driven
    straight forward with a bright edge.
  * leap slash        - cols 24-28: crouch, jump with the sword raised, apex,
    vertical crescent slash, landing with the blade extended.
  * draw              - col 23: sword lifted straight up with a glint.
  * sheath            - sword carried diagonally on the back, hilt over the
    shoulder.
Trunks' body cannot be reused on Goku, so each key frame is re-posed on the
closest HU2 Goku pose (Goku.dmi) and only the sword, scabbard and trails are
drawn here. The runtime (SwordAnimationLibrary) blends back layer + Goku body
+ front layer.

Usage (from the project root, Pillow required):
    python tools/sword/build_sword_overlay.py [--preview <png>]
"""

import json
import math
import re
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = ROOT / "assets" / "sprites" / "equipment" / "sword"
DMI_PATH = ROOT / "assets" / "sprites" / "characters" / "goku" / "hu2" / "Goku.dmi"

CELL = 48
ORIGIN = 8  # where the 32x32 body cell sits inside the 48x48 overlay cell
DIRECTIONS = ["down", "left", "right", "up"]

# Palette taken from Trunks' LoG II sword / scabbard.
BLADE_LIGHT = (222, 222, 230, 255)
BLADE_SHADE = (115, 115, 125, 255)
BLADE_TIP = (255, 255, 255, 255)
GUARD = (247, 198, 115, 255)
GUARD_DARK = (173, 123, 57, 255)
HILT = (132, 82, 24, 255)
HILT_DARK = (66, 33, 0, 255)
SCABBARD = (123, 49, 0, 255)
SCABBARD_LIGHT = (173, 74, 0, 255)
SCABBARD_CAP = (173, 173, 173, 255)
STRAP = (132, 82, 24, 255)
TRAIL = (255, 255, 255, 255)
TRAIL_INNER = (189, 222, 255, 255)

# Hand anchors (32x32 body coordinates) measured on the HU2 Goku frames.
HANDS = {
    ("Land", 0): {"down": (25, 11), "up": (5, 3), "right": (11, 7), "left": (21, 7)},
    ("kiblast", 0): {"down": (25, 17), "up": (8, 20), "right": (26, 18), "left": (5, 16)},
    ("Beam", 0): {"down": (15, 20), "up": (16, 15), "right": (26, 15), "left": (5, 16)},
    ("Guard", 0): {"down": (16, 19), "up": (10, 20), "right": (18, 17), "left": (13, 18)},
}


def frame(body, angle, layer, *, dy=0, length=13, trail=None, extra=None, duration=0.1, hand=None):
    return {
        "body": body,
        "angle": angle,
        "layer": layer,
        "dy": dy,
        "length": length,
        "trail": trail,
        "extra": extra or [],
        "duration": duration,
        "hand": hand,
    }


def ellipse(cx, cy, rx, ry, t0, t1, layer="front", width=2, alpha=1.0):
    return {"kind": "ellipse", "c": (cx, cy), "r": (rx, ry), "t": (t0, t1), "layer": layer, "width": width, "alpha": alpha}


def streak(points, layer="front", alpha=1.0):
    return {"kind": "streak", "points": points, "layer": layer, "alpha": alpha}


G = ("Guard", 0)
L = ("Land", 0)
K = ("kiblast", 0)
B = ("Beam", 0)

# ---------------------------------------------------------------------------
# Animations, per facing. Angles: degrees, 0 = screen right, 90 = screen down.
# ---------------------------------------------------------------------------
ANIMATIONS = {
    # Slash 1: horizontal sweep (Trunks cols 33-35).
    "sword_1": {
        "right": [
            frame(L, -160, "back", duration=0.08),
            frame(K, 15, "front", trail=ellipse(17, 20, 16, 7, 215, -5), duration=0.10),
            frame(K, 45, "front", trail=ellipse(17, 20, 16, 7, 80, -5, alpha=0.55), duration=0.10),
            frame(G, 70, "front", duration=0.14),
        ],
        "left": [
            frame(L, -20, "back", duration=0.08),
            frame(K, 165, "front", trail=ellipse(15, 20, 16, 7, -35, 185), duration=0.10),
            frame(K, 135, "front", trail=ellipse(15, 20, 16, 7, 100, 185, alpha=0.55), duration=0.10),
            frame(G, 110, "front", duration=0.14),
        ],
        "down": [
            frame(L, -45, "back", duration=0.08),
            frame(K, 120, "front", trail=ellipse(16, 21, 16, 7, -20, 200), duration=0.10),
            frame(K, 150, "front", trail=ellipse(16, 21, 16, 7, 110, 200, alpha=0.55), duration=0.10),
            frame(G, 135, "front", duration=0.14),
        ],
        "up": [
            frame(L, -135, "front", duration=0.08),
            frame(K, -150, "back", trail=ellipse(16, 15, 16, 7, 200, 380, layer="back"), duration=0.10),
            frame(K, -170, "back", trail=ellipse(16, 15, 16, 7, 290, 380, layer="back", alpha=0.55), duration=0.10),
            frame(G, -120, "back", duration=0.14),
        ],
    },
    # Slash 2: thrust (Trunks cols 15-17).
    "sword_2": {
        "right": [
            frame(G, -15, "front", duration=0.08),
            frame(B, 0, "front", length=16, trail=streak([(4, 13, 20), (8, 16, 22), (2, 19, 18)]), extra=["glint"], duration=0.12),
            frame(K, 8, "front", length=15, duration=0.10),
            frame(G, 35, "front", duration=0.12),
        ],
        "left": [
            frame(G, 195, "front", duration=0.08),
            frame(B, 180, "front", length=16, trail=streak([(12, 14, 28), (10, 17, 24), (14, 20, 30)]), extra=["glint"], duration=0.12),
            frame(K, 172, "front", length=15, duration=0.10),
            frame(G, 145, "front", duration=0.12),
        ],
        "down": [
            frame(G, 60, "front", length=11, duration=0.08),
            frame(B, 88, "front", length=10, extra=["glint"], duration=0.12),
            frame(B, 92, "front", length=10, duration=0.10),
            frame(G, 120, "front", length=11, duration=0.12),
        ],
        "up": [
            frame(G, -60, "back", length=11, duration=0.08),
            frame(K, -88, "back", length=12, hand=(16, 14), extra=["glint"], duration=0.12),
            frame(K, -92, "back", length=12, hand=(16, 14), duration=0.10),
            frame(G, -120, "back", length=11, duration=0.12),
        ],
    },
    # Slash 3 / finisher: leap and vertical slash (Trunks cols 24-28).
    "sword_3": {
        "right": [
            frame(G, 160, "back", dy=1, duration=0.08),
            frame(L, -150, "back", dy=-4, duration=0.08),
            frame(L, -95, "front", dy=-6, duration=0.08),
            frame(B, 60, "front", dy=-2, trail=ellipse(16, 13, 15, 15, -100, 62, width=3), duration=0.12),
            frame(K, 35, "front", trail=ellipse(16, 13, 15, 15, 0, 62, alpha=0.5), extra=["dust"], duration=0.18),
        ],
        "left": [
            frame(G, 20, "back", dy=1, duration=0.08),
            frame(L, -30, "back", dy=-4, duration=0.08),
            frame(L, -85, "front", dy=-6, duration=0.08),
            frame(B, 120, "front", dy=-2, trail=ellipse(16, 13, 15, 15, 280, 118, width=3), duration=0.12),
            frame(K, 145, "front", trail=ellipse(16, 13, 15, 15, 180, 118, alpha=0.5), extra=["dust"], duration=0.18),
        ],
        "down": [
            frame(G, 135, "back", dy=1, duration=0.08),
            frame(L, -60, "back", dy=-4, duration=0.08),
            frame(L, -90, "back", dy=-6, duration=0.08),
            frame(B, 90, "front", dy=-2, trail=streak([(16, -6, 16, 30)], alpha=1.0), duration=0.12),
            frame(B, 90, "front", trail=streak([(16, 18, 16, 31)], alpha=0.5), extra=["dust"], duration=0.18),
        ],
        "up": [
            frame(G, -45, "back", dy=1, duration=0.08),
            frame(L, -120, "front", dy=-4, duration=0.08),
            frame(L, -90, "front", dy=-6, hand=(16, 2), duration=0.08),
            frame(K, -90, "back", dy=-2, hand=(16, 12), trail=streak([(16, -8, 16, 12)], layer="back"), duration=0.12),
            frame(K, -90, "back", hand=(16, 12), extra=["dust"], duration=0.18),
        ],
    },
    # Equip: draw the sword and raise it (Trunks col 23).
    "sword_equip": {
        "right": [frame(L, -80, "front", duration=0.12), frame(L, -80, "front", extra=["glint_tip"], duration=0.22)],
        "left": [frame(L, -100, "front", duration=0.12), frame(L, -100, "front", extra=["glint_tip"], duration=0.22)],
        "down": [frame(L, -80, "front", duration=0.12), frame(L, -80, "front", extra=["glint_tip"], duration=0.22)],
        "up": [frame(L, -100, "front", duration=0.12), frame(L, -100, "front", extra=["glint_tip"], duration=0.22)],
    },
}

# Scabbard on the back: (hip anchor, angle pointing to the hilt, layer).
SHEATHS = {
    "right": ((15, 23), -118, "back"),
    "left": ((17, 23), -62, "back"),
    "down": ((4, 26), -27, "back"),
    "up": ((25, 24), -132, "front"),
}
# Horizontal "fly" pose (HU2): the back faces the top of the screen, so the
# scabbard lies along it with the hilt past the shoulder, towards the head.
# Torso top edge of the right-facing fly frame is body y=19, x 7..17 (same
# body coordinates as SHEATHS); the left pose is its mirror (x' = 31 - x).
FLY_SHEATHS = {
    "fly_right": ((6, 19), -9, "front"),
    "fly_left": ((25, 19), -171, "front"),
}
FLY_SHEATH_LENGTH = 12


# ---------------------------------------------------------------------------
# Raster helpers
# ---------------------------------------------------------------------------
def put(img, x, y, color, alpha=1.0):
    x = int(round(x)) + ORIGIN
    y = int(round(y)) + ORIGIN
    if 0 <= x < CELL and 0 <= y < CELL:
        r, g, b, a = color
        a = int(a * alpha)
        if a <= 0:
            return
        if a >= 255:
            img.putpixel((x, y), (r, g, b, 255))
            return
        base = img.getpixel((x, y))
        out_a = a + base[3] * (255 - a) // 255
        if out_a == 0:
            return
        mix = lambda c0, c1: (c1 * a + c0 * base[3] * (255 - a) // 255) // out_a
        img.putpixel((x, y), (mix(base[0], r), mix(base[1], g), mix(base[2], b), out_a))


def line_points(x0, y0, x1, y1):
    steps = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
    pts = []
    for i in range(steps + 1):
        t = i / max(steps, 1)
        p = (round(x0 + (x1 - x0) * t), round(y0 + (y1 - y0) * t))
        if not pts or pts[-1] != p:
            pts.append(p)
    return pts


def draw_line(img, a, b, color, alpha=1.0):
    for x, y in line_points(a[0], a[1], b[0], b[1]):
        put(img, x, y, color, alpha)


def draw_sword(img, hand, angle, length):
    d = (math.cos(math.radians(angle)), math.sin(math.radians(angle)))
    n = (-d[1], d[0])
    hx, hy = hand
    # Hilt behind the fist, guard at the fist, blade forward.
    draw_line(img, (hx - d[0] * 3, hy - d[1] * 3), (hx, hy), HILT)
    put(img, hx - d[0] * 3, hy - d[1] * 3, HILT_DARK)
    gx, gy = hx + d[0] * 1.5, hy + d[1] * 1.5
    draw_line(img, (gx - n[0] * 2, gy - n[1] * 2), (gx + n[0] * 2, gy + n[1] * 2), GUARD)
    put(img, gx + n[0] * 2, gy + n[1] * 2, GUARD_DARK)
    start = (hx + d[0] * 2.5, hy + d[1] * 2.5)
    end = (hx + d[0] * (2.5 + length), hy + d[1] * (2.5 + length))
    shade_side = 1 if n[1] >= 0 else -1
    draw_line(img, (start[0] + n[0] * shade_side, start[1] + n[1] * shade_side),
              (end[0] - d[0] + n[0] * shade_side, end[1] - d[1] + n[1] * shade_side), BLADE_SHADE)
    draw_line(img, start, end, BLADE_LIGHT)
    put(img, end[0], end[1], BLADE_TIP)
    return end


def draw_sheath(back, front, hip, angle, layer, with_sword, length=17):
    """Scabbard on `layer`; the hilt always peeks over the shoulder (front)."""
    target = front if layer == "front" else back
    d = (math.cos(math.radians(angle)), math.sin(math.radians(angle)))
    n = (-d[1], d[0])
    hx, hy = hip
    top = (hx + d[0] * length, hy + d[1] * length)
    draw_line(target, (hx - n[0], hy - n[1]), (top[0] - n[0], top[1] - n[1]), HILT_DARK)
    draw_line(target, (hx + n[0], hy + n[1]), (top[0] + n[0], top[1] + n[1]), SCABBARD)
    draw_line(target, hip, top, SCABBARD_LIGHT)
    for k in (-1, 0, 1):
        put(target, hx + n[0] * k, hy + n[1] * k, SCABBARD_CAP)
    mouth = (top[0] + d[0], top[1] + d[1])
    for k in (-1, 0, 1):
        put(front if with_sword else target, mouth[0] + n[0] * k, mouth[1] + n[1] * k, GUARD_DARK if not with_sword else SCABBARD_CAP)
    if with_sword:
        gx, gy = top[0] + d[0] * 2, top[1] + d[1] * 2
        draw_line(front, (gx - n[0] * 2, gy - n[1] * 2), (gx + n[0] * 2, gy + n[1] * 2), GUARD)
        put(front, gx + n[0] * 2, gy + n[1] * 2, GUARD_DARK)
        hilt_end = (gx + d[0] * 5, gy + d[1] * 5)
        draw_line(front, (gx + d[0], gy + d[1]), hilt_end, HILT)
        put(front, hilt_end[0], hilt_end[1], HILT_DARK)


def draw_trail(img, trail, alpha_scale=1.0):
    alpha = trail.get("alpha", 1.0) * alpha_scale
    if trail["kind"] == "ellipse":
        (cx, cy), (rx, ry), (t0, t1) = trail["c"], trail["r"], trail["t"]
        steps = int(abs(t1 - t0) / 3) + 2
        for i in range(steps + 1):
            u = i / steps
            t = math.radians(t0 + (t1 - t0) * u)
            # Thicker and brighter towards the leading edge (the sword).
            fade = 0.6 + 0.4 * u
            for w in range(trail["width"]):
                inner = w / max(trail["width"], 1)
                color = TRAIL if (w == 0 or u > 0.55) else TRAIL_INNER
                if u < 0.25 and w > 0:
                    continue
                put(img, cx + (rx - w) * math.cos(t), cy + (ry - w * ry / max(rx, 1)) * math.sin(t), color, alpha * fade * (1 - inner * 0.3))
    elif trail["kind"] == "streak":
        for pts in trail["points"]:
            if len(pts) == 3:  # horizontal speed line: (x0, y, x1)
                x0, y, x1 = pts
                for x, yy in line_points(x0, y, x1, y):
                    u = (x - min(x0, x1)) / max(abs(x1 - x0), 1)
                    put(img, x, yy, TRAIL if u > 0.5 else TRAIL_INNER, alpha * (0.3 + 0.7 * u))
            else:  # vertical slash line: (x, y0, x1, y1)
                x0, y0, x1, y1 = pts
                for x, y in line_points(x0, y0, x1, y1):
                    put(img, x, y, TRAIL, alpha)
                    put(img, x + 1, y, TRAIL_INNER, alpha * 0.6)


def draw_extra(img, kind, tip, hand):
    if kind in ("glint", "glint_tip"):
        x, y = tip
        for dx, dy, a in [(0, 0, 1), (1, 0, .8), (-1, 0, .8), (0, 1, .8), (0, -1, .8), (2, 0, .4), (-2, 0, .4), (0, 2, .4), (0, -2, .4)]:
            put(img, x + dx, y + dy, TRAIL, a)
    elif kind == "dust":
        for dx, dy in [(-6, 30), (-4, 29), (6, 30), (4, 29), (-8, 31), (8, 31)]:
            put(img, 16 + dx, dy, (222, 206, 173, 255), 0.7)


def render():
    sheet_frames = []  # list of (back, front) images
    manifest = {"cell": CELL, "origin": ORIGIN, "animations": {}, "sheath": {}}

    def add_cells(back, front):
        sheet_frames.append(back)
        sheet_frames.append(front)
        return len(sheet_frames) - 2

    for name, per_dir in ANIMATIONS.items():
        anim = {}
        for facing in DIRECTIONS:
            frames = []
            for f in per_dir[facing]:
                back = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
                front = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
                hand = f["hand"] or HANDS[f["body"]][facing]
                hand = (hand[0], hand[1] + f["dy"])
                target = front if f["layer"] == "front" else back
                if f["trail"]:
                    t = dict(f["trail"])
                    if f["dy"] and t["kind"] == "ellipse":
                        t["c"] = (t["c"][0], t["c"][1] + f["dy"])
                    draw_trail(front if t.get("layer", "front") == "front" else back, t)
                tip = draw_sword(target, hand, f["angle"], f["length"])
                for extra in f["extra"]:
                    draw_extra(front, extra, tip, hand)
                index = add_cells(back, front)
                frames.append({
                    "state": f["body"][0],
                    "frame": f["body"][1],
                    "dy": f["dy"],
                    "cell": index,
                    "duration": f["duration"],
                })
            anim[facing] = frames
        manifest["animations"][name] = anim

    for variant, with_sword in (("sheath", True), ("sheath_empty", False)):
        manifest["sheath"][variant] = {}
        for facing in DIRECTIONS:
            hip, angle, layer = SHEATHS[facing]
            back = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
            front = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
            draw_sheath(back, front, hip, angle, layer, with_sword, 20 if facing == "down" else 17)
            if facing == "down":
                # Strap across the chest, as on Trunks' front view.
                draw_line(front, (12, 15), (19, 21), STRAP)
            manifest["sheath"][variant][facing] = add_cells(back, front)
        for key, (hip, angle, layer) in FLY_SHEATHS.items():
            back = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
            front = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
            draw_sheath(back, front, hip, angle, layer, with_sword, FLY_SHEATH_LENGTH)
            manifest["sheath"][variant][key] = add_cells(back, front)

    columns = 16
    rows = (len(sheet_frames) + columns - 1) // columns
    sheet = Image.new("RGBA", (columns * CELL, rows * CELL), (0, 0, 0, 0))
    for i, img in enumerate(sheet_frames):
        sheet.paste(img, ((i % columns) * CELL, (i // columns) * CELL))
    manifest["columns"] = columns
    return sheet, manifest


def render_icon():
    icon = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    big = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    draw_sword(big, (4, 11), -45, 9)
    icon.paste(big.crop((ORIGIN, ORIGIN, ORIGIN + 16, ORIGIN + 16)), (0, 0))
    return icon


def render_rack(with_sword):
    """Wall rack for Kame House: wooden board, two pegs, sheathed sword."""
    rack = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    wood, wood_dark, wood_light = (173, 107, 49, 255), (123, 49, 0, 255), (222, 173, 99, 255)
    # Coordinates are body-cell based (ORIGIN offset is applied by put()).
    for x in range(-6, 38):
        put(rack, x, 6, wood_light)
        put(rack, x, 7, wood)
        put(rack, x, 8, wood)
        put(rack, x, 9, wood_dark)
    for px in (2, 28):
        for y in range(10, 15):
            put(rack, px, y, wood_dark)
            put(rack, px + 1, y, wood)
    if with_sword:
        back = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
        draw_sheath(back, back, (-2, 13), 0, "back", True, length=28)
        rack.alpha_composite(back)
    return rack.crop((ORIGIN - 6, ORIGIN + 4, ORIGIN + 38, ORIGIN + 18))


def load_dmi_bodies():
    im = Image.open(DMI_PATH)
    desc = im.info["Description"]
    im = im.convert("RGBA")
    icons = {}
    idx = 0
    for blk in re.split(r"\nstate = ", desc)[1:]:
        n = re.match(r'"(.*)"', blk).group(1)
        d = int(re.search(r"dirs = (\d+)", blk).group(1))
        f = int(re.search(r"frames = (\d+)", blk).group(1))
        icons.setdefault(n, (idx, d, f))
        idx += d * f
    cols = im.width // 32
    order = {"down": 0, "up": 1, "right": 2, "left": 3}

    def body(state, fr, facing):
        i, d, _ = icons[state]
        ic = i + fr * d + order[facing]
        return im.crop(((ic % cols) * 32, (ic // cols) * 32, (ic % cols) * 32 + 32, (ic // cols) * 32 + 32))

    return body


def preview(sheet, manifest, path):
    body = load_dmi_bodies()
    cols = manifest["columns"]

    def cell(i):
        return sheet.crop(((i % cols) * CELL, (i // cols) * CELL, (i % cols) * CELL + CELL, (i // cols) * CELL + CELL))

    rows = []
    for name, anim in manifest["animations"].items():
        for facing in DIRECTIONS:
            row = []
            for f in anim[facing]:
                img = Image.new("RGBA", (CELL, CELL), (60, 120, 90, 255))
                img.alpha_composite(cell(f["cell"]))
                img.alpha_composite(body(f["state"], f["frame"], facing), (ORIGIN, ORIGIN + f["dy"]))
                img.alpha_composite(cell(f["cell"] + 1))
                row.append(img)
            rows.append(row)
    for variant in ("sheath", "sheath_empty"):
        row = []
        for facing in DIRECTIONS:
            i = manifest["sheath"][variant][facing]
            img = Image.new("RGBA", (CELL, CELL), (60, 120, 90, 255))
            img.alpha_composite(cell(i))
            img.alpha_composite(body("", 0, facing), (ORIGIN, ORIGIN))
            img.alpha_composite(cell(i + 1))
            row.append(img)
        for key in FLY_SHEATHS:
            i = manifest["sheath"][variant][key]
            img = Image.new("RGBA", (CELL, CELL), (60, 120, 90, 255))
            img.alpha_composite(cell(i))
            img.alpha_composite(body("fly", 0, key[4:]), (ORIGIN, ORIGIN))
            img.alpha_composite(cell(i + 1))
            row.append(img)
        rows.append(row)
    width = max(len(r) for r in rows)
    zoom = 4
    out = Image.new("RGBA", (width * CELL * zoom, len(rows) * CELL * zoom), (30, 30, 30, 255))
    for y, r in enumerate(rows):
        for x, img in enumerate(r):
            out.paste(img.resize((CELL * zoom, CELL * zoom), Image.NEAREST), (x * CELL * zoom, y * CELL * zoom))
    out.save(path)


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    sheet, manifest = render()
    sheet.save(OUT_DIR / "sword_overlay.png")
    (OUT_DIR / "sword_overlay.json").write_text(json.dumps(manifest, indent=1), encoding="utf-8")
    render_icon().save(OUT_DIR / "sword_icon.png")
    render_rack(True).save(OUT_DIR / "sword_rack_full.png")
    render_rack(False).save(OUT_DIR / "sword_rack_empty.png")
    if "--preview" in sys.argv:
        preview(sheet, manifest, sys.argv[sys.argv.index("--preview") + 1])
    print("sword overlay:", len(manifest["animations"]), "animations")


if __name__ == "__main__":
    main()
