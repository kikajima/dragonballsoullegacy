"""Read-only source analysis. No image generation, modification or guessed pose labels."""
from pathlib import Path
import argparse, collections, hashlib, html, json, re, struct, zlib
from PIL import Image
from sprite_mapping_workspace import prepare, extra_summary, write_workspace

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_GBA = Path(r'C:\spriters-resource-downloader\Spriters-Resource-Downloader-v2.7-unofficial\downloaded\game_boy_advance')
GAMES = ('dbzlog', 'dbzlog2', 'dbzbuusfury')
FOLDERS = {'Playable Characters', 'Non-Playable Characters', 'Enemies & Bosses', 'Prototype', 'Unused Content'}
DIRECTIONS = ['down', 'up', 'right', 'left', 'down_right', 'down_left', 'up_right', 'up_left']

def png_metadata(path):
    data = path.read_bytes()
    offset, description = 8, ''
    while offset + 12 <= len(data):
        length = struct.unpack('>I', data[offset:offset+4])[0]
        kind = data[offset+4:offset+8]
        chunk = data[offset+8:offset+8+length]
        offset += length + 12
        if kind == b'zTXt':
            key, value = chunk.split(b'\0', 1)
            if key == b'Description':
                description = zlib.decompress(value[1:]).decode('utf-8')
        elif kind == b'tEXt' and chunk.startswith(b'Description\0'):
            description = chunk.split(b'\0', 1)[1].decode('utf-8')
    return description

