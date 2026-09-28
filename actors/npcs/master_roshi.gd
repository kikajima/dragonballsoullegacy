class_name MasterRoshiNPC
extends StaticBody2D

const DMI_SPRITE_SHEET_SCRIPT = preload(
	"res://core/assets/dmi_sprite_sheet.gd"
)

const TRAINING_QUEST_ID: StringName = &"training_basics"
const TRAINING_OBJECTIVE_ID: StringName = &"defeat_training_dummy"
const SPEAKER_NAME: String = "Master Roshi"

const DMI_PATH := (
	"res://assets/vendor/hu2/Icons/Characters/MasterRoshi.dmi"
)

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	_load_roshi_sprite()

func get_interaction_label() -> String:
	return "Talk to Master Roshi"

func interact(actor: Node) -> void:
	if actor is Node2D:
		_face_actor(actor as Node2D)

	var dialogue := get_tree().get_first_node_in_group(
		"dialogue_ui"
	) as DialogueBox
	var quests := get_tree().get_first_node_in_group(
		"quest_manager"
	) as QuestManager

	if dialogue == null:
		return

	if quests == null:
		dialogue.show_dialogue(
			["Keep training. A martial artist never stops improving."],
			SPEAKER_NAME
		)
		return

	if quests.is_completed(TRAINING_QUEST_ID):
		dialogue.show_dialogue(
			[
				"You're improving.",
				"Train your body, your Ki, and your judgment. Power alone isn't enough."
			],
			SPEAKER_NAME
		)
		return

	if quests.is_active(TRAINING_QUEST_ID):
		var state := quests.get_quest(TRAINING_QUEST_ID)
		var progress: int = int(state.get("progress", 0))
		var target: int = int(state.get("target_count", 2))
		dialogue.show_dialogue(
			[
				"Keep at it!",
				"Training opponents defeated: %d/%d." % [
					progress,
					target,
				]
			],
			SPEAKER_NAME
		)
		return

	quests.start_simple_quest(
		TRAINING_QUEST_ID,
		"Master Roshi's Basics",
		"Show Master Roshi that your fundamentals are sharp.",
		TRAINING_OBJECTIVE_ID,
		"Defeat the training opponent",
		2,
		50,
		&"senzu_bean",
		1,
		120
	)

	dialogue.show_dialogue(
		[
			"Welcome to my island!",
			"Before chasing stronger techniques, prove your basics.",
			"Defeat the training fighter twice, then come back to me."
		],
		SPEAKER_NAME
	)

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
