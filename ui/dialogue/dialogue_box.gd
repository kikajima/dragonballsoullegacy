class_name DialogueBox
extends Control

signal dialogue_started
signal line_changed(index: int, text: String)
signal dialogue_finished

enum DialogueState {
	CLOSED,
	OPENING,
	TYPING,
	READY,
	CLOSING,
}

@export_file("*.png")
var dialogue_sheet_path: String = (
	"res://assets/ui/legacy/processed/dialogue_box_font.png"
)

@export var open_duration: float = 0.16
@export var close_duration: float = 0.12
@export var characters_per_second: float = 45.0
@export var collapsed_width: float = 10.0
@export var expanded_width: float = 160.0

@onready var dialogue_root: Control = $DialogueRoot
@onready var portrait_background: ColorRect = (
	$DialogueRoot/PortraitBackground
)
@onready var portrait_border: NinePatchRect = (
	$DialogueRoot/PortraitBorder
)
@onready var portrait: TextureRect = (
	$DialogueRoot/Portrait
)
@onready var text_clip: Control = (
	$DialogueRoot/TextClip
)
@onready var text_frame: TextureRect = (
	$DialogueRoot/TextClip/Frame
)
@onready var text_renderer: LegacyDialogueText = (
	$DialogueRoot/TextClip/LegacyText
)

const DIALOGUE_FRAME_REGION := Rect2(6, 16, 160, 64)

# O atlas limpo enviado pelo usuário é exatamente a arte original ampliada.
# Em vez de recortar e remontar regiões individualmente, reduzimos o atlas
# inteiro à malha original. Isso preserva perfeitamente as coordenadas da
# moldura e da fonte.
const CLEAN_ATLAS_MIN_WIDTH: int = 1000
const NORMALIZED_ATLAS_SIZE := Vector2i(371, 98)
const FONT_BACKGROUND_REGION := Rect2i(170, 0, 201, 98)

var _sheet: Texture2D
var _pages: Array[String] = []
var _speaker: String = ""
var _page_index: int = 0
var _state: DialogueState = DialogueState.CLOSED
var _animation_time: float = 0.0
var _typing_progress: float = 0.0
var _previous_pause_state: bool = false

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load_legacy_sheet()

func _process(delta: float) -> void:
	match _state:
		DialogueState.OPENING:
			_process_opening(delta)
		DialogueState.TYPING:
			_process_typing(delta)
		DialogueState.CLOSING:
			_process_closing(delta)
		_:
			pass

func show_dialogue(
	lines: Array[String],
	speaker: String = "",
	portrait_texture_path: String = ""
) -> void:
	if lines.is_empty():
		return

	if _sheet == null:
		_load_legacy_sheet()

	_pages = lines.duplicate()
	_speaker = speaker
	_page_index = 0
	_typing_progress = 0.0
	_previous_pause_state = get_tree().paused

	_apply_portrait(portrait_texture_path)

	get_tree().paused = true
	visible = true

	text_clip.size.x = collapsed_width
	text_renderer.set_text("")
	text_renderer.set_visible_characters(0)

	_animation_time = 0.0
	_state = DialogueState.OPENING
	dialogue_started.emit()

func is_open() -> bool:
	return visible

func advance() -> void:
	if not visible:
		return

	match _state:
		DialogueState.OPENING:
			text_clip.size.x = expanded_width
			_start_current_page()
		DialogueState.TYPING:
			text_renderer.show_all()
			_typing_progress = float(
				text_renderer.get_character_count()
			)
			_state = DialogueState.READY
		DialogueState.READY:
			_page_index += 1
			if _page_index >= _pages.size():
				close_dialogue()
			else:
				_start_current_page()
		DialogueState.CLOSING:
			_finish_close()
		_:
			pass

func close_dialogue() -> void:
	if not visible:
		return

	if _state == DialogueState.CLOSING:
		return

	_animation_time = 0.0
	_state = DialogueState.CLOSING

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if (
		event.is_action_pressed("interact")
		or event.is_action_pressed("ui_accept")
	):
		advance()
		get_viewport().set_input_as_handled()

func _process_opening(delta: float) -> void:
	_animation_time += delta
	var safe_duration: float = maxf(open_duration, 0.001)
	var ratio: float = clampf(
		_animation_time / safe_duration,
		0.0,
		1.0
	)

	text_clip.size.x = roundf(
		lerpf(collapsed_width, expanded_width, ratio)
	)

	if ratio >= 1.0:
		text_clip.size.x = expanded_width
		_start_current_page()

func _process_typing(delta: float) -> void:
	_typing_progress += (
		delta * maxf(characters_per_second, 1.0)
	)
	var character_count: int = (
		text_renderer.get_character_count()
	)
	var visible_count: int = mini(
		int(floor(_typing_progress)),
		character_count
	)

	text_renderer.set_visible_characters(visible_count)

	if visible_count >= character_count:
		_state = DialogueState.READY