def dmi_entry(path, expected):
    data = path.read_bytes()
    blob = hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()
    metadata = png_metadata(path)
    image = Image.open(path)
    header = metadata.split('state =', 1)[0]
    width = int(re.search(r'width\s*=\s*(\d+)', header)[1])
    height = int(re.search(r'height\s*=\s*(\d+)', header)[1])
    columns = image.width // width
    offset, states, occurrences = 0, [], collections.Counter()
    for block in re.split(r'^state\s*=\s*', metadata, flags=re.M)[1:]:
        name = json.loads(block.splitlines()[0])
        attrs = dict(re.findall(r'^\s*(\w+)\s*=\s*([^\r\n]+)', block, re.M))
        dirs, frames = int(attrs.get('dirs', 1)), int(attrs.get('frames', 1))
        delays = [float(v) for v in attrs.get('delay', '1').split(',')]
        occurrence = occurrences[name]
        occurrences[name] += 1
        state = {'id': f'{name or "idle"}#{occurrence}', 'source_name': name,
                 'directions': dirs, 'frame_count': frames, 'attributes': attrs,
                 'status': 'source_metadata', 'frames': []}
        for frame in range(frames):
            for direction in range(dirs):
                tile = offset + frame * dirs + direction
                rect = [(tile % columns)*width, (tile//columns)*height, width, height]
                if rect[1] + height > image.height:
                    raise ValueError(f'Frame outside sheet: {path} {state["id"]}')
                state['frames'].append({'direction': 'single' if dirs == 1 else DIRECTIONS[direction],
                    'frame': frame, 'rect': rect, 'duration_seconds': delays[min(frame, len(delays)-1)]/10})
        states.append(state)
        offset += dirs * frames
    return {'kind': 'dmi', 'name': path.stem, 'path': str(path), 'size': list(image.size),
            'git_blob': blob, 'github_match': blob == expected, 'states': states}

def candidates(image):
    """Connected ink bounds are candidates, never semantic animations.

    Only discard alpha and dominant saturated green/cyan sheet backgrounds.
    Detached pixels and annotation text can remain: approval is required.
    """
    image = image.convert('RGBA')
    counts = collections.Counter(image.getdata())
    backgrounds = {c for c, n in counts.most_common(8)
                   if n > image.width*image.height*.015 and c[1] > c[0]*1.35 and c[1] > c[2]*.9}
    pixels = image.load()
    ink = {(x,y) for y in range(image.height) for x in range(image.width)
           if pixels[x,y][3] and pixels[x,y] not in backgrounds}
    bounds = []
    while ink:
        seed = ink.pop()
        stack = [seed]
        x0=x1=seed[0]; y0=y1=seed[1]; area=0
        while stack:
            x,y=stack.pop(); area+=1
            x0=min(x0,x); x1=max(x1,x); y0=min(y0,y); y1=max(y1,y)
            for dx,dy in ((-1,0),(1,0),(0,-1),(0,1),(-1,-1),(1,-1),(-1,1),(1,1)):
                point=(x+dx,y+dy)
                if point in ink:
                    ink.remove(point); stack.append(point)
        if area >= 12:
            bounds.append([x0,y0,x1-x0+1,y1-y0+1])
    return sorted(bounds, key=lambda r:(r[1],r[0])), [list(c) for c in backgrounds]

def gba_entry(path, base):
    image = Image.open(path)
    regions, backgrounds = candidates(image)
    poses = []
    if path.name == 'Goku__47770.png' and 'dbzbuusfury' in path.parts:
        poses = [{'name':'spirit_charge', 'status':'visually_confirmed', 'frames':[
            {'direction':direction,'frame':0,'rect':[1120,32+row*32,32,32]}
            for row,direction in enumerate(['down','left','right','up'])]}]
    return {'kind':'gba', 'name':path.stem, 'path':str(path), 'relative_path':path.relative_to(base).as_posix(),
            'size':list(image.size), 'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
            'status':'needs_visual_mapping', 'background_candidates':backgrounds,
            'candidate_regions':regions, 'poses':poses}

def write_viewer(entries, output):
    # Source PNG/DMI are linked intact; browser reads their existing PNG bytes.
    payload = json.dumps([{**e, 'url':Path(e['path']).as_uri()} for e in entries]).replace('</','<\\/')
    page = (ROOT/'tools/sprite_generator/catalog.html').read_text(encoding='utf-8')
    (output/'index.html').write_text(page.replace('PAYLOAD',payload),encoding='utf-8')

def apply_reviews(entries):
    reviews={'sheets':[]}
    for filename in ['gba_reviewed_poses.json', 'gba_reviewed_movement.json', 'gba_reviewed_combat.json', 'gba_reviewed_extended.json']:
        reviews['sheets'].extend(json.loads((ROOT/'tools/sprite_generator'/filename).read_text(encoding='utf-8'))['sheets'])
    by_path={entry.get('relative_path'):entry for entry in entries if entry['kind']=='gba'}
    for review in reviews['sheets']:
        entry=by_path[review['relative_path']]
        if entry['sha256'] != review['sha256']:
            raise ValueError('Reviewed source changed: '+review['relative_path'])
        for pose in review['poses']:
            for frame in pose['frames']:
                x,y,w,h=frame['rect']
                if min(x,y)<0 or min(w,h)<=0 or x+w>entry['size'][0] or y+h>entry['size'][1]:
                    raise ValueError('Reviewed frame outside source: '+pose['name'])
        by_name={pose['name']:pose for pose in entry.get('poses',[])}
        by_name.update({pose['name']:pose for pose in review['poses']})
        entry['poses']=list(by_name.values())
        entry['review_status']=review['review_status']
        entry['review_notes']=review['notes']

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--gba-root',type=Path,default=DEFAULT_GBA)
    parser.add_argument('--refresh-reviews',action='store_true',help='Reuse cached inventory and apply reviewed coordinates')
    args=parser.parse_args()
    output=ROOT/'generated/sprites/catalog'
    output.mkdir(parents=True,exist_ok=True)
    manifest=json.loads((ROOT/'tools/sprite_generator/github_manifest.json').read_text())
    entries=[]; errors=[]
    if args.refresh_reviews:
        cached=json.loads((output/'catalog.json').read_text(encoding='utf-8'))
        entries=cached['entries']
        # Recheck the actual source, not only the cached digest.
        for entry in entries:
            if entry['kind']=='gba':
                actual=hashlib.sha256(Path(entry['path']).read_bytes()).hexdigest()
                if actual!=entry['sha256']: raise ValueError('Source changed; rebuild catalog: '+entry['path'])
            else:
                raw=Path(entry['path']).read_bytes()
                actual=hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()
                if actual!=entry['git_blob']: raise ValueError('DMI changed; rebuild catalog: '+entry['path'])
        apply_reviews(entries)
        prepare(entries)
        cached['summary']['gba_confirmed_poses']=sum(len(e.get('poses',[])) for e in entries)
        cached['summary'].update(extra_summary(entries))
        (output/'catalog.json').write_text(json.dumps(cached,indent=2),encoding='utf-8')
        (output/'summary.json').write_text(json.dumps(cached['summary'],indent=2),encoding='utf-8')
        write_viewer(entries,output)
        write_workspace(entries,output,cached['summary'])
        from split_gba_characters import build
        build()
        print(json.dumps(cached['summary'],indent=2))
        return
    for file in manifest['files']:
        try: entries.append(dmi_entry(ROOT/file['path'],file['sha']))
        except Exception as exc: errors.append({'path':file['path'],'error':str(exc)})
    for game in GAMES:
        for path in sorted((args.gba_root/game).rglob('*.png')):
            if path.parent.name not in FOLDERS: continue
            try: entries.append(gba_entry(path,args.gba_root))
            except Exception as exc: errors.append({'path':str(path),'error':str(exc)})
    apply_reviews(entries)
    prepare(entries)
    summary={'github_commit':manifest['commit'],'dmi_files':sum(e['kind']=='dmi' for e in entries),
             'dmi_states':sum(len(e.get('states',[])) for e in entries),
             'dmi_frames':sum(len(s['frames']) for e in entries for s in e.get('states',[])),
             'github_mismatches':[e['path'] for e in entries if e['kind']=='dmi' and not e['github_match']],
             'gba_sheets':sum(e['kind']=='gba' for e in entries),
             'gba_candidate_regions':sum(len(e.get('candidate_regions',[])) for e in entries),
             'gba_confirmed_poses':sum(len(e.get('poses',[])) for e in entries),'errors':errors}
    summary.update(extra_summary(entries))
    (output/'catalog.json').write_text(json.dumps({'summary':summary,'entries':entries},indent=2),encoding='utf-8')
    (output/'summary.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
    write_viewer(entries,output)
    write_workspace(entries,output,summary)
    from split_gba_characters import build
    build()
    print(json.dumps(summary,indent=2))
    if errors: raise SystemExit(1)

if __name__=='__main__': main()
