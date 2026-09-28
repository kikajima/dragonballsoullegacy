class_name DmiSpriteSheet
extends RefCounted

const PNG_SIGNATURE_SIZE := 8
const MAX_METADATA_BYTES := 1024 * 1024

static var _loaded_cache: Dictionary = {}

var source_path: String = ""
var texture: Texture2D
var frame_size: Vector2i = Vector2i(32, 32)
var states: Dictionary = {}
var _sheet_columns: int = 1

static func load_file(path: String) -> DmiSpriteSheet:
	var cached: Variant = _loaded_cache.get(path, null)
	if cached is DmiSpriteSheet:
		return cached as DmiSpriteSheet

	var sheet := DmiSpriteSheet.new()
	if sheet._load(path):
		_loaded_cache[path] = sheet
		return sheet
	return null

func has_state(state_name: StringName) -> bool:
	return states.has(String(state_name))

func get_frame_count(state_name: StringName) -> int:
	var state: Dictionary = states.get(String(state_name), {})
	if state.is_empty():
		return 0
	return int(state.get("frames", 1))

func get_frame_delay(state_name: StringName, frame_index: int) -> float:
	var state: Dictionary = states.get(String(state_name), {})
	if state.is_empty():
		return 1.0

	var delays: PackedFloat32Array = state.get(
		"delay",
		PackedFloat32Array()
	)
	if frame_index >= 0 and frame_index < delays.size():
		return maxf(delays[frame_index], 0.01)

	return 1.0

func get_frame_texture(
	state_name: StringName,
	facing: StringName,
	frame_index: int
) -> AtlasTexture:
	var state: Dictionary = states.get(String(state_name), {})
	if state.is_empty() or texture == null:
		return null

	var frames: int = int(state.get("frames", 1))
	if frame_index < 0 or frame_index >= frames:
		return null

	var dirs: int = int(state.get("dirs", 1))
	var direction_index := _direction_index(dirs, facing)
	var tile_index: int = (
		int(state.get("tile_start", 0))
		+ frame_index * dirs
		+ direction_index
	)

	var column := tile_index % _sheet_columns
	var row := tile_index / _sheet_columns

	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(
		Vector2(column * frame_size.x, row * frame_size.y),
		Vector2(frame_size.x, frame_size.y)
	)
	return atlas

func _load(path: String) -> bool:
	source_path = path
	if not FileAccess.file_exists(path):
		push_warning("DMI nao encontrado: %s" % path)
		return false

	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() <= PNG_SIGNATURE_SIZE:
		push_warning("DMI vazio ou invalido: %s" % path)
		return false

	var image := Image.new()
	var image_error := image.load_png_from_buffer(bytes)
	if image_error != OK:
		push_warning(
			"Nao foi possivel decodificar o PNG interno do DMI %s (erro %s)."
			% [path, image_error]
		)
		return false

	var description := _extract_dmi_description(bytes)
	if description.is_empty():
		push_warning("Metadata DMI nao encontrada em: %s" % path)
		return false

	if not _parse_metadata(description):
		push_warning("Metadata DMI invalida em: %s" % path)
		return false

	_sheet_columns = maxi(image.get_width() / frame_size.x, 1)
	texture = ImageTexture.create_from_image(image)
	return texture != null

func _extract_dmi_description(bytes: PackedByteArray) -> String:
	var offset := PNG_SIGNATURE_SIZE

	while offset + 12 <= bytes.size():
		var chunk_length := _read_u32_be(bytes, offset)
		var type_start := offset + 4
		var data_start := offset + 8
		var data_end := data_start + chunk_length

		if chunk_length < 0 or data_end + 4 > bytes.size():
			return ""

		var chunk_type := bytes.slice(
			type_start,
			type_start + 4
		).get_string_from_ascii()

		if chunk_type == "zTXt":
			var separator := _find_zero(bytes, data_start, data_end)
			if separator >= data_start and separator + 2 <= data_end:
				var keyword := bytes.slice(
					data_start,
					separator
				).get_string_from_ascii()

				var compression_method := int(bytes[separator + 1])
				if keyword == "Description" and compression_method == 0:
					var compressed := bytes.slice(separator + 2, data_end)
					var decompressed := compressed.decompress_dynamic(
						MAX_METADATA_BYTES,
						FileAccess.COMPRESSION_DEFLATE
					)
					if not decompressed.is_empty():
						return decompressed.get_string_from_utf8()

		elif chunk_type == "tEXt":
			var separator := _find_zero(bytes, data_start, data_end)
			if separator >= data_start:
				var keyword := bytes.slice(
					data_start,
					separator
				).get_string_from_ascii()
				if keyword == "Description":
					return bytes.slice(
						separator + 1,
						data_end
					).get_string_from_utf8()

		if chunk_type == "IEND":
			break

		offset = data_end + 4

	return ""

