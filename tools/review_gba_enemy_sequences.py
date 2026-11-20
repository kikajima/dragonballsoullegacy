"""Apply the manually inspected 2026-10-24 enemy sheet review.

Column selections below are specific to these sheets, not inferred for others.
Names describe visible motion; original playback and gameplay triggers are unknown.
"""
import json
from pathlib import Path

PATH = Path(__file__).resolve().parent / 'sprite_generator/gba_character_splits.json'
DIRECTIONS = ('down', 'left', 'right', 'up')
REVIEWS = {
    'Ladybug__224074.png': [
        ('move', [2, 3, 4, 5], DIRECTIONS),
        ('shell_close', [11, 12, 13], DIRECTIONS),
        ('shell_lower', [14, 15, 16, 17, 18], ('left', 'right')),
    ],
    'Phantom__588117.png': [
        ('float', [0, 1, 2], DIRECTIONS),
        ('raise_arms', [3, 4], DIRECTIONS),
        ('turn_edge_on', [5, 6], DIRECTIONS),
        ('stretch', [7, 8, 9], DIRECTIONS),
        ('materialize', list(range(10, 17)), ('down',)),
    ],
    'Laser Turret__588112.png': [
        ('deploy', [0, 1, 2, 3], DIRECTIONS),
        ('barrel_pulse', [4, 5], DIRECTIONS),
        ('barrel_recoil', [6, 7, 8], DIRECTIONS),
    ],
}


def main():
    data = json.loads(PATH.read_text(encoding='utf-8'))
    count = 0
    for sheet in data['sheets']:
        definitions = REVIEWS.get(sheet['relative_path'].split('/')[-1])
        if definitions is None:
            continue
        for character in sheet['characters']:
            x, y, _, _ = character['rectangles'][0]
            width, height = character['frame_grid']
            poses = {pose['name']: pose for pose in character.get('poses', [])}
            for name, columns, directions in definitions:
                poses[name] = {
                    'name': name,
                    'status': 'visually_confirmed',
                    'timing_status': 'preview_only_7fps',
                    'review_date': '2026-10-24',
                    'notes': 'Original sheet and each palette variant visually inspected. '
                             'Descriptive motion name; original timing, looping and gameplay trigger unverified.',
                    'frames': [
                        {'direction': direction, 'frame': index,
                         'rect': [x + column * width,
                                  y + DIRECTIONS.index(direction) * height, width, height]}
                        for direction in directions
                        for index, column in enumerate(columns)
                    ],
                }
                count += 1
            character['poses'] = list(poses.values())
    PATH.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'Registered {count} visually reviewed sequences.')


if __name__ == '__main__':
    main()
