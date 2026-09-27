class_name CheckpointArea
extends Area2D

@export var checkpoint_id: StringName = &"checkpoint"
@export var activate_once: bool = true
@export var autosave: bool = true
@export var restore_health: bool = true
@export var restore_ki: bool = true

var _activated: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if _activated and activate_once:
		return

	if body == null or not body.is_in_group("player"):
		return

	var manager := get_tree().get_first_node_in_group(
		"checkpoint_manager"
	) as CheckpointManager
	if manager == null:
		return

	_activated = true
	manager.set_checkpoint(
		checkpoint_id,
		body.global_position
	)

	if restore_health:
		var health := body.get_node_or_null(
			"Components/HealthComponent"
		) as HealthComponent
		if health != null:
			health.restore_full()

	if restore_ki:
		var ki := body.get_node_or_null(
			"Components/KiComponent"
		) as KiComponent
		if ki != null:
			ki.restore_full()

	if autosave:
		var save_manager := get_tree().get_first_node_in_group(
			"save_manager"
		) as SaveManager
		if save_manager != null:
			save_manager.call_deferred("save_game")
