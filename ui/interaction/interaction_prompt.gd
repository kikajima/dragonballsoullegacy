class_name InteractionPrompt
extends Control

@onready var label: Label = $Panel/Label

func _ready() -> void:
	position = Vector2(170.0, 232.0)
	size = Vector2(140.0, 22.0)
	z_index = 100
	visible = false
	call_deferred("_bind_player")

func _bind_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return

	var sensor := player.get_node_or_null(
		"InteractionSensor"
	) as InteractionSensor
	if sensor == null:
		return

	sensor.target_changed.connect(_on_target_changed)
	_on_target_changed(sensor.get_closest_interactable())

func _on_target_changed(target: Node) -> void:
	if target == null:
		visible = false
		return

	var interaction_target: Node = target
	if not target.has_method("interact"):
		interaction_target = target.get_parent()

	if interaction_target == null:
		visible = false
		return

	var action_text: String = "Interact"
	if interaction_target.has_method("get_interaction_label"):
		action_text = str(
			interaction_target.call("get_interaction_label")
		)

	label.text = "E  %s" % action_text
	visible = true
