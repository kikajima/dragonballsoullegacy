# Kame Island sand

`sand-light-v1.png` is a new texture generated with the built-in imagegen tool, not extracted by REA or copied from HU2. The original output is preserved. `kame_island.gd` samples it at 128x128 with nearest-neighbor filtering, repeats it and clips it to the existing beach polygon. Grass and collision use their existing independent geometry.

Generation prompt:

> Use case: stylized-concept. Asset type: seamless repeating ground texture for a top-down 2D pixel-art island beach game. Create ONLY a flat square of pale warm sandy ground, uniformly filling entire image edge to edge. GBA-era pixel art, strict crisp square pixel clusters, deliberately limited palette of cream, light golden beige and a few muted tan flecks. Very subtle sparse tiny grains and short two-pixel wind marks, mostly quiet flat pale sand. No dunes, shadows, lighting gradient, perspective, objects, shells, rocks, grass, water, border, grid, labels or text. All four edges must tile seamlessly, with identical pale base color near edges. Think a 128 by 128 logical pixel texture enlarged nearest-neighbor. This texture will be repeated and cropped to a beach silhouette around Master Roshi's island, compatible with 32px terrain tiles. Output a single square texture, not a tileset presentation or scene.