func _parse_metadata(description: String) -> bool:
	states.clear()

	var current_state: Dictionary = {}
	var tile_cursor := 0

	for raw_line in description.split("\n"):
		var line := String(raw_line).strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue

		var separator := line.find("=")
		if separator < 0:
			continue

		var key := line.substr(0, separator).strip_edges()
		var value := line.substr(separator + 1).strip_edges()

		match key:
			"width":
				frame_size.x = maxi(int(value), 1)
			"height":
				frame_size.y = maxi(int(value), 1)
			"state":
				if not current_state.is_empty():
					tile_cursor = _finalize_state(
						current_state,
						tile_cursor
					)

				current_state = {
					"name": _unquote(value),
					"dirs": 1,
					"frames": 1,
					"delay": PackedFloat32Array(),
					"loop": 0,
					"rewind": 0,
					"movement": 0,
				}
			"dirs":
				if not current_state.is_empty():
					current_state["dirs"] = maxi(int(value), 1)
			"frames":
				if not current_state.is_empty():
					current_state["frames"] = maxi(int(value), 1)
			"delay":
				if not current_state.is_empty():
					current_state["delay"] = _parse_delays(value)
			"loop":
				if not current_state.is_empty():
					current_state["loop"] = int(value)
			"rewind":
				if not current_state.is_empty():
					current_state["rewind"] = int(value)
			"movement":
				if not current_state.is_empty():
					current_state["movement"] = int(value)

	if not current_state.is_empty():
		_finalize_state(current_state, tile_cursor)

	return (
		frame_size.x > 0
		and frame_size.y > 0
		and not states.is_empty()
	)

func _finalize_state(state: Dictionary, tile_cursor: int) -> int:
	state["tile_start"] = tile_cursor

	var state_name := String(state.get("name", ""))
	states[state_name] = state.duplicate(true)

	return (
		tile_cursor
		+ int(state.get("dirs", 1))
		* int(state.get("frames", 1))
	)

func _parse_delays(value: String) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	for part in value.split(","):
		var trimmed := String(part).strip_edges()
		if not trimmed.is_empty():
			result.append(float(trimmed))
	return result

func _unquote(value: String) -> String:
	if (
		value.length() >= 2
		and value.begins_with("\"")
		and value.ends_with("\"")
	):
		return value.substr(1, value.length() - 2)
	return value

func _direction_index(dirs: int, facing: StringName) -> int:
	if dirs <= 1:
		return 0

	# BYOND DMI cardinal order:
	# SOUTH, NORTH, EAST, WEST.
	match facing:
		&"down":
			return 0
		&"up":
			return mini(1, dirs - 1)
		&"right":
			return mini(2, dirs - 1)
		&"left":
			return mini(3, dirs - 1)

	return 0

func _read_u32_be(bytes: PackedByteArray, offset: int) -> int:
	if offset < 0 or offset + 4 > bytes.size():
		return -1

	return (
		(int(bytes[offset]) << 24)
		| (int(bytes[offset + 1]) << 16)
		| (int(bytes[offset + 2]) << 8)
		| int(bytes[offset + 3])
	)

func _find_zero(
	bytes: PackedByteArray,
	start: int,
	end: int
) -> int:
	for index in range(start, end):
		if bytes[index] == 0:
			return index
	return -1
