class_name DebugMentor
extends Node2D

const TRAINING_QUEST_ID: StringName = &"training_basics"
const TRAINING_OBJECTIVE_ID: StringName = &"defeat_training_dummy"
const SPEAKER_NAME: String = "Master Roshi"

@export_file("*.png")
var sprite_path: String = (
	"res://assets/sprites/npcs/master_roshi/processed/master_roshi_idle.png"
)

@export_file("*.png")
var portrait_path: String = (
	"res://assets/ui/portraits/master_roshi_portrait.png"
)

@onready var sprite: Sprite2D = $Sprite2D
@onready var fallback_body: Polygon2D = $Body
@onready var fallback_head: Polygon2D = $Head

func _ready() -> void:
	_load_local_sprite()

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
			["The quest system is not available yet."],
			SPEAKER_NAME,
			portrait_path
		)
		return

	if quests.is_completed(TRAINING_QUEST_ID):
		dialogue.show_dialogue(
			[
				"Good work. You already completed the basic training.",
				"Come back later. I will have tougher training for you."
			],
			SPEAKER_NAME,
			portrait_path
		)
		return

	if quests.is_active(TRAINING_QUEST_ID):
		var state := quests.get_quest(TRAINING_QUEST_ID)
		var progress: int = int(state.get("progress", 0))
		var target: int = int(state.get("target_count", 2))

		dialogue.show_dialogue(
			[
				"Keep training.",
				"Training opponents defeated: %d/%d." % [
					progress,
					target,
				]
			],
			SPEAKER_NAME,
			portrait_path
		)
		return

	quests.start_simple_quest(
		TRAINING_QUEST_ID,
		"Basic Training",
		"Practice combat against the training opponent.",
		TRAINING_OBJECTIVE_ID,
		"Defeat the training opponent",
		2,
		40,
		&"senzu_bean",
		1,
		100
	)

	dialogue.show_dialogue(
		[
			"Let me test your progress, Goku.",
			"Defeat the training opponent twice.",
			"As a reward, you will receive extra XP, Zeni, and a Senzu Bean."
		],
		SPEAKER_NAME,
		portrait_path
	)

func _load_local_sprite() -> void:
	if not ResourceLoader.exists(sprite_path):
		sprite.visible = false
		fallback_body.visible = true
		fallback_head.visible = true
		return

	var texture := load(sprite_path) as Texture2D
	if texture == null:
		sprite.visible = false
		fallback_body.visible = true
		fallback_head.visible = true
		return

	sprite.texture = texture
	sprite.hframes = 1
	sprite.vframes = 4
	sprite.frame = 0
	sprite.visible = true

	fallback_body.visible = false
	fallback_head.visible = false

func _face_actor(actor: Node2D) -> void:
	if not sprite.visible:
		return

	var direction := actor.global_position - global_position
	if direction.is_zero_approx():
		return

	if absf(direction.x) > absf(direction.y):
		sprite.frame = 2 if direction.x > 0.0 else 1
	else:
		sprite.frame = 0 if direction.y > 0.0 else 3