func _process_closing(delta: float) -> void:
	_animation_time += delta
	var safe_duration: float = maxf(close_duration, 0.001)
	var ratio: float = clampf(
		_animation_time / safe_duration,
		0.0,
		1.0
	)

	text_clip.size.x = roundf(
		lerpf(expanded_width, collapsed_width, ratio)
	)

	if ratio >= 1.0:
		_finish_close()

func _start_current_page() -> void:
	if _page_index < 0 or _page_index >= _pages.size():
		close_dialogue()
		return

	var current_text: String = _pages[_page_index]
	text_renderer.set_text(current_text)
	text_renderer.set_visible_characters(0)

	_typing_progress = 0.0
	_state = DialogueState.TYPING

	line_changed.emit(_page_index, current_text)

func _finish_close() -> void:
	visible = false
	_pages.clear()
	_page_index = 0
	_typing_progress = 0.0
	text_renderer.set_text("")
	text_clip.size.x = collapsed_width
	_state = DialogueState.CLOSED

	get_tree().paused = _previous_pause_state
	dialogue_finished.emit()

func _load_legacy_sheet() -> void:
	if not ResourceLoader.exists(dialogue_sheet_path):
		push_warning(
			"DialogueBox: asset local não encontrado em %s"
			% dialogue_sheet_path
		)
		return

	var source_texture := load(
		dialogue_sheet_path
	) as Texture2D
	if source_texture == null:
		return

	var source_image: Image = source_texture.get_image()
	if source_image == null:
		return

	var normalized_image: Image

	if source_image.get_width() >= CLEAN_ATLAS_MIN_WIDTH:
		normalized_image = _normalize_clean_atlas(source_image)
	else:
		normalized_image = _normalize_original_atlas(source_image)

	_sheet = ImageTexture.create_from_image(normalized_image)

	var frame_texture := _atlas_region(
		DIALOGUE_FRAME_REGION
	)
	text_frame.texture = frame_texture
	portrait_border.texture = frame_texture
	text_renderer.set_sheet(_sheet)

func _normalize_clean_atlas(source_image: Image) -> Image:
	var normalized: Image = source_image.duplicate() as Image
	normalized.resize(
		NORMALIZED_ATLAS_SIZE.x,
		NORMALIZED_ATLAS_SIZE.y,
		Image.INTERPOLATE_NEAREST
	)

	# O fundo preto é necessário dentro da moldura verde, então removemos
	# preto somente da área da fonte à direita do atlas.
	_make_black_transparent_region(
		normalized,
		FONT_BACKGROUND_REGION
	)

	return normalized

func _normalize_original_atlas(source_image: Image) -> Image:
	var normalized := source_image.duplicate()

	for y in range(normalized.get_height()):
		for x in range(normalized.get_width()):
			var pixel: Color = normalized.get_pixel(x, y)
			var red: int = int(round(pixel.r * 255.0))
			var green: int = int(round(pixel.g * 255.0))
			var blue: int = int(round(pixel.b * 255.0))

			var is_background_blue: bool = (
				(red == 68 and green == 140 and blue == 203)
				or
				(red == 0 and green == 174 and blue == 239)
			)

			if is_background_blue:
				pixel.a = 0.0
				normalized.set_pixel(x, y, pixel)

	return normalized

func _make_black_transparent_region(
	image: Image,
	region: Rect2i
) -> void:
	var start_x: int = clampi(region.position.x, 0, image.get_width())
	var start_y: int = clampi(region.position.y, 0, image.get_height())
	var end_x: int = clampi(
		region.end.x,
		start_x,
		image.get_width()
	)
	var end_y: int = clampi(
		region.end.y,
		start_y,
		image.get_height()
	)

	for y in range(start_y, end_y):
		for x in range(start_x, end_x):
			var pixel: Color = image.get_pixel(x, y)

			if (
				pixel.r <= 0.02
				and pixel.g <= 0.02
				and pixel.b <= 0.02
			):
				pixel.a = 0.0
				image.set_pixel(x, y, pixel)

func _atlas_region(region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = _sheet
	atlas.region = region
	return atlas

func _apply_portrait(path: String) -> void:
	portrait.visible = false

	if not path.is_empty() and ResourceLoader.exists(path):
		var portrait_texture := load(path) as Texture2D
		if portrait_texture != null:
			portrait.texture = portrait_texture
			portrait.visible = true

	# Character portraits keep their original silver frame from the portrait
	# sheet, while the dialogue HUD adds its golden frame around the outside.
	# The cyan fallback background is only used when no portrait is available.
	portrait_background.visible = not portrait.visible
	portrait_border.visible = _sheet != null
