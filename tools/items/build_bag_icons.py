"""Builds the 16x16 item icons used by the inventory (pixel art, no AA):
bags in assets/sprites/equipment/bags, the Senzu Bean in assets/sprites/items.

    python tools/items/build_bag_icons.py
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/sprites/equipment/bags"
ITEMS_OUT = ROOT / "assets/sprites/items"

# Each icon: palette + 16 rows. "." transparent.
ICONS = {
    "small_pouch": (
        {"o": (40, 24, 16), "b": (150, 96, 52), "h": (196, 140, 84), "s": (104, 62, 32), "c": (226, 196, 110)},
        [
            "................",
            "................",
            "................",
            "......oooo......",
            ".....occcco.....",
            "......obbo......",
            ".....obhhbo.....",
            "....obhhbbbo....",
            "...obhbbbbbso...",
            "...obbbbbbbso...",
            "...obbbbbbsso...",
            "...osbbbbssso...",
            "....osssssso....",
            ".....oooooo.....",
            "................",
            "................",
        ],
    ),
    "travel_bag": (
        {"o": (22, 30, 44), "b": (52, 104, 168), "h": (102, 156, 214), "s": (32, 64, 112), "y": (232, 196, 72), "w": (210, 214, 224)},
        [
            "................",
            ".....oooooo.....",
            "....oo....oo....",
            "....o......o....",
            "..oooooooooooo..",
            ".obhhhhhhhhhhbo.",
            ".obhbbbbbbbbbbo.",
            ".obbbbbyybbbbso.",
            ".oooooooooooooo.",
            ".obbbbbbbbbbbso.",
            ".obbwwwwwwwbbso.",
            ".obbbbbbbbbbbso.",
            ".obbbbbbbbbbsso.",
            ".ossssssssssssso",
            "..oooooooooooo..",
            "................",
        ],
    ),
    "capsule_case": (
        {"o": (30, 30, 36), "w": (236, 238, 244), "g": (170, 176, 190), "s": (112, 118, 132), "r": (214, 52, 44), "y": (246, 206, 60)},
        [
            "................",
            "................",
            "......oooo......",
            ".....o....o.....",
            "..oooooooooooo..",
            ".owwwwwwwwwwwgo.",
            ".owwwwwwwwwwwgo.",
            ".orrrrrrrrrrrro.",
            ".owwwwwoowwwwgo.",
            ".owwwwoyyowwwgo.",
            ".owwwwwoowwwwgo.",
            ".owwwwwwwwwwggo.",
            ".oggggggggggsso.",
            "..oooooooooooo..",
            "................",
            "................",
        ],
    ),
}


SENZU = (
    {"o": (20, 48, 20), "g": (84, 176, 64), "h": (168, 226, 120), "s": (44, 112, 40)},
    [
        "................",
        "................",
        "................",
        "......oooo......",
        ".....ohhggo.....",
        "....ohhgggso....",
        "....ohgggggso...",
        "....oggggggso...",
        ".....ogggggso...",
        "......oggggso...",
        "......oggggso...",
        ".....oggggsso...",
        ".....osssssso...",
        "......oooooo....",
        "................",
        "................",
    ],
)


def build(name, palette, rows, out=None):
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        assert len(row) == 16, (name, y, len(row), row)
        for x, ch in enumerate(row):
            if ch in palette:
                img.putpixel((x, y), palette[ch] + (255,))
    img.save((out or OUT) / f"{name}_icon.png")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for key, (palette, rows) in ICONS.items():
        build(key, palette, rows)
    ITEMS_OUT.mkdir(parents=True, exist_ok=True)
    build("senzu_bean", *SENZU, out=ITEMS_OUT)
    print("bag icons ->", OUT)
