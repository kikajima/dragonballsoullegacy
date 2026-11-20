extends RefCounted

static var _textures: Dictionary = {}

static func apply(surface: Polygon2D, sheet_name: String, state: StringName) -> void:
	if surface == null:
		return
	var key := sheet_name + ":" + String(state)
	if not _textures.has(key):
		var sheet := DmiSpriteSheet.load_file("res://assets/vendor/hu2/Icons/Turfs/" + sheet_name + ".dmi")
		if sheet == null or not sheet.has_state(state):
			push_warning("Missing terrain state: " + key)
			return
		# Repeat the extracted tile, not the entire DMI atlas.
		_textures[key] = ImageTexture.create_from_image(sheet.get_frame_texture(state, &"down", 0).get_image())
	surface.texture = _textures[key]
	surface.uv = surface.polygon
	surface.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	surface.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	surface.color = Color.WHITE
