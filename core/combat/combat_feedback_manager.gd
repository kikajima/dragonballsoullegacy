class_name CombatFeedbackManager
extends Node

signal target_changed(target: Node)
signal hit_reported(target: Node, damage: int)

const FLOATING_TEXT_SCENE := preload(
	"res://ui/combat/floating_combat_text.tscn"
)

func report_hit(
	target: Node,
	damage: int,
	_world_source_position: Vector2 = Vector2.ZERO
) -> void:
	if target == null or damage <= 0:
		return

	var actor: Node = _resolve_actor(target)
	var position := Vector2.ZERO

	if actor is Node2D:
		position = (actor as Node2D).global_position
	elif target is Node2D:
		position = (target as Node2D).global_position

	spawn_floating_text(
		"-%d" % damage,
		position + Vector2(0.0, -18.0),
		Color(1.0, 0.92, 0.35, 1.0)
	)

	if actor != null and actor.is_in_group("enemy"):
		target_changed.emit(actor)

	hit_reported.emit(actor if actor != null else target, damage)

func report_damage_taken(actor: Node, damage: int) -> void:
	if actor == null or damage <= 0:
		return

	var position := Vector2.ZERO
	if actor is Node2D:
		position = (actor as Node2D).global_position

	spawn_floating_text(
		"-%d" % damage,
		position + Vector2(0.0, -18.0),
		Color(1.0, 0.48, 0.48, 1.0)
	)

func report_heal(actor: Node, amount: int) -> void:
	if actor == null or amount <= 0:
		return

	var position := Vector2.ZERO
	if actor is Node2D:
		position = (actor as Node2D).global_position

	spawn_floating_text(
		"+%d" % amount,
		position + Vector2(0.0, -18.0),
		Color(0.45, 1.0, 0.55, 1.0)
	)

func spawn_floating_text(
	text_value: String,
	world_position: Vector2,
	text_color: Color = Color.WHITE
) -> void:
	var instance := FLOATING_TEXT_SCENE.instantiate() as FloatingCombatText
	if instance == null:
		return

	var world_container := get_tree().get_first_node_in_group(
		"world_container"
	)
	if world_container == null:
		world_container = get_tree().current_scene

	if world_container == null:
		return

	world_container.add_child(instance)
	instance.global_position = world_position
	instance.setup(text_value, text_color)

func _resolve_actor(target: Node) -> Node:
	if target == null:
		return null

	if target.is_in_group("enemy") or target.is_in_group("player"):
		return target

	var parent: Node = target.get_parent()
	if parent != null:
		if parent.is_in_group("enemy") or parent.is_in_group("player"):
			return parent

	return target
