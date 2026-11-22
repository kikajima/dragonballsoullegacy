class_name BakedShadowStripper
extends RefCounted

# HU2 character frames carry a baked ground shadow: a pure black (#000000)
# blob under the feet. Outlines use dark tints, never pure black, so the
# shadow is the pure-black region connected to the bottom rows of the
# figure. While flying, actors swap to a copy of their SpriteFrames with that
# blob removed (the FlightShadow on the ground replaces it).

# Pure-black pixels this many rows above the figure's lowest row seed the
# flood fill; hair and outlines higher up are never reached.
const SEED_ROWS := 4

static var _airborne_of: Dictionary = {} # ground frames id -> airborne frames
static var _ground_of: Dictionary = {}   # airborne frames id -> ground frames
static var _texture_cache: Dictionary = {}
static var _atlas_images: Dictionary = {}

static func is_airborne_set(frames: SpriteFrames) -> bool:
	return frames != null and _ground_of.has(frames.get_instance_id())

static func ground_set(frames: SpriteFrames) -> SpriteFrames:
	if frames == null:
		return null
	var ground: Variant = _ground_of.get(frames.get_instance_id())
	return ground as SpriteFrames if ground != null and is_instance_valid(ground) else frames

static func airborne_set(frames: SpriteFrames) -> SpriteFrames:
	if frames == null or is_airborne_set(frames):
		return frames
	var id := frames.get_instance_id()
	var cached: Variant = _airborne_of.get(id)
	if cached != null and is_instance_valid(cached) and _matches(frames, cached):
		return cached
	var air := SpriteFrames.new()
	if air.has_animation(&"default"):
		air.remove_animation(&"default")
	for animation in frames.get_animation_names():
		air.add_animation(animation)
		air.set_animation_loop(animation, frames.get_animation_loop(animation))
		air.set_animation_speed(animation, frames.get_animation_speed(animation))
		for index in frames.get_frame_count(animation):
			air.add_frame(
				animation,
				strip_texture(frames.get_frame_texture(animation, index)),
				frames.get_frame_duration(animation, index)
			)
	_airborne_of[id] = air
	_ground_of[air.get_instance_id()] = frames
	return air

# Swaps the sprite's frames keeping the current animation, frame and timing.
static func swap(sprite: AnimatedSprite2D, frames: SpriteFrames) -> void:
	if sprite == null or frames == null or sprite.sprite_frames == frames:
		return
	var animation := sprite.animation
	var frame := sprite.frame
	var progress := sprite.frame_progress
	var playing := sprite.is_playing()
	var speed := sprite.speed_scale
	sprite.sprite_frames = frames
	if frames.has_animation(animation):
		sprite.animation = animation
		sprite.set_frame_and_progress(frame, progress)
		if playing:
			sprite.play(animation, speed)
	sprite.speed_scale = speed

static func strip_texture(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	var key := _texture_key(texture)
	if _texture_cache.has(key):
		return _texture_cache[key]
	var image := _texture_image(texture)
	if image == null:
		return texture
	var result: Texture2D = texture
	if strip_image(image):
		result = ImageTexture.create_from_image(image)
	_texture_cache[key] = result
	return result

# Removes the baked shadow in place. Returns true if anything was removed.
static func strip_image(image: Image) -> bool:
	var size := image.get_size()
	var lowest := -1
	for y in range(size.y - 1, -1, -1):
		for x in size.x:
			if image.get_pixel(x, y).a > 0.01:
				lowest = y
				break
		if lowest >= 0:
			break
	if lowest < 0:
		return false
	var stack: Array[Vector2i] = []
	var seen := {}
	for y in range(maxi(lowest - SEED_ROWS + 1, 0), lowest + 1):
		for x in size.x:
			if _is_shadow(image.get_pixel(x, y)):
				stack.append(Vector2i(x, y))
	var removed := false
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if seen.has(p):
			continue
		seen[p] = true
		if not _is_shadow(image.get_pixelv(p)):
			continue
		image.set_pixelv(p, Color(0, 0, 0, 0))
		removed = true
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = p + d
			if n.x >= 0 and n.y >= 0 and n.x < size.x and n.y < size.y and not seen.has(n):
				stack.append(n)
	return removed

static func _is_shadow(color: Color) -> bool:
	return color.a > 0.99 and color.r8 == 0 and color.g8 == 0 and color.b8 == 0

static func _texture_image(texture: Texture2D) -> Image:
	var image: Image
	if texture is AtlasTexture:
		var atlas := texture as AtlasTexture
		if atlas.atlas == null:
			return null
		var source_id := atlas.atlas.get_instance_id()
		if not _atlas_images.has(source_id):
			var full := atlas.atlas.get_image()
			if full == null:
				return null
			full.convert(Image.FORMAT_RGBA8)
			_atlas_images[source_id] = full
		image = (_atlas_images[source_id] as Image).get_region(Rect2i(atlas.region))
	else:
		image = texture.get_image()
		if image == null:
			return null
		image = image.duplicate()
		image.convert(Image.FORMAT_RGBA8)
	return image

static func _texture_key(texture: Texture2D) -> String:
	if texture is AtlasTexture:
		var atlas := texture as AtlasTexture
		return "%d:%s" % [atlas.atlas.get_instance_id() if atlas.atlas != null else 0, atlas.region]
	return str(texture.get_instance_id())

static func _matches(frames: SpriteFrames, air: SpriteFrames) -> bool:
	var names := frames.get_animation_names()
	if names.size() != air.get_animation_names().size():
		return false
	for animation in names:
		if not air.has_animation(animation) or air.get_frame_count(animation) != frames.get_frame_count(animation):
			return false
	return true
