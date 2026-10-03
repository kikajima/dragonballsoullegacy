class_name CharacterShadowSystem
extends Node

const SHADOW_DMI_PATH := (
	"res://assets/vendor/hu2/Icons/Other/Other.dmi"
)
const SHADOW_STATE: StringName = &"FlightShadow"

@export var refresh_interval: float = 0.5

var _refresh_left: float = 0.0

func _ready() -> void:
	call_deferred("_refresh_characters")

func _process(delta: float) -> void:
	_refresh_left = maxf(_refresh_left - delta, 0.0)
	if _refresh_left > 0.0:
		return

	_refresh_left = refresh_interval
	_refresh_characters()

func _refresh_characters() -> void:
	_apply_group(&"player")
	_apply_group(&"enemy")
	_apply_group(&"npc")

func _apply_group(group_name: StringName) -> void:
	var nodes: Array[Node] = get_tree().get_nodes_in_group(group_name)
	for node: Node in nodes:
		var actor: Node2D = node as Node2D
		if actor == null:
			continue
		_ensure_shadow(actor)

func _ensure_shadow(actor: Node2D) -> void:
	var visual_parent: Node = actor.get_node_or_null("Visuals")
	if visual_parent == null:
		visual_parent = actor

	if visual_parent.get_node_or_null("GroundShadow") != null:
		return

	var shadow := DmiEffectSprite2D.new()
	shadow.name = "GroundShadow"
	shadow.position = Vector2(0, 17)
	shadow.z_index = -5
	shadow.scale = Vector2(0.72, 0.72)
	shadow.modulate = Color(1, 1, 1, 0.52)
	shadow.dmi_path = SHADOW_DMI_PATH
	shadow.dmi_state = SHADOW_STATE
	shadow.loop_animation = false
	shadow.play_on_ready = true
	visual_parent.add_child(shadow)
