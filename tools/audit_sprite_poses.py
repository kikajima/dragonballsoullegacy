"""Audit mapped poses for missing/empty frames, bounds and sequence numbering."""
import json
from pathlib import Path
from collections import defaultdict
from PIL import Image

root=Path(__file__).resolve().parents[1]/'generated/sprites/characters'
manifest=json.loads((root/'manifest.json').read_text(encoding='utf-8'))
issues=[]
frame_count=0
for character in manifest['characters']:
    image=Image.open(root/character['image']).convert('RGBA')
    for pose in character['poses']:
        directions=defaultdict(list)
        for frame in pose['frames']:
            frame_count+=1
            x,y,w,h=frame['rect']
            reason=None
            if min(x,y)<0 or min(w,h)<=0 or x+w>image.width or y+h>image.height:
                reason='outside_image'
            else:
                cell=image.crop((x,y,x+w,y+h))
                colors=cell.getcolors(2)
                if cell.getchannel('A').getbbox() is None or (colors and len(colors)==1):
                    reason='empty_or_uniform_frame'
            if reason:
                issues.append({'source':character['source'],'character':character['label'],
                               'pose':pose['name'],'frame':frame,'issue':reason})
            directions[frame['direction']].append(frame['frame'])
        for direction,indices in directions.items():
            if indices!=list(range(len(indices))):
                issues.append({'character':character['label'],'pose':pose['name'],
                               'direction':direction,'issue':'non_contiguous_sequence'})
report={'entries':len(manifest['characters']), 'poses':manifest['mapped_poses'],
        'frames':frame_count,'issues':issues,'semantic_review_complete':False,
        'pending_regions':manifest['pending_regions']}
(root/'POSE_AUDIT.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(f"Pose audit: {report['poses']} poses, {frame_count} frames, {len(issues)} issues")
if issues:
    raise SystemExit(1)
