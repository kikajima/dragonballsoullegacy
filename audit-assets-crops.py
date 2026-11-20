from PIL import Image,ImageDraw
im=Image.open('audit-assets-furniture.png').convert('RGBA')
rects={'bed':(376,112,40,64),'tv':(416,184,48,64),'fridge':(696,8,24,48),'table':(320,312,48,56),'sofa':(832,112,40,64),'coffee_table':(200,400,48,32),'terminal':(776,192,48,56)}
out=Image.new('RGBA',(len(rects)*150,190),'#414b54');d=ImageDraw.Draw(out)
for i,(name,(x,y,w,h)) in enumerate(rects.items()):
 crop=im.crop((x,y,x+w,y+h));pix=crop.load()
 for cy in range(h):
  for cx in range(w):
   if pix[cx,cy][:3] in [(172,0,205),(116,0,136)]: pix[cx,cy]=(0,0,0,0)
 d.text((i*150,0),name,fill='white');d.text((i*150,14),str(crop.getbbox()),fill='white');crop=crop.resize((w*2,h*2),Image.Resampling.NEAREST);out.alpha_composite(crop,(i*150,40))
out.convert('RGB').save('audit-assets-crops.png')
