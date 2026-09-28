class_name TurtleNPC
extends StaticBody2D

const DMI_SPRITE_SHEET_SCRIPT = preload(
	"res://core/assets/dmi_sprite_sheet.gd"
)
const DMI_PATH := (
	"res://assets/vendor/hu2/Icons/Characters/Turtle.dmi"
)

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	_apply_facing(&"down")

func get_interaction_label() -> String:
	return "Talk to Turtle"

func interact(actor: Node) -> void:
	if actor is Node2D:
		_face_actor(actor as Node2D)

	var dialogue := get_tree().get_first_node_in_group(
		"dialogue_ui"
	) as DialogueBox
	if dialogue == null:
		return

	dialogue.show_dialogue(
		[
			"The sea is peaceful today.",
			"Master Roshi may act carefree, but his training is serious.",
			"Rest inside Kame House whenever you need to recover."
		],
		"Turtle"
	)

func _face_actor(actor: Node2D) -> void:
	var direction: Vector2 = actor.global_position - global_position
	if direction.is_zero_approx():
		return

	if absf(direction.x) > absf(direction.y):
		_apply_facing(
			&"right" if direction.x > 0.0 else &"left"
		)
	else:
		_apply_facing(
			&"down" if direction.y > 0.0 else &"up"
		)

func _apply_facing(facing: StringName) -> void:
	var dmi = DMI_SPRITE_SHEET_SCRIPT.load_file(DMI_PATH)
	if dmi == null:
		return

	var state: StringName = &""
	if not dmi.has_state(state):
		state = &"movement"

	var texture: Texture2D = dmi.get_frame_texture(
		state,
		facing,
		0
	)
	if texture != null:
		sprite.texture = texture
