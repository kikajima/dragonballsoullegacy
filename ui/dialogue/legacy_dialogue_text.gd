class_name LegacyDialogueText
extends Control

@export var character_advance: int = 7
@export var line_height: int = 12
@export var glyph_size: Vector2i = Vector2i(15, 15)
@export var glyph_origin: Vector2i = Vector2i(172, 3)
@export var glyph_draw_offset: Vector2 = Vector2(-3, -2)

var _sheet: Texture2D
var _raw_text: String = ""
var _wrapped_text: String = ""
var _visible_characters: int = 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

func set_sheet(sheet: Texture2D) -> void:
	_sheet = sheet
	queue_redraw()

func set_text(value: String) -> void:
	_raw_text = value
	_wrapped_text = _wrap_text(_raw_text)
	_visible_characters = 0
	queue_redraw()

func set_visible_characters(count: int) -> void:
	_visible_characters = clampi(
		count,
		0,
		_wrapped_text.length()
	)
	queue_redraw()

func show_all() -> void:
	_visible_characters = _wrapped_text.length()
	queue_redraw()

func get_character_count() -> int:
	return _wrapped_text.length()

func _draw() -> void:
	if _sheet == null or _wrapped_text.is_empty():
		return

	var cursor := Vector2.ZERO

	for index in range(_wrapped_text.length()):
		if index >= _visible_characters:
			break

		var character: String = _wrapped_text.substr(index, 1)

		if character == "\n":
			cursor.x = 0.0
			cursor.y += float(line_height)
			continue

		if character == " ":
			cursor.x += float(character_advance)
			continue

		var normalized: String = _normalize_character(character)
		var cell: Vector2i = _get_glyph_cell(normalized)

		if cell.x >= 0 and cell.y >= 0:
			var source := Rect2(
				Vector2(
					glyph_origin.x + cell.x * glyph_size.x,
					glyph_origin.y + cell.y * glyph_size.y
				),
				Vector2(glyph_size)
			)
			var destination := Rect2(
				cursor + glyph_draw_offset,
				Vector2(glyph_size)
			)

			draw_texture_rect_region(
				_sheet,
				destination,
				source
			)

		cursor.x += float(character_advance)

func _wrap_text(value: String) -> String:
	if value.is_empty():
		return ""

	var max_columns: int = maxi(
		int(floor(size.x / float(maxi(character_advance, 1)))),
		1
	)
	var output_lines := PackedStringArray()
	var paragraphs := value.split("\n", true)

	for paragraph in paragraphs:
		if paragraph.is_empty():
			output_lines.append("")
			continue

		var words := paragraph.split(" ", false)
		var current_line: String = ""

		for word in words:
			var safe_word: String = String(word)

			if current_line.is_empty():
				current_line = safe_word
				continue

			var candidate_length: int = (
				current_line.length()
				+ 1
				+ safe_word.length()
			)

			if candidate_length <= max_columns:
				current_line += " " + safe_word
			else:
				output_lines.append(current_line)
				current_line = safe_word

		if not current_line.is_empty():
			output_lines.append(current_line)

	return "\n".join(output_lines)

func _get_glyph_cell(character: String) -> Vector2i:
	if character.is_empty():
		return Vector2i(-1, -1)

	var code: int = character.unicode_at(0)

	if code >= 65 and code <= 77:
		return Vector2i(code - 65, 0)

	if code >= 78 and code <= 90:
		return Vector2i(code - 78, 1)

	if code >= 97 and code <= 109:
		return Vector2i(code - 97, 2)

	if code >= 110 and code <= 122:
		return Vector2i(code - 110, 3)

	if code >= 48 and code <= 57:
		return Vector2i(code - 48, 4)

	match character:
		"?":
			return Vector2i(11, 4)
		"!":
			return Vector2i(12, 4)
		"'":
			return Vector2i(0, 5)
		",":
			return Vector2i(1, 5)
		".":
			return Vector2i(2, 5)
		":":
			return Vector2i(3, 5)
		";":
			return Vector2i(4, 5)
		_:
			return Vector2i(-1, -1)

func _normalize_character(character: String) -> String:
	match character:
		"á", "à", "ã", "â", "ä", "Á", "À", "Ã", "Â", "Ä":
			return "a" if character.to_lower() == character else "A"
		"é", "è", "ê", "ë", "É", "È", "Ê", "Ë":
			return "e" if character.to_lower() == character else "E"
		"í", "ì", "î", "ï", "Í", "Ì", "Î", "Ï":
			return "i" if character.to_lower() == character else "I"
		"ó", "ò", "õ", "ô", "ö", "Ó", "Ò", "Õ", "Ô", "Ö":
			return "o" if character.to_lower() == character else "O"
		"ú", "ù", "û", "ü", "Ú", "Ù", "Û", "Ü":
			return "u" if character.to_lower() == character else "U"
		"ç", "Ç":
			return "c" if character == "ç" else "C"
		"’", "´", "`":
			return "'"
		_:
			return character
