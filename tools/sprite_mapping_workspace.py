"""Provisional spatial groups and a regenerable Markdown curation workspace."""
from pathlib import Path
import hashlib
import json


def prepare(entries):
    for entry in entries:
        source = entry.get('relative_path', entry['path'])
        entry['catalog_id'] = hashlib.sha256(source.encode()).hexdigest()[:16]
        if entry['kind'] != 'gba':
            continue
        # Never feed automatic groups into reviewed poses or the game exporter.
        groups = []
        for index, rect in enumerate(entry['candidate_regions']):
            x, y, w, h = rect
            flags = []
            if min(w, h) < 8:
                flags.append('small_fragment_or_text')
            if w > 96 or h > 96:
                flags.append('large_region_or_background')
            if max(w, h) > 4 * min(w, h):
                flags.append('elongated_region')
            frame = {'rect': rect, 'frame': index, 'candidate_index': index,
                     'flags': flags}
            # A row is an inspection order, NOT an inferred animation/action.
            row = next((g for g in reversed(groups) if abs(g['anchor_y'] - y) <= 8), None)
            if row is None:
                row = {'id': f'row_{len(groups):04d}', 'name': f'Linha provisória {len(groups)+1}',
                       'status': 'provisional_spatial_group', 'anchor_y': y, 'frames': []}
                groups.append(row)
            row['frames'].append(frame)
        for group in groups:
            group['frames'].sort(key=lambda f: (f['rect'][0], f['rect'][1]))
            group['flags'] = sorted({flag for f in group['frames'] for flag in f['flags']})
        entry['provisional_groups'] = groups
        entry['coverage'] = 'candidate_regions_grouped' if groups else 'manual_segmentation_required'


def extra_summary(entries):
    return {
        'gba_provisional_groups': sum(len(e.get('provisional_groups', [])) for e in entries),
        'gba_flagged_regions': sum(bool(f['flags']) for e in entries
                                  for g in e.get('provisional_groups', []) for f in g['frames']),
        'gba_without_candidates': [e['relative_path'] for e in entries
                                   if e['kind'] == 'gba' and not e['candidate_regions']],
    }


def write_workspace(entries, output, summary):
    vault = output / 'obsidian'
    sheets = vault / 'Fontes'
    sheets.mkdir(parents=True, exist_ok=True)
    links = []
    for entry in entries:
        key = entry['catalog_id']
        filename = f'{key}.md'
        poses = entry.get('states', entry.get('poses', []))
        groups = entry.get('provisional_groups', [])
        title = entry['kind'].upper() + ' — ' + entry['name']
        viewer = (output / 'index.html').as_uri() + '#source=' + key
        text = f'# {title}\n\nFicha gerada automaticamente; escreva suas decisões em [[Curadoria]].\n\n'
        text += f'[Abrir no catálogo]({viewer}) · [Fonte original]({Path(entry["path"]).as_uri()})\n\n'
        text += f'Identificador: `{key}`\n\nOrigem: `{entry.get("relative_path", entry["path"])}`\n\n'
        text += f'Hash: `{entry.get("sha256", entry.get("git_blob"))}`\n\n'
        text += f'Sequências com metadados/revisadas: **{len(poses)}**. Grupos espaciais provisórios: **{len(groups)}**.\n\n'
        text += '## Sequências conhecidas\n\n'
        text += '\n'.join(f'- `{p.get("id", p.get("name"))}` — {len(p["frames"])} recortes — {p["status"]}' for p in poses) or 'Nenhuma sequência confirmada nesta folha.'
        text += '\n\n## Grupos para curadoria\n\n'
        text += '\n'.join(f'- `{g["id"]}`: y={g["anchor_y"]}, {len(g["frames"])} regiões; alertas: {", ".join(g["flags"]) or "nenhum automático"}' for g in groups) or 'Sem grupos provisórios.'
        (sheets / filename).write_text(text + '\n', encoding='utf-8')
        links.append(f'- [[Fontes/{key}|{title}]]')
    home = '# Biblioteca de sprites\n\n'
    home += 'Abra esta pasta como cofre no Obsidian. As fichas são regeneradas; suas notas em **Curadoria.md** são preservadas.\n\n'
    home += f'[Catálogo visual]({(output / "index.html").as_uri()}) · [[Personagens GBA]] · [[Curadoria]] · [[Fontes]]\n\n'
    home += f'{summary["dmi_files"]} arquivos HU2; {summary["gba_sheets"]} folhas GBA; {summary["gba_confirmed_poses"]} sequências GBA confirmadas; {summary["gba_provisional_groups"]} grupos espaciais provisórios.\n\n'
    home += 'Uma folha pode conter vários personagens. Grupos espaciais não confirmam ações, direções, duração ou separação de personagens. O catálogo permite registrar decisões e exportá-las em JSON; esses registros não modificam o jogo automaticamente.\n'
    (vault / 'Início.md').write_text(home, encoding='utf-8')
    (vault / 'Fontes.md').write_text('# Todas as fontes\n\n' + '\n'.join(links) + '\n', encoding='utf-8')
    notes = vault / 'Curadoria.md'
    if not notes.exists():
        notes.write_text('# Curadoria\n\nNotas manuais preservadas nas próximas gerações.\n\n'
                         '| Fonte / grupo | Personagem | Ação | Direção | Decisão / observações |\n'
                         '| --- | --- | --- | --- | --- |\n', encoding='utf-8')
