"""Lossless atlas extraction from visually reviewed source rectangles.

This is pixel copying, not image synthesis or automatic identity recognition.
"""
from pathlib import Path
import hashlib
import html
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def build():
    catalog = json.loads((ROOT/'generated/sprites/catalog/catalog.json').read_text(encoding='utf-8'))
    entries = {e['relative_path']: e for e in catalog['entries'] if e['kind'] == 'gba'}
    recipe = json.loads((ROOT/'tools/sprite_generator/gba_character_splits.json').read_text(encoding='utf-8'))
    collective_count = len(recipe['sheets'])
    covered = {s['relative_path'] for s in recipe['sheets']}
    for key, entry in entries.items():
        if key not in covered:
            recipe['sheets'].append({'relative_path':key, 'sha256':entry['sha256'],
                'characters':[{'id':'character_01', 'label':entry['name'].split('__')[0],
                               'rectangles':[[0,0,*entry['size']]], 'poses':entry.get('poses', [])}]})
            if '/Playable Characters/' in key and key.startswith(('dbzlog2/', 'dbzbuusfury/')) and entry['size'][1]==192:
                recipe['sheets'][-1]['characters'][0].update({'frame_grid':[32,32],
                    'frame_grid_regions':[[0,32,entry['size'][0]//32*32,128]]})
    output = ROOT/'generated/sprites/characters'
    output.mkdir(parents=True, exist_ok=True)
    exports = []
    # Validate all recipes before writing outputs.
    for sheet in recipe['sheets']:
        entry = entries[sheet['relative_path']]
        raw = Path(entry['path']).read_bytes()
        if hashlib.sha256(raw).hexdigest() != sheet['sha256']:
            raise ValueError('Source changed: '+sheet['relative_path'])
        ids = [c['id'] for c in sheet['characters']]
        if len(ids) != len(set(ids)):
            raise ValueError('Duplicate character id')
        for character in sheet['characters']:
            for x,y,w,h in character['rectangles']:
                if min(x,y)<0 or min(w,h)<=0 or x+w>entry['size'][0] or y+h>entry['size'][1]:
                    raise ValueError('Invalid rectangle: '+character['id'])
    for sheet in recipe['sheets']:
        entry = entries[sheet['relative_path']]
        source = Image.open(entry['path']).convert('RGBA')
        folder = output/entry['catalog_id']
        folder.mkdir(exist_ok=True)
        for character in sheet['characters']:
            rectangles = character['rectangles']
            atlas = Image.new('RGBA', (max(r[2] for r in rectangles), sum(r[3] for r in rectangles)))
            blocks = []
            offset = 0
            for x,y,w,h in rectangles:
                atlas.paste(source.crop((x,y,x+w,y+h)), (0,offset))
                blocks.append({'source_rect':[x,y,w,h], 'atlas_rect':[0,offset,w,h]})
                offset += h
            name = character['id']+'.png'
            atlas.save(folder/name)
            record = {**character, 'source':sheet['relative_path'], 'source_path':entry['path'],
                      'source_sha256':sheet['sha256'], 'source_id':entry['catalog_id'],
                      'image':(folder/name).relative_to(output).as_posix(), 'blocks':blocks,
                      'size':list(atlas.size), 'status':'visually_reviewed_bounds',
                      'notes':'Source pixels and backgrounds preserved. No animation timing inferred. See original for credits.'}
            record['poses'] = []
            for pose in character.get('poses', []):
                mapped = {**pose, 'frames':[]}
                for frame in pose['frames']:
                    x,y,w,h = frame['rect']
                    matches = [b for b in blocks if b['source_rect'][0]<=x and b['source_rect'][1]<=y
                               and x+w<=b['source_rect'][0]+b['source_rect'][2]
                               and y+h<=b['source_rect'][1]+b['source_rect'][3]]
                    if len(matches)!=1:
                        raise ValueError('Pose outside character: '+character['label']+' '+pose['name'])
                    b=matches[0]
                    mapped['frames'].append({**frame,'source_rect':frame['rect'],
                        'rect':[x-b['source_rect'][0]+b['atlas_rect'][0],y-b['source_rect'][1]+b['atlas_rect'][1],w,h]})
                record['poses'].append(mapped)
            # Keep every still-unclassified region accessible even on sheets with
            # a few approved animations. Do not infer action/direction from position.
            record['unreviewed_regions'] = []
            reviewed = [f['source_rect'] for p in record['poses'] for f in p['frames']]
            for candidate_index, (x,y,w,h) in enumerate(entry['candidate_regions']):
                if any(a<=x and b<=y and x+w<=a+c and y+h<=b+d for a,b,c,d in reviewed):
                    continue
                for block_index, b in enumerate(blocks):
                    a,by,c,d = b['source_rect']
                    left,top,right,bottom = max(x,a),max(y,by),min(x+w,a+c),min(y+h,by+d)
                    if right<=left or bottom<=top:
                        continue
                    record['unreviewed_regions'].append({
                        'id':f'region_{candidate_index:05d}_block_{block_index:02d}',
                        'status':'needs_visual_review', 'candidate_index':candidate_index,
                        'source_rect':[left,top,right-left,bottom-top],
                        'rect':[left-a+b['atlas_rect'][0],top-by+b['atlas_rect'][1],right-left,bottom-top],
                        'clipped_at_character_boundary': [left,top,right-left,bottom-top]!=[x,y,w,h]})
            if character.get('frame_grid'):
                # Only recipes whose layout was checked use a grid. Keep whole
                # cells, including detached hands/particles, instead of ink blobs.
                fw,fh=character['frame_grid']
                record['unreviewed_regions']=[]
                for bi,b in enumerate(blocks):
                    sx,sy,bw,bh=b['source_rect']
                    areas=character.get('frame_grid_regions', [[sx,sy,bw,bh]])
                    for ax,ay,aw,ah in areas:
                        for y in range(ay,ay+ah-fh+1,fh):
                            for x in range(ax,ax+aw-fw+1,fw):
                                if not(sx<=x and sy<=y and x+fw<=sx+bw and y+fh<=sy+bh):
                                    continue
                                if any(a<=x and bb<=y and x+fw<=a+c and y+fh<=bb+d for a,bb,c,d in reviewed):
                                    continue
                                cell=source.crop((x,y,x+fw,y+fh))
                                if len(cell.getcolors(fw*fh) or [])<=1:
                                    continue
                                record['unreviewed_regions'].append({
                                    'id':f'cell_b{bi}_x{x}_y{y}', 'status':'grid_cell_action_pending',
                                    'source_rect':[x,y,fw,fh],
                                    'rect':[x-sx+b['atlas_rect'][0],y-sy+b['atlas_rect'][1],fw,fh],
                                    'clipped_at_character_boundary':False})
            # Show likely sprite-sized regions before tiny lettering or giant
            # background components, but retain all candidates for review.
            record['unreviewed_regions'].sort(key=lambda r:(
                r['rect'][2]<8 or r['rect'][3]<16 or max(r['rect'][2:])>96,
                r['rect'][1],r['rect'][0]))
            record['coverage'] = {'reviewed_poses':len(record['poses']),
                'pending_regions':len(record['unreviewed_regions']),
                'semantic_mapping_complete':False,
                'note':'Region coverage is not proof that all poses were identified. Text/fragments may remain.'}
            (folder/(character['id']+'.json')).write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding='utf-8')
            exports.append(record)
    manifest = {'version':1, 'sources_split':len(recipe['sheets']), 'collective_sources':collective_count,
                'characters_exported':len(exports), 'mapped_poses':sum(len(e['poses']) for e in exports),
                'pending_regions':sum(len(e['unreviewed_regions']) for e in exports), 'characters':exports}
    (output/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    coverage = '# Cobertura das poses GBA\n\nTodas as fontes do inventário estão disponíveis no gerador. Isso não significa que todas as ações estejam identificadas.\n\n'
    coverage += '| Fonte | Personagem/variante | Poses revisadas | Regiões pendentes |\n| --- | --- | ---: | ---: |\n'
    coverage += '\n'.join(f'| {e["source"]} | {e["label"]} | {len(e["poses"])} | {len(e["unreviewed_regions"])} |' for e in exports)
    (output/'POSE_COVERAGE.md').write_text(coverage+'\n',encoding='utf-8')
    cards = []
    esc = html.escape
    for e in exports:
        source_url = Path(e['source_path']).as_uri()
        cards.append(f'<article data-search="{esc(e["label"]+" "+e["source"],quote=True)}"><h2>{esc(e["label"])}</h2>'
                     f'<p>{len(e["poses"])} poses verificadas · {len(e["unreviewed_regions"])} regiões pendentes</p>'
                     f'<p>{esc(e["source"])}</p><a href="{e["image"]}"><img loading="lazy" src="{e["image"]}" alt="{esc(e["label"],quote=True)}"></a>'
                     f'<p><a href="{e["image"]}" download>PNG</a> · <a href="{e["image"][:-4]}.json">Coordenadas</a> · <a href="{source_url}">Original e créditos</a> · '
                     f'<a href="../catalog/index.html#source={e["source_id"]}">Catálogo</a></p></article>')
    page = '<!doctype html><html lang="pt-BR"><meta charset="utf-8"><title>GBA por personagem</title><style>body{background:#17212c;color:#eee;font:16px system-ui;margin:24px}a{color:#8ce0ff}input{padding:12px;width:80%}#cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(360px,1fr));gap:16px}article{border:1px solid #607086;padding:12px;overflow:auto}h2{font-size:18px}img{image-rendering:pixelated;max-width:none}p{overflow-wrap:anywhere}article[hidden]{display:none}</style>'
    page += f'<h1>GBA por personagem/variante</h1><p>{len(exports)} entradas: {collective_count} folhas coletivas separadas e personagens individuais revisados. {manifest["mapped_poses"]} sequências mapeadas para o gerador. Pixels originais preservados; duração GBA ilustrativa a 7 fps.</p>'
    page += '<p><a href="../catalog/index.html">Catálogo de poses</a> · <a href="manifest.json">Manifesto completo</a></p><input id="search" placeholder="Buscar personagem, jogo ou folha"><p id="count"></p><div id="cards">'+''.join(cards)+'</div>'
    page += '<script>const search=document.getElementById("search");function filter(){let n=0;document.querySelectorAll("article").forEach(card=>{card.hidden=!card.dataset.search.toLowerCase().includes(search.value.toLowerCase());if(!card.hidden)n++});document.getElementById("count").textContent=n+" resultados"}search.oninput=filter;filter()</script></html>'
    (output/'index.html').write_text(page,encoding='utf-8')
    vault = ROOT/'generated/sprites/catalog/obsidian'
    if vault.exists():
        note = '# GBA por personagem\n\n[Índice visual dos recortes]('+ (output/'index.html').as_uri()+')\n\n'
        note += 'Pixels originais, sem escala. As fichas das fontes continuam disponíveis em [[Fontes]].\n\n'
        note += '[Relatório de cobertura das poses]('+(output/'POSE_COVERAGE.md').as_uri()+')\n\n'
        note += '\n'.join(f'- **{e["label"]}** — [PNG]({(output/e["image"]).as_uri()}) · [[Fontes/{e["source_id"]}|Fonte]]' for e in exports)
        (vault/'Personagens GBA.md').write_text(note+'\n',encoding='utf-8')
    print(json.dumps({'sources_split':len(recipe['sheets']),'characters_exported':len(exports)}))


if __name__ == '__main__':
    build()
