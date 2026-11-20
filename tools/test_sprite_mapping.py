"""Checks source coverage, deterministic grouping and preservation of manual notes."""
import copy
import json
from pathlib import Path
import tempfile
from sprite_mapping_workspace import prepare, extra_summary, write_workspace
from map_sprite_library import DEFAULT_GBA, GAMES, FOLDERS

root = Path(__file__).resolve().parents[1]
catalog = json.loads((root/'generated/sprites/catalog/catalog.json').read_text(encoding='utf-8'))
entries = catalog['entries']
actual_gba = {p.resolve() for game in GAMES for p in (DEFAULT_GBA/game).rglob('*.png')
              if p.parent.name in FOLDERS}
assert actual_gba == {Path(e['path']).resolve() for e in entries if e['kind'] == 'gba'}, 'Rebuild after adding/removing sources'
before = copy.deepcopy(entries)
prepare(entries)
assert entries == before, 'Grouping must be deterministic on regeneration'
assert len({e['catalog_id'] for e in entries}) == len(entries)
for entry in entries:
    if entry['kind'] == 'gba':
        frames = [f for g in entry['provisional_groups'] for f in g['frames']]
        assert sorted(f['candidate_index'] for f in frames) == list(range(len(entry['candidate_regions'])))
        assert all(f['rect'] == entry['candidate_regions'][f['candidate_index']] for f in frames)
        assert all(p['status'] != 'provisional_spatial_group' for p in entry['poses'])
    for group in entry.get('states', entry.get('poses', [])) + entry.get('provisional_groups', []):
        for frame in group['frames']:
            x,y,w,h = frame['rect']
            assert min(x,y) >= 0 and min(w,h) > 0
            assert x+w <= entry['size'][0] and y+h <= entry['size'][1]
with tempfile.TemporaryDirectory() as folder:
    output = Path(folder)
    write_workspace(entries, output, catalog['summary'])
    notes = output/'obsidian/Curadoria.md'
    notes.write_text('Minha decisão manual: conservar.\n', encoding='utf-8')
    write_workspace(entries, output, catalog['summary'])
    assert notes.read_text(encoding='utf-8') == 'Minha decisão manual: conservar.\n'
    assert len(list((output/'obsidian/Fontes').glob('*.md'))) == len(entries)
assert extra_summary(entries)['gba_without_candidates'] == []
print(f'PASS: {len(entries)} sources; exact candidate coverage; bounds; deterministic groups; manual notes preserved.')
