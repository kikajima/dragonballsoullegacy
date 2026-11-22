class_name WorldNPC
extends StaticBody2D

const DMI_SPRITE_SHEET_SCRIPT = preload(
	"res://core/assets/dmi_sprite_sheet.gd"
)

@export var display_name: String = "Traveler"
@export_file("*.dmi") var dmi_path: String
@export_multiline var dialogue_text: String = ""
@export var interaction_label: String = ""
# Quest id of this NPC ("bulma", "piccolo"...): quests offered, reported
# here or "talk:<npc_id>" objectives (QuestTalk).
@export var npc_id: StringName = &""

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	_load_sprite(&"down")
	if npc_id != &"":
		NpcQuestMarker.attach(self, npc_id)

func get_display_name() -> String:
	return display_name

func get_interaction_label() -> String:
	if not interaction_label.is_empty():
		return interaction_label
	return "Talk to " + display_name

func interact(actor: Node) -> void:
	if actor is Node2D:
		_face_actor(actor as Node2D)

	var lines: Array = Array(dialogue_text.split("|", false))
	if lines.is_empty():
		lines = ["The road ahead is quiet."]
	QuestTalk.talk(self, npc_id, display_name, lines)

func _face_actor(actor: Node2D) -> void:
	var direction := actor.global_position - global_position
	if direction.is_zero_approx():
		return

	if absf(direction.x) > absf(direction.y):
		_load_sprite(&"right" if direction.x > 0.0 else &"left")
	else:
		_load_sprite(&"down" if direction.y > 0.0 else &"up")

func _load_sprite(facing: StringName) -> void:
	if dmi_path.is_empty():
		return

	var dmi = DMI_SPRITE_SHEET_SCRIPT.load_file(dmi_path)
	if dmi == null:
		return

	var state: StringName = &""
	if not dmi.has_state(state):
		state = &"movement"
	if not dmi.has_state(state):
		return

	var texture: Texture2D = dmi.get_frame_texture(state, facing, 0)
	if texture != null:
		sprite.texture = texture
