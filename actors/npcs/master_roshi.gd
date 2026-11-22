class_name MasterRoshiNPC
extends StaticBody2D

const DMI_SPRITE_SHEET_SCRIPT = preload(
	"res://core/assets/dmi_sprite_sheet.gd"
)

const SPEAKER_NAME: String = "Master Roshi"
const NPC_ID: StringName = &"roshi"

const DMI_PATH := (
	"res://assets/vendor/hu2/Icons/Characters/MasterRoshi.dmi"
)

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	_load_roshi_sprite()
	NpcQuestMarker.attach(self, NPC_ID, 30.0)

func get_interaction_label() -> String:
	return "Talk to Master Roshi"

func interact(actor: Node) -> void:
	if actor is Node2D:
		_face_actor(actor as Node2D)
	QuestTalk.talk(self, NPC_ID, SPEAKER_NAME, [
		"Keep training. A martial artist never stops improving.",
		"Rest in Kame House whenever you need to.",
		"And remember: work hard, study well, eat and sleep plenty!",
	])

func on_ki_blast_blocked(projectile_direction: Vector2) -> void:
	if projectile_direction.is_zero_approx():
		return
	_face_direction(-projectile_direction.normalized())

func _load_roshi_sprite() -> void:
	var dmi = DMI_SPRITE_SHEET_SCRIPT.load_file(DMI_PATH)
	if dmi == null:
		return

	var state: StringName = &""
	if not dmi.has_state(state):
		state = &"movement"

	var texture: Texture2D = dmi.get_frame_texture(
		state,
		&"down",
		0
	)
	if texture != null:
		sprite.texture = texture

func _face_actor(actor: Node2D) -> void:
	_face_direction(actor.global_position - global_position)

func _face_direction(direction: Vector2) -> void:
	if direction.is_zero_approx():
		return

	var facing: StringName = &"down"
	if absf(direction.x) > absf(direction.y):
		facing = &"right" if direction.x > 0.0 else &"left"
	else:
		facing = &"down" if direction.y > 0.0 else &"up"

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
