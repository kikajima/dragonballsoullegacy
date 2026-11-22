class_name SwordAnimationLibrary
extends RefCounted

# Builds the sword animations (sword_1/2/3, sword_equip) for a DMI character
# by blending: sword back layer + DMI body frame + sword front layer.
# Layers come from tools/sword/build_sword_overlay.py, which re-poses Future
# Trunks' Legacy of Goku II sword moves on the HU2 Goku frames.

const OVERLAY_PATH := "res://assets/sprites/equipment/sword/sword_overlay.png"
const MANIFEST_PATH := "res://assets/sprites/equipment/sword/sword_overlay.json"
const FRAME_UNIT := 0.1 # seconds per SpriteFrames duration unit at 10 fps

static var _manifest: Dictionary = {}
static var _overlay: Image
static var _cell_cache: Dictionary = {}

static func is_available() -> bool:
	return _load()

static func get_animation_names() -> Array:
	if not _load():
		return []
	return (_manifest["animations"] as Dictionary).keys()

# Total animation time for one facing, in seconds.
static func get_duration(animation: StringName, facing: StringName = &"right") -> float:
	if not _load():
		return 0.0
	var anim: Dictionary = _manifest["animations"].get(String(animation), {})
	var total := 0.0
	for entry in anim.get(String(facing), []):
		total += float(entry["duration"])
	return total

static func add_animations(frames: SpriteFrames, dmi, fps: float) -> bool:
	if frames == null or dmi == null or not _load():
		return false
	var added := false
	var animations: Dictionary = _manifest["animations"]
	for animation_name in animations.keys():
		var per_facing: Dictionary = animations[animation_name]
		for facing in per_facing.keys():
			var full_name := StringName("%s_%s" % [animation_name, facing])
			if frames.has_animation(full_name):
				frames.remove_animation(full_name)
			frames.add_animation(full_name)
			frames.set_animation_loop(full_name, false)
			frames.set_animation_speed(full_name, fps)
			for entry in per_facing[facing]:
				var texture := _compose_frame(dmi, StringName(facing), entry)
				if texture == null:
					continue
				frames.add_frame(
					full_name,
					texture,
					float(entry["duration"]) * fps
				)
				added = true
	return added

# Back/front layer textures for the scabbard on the character's back.
static func get_sheath_textures(facing: StringName, with_sword: bool) -> Array[Texture2D]:
	var result: Array[Texture2D] = [null, null]
	if not _load():
		return result
	var variant := "sheath" if with_sword else "sheath_empty"
	var sheaths: Dictionary = _manifest["sheath"].get(variant, {})
	if not sheaths.has(String(facing)):
		return result
	var index := int(sheaths[String(facing)])
	result[0] = ImageTexture.create_from_image(_cell(index))
	result[1] = ImageTexture.create_from_image(_cell(index + 1))
	return result

static func _compose_frame(dmi, facing: StringName, entry: Dictionary) -> Texture2D:
	var state := StringName(str(entry["state"]))
	if not dmi.has_state(state):
		return null
	var atlas: AtlasTexture = dmi.get_frame_texture(state, facing, int(entry["frame"]))
	if atlas == null or atlas.atlas == null:
		return null
	var body := atlas.atlas.get_image().get_region(Rect2i(atlas.region))
	body.convert(Image.FORMAT_RGBA8)
	_strip_baked_trails(body)
	var cell_size := int(_manifest["cell"])
	var origin := int(_manifest["origin"])
	var index := int(entry["cell"])
	var canvas := _cell(index).duplicate() as Image
	canvas.blend_rect(
		body,
		Rect2i(Vector2i.ZERO, body.get_size()),
		Vector2i(origin, origin + int(entry.get("dy", 0)))
	)
	canvas.blend_rect(_cell(index + 1), Rect2i(0, 0, cell_size, cell_size), Vector2i.ZERO)
	return ImageTexture.create_from_image(canvas)

# HU2 strike frames carry their own white punch swooshes. Those touch the
# transparent background; eye highlights never do.
static func _strip_baked_trails(image: Image) -> void:
	var size := image.get_size()
	var changed := true
	while changed:
		changed = false
		for y in size.y:
			for x in size.x:
				var c := image.get_pixel(x, y)
				if c.a < 0.5 or c.r < 0.97 or c.g < 0.97 or c.b < 0.97:
					continue
				for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var p: Vector2i = Vector2i(x, y) + offset
					if p.x < 0 or p.y < 0 or p.x >= size.x or p.y >= size.y or image.get_pixelv(p).a < 0.1:
						image.set_pixel(x, y, Color.TRANSPARENT)
						changed = true
						break

static func _cell(index: int) -> Image:
	if _cell_cache.has(index):
		return _cell_cache[index]
	var cell_size := int(_manifest["cell"])
	var columns := int(_manifest["columns"])
	var region := Rect2i(
		(index % columns) * cell_size,
		(index / columns) * cell_size,
		cell_size,
		cell_size
	)
	var image := _overlay.get_region(region)
	image.convert(Image.FORMAT_RGBA8)
	_cell_cache[index] = image
	return image

static func _load() -> bool:
	if not _manifest.is_empty() and _overlay != null:
		return true
	if not FileAccess.file_exists(MANIFEST_PATH) or not ResourceLoader.exists(OVERLAY_PATH):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not parsed is Dictionary:
		return false
	var texture := load(OVERLAY_PATH) as Texture2D
	if texture == null:
		return false
	_overlay = texture.get_image()
	_overlay.convert(Image.FORMAT_RGBA8)
	_manifest = parsed
	return true
