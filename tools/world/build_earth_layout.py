"""Builds the Earth layout: one pixel per 32 px ground tile.

    python tools/world/build_earth_layout.py

Outputs
  assets/world/earth_layout.png   biome of every tile (palette below)
  assets/world/earth_sky.png      the planet seen from the sky (SkyWorld),
                                  SKY_TILE px per tile, with relief
  world/earth_layout_data.gd      zones, landmarks and region placement
  (optional) --preview=<file>     an 8x enlarged colour preview

The geography is our own design: a main continent with a mountain wall and
snow to the north, the Rocky Wastes in its middle, a forested holy land to
the west across a strait, a southern continent and tropical islands in the
south-east sea, where Kame Island sits alone. Shapes are hand-placed
polygons roughened with deterministic noise, so re-running gives the same
map.
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

W, H = 208, 144
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

# Biome palette (exact colours, read back by world/earth_terrain.gd).
DEEP = (24, 64, 140)
SHALLOW = (62, 140, 212)
SAND = (232, 206, 140)
GRASS = (112, 172, 62)
FOREST = (42, 112, 44)
DIRT = (204, 152, 102)
MOUNTAIN = (132, 82, 52)
SNOW = (242, 246, 250)
RIVER = (84, 164, 232)
PATH = (184, 150, 100)
BRIDGE = (150, 98, 56)
CITY = (192, 192, 198)

# Region scenes placed in the world (top-left tile, size in tiles).
REGIONS = {
    "WestCityOutskirts": ((52, 66), (40, 22.5), CITY),
    "RockyWastes": ((92, 66), (40, 22.5), DIRT),
    "KameIsland": ((172, 86), (30, 17), None),
}

MAIN = [(44, 30), (60, 22), (80, 18), (100, 20), (118, 16), (140, 18), (160, 22), (172, 30),
        (178, 44), (171, 56), (177, 68), (173, 82), (162, 93), (150, 101), (138, 107), (122, 105),
        (110, 111), (96, 109), (84, 113), (72, 107), (58, 105), (49, 97), (45, 86), (47, 76),
        (42, 66), (46, 54), (40, 44)]
WEST = [(6, 40), (18, 33), (30, 37), (36, 50), (34, 64), (37, 78), (33, 96), (26, 112), (15, 119),
        (7, 108), (10, 90), (4, 74), (8, 58)]
SOUTH = [(62, 119), (80, 115), (100, 117), (118, 121), (125, 130), (113, 138), (90, 140), (70, 138),
         (58, 130)]
ISLETS = [(150, 118, 6, 3), (162, 127, 5, 3), (176, 121, 4, 3), (140, 129, 5, 2), (190, 110, 3, 2),
          (22, 24, 4, 2), (196, 60, 3, 4), (130, 8, 5, 2)]

NORTH_RANGE = [(50, 31), (70, 23), (96, 25), (118, 21), (140, 23), (164, 27), (168, 39), (150, 41),
               (130, 37), (112, 42), (96, 37), (78, 42), (60, 41)]
SNOW_CAPS = [(64, 25), (96, 23), (120, 19), (142, 20), (162, 24), (172, 31), (168, 35), (150, 33),
             (130, 30), (110, 32), (92, 30), (72, 31)]
EAST_RIDGE = [(158, 50), (167, 57), (166, 77), (159, 73), (155, 60)]
SOUTH_PEAKS = [(98, 94), (112, 92), (121, 100), (109, 104), (97, 102)]
WASTES = [(86, 55), (140, 51), (149, 64), (143, 96), (128, 101), (95, 99), (87, 90)]
FORESTS = [
    [(118, 44), (150, 43), (156, 56), (141, 62), (121, 57)],
    [(58, 44), (79, 46), (84, 57), (66, 61), (55, 54)],
    [(149, 78), (169, 80), (161, 92), (145, 90)],
    [(8, 44), (30, 40), (34, 62), (30, 92), (24, 108), (12, 110), (10, 80)],
]
# Water cut back into the land: bays, a gulf and an inland lake.
BAYS = [
    [(103, 116), (112, 99), (131, 101), (129, 117)],       # southern bay
    [(172, 60), (166, 64), (170, 70), (180, 68)],            # eastern gulf
    [(40, 98), (50, 92), (54, 100), (46, 106)],              # western cove
    [(100, 14), (106, 22), (112, 14)],                       # northern fjord
]
LAKE = (104, 52, 5, 3)
SOUTH_DESERT = [(72, 121), (110, 121), (117, 131), (96, 136), (74, 134)]
SOUTH_MOUNT = [(84, 124), (96, 122), (100, 130), (88, 132)]

RIVERS = [
    [(86, 38), (82, 47), (72, 53), (58, 58), (43, 60)],
    [(146, 41), (151, 55), (152, 70), (147, 84), (149, 97), (151, 106)],
    [(24, 40), (20, 58), (24, 72), (18, 90), (20, 112)],
]
PATHS = [
    [(72, 66), (72, 58), (70, 51)],             # West City -> Ginger Town
    [(132, 77), (144, 76), (156, 74), (166, 74)],  # wastes -> East City
    [(120, 89), (130, 94), (140, 98)],           # wastes -> Cell Games
    [(162, 62), (156, 70), (156, 74)],           # Mount Paozu trail
]

ZONES = [
    ("GINGER TOWN", [(64, 46), (78, 46), (78, 56), (64, 56)]),
    ("CELL GAMES ARENA", [(134, 93), (146, 93), (146, 103), (134, 103)]),
    ("NORTHERN MOUNTAINS", NORTH_RANGE),
    ("SNOWY HIGHLANDS", [(136, 16), (172, 24), (176, 36), (150, 36)]),
    ("HOLY LAND FOREST", WEST),
    ("SOUTHERN CONTINENT", SOUTH),
    ("TROPICAL ISLANDS", [(134, 112), (196, 104), (196, 134), (134, 134)]),
    ("EASTERN FOREST", FORESTS[2]),
    ("MOUNT PAOZU", EAST_RIDGE + [(150, 64)]),
    ("GREAT FOREST", FORESTS[0]),
    ("CENTRAL PLAINS", MAIN),
]

LANDMARKS = [
    ("West City", (72, 77), "city"),
    ("Capsule Corp", (80, 72), "capsule"),
    ("Rocky Wastes", (112, 77), "wastes"),
    ("Kame House", (187, 95), "kame"),
    ("Ginger Town", (70, 50), "town"),
    ("East City", (166, 74), "town"),
    ("Mount Paozu", (162, 62), "mountain"),
    ("Cell Games", (140, 98), "arena"),
    ("Korin Tower", (21, 74), "tower"),
    ("Snowy Highlands", (156, 27), "snow"),
    ("Tropical Islands", (162, 124), "island"),
    ("Southern Continent", (94, 128), "desert"),
]


def noise(scale, seed):
    """Smooth value noise in [-1, 1], size H x W."""
    rng = np.random.default_rng(seed)
    gw, gh = W // scale + 3, H // scale + 3
    grid = rng.uniform(-1, 1, (gh, gw)).astype(np.float32)
    img = Image.fromarray(((grid + 1) * 127.5).astype(np.uint8))
    img = img.resize((gw * scale, gh * scale), Image.BICUBIC).crop((0, 0, W, H))
    return np.asarray(img, dtype=np.float32) / 127.5 - 1.0


ROUGH = noise(9, 1) * 0.5 + noise(4, 2) * 0.35 + noise(2, 3) * 0.15


def shape(points, rough=0.38, blur=1.6):
    img = Image.new("L", (W, H), 0)
    ImageDraw.Draw(img).polygon(points, fill=255)
    img = img.filter(ImageFilter.GaussianBlur(blur))
    soft = np.asarray(img, dtype=np.float32) / 255.0
    return soft + ROUGH * rough > 0.5


def ellipse(cx, cy, rx, ry):
    img = Image.new("L", (W, H), 0)
    ImageDraw.Draw(img).ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=255)
    return np.asarray(img) > 0


def line(points, width):
    img = Image.new("L", (W, H), 0)
    ImageDraw.Draw(img).line(points, fill=255, width=width, joint="curve")
    return np.asarray(img) > 0


def region_mask(name, margin=0):
    (x, y), (w, h), _ = REGIONS[name]
    mask = np.zeros((H, W), bool)
    mask[int(y) - margin:int(math.ceil(y + h)) + margin, int(x) - margin:int(math.ceil(x + w)) + margin] = True
    return mask


def build():
    img = np.zeros((H, W, 3), np.uint8)
    img[:] = DEEP
    land = shape(MAIN) | shape(WEST) | shape(SOUTH, 0.18)
    for cx, cy, rx, ry in ISLETS:
        land |= ellipse(cx, cy, rx, ry) & (ROUGH > -0.5)
    for bay in BAYS:
        land &= ~shape(bay, 0.3, 1.2)
    lake = ellipse(*LAKE) & (ROUGH > -0.6)
    # The mainland regions always stand on solid ground.
    for name in ("WestCityOutskirts", "RockyWastes"):
        land |= region_mask(name, 3)
    kame = region_mask("KameIsland", 2)
    land &= ~kame

    # Shallow water two tiles around every coast.
    near = np.asarray(Image.fromarray((land * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5))) > 0
    img[near & ~land] = SHALLOW
    img[land] = GRASS
    coast = land & ~(np.asarray(Image.fromarray((land * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(3))) > 0)
    img[coast] = SAND

    def paint(mask, colour):
        img[mask & land & ~coast] = colour

    paint(shape(WASTES, 0.3), DIRT)
    paint(shape(SOUTH_DESERT, 0.3), DIRT)
    for forest in FORESTS:
        paint(shape(forest, 0.35), FOREST)
    paint(shape(NORTH_RANGE, 0.3), MOUNTAIN)
    paint(shape(EAST_RIDGE, 0.25, 1.5), MOUNTAIN)
    paint(shape(SOUTH_PEAKS, 0.25, 1.5), MOUNTAIN)
    paint(shape(SOUTH_MOUNT, 0.25, 1.5), MOUNTAIN)
    paint(shape(SNOW_CAPS, 0.3), SNOW)
    img[lake] = SHALLOW

    for river in RIVERS:
        paint(line(river, 2), RIVER)
    for path in PATHS:
        trail = line(path, 2) & land
        img[trail & np.all(img == RIVER, axis=2)] = BRIDGE
        img[trail & ~np.all(img == BRIDGE, axis=2)] = PATH

    # Region footprints (the region scenes draw the real ground there).
    for name, ((x, y), (w, h), colour) in REGIONS.items():
        if colour is not None:
            img[int(y):int(math.ceil(y + h)), int(x):int(x + w)] = colour
    # Kame Island: open sea with the island itself, for the sky map.
    kx, ky = REGIONS["KameIsland"][0]
    img[kame] = DEEP
    island = ellipse(kx + 14.8, ky + 8.8, 9.5, 6.0)
    img[ellipse(kx + 14.8, ky + 8.8, 11.5, 7.6) & ~island] = SHALLOW
    img[island] = SAND
    img[ellipse(kx + 14.8, ky + 8.6, 8.0, 4.8)] = GRASS
    return img


SKY_TILE = 6


def hash2(x, y):
    return abs((x * 73856093) ^ (y * 19349663)) % 1000003


def render_sky(img):
    """The planet seen from above: shaded relief, round tree tops, water
    that is lighter near the coast and sparkles far out."""
    code = {tuple(c): i for i, c in enumerate(
        [DEEP, SHALLOW, SAND, GRASS, FOREST, DIRT, MOUNTAIN, SNOW, RIVER, PATH, BRIDGE, CITY])}
    tiles = np.zeros((H, W), np.int16)
    for y in range(H):
        for x in range(W):
            tiles[y, x] = code.get(tuple(int(v) for v in img[y, x]), 3)
    water = (tiles == 0) | (tiles == 1)
    # Distance from land, in tiles (0 on land, up to 6).
    dist = np.where(water, 99, 0)
    for step in range(1, 7):
        grown = np.zeros_like(dist, bool)
        land_like = dist < step
        grown[1:, :] |= land_like[:-1, :]
        grown[:-1, :] |= land_like[1:, :]
        grown[:, 1:] |= land_like[:, :-1]
        grown[:, :-1] |= land_like[:, 1:]
        dist = np.where((dist == 99) & grown, step, dist)
    dist = np.minimum(dist, 6)

    def at(x, y):
        if 0 <= x < W and 0 <= y < H:
            return tiles[y, x]
        return 0

    S = SKY_TILE
    out = np.zeros((H * S, W * S, 3), np.uint8)
    near_sea, far_sea = np.array([76, 160, 222]), np.array([30, 78, 160])
    for ty in range(H):
        for tx in range(W):
            t = tiles[ty, tx]
            block = np.zeros((S, S, 3), np.float32)
            for py in range(S):
                for px in range(S):
                    x, y = tx * S + px, ty * S + py
                    grain = (hash2(x, y) % 100) / 100.0
                    if t in (0, 1):
                        depth = min(dist[ty, tx] / 5.0, 1.0)
                        c = near_sea * (1 - depth) + far_sea * depth
                        if grain > 0.985 and depth > 0.6:
                            c = c + (255 - c) * 0.35
                    elif t == 6:  # mountain relief
                        lit = at(tx - 1, ty) != 6 or at(tx, ty - 1) != 6
                        dark = at(tx + 1, ty) != 6 or at(tx, ty + 1) != 6
                        c = np.array(MOUNTAIN) * (1 - 0.08 * grain)
                        if lit and (px < 2 or py < 2):
                            c = np.array([178, 122, 78])
                        elif dark and (px > 3 or py > 3):
                            c = np.array([84, 50, 32])
                        elif (px + py + tx * 3 + ty) % 5 == 0:
                            c = c + (255 - c) * 0.12
                    elif t == 4:  # tree tops
                        cx = px - 2.5 + hash2(tx, ty) % 2
                        cy = py - 2.5
                        if cx * cx + cy * cy < 5.0:
                            c = np.array([34, 128, 46]) if cy >= -0.5 else np.array([66, 152, 76])
                        else:
                            c = np.array([26, 84, 34])
                    elif t == 7:
                        c = np.array([236, 242, 250]) if grain > 0.2 else np.array([196, 214, 236])
                    elif t == 11:  # city blocks
                        if px == 0 or py == 0:
                            c = np.array([120, 124, 134])
                        elif hash2(tx, ty) % 5 == 0 and px > 1 and py > 1:
                            c = np.array([88, 132, 200])  # a blue Capsule roof
                        else:
                            c = np.array([214, 216, 222]) if (px + py) % 5 else np.array([176, 180, 190])
                    elif t == 8:
                        c = np.array([88, 176, 236])
                    else:
                        base = np.array(img[ty, tx], np.float32)
                        c = base * (0.9 if grain > 0.7 else 1.0)
                    block[py, px] = c
            out[ty * S:(ty + 1) * S, tx * S:(tx + 1) * S] = np.clip(block, 0, 255).astype(np.uint8)
    return out


def render_clouds(out_dir):
    """Three soft pixel-art clouds for the sky layer (white, shaded below)."""
    rng = np.random.default_rng(7)
    for index in range(3):
        w, h = 72 + index * 12, 34 + index * 4
        alpha = np.zeros((h, w), np.float32)
        shade = np.zeros((h, w), np.float32)
        puffs = [(w * 0.5, h * 0.62, h * 0.38)]
        for _ in range(6 + index):
            puffs.append((rng.uniform(w * 0.2, w * 0.8), rng.uniform(h * 0.4, h * 0.65), rng.uniform(h * 0.18, h * 0.34)))
        yy, xx = np.mgrid[0:h, 0:w]
        for cx, cy, r in puffs:
            d = np.sqrt((xx - cx) ** 2 + ((yy - cy) * 1.2) ** 2)
            alpha = np.maximum(alpha, (d < r).astype(np.float32))
            shade = np.maximum(shade, ((d < r) & (yy > cy + r * 0.35)).astype(np.float32))
        img = np.zeros((h, w, 4), np.uint8)
        img[..., 0] = np.where(shade > 0, 206, 250)
        img[..., 1] = np.where(shade > 0, 220, 252)
        img[..., 2] = np.where(shade > 0, 240, 255)
        img[..., 3] = (alpha * 235).astype(np.uint8)
        Image.fromarray(img, "RGBA").save(os.path.join(out_dir, "sky_cloud_%d.png" % index))


def write_data():
    def gd(value):
        if isinstance(value, (list, tuple)) and len(value) == 2 and all(isinstance(v, (int, float)) for v in value):
            return "Vector2(%s, %s)" % (value[0], value[1])
        if isinstance(value, (list, tuple)):
            return "[" + ", ".join(gd(v) for v in value) + "]"
        return json.dumps(value)

    lines = [
        "# Generated by tools/world/build_earth_layout.py. Do not edit by hand.",
        "extends RefCounted",
        "",
        "const SIZE := Vector2i(%d, %d)" % (W, H),
        "const LAYOUT_PATH := \"res://assets/world/earth_layout.png\"",
        "const SKY_PATH := \"res://assets/world/earth_sky.png\"",
        "const SKY_TILE := %d" % SKY_TILE,
        "",
        "# Name -> polygon in tiles. The first zone containing a point wins.",
        "const ZONES := [",
    ]
    for name, points in ZONES:
        lines.append("\t[%s, %s]," % (json.dumps(name), gd(list(points))))
    lines += ["]", "", "# [name, tile, kind]", "const LANDMARKS := ["]
    for name, tile, kind in LANDMARKS:
        lines.append("\t[%s, %s, %s]," % (json.dumps(name), gd(tile), json.dumps(kind)))
    lines += ["]", "", "# Region scene -> [top-left tile, size in tiles]", "const REGIONS := {"]
    for name, (pos, size, _) in REGIONS.items():
        lines.append("\t%s: [%s, %s]," % (json.dumps(name), gd(pos), gd(size)))
    lines.append("}")
    with open(os.path.join(ROOT, "world", "earth_layout_data.gd"), "w", newline="\n") as f:
        f.write("\n".join(lines) + "\n")


def main():
    img = build()
    out = os.path.join(ROOT, "assets", "world")
    os.makedirs(out, exist_ok=True)
    Image.fromarray(img).save(os.path.join(out, "earth_layout.png"))
    Image.fromarray(render_sky(img)).save(os.path.join(out, "earth_sky.png"))
    render_clouds(out)
    write_data()
    for arg in sys.argv[1:]:
        if arg.startswith("--preview="):
            Image.fromarray(img).resize((W * 8, H * 8), Image.NEAREST).save(arg.split("=", 1)[1])
    print("earth layout", W, "x", H)


if __name__ == "__main__":
    main()
