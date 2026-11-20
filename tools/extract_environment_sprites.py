"""Extract visually reviewed LoG2 props from the local furniture sheet.

Only the two exact checkerboard colors are keyed out. Sprite pixels are not
rescaled/repainted. Original source hash, rectangles and sheet credit are saved.
"""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = Path('C:/spriters-resource-downloader/Spriters-Resource-Downloader-v2.7-unofficial/downloaded/game_boy_advance/dbzlog2/Objects/Furniture__232446.png')
RECTS = {
    'bed': (376, 112, 40, 64),
    'tv': (416, 184, 48, 64),
    'fridge': (696, 8, 24, 48),
    'table': (320, 312, 48, 56),
    'sofa': (832, 112, 40, 64),
    'coffee_table': (200, 400, 48, 32),
    'terminal': (776, 192, 48, 56),
    'beach_chair': (960, 224, 48, 32),
    'wooden_table': (712, 264, 48, 64),
    'recovery_pod': (776, 784, 32, 88),
    'house_plant': (216, 536, 40, 40),
    'bookshelf': (200, 8, 48, 64),
    'shelf': (8, 8, 48, 64),
    'rug': (8, 112, 64, 56),
    'west_city_sign': (440, 448, 40, 40),
}
KEYS = {(172, 0, 205), (116, 0, 136)}
# The neighboring umbrella pole intrudes into the chair's rectangular crop.
EXCLUDED = {'beach_chair': [(32, 0, 8, 16)]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=DEFAULT_SOURCE)
    parser.add_argument('--terrain-source', type=Path, default=DEFAULT_SOURCE.parent.parent / 'Backgrounds/Northern Wastelands__159968.png')
    args = parser.parse_args()
    sheet = Image.open(args.source).convert('RGBA')
    output = ROOT / 'assets/sprites/environment/gba_furniture'
    output.mkdir(parents=True, exist_ok=True)
    entries = []
    for name, rect in RECTS.items():
        x, y, width, height = rect
        assert x + width <= sheet.width and y + height <= sheet.height
        crop = sheet.crop((x, y, x + width, y + height))
        crop.putdata([(0, 0, 0, 0) if pixel[:3] in KEYS else pixel for pixel in crop.getdata()])
        for ex, ey, ew, eh in EXCLUDED.get(name, []):
            crop.paste((0, 0, 0, 0), (ex, ey, ex + ew, ey + eh))
        bounds = crop.getbbox()
        assert bounds, name
        crop = crop.crop(bounds)
        crop.save(output / (name + '.png'))
        entries.append({'name': name, 'source_rect': rect, 'excluded_local_rects': EXCLUDED.get(name, []), 'alpha_trim': bounds, 'size': crop.size})
    manifest = {'source': str(args.source), 'sha256': hashlib.sha256(args.source.read_bytes()).hexdigest(),
                'credit_on_sheet': 'Dragon Ball Z: The Legacy of Goku II — ripped by SPYN',
                'transparent_colors': sorted(KEYS), 'sprites': entries}
    (output / 'sources.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    terrain = Image.open(args.terrain_source).convert('RGBA')
    terrain.crop((288, 864, 320, 896)).save(output / 'wastes_ground.png')
    terrain_manifest = {'source': str(args.terrain_source), 'sha256': hashlib.sha256(args.terrain_source.read_bytes()).hexdigest(),
                        'source_rect': [288, 864, 32, 32], 'credit_on_sheet': 'Ripped by DrApollo', 'processing': 'Exact crop, no color changes'}
    (output / 'terrain_source.json').write_text(json.dumps(terrain_manifest, indent=2) + '\n', encoding='utf-8')
    print(f'Extracted {len(entries)} props: {output}')


if __name__ == '__main__':
    main()
