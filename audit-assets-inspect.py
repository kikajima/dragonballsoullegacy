from pathlib import Path
import re,json
from PIL import Image,ImageDraw
base=Path('assets/vendor/hu2/Icons')
items=[]
for filename,states in {'Turfs/CityTurfs.dmi':['PlantL','PlantM','PlantR','BenchL','BenchR','DumpsterB','DumpsterT','RoadDashH','CrossWalkH','CrossWalkV'],'Turfs/Flowers.dmi':['rock','rock1','rock2','rock3','rock4','rock5','rock6','rock7','rock8'],'Other/Other.dmi':['SpeedBag','PunchingBag','SpeedBagHit','PunchingBagHit'],'Turfs/RectBuilding.dmi':['TL','TM','TR','ML','MM','MR','BL','BM','BR','Door','RoofBL','RoofBM','RoofBR','RoofML','RoofMM','RoofMR','RoofTL','RoofTM','RoofTR'],'Turfs/SquareBuilding.dmi':['BL','Window','Door','BR','ML','MM','MR','TML','TMM','TMR','TL','TM','TR']}.items():
 im=Image.open(base/filename).convert('RGBA'); meta=Image.open(base/filename).info['Description']; head=meta.split('state =')[0]; w=int(re.search(r'width = (\d+)',head).group(1)) if 'width =' in head else 32; h=int(re.search(r'height = (\d+)',head).group(1)) if 'height =' in head else 32
 tile=0
 for block in re.split(r'(?=state =)',meta)[1:]:
  name=re.search('state = "(.*?)"',block).group(1); dirs=int(re.search(r'dirs = (\d+)',block).group(1)); frames=int(re.search(r'frames = (\d+)',block).group(1)); cols=im.width//w
  if name in states:
   rect=[tile%cols*w,tile//cols*h,w,h]; items.append((filename,name,dirs,frames,rect,im.crop((rect[0],rect[1],rect[0]+w,rect[1]+h))))
  tile+=dirs*frames
out=Image.new('RGB',(800,((len(items)+5)//6)*120),'#414b54');d=ImageDraw.Draw(out)
for i,(fn,name,dirs,frames,r,im) in enumerate(items):
 x=(i%6)*132;y=(i//6)*120;d.text((x,y),fn.split('/')[-1][:-4],fill='white');d.text((x,y+13),f'{name} d{dirs} f{frames}',fill='white');im=im.resize((r[2]*2,r[3]*2));out.paste(im,(x,y+30),im)
out.save('audit-assets-states.png');Path('audit-assets-states.json').write_text(json.dumps([{ 'path':str(base/fn),'state':n,'dirs':d,'frames':f,'rect':r}for fn,n,d,f,r,im in items],indent=2))
print(len(items))
