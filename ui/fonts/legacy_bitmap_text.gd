class_name LegacyBitmapText
extends Control

enum FontMode {
	MENU,
	COMBO_NUMBERS,
}

@export_enum("Menu", "Combo Numbers")
var font_mode: int = FontMode.MENU

@export var text: String = ""
@export var render_scale: float = 1.0
@export var glyph_advance: float = 6.0
@export var horizontal_alignment: int = 0
@export var vertical_center: bool = false

@export_file("*.png")
var menu_font_path: String = (
	"res://assets/ui/fonts/legacy/processed/menu_font.png"
)

@export_file("*.png")
var combo_numbers_path: String = (
	"res://assets/ui/fonts/legacy/processed/combo_numbers.png"
)

var _texture: Texture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load_texture()

func set_text(value: String) -> void:
	if text == value:
		return

	text = value
	queue_redraw()

func get_text_width() -> float:
	if text.is_empty():
		return 0.0

	return maxf(
		0.0,
		(float(text.length()) * glyph_advance)
			* render_scale
	)

func _load_texture() -> void:
	var path: String = (
		menu_font_path
		if font_mode == FontMode.MENU
		else combo_numbers_path
	)

	if ResourceLoader.exists(path):
		_texture = load(path) as Texture2D

	queue_redraw()

func _draw() -> void:
	if _texture == null or text.is_empty():
		return

	var source_size: Vector2 = _get_source_cell_size()
	var advance: float = glyph_advance * render_scale
	var line_width: float = get_text_width()
	var cursor_x: float = 0.0

	if horizontal_alignment == 1:
		cursor_x = (size.x - line_width) * 0.5
	elif horizontal_alignment == 2:
		cursor_x = size.x - line_width

	var draw_height: float = source_size.y * render_scale
	var cursor_y: float = 0.0

	if vertical_center:
		cursor_y = (size.y - draw_height) * 0.5

	for character in text:
		if character == " ":
			cursor_x += advance
			continue

		var glyph_index: int = _get_glyph_index(character)

		if glyph_index >= 0:
			var source := Rect2(
				Vector2(
					float(glyph_index) * source_size.x,
					0.0
				),
				source_size
			)
			var destination := Rect2(
				Vector2(cursor_x, cursor_y),
				source_size * render_scale
			)

			draw_texture_rect_region(
				_texture,
				destination,
				source
			)
		elif font_mode == FontMode.MENU:
			_draw_manual_menu_glyph(
				character,
				Vector2(cursor_x, cursor_y)
			)

		cursor_x += advance

func _get_source_cell_size() -> Vector2:
	if font_mode == FontMode.COMBO_NUMBERS:
		return Vector2(16.0, 20.0)

	return Vector2(11.0, 12.0)

func _get_glyph_index(character: String) -> int:
	if character.is_empty():
		return -1

	var code: int = character.unicode_at(0)

	if font_mode == FontMode.COMBO_NUMBERS:
		if code >= 48 and code <= 57:
			return code - 48
		return -1

	if code >= 65 and code <= 90:
		return code - 65

	if code >= 97 and code <= 122:
		return 26 + code - 97

	if code >= 48 and code <= 57:
		return 52 + code - 48

	match character:
		"é":
			return 62
		":":
			return 63
		"+":
			return 65
		"-":
			return 66
		",":
			return 67
		".":
			return 68
		"!":
			return 69
		"?":
			return 70
		"'":
			return 71
		"’":
			return 71
		"_":
			return 77
		_:
			return -1

func _draw_manual_menu_glyph(
	character: String,
	position: Vector2
) -> void:
	if character != "/":
		return

	var scale_value: float = maxf(render_scale, 0.01)
	var top := position + Vector2(4.0, 1.0) * scale_value
	var bottom := position + Vector2(1.0, 8.0) * scale_value

	draw_line(
		top,
		bottom,
		Color.WHITE,
		maxf(1.0 * scale_value, 1.0)
	)
