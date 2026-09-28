class_name DmiEffectSprite2D
extends AnimatedSprite2D

const DMI_SPRITE_SHEET_SCRIPT = preload(
	"res://core/assets/dmi_sprite_sheet.gd"
)
const DMI_EFFECT_FPS := 10.0

@export_file("*.dmi")
var dmi_path: String = ""

@export var dmi_state: StringName = &""
@export_enum("down", "up", "right", "left")
var facing: String = "down"
@export var loop_animation: bool = true
@export var play_on_ready: bool = true

func _ready() -> void:
	_build_from_dmi()

func _build_from_dmi() -> void:
	if dmi_path.is_empty() or dmi_state == &"":
		return

	var dmi = DMI_SPRITE_SHEET_SCRIPT.load_file(dmi_path)
	if dmi == null:
		return

	if not dmi.has_state(dmi_state):
		push_warning(
			"Estado DMI '%s' nao encontrado em %s."
			% [dmi_state, dmi_path]
		)
		return

	var frames := SpriteFrames.new()
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")

	frames.add_animation(&"effect")
	frames.set_animation_loop(&"effect", loop_animation)
	frames.set_animation_speed(&"effect", DMI_EFFECT_FPS)

	var frame_count: int = dmi.get_frame_count(dmi_state)
	for frame_index in range(frame_count):
		var frame_texture: AtlasTexture = dmi.get_frame_texture(
			dmi_state,
			StringName(facing),
			frame_index
		)
		if frame_texture == null:
			continue

		frames.add_frame(
			&"effect",
			frame_texture,
			dmi.get_frame_delay(dmi_state, frame_index)
		)

	if frames.get_frame_count(&"effect") <= 0:
		return

	sprite_frames = frames
	animation = &"effect"

	if play_on_ready:
		play(&"effect")
