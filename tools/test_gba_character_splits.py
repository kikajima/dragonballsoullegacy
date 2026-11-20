"""Round-trip every extracted block to its original pixels; never accept scaling."""
from pathlib import Path
import hashlib
import json
from PIL import Image

root=Path(__file__).resolve().parents[1]
output=root/'generated/sprites/characters'
manifest=json.loads((output/'manifest.json').read_text(encoding='utf-8'))
sources={}
for entry in manifest['characters']:
    source_path=entry['source_path']
    if source_path not in sources:
        assert hashlib.sha256(Path(source_path).read_bytes()).hexdigest()==entry['source_sha256']
        sources[source_path]=Image.open(source_path).convert('RGBA')
    source=sources[source_path]
    extracted=Image.open(output/entry['image']).convert('RGBA')
    assert list(extracted.size)==entry['size']
    for block in entry['blocks']:
        x,y,w,h=block['source_rect'];a,b,c,d=block['atlas_rect']
        assert (w,h)==(c,d)
        assert min(x,y,a,b)>=0 and min(w,h)>0
        assert x+w<=source.width and y+h<=source.height
        assert a+c<=extracted.width and b+d<=extracted.height
        assert source.crop((x,y,x+w,y+h)).tobytes()==extracted.crop((a,b,a+c,b+d)).tobytes(),entry['image']
    for region in entry.get('unreviewed_regions', []):
        x,y,w,h=region['source_rect'];a,b,c,d=region['rect']
        assert (w,h)==(c,d) and min(x,y,a,b)>=0
        assert a+c<=extracted.width and b+d<=extracted.height
        assert source.crop((x,y,x+w,y+h)).tobytes()==extracted.crop((a,b,a+c,b+d)).tobytes()
assert len(sources)==manifest['sources_split']
catalog=json.loads((root/'generated/sprites/catalog/catalog.json').read_text(encoding='utf-8'))
assert {e['path'] for e in catalog['entries'] if e['kind']=='gba'} == set(sources)
assert len({e['image'] for e in manifest['characters']})==manifest['characters_exported']
print(f'PASS: {len(sources)} original sources unchanged; {len(manifest["characters"])} exports pixel-identical to source rectangles.')
