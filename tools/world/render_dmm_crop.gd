extends SceneTree

# Renders a layered tile crop (exported by a .dmm reader) to a PNG, so the
# way reference maps combine HU2 tiles can be studied.
# Usage: Godot --headless --path . --script res://tools/world/render_dmm_crop.gd -- <in.json> <out.png> [tile_px]

var _sheets := {}
var _images := {}
var _tiles := {}

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var size := int(args[2]) if args.size() > 2 else 32
	var w := int(data["w"])
	var h := int(data["h"])
	var out := Image.create(w * size, h * size, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 1))
	var palette: Array = data["palette"]
	var cells: Array = data["cells"]
	var cache := {}
	for i in cells.size():
		var p := int(cells[i])
		if not cache.has(p):
			cache[p] = _compose(palette[p], size)
		var img: Image = cache[p]
		if img != null:
			out.blend_rect(img, Rect2i(0, 0, size, size), Vector2i(i % w, i / w) * size)
	out.save_png(args[1])
	print("rendered ", args[1], " ", out.get_size())
	quit()

func _compose(layers: Array, size: int) -> Image:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for layer in layers:
		var tile := _tile(str(layer[0]), str(layer[1]))
		if tile != null:
			img.blend_rect(tile, Rect2i(0, 0, 32, 32), Vector2i.ZERO)
	if size != 32:
		img.resize(size, size, Image.INTERPOLATE_BILINEAR if size < 32 else Image.INTERPOLATE_NEAREST)
	return img

func _tile(icon: String, state: String) -> Image:
	var key := icon + "|" + state
	if _tiles.has(key):
		return _tiles[key]
	var result: Image = null
	if icon.ends_with(".png"):
		if not _images.has(icon):
			_images[icon] = (load(icon) as Texture2D).get_image() if ResourceLoader.exists(icon) else null
		var big: Image = _images[icon]
		var parts := state.split(",")
		if big != null and parts.size() == 2:
			var tx := int(parts[0])
			var ty := big.get_height() / 32 - 1 - int(parts[1])
			result = big.get_region(Rect2i(tx * 32, ty * 32, 32, 32))
	else:
		if not _sheets.has(icon):
			_sheets[icon] = DmiSpriteSheet.load_file(icon)
		var dmi: DmiSpriteSheet = _sheets[icon]
		if dmi != null and dmi.has_state(StringName(state)):
			result = dmi.get_frame_texture(StringName(state), &"down", 0).get_image()
			result.convert(Image.FORMAT_RGBA8)
	_tiles[key] = result
	return result
