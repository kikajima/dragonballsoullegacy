class_name MasterRoshiNPC
extends StaticBody2D

const DMI_SPRITE_SHEET_SCRIPT = preload(
	"res://core/assets/dmi_sprite_sheet.gd"
)

const TRAINING_QUEST_ID: StringName = &"training_basics"
const TRAINING_OBJECTIVE_ID: StringName = &"defeat_training_dummy"
const KI_QUEST_ID: StringName = &"roshi_ki_control"
const KI_OBJECTIVE_ID: StringName = &"charge_ki_second"
const SPECIAL_QUEST_ID: StringName = &"roshi_special_training"
const SPECIAL_OBJECTIVE_ID: StringName = &"use_special_attack"
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

	if quests.is_completed(SPECIAL_QUEST_ID):
		dialogue.show_dialogue(
			[
				"Good. Your basics, Ki control, and techniques are taking shape.",
				"From here on, real experience will be your teacher.",
				"West City and the Rocky Wastes are waiting when you're ready."
			],
			SPEAKER_NAME
		)
		return

	if quests.is_active(SPECIAL_QUEST_ID):
		_show_progress(
			dialogue,
			quests,
			SPECIAL_QUEST_ID,
			"Special techniques used"
		)
		return

	if quests.is_completed(KI_QUEST_ID):
		quests.start_simple_quest(
			SPECIAL_QUEST_ID,
			"Roshi's Special Technique Training",
			"Practice controlling your stronger techniques.",
			SPECIAL_OBJECTIVE_ID,
			"Use special techniques",
			3,
			100,
			&"",
			0,
			200
		)
		dialogue.show_dialogue(
			[
				"Now put that Ki control into a real technique.",
				"Use three special techniques. Different techniques are even better.",
				"Remember: R changes the selected special, O uses it."
			],
			SPEAKER_NAME
		)
		return

	if quests.is_active(KI_QUEST_ID):
		_show_progress(
			dialogue,
			quests,
			KI_QUEST_ID,
			"Seconds spent charging Ki"
		)
		return

	if quests.is_completed(TRAINING_QUEST_ID):
		quests.start_simple_quest(
			KI_QUEST_ID,
			"Roshi's Ki Control",
			"Learn to recover and control your Ki deliberately.",
			KI_OBJECTIVE_ID,
			"Charge Ki for 5 seconds",
			5,
			75,
			&"",
			0,
			150
		)
		dialogue.show_dialogue(
			[
				"Strength without Ki control won't get you far.",
				"Hold L and charge your Ki for a total of five seconds.",
				"Watch your aura and your Ki bar. Then come back."
			],
			SPEAKER_NAME
		)
		return

	if quests.is_active(TRAINING_QUEST_ID):
		_show_progress(
			dialogue,
			quests,
			TRAINING_QUEST_ID,
			"Training opponents defeated"
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
			"Defeat the training fighter twice, then come back to me.",
			"You can rest and save inside Kame House whenever you need to."
		],
		SPEAKER_NAME
	)

func _show_progress(
	dialogue: DialogueBox,
	quests: QuestManager,
	quest_id: StringName,
	label: String
) -> void:
	var state: Dictionary = quests.get_quest(quest_id)
	var progress: int = int(state.get("progress", 0))
	var target: int = int(state.get("target_count", 1))

	dialogue.show_dialogue(
		[
			"Keep at it!",
			"%s: %d/%d." % [label, progress, target]
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
