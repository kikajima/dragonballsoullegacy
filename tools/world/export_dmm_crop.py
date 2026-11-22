"""Export a crop of a BYOND .dmm map (the HU2 world map) as layered
[icon, state] cells for tools/world/render_dmm_crop.gd.

usage: python tools/world/export_dmm_crop.py Map.dmm z x0 y0 w h out.json
       (x0, y0: top-left tile, counted from the top row)
"""
import json
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dmm_reader  # noqa: E402

keys, zs = {}, {}

T = 'res://assets/vendor/hu2/Icons/Turfs/'
I = 'res://assets/vendor/hu2/Icons/Images/'

TURF = {  # type path suffix -> (icon, default state)
    'Generic/Grass': (T + 'NewTurfs.dmi', 'DarkGrass#4'),
    'Generic/Water': (T + 'NewTurfs.dmi', 'Water'),
    'Other/White': (T + 'NewTurfs.dmi', 'White'),
    'Other/Blackness': (T + 'NewTurfs.dmi', 'Black'),
    'HighwayCliffs/Dirt': (T + 'HighwayCliffs.dmi', 'Dirt#4'),
    'HighwayCliffs/Path': (T + 'HighwayCliffs.dmi', 'Path#3'),
    'HighwayCliffs/CliffEdge': (T + 'HighwayCliffs.dmi', 'CliffL'),
    'HighwayCliffs/Cliff': (T + 'HighwayCliffs.dmi', 'B'),
    'HighwayCliffs/GuardRail': (T + 'HighwayCliffs.dmi', 'GuardRailB'),
    'City/Tile': (T + 'CityTurfs.dmi', 'Tile'),
    'City/Road': (T + 'CityTurfs.dmi', 'Road'),
    'City/CrossWalk': (T + 'CityTurfs.dmi', 'CrossWalkH'),
    'City/Plant': (T + 'CityTurfs.dmi', 'PlantM'),
    'City/Bench': (T + 'CityTurfs.dmi', 'BenchL'),
    'City/CityWall': (T + 'CityWall.dmi', 'B'),
    'City/Stairs': (T + 'CityStairs.dmi', 'Stairs'),
    'DbzTurfs/GrayTile': (T + 'DbzTurfs.dmi', 'GrayTile'),
    'DbzTurfs/WallTop': (T + 'DbzTurfs.dmi', 'WallTopB'),
    'Buildings/SquareBuilding': (T + 'SquareBuilding.dmi', 'BL'),
    'Buildings/RectBuilding': (T + 'RectBuilding.dmi', 'BL'),
    'Buildings/RoundBuilding': (T + 'RoundTower.dmi', 'BL'),
    'Buildings/RedHut': (T + 'RedHut.dmi', '7'),
    'Buildings/PurpleHut': (T + 'PurpleHut.dmi', '7'),
    'Overflow/Tree': (I + 'Tree.png', ''),
}
OBJ = {
    'Cliff': (T + 'NewCliffs.dmi', 'TM1'),
    'DenseGrassFuzz': (T + 'NewTurfs.dmi', 'GrassFuzzL'),
    'GrassCorners': (T + 'NewTurfs.dmi', 'DarkGrassTL'),
    'Tree': (I + 'Tree.png', ''),
    'PalmTree': (I + 'PalmTree.png', ''),
    'FancyTree16': (I + 'FancyTree.png', ''),
    'RockSlide': (I + 'RockSlide.png', ''),
    'Kame_House': (I + 'NewKameHouse.png', ''),
    'Capsule_Ship': (I + 'CapsuleShip.png', ''),
    'CellGamesArena': (I + 'CellGamesArena.png', ''),
    'Dumpster': (T + 'CityTurfs.dmi', 'DumpsterB'),
    'BuildingToppers': (T + 'SquareBuilding.dmi', 'RoofGrate'),
    'BuildingLetters': (T + 'BuildingLetters.dmi', 'GoldZ'),
}


def resolve(path, vars_, table):
    for suffix, (icon, state) in table.items():
        if path.endswith('/' + suffix):
            break
    else:
        return None
    state = vars_.get('icon_state', state)
    if 'icon' in vars_:
        name = vars_['icon'].strip("'")
        icon = (I if name.endswith('.png') else T) + name
    if state == 'TM1':
        state = 'TM#3@2'
    if state == 'BM1':
        state = 'BM#3'
    return [icon, state]


def layers(k, rnd):
    out = []
    turfs = [a for a in keys[k] if a[0].startswith('/turf')]
    objs = [a for a in keys[k] if a[0].startswith('/obj/TurfType')]
    for p, v in turfs[::-1]:  # dmm lists the top turf last? keep underlying first
        r = resolve(p, v, TURF)
        if r:
            out.append(r)
    for p, v in objs[::-1]:
        r = resolve(p, v, OBJ)
        if r:
            out.append(r)
    for r in out:  # random variants like the New() procs
        s = r[1]
        if '#' in s:
            base, rest = s.split('#')
            hi = int(rest.split('@')[0])
            lo = int(rest.split('@')[1]) if '@' in rest else 1
            r[1] = base + str(rnd.randint(lo, hi))
    return out


def main():
    global keys, zs
    keys, zs = dmm_reader.load(sys.argv[1])
    z, x0, y0, w, h, out = int(sys.argv[2]), *map(int, sys.argv[3:7]), sys.argv[7]
    grid = zs[z][0][2]
    rnd = random.Random(7)
    palette, index, cells = [], {}, []
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            ls = layers(grid[y][x], rnd)
            key = json.dumps(ls)
            if key not in index:
                index[key] = len(palette)
                palette.append(ls)
            cells.append(index[key])
    json.dump({'w': w, 'h': h, 'palette': palette, 'cells': cells}, open(out, 'w'))


if __name__ == '__main__':
    main()
