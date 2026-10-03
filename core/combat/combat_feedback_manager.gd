class_name CombatFeedbackManager
extends Node

signal target_changed(target: Node)
signal hit_reported(target: Node, damage: int)

const FLOATING_TEXT_SCENE := preload(
	"res://ui/combat/floating_combat_text.tscn"
)

var _camera: Camera2D
var _shake_time_left: float = 0.0
var _shake_duration: float = 0.0
var _shake_intensity: float = 0.0

func _process(delta: float) -> void:
	if _shake_time_left <= 0.0:
		_reset_camera_offset()
		return

	_shake_time_left = maxf(_shake_time_left - delta, 0.0)
	var camera: Camera2D = _get_camera()
	if camera == null:
		return

	var duration: float = maxf(_shake_duration, 0.001)
	var ratio: float = clampf(
		_shake_time_left / duration,
		0.0,
		1.0
	)
	var strength: float = _shake_intensity * ratio
	camera.offset = Vector2(
		randf_range(-strength, strength),
		randf_range(-strength, strength)
	)

func report_hit(
	target: Node,
	damage: int,
	_world_source_position: Vector2 = Vector2.ZERO
) -> void:
	if target == null or damage <= 0:
		return

	var actor: Node = _resolve_actor(target)
	var position: Vector2 = Vector2.ZERO

	if actor is Node2D:
		position = (actor as Node2D).global_position
	elif target is Node2D:
		position = (target as Node2D).global_position

	# Buu's Fury keeps damage feedback compact: red numbers directly above
	# the target, without a minus prefix or a large UI callout.
	spawn_floating_text(
		str(damage),
		position + Vector2(randf_range(-4.0, 4.0), -20.0),
		Color(1.0, 0.22, 0.16, 1.0)
	)

	request_camera_shake(
		clampf(0.65 + float(damage) * 0.025, 0.65, 2.2),
		0.055
	)

	if actor != null and actor.is_in_group("enemy"):
		target_changed.emit(actor)

	hit_reported.emit(actor if actor != null else target, damage)

func report_damage_taken(actor: Node, damage: int) -> void:
	if actor == null or damage <= 0:
		return

	var position: Vector2 = Vector2.ZERO
	if actor is Node2D:
		position = (actor as Node2D).global_position

	spawn_floating_text(
		str(damage),
		position + Vector2(randf_range(-4.0, 4.0), -20.0),
		Color(1.0, 0.42, 0.32, 1.0)
	)
	request_camera_shake(
		clampf(1.0 + float(damage) * 0.035, 1.0, 2.8),
		0.085
	)

func report_heal(actor: Node, amount: int) -> void:
	if actor == null or amount <= 0:
		return

	var position: Vector2 = Vector2.ZERO
	if actor is Node2D:
		position = (actor as Node2D).global_position

	spawn_floating_text(
		"+%d" % amount,
		position + Vector2(0.0, -18.0),
		Color(0.45, 1.0, 0.55, 1.0)
	)

func report_block(actor: Node, perfect: bool = false) -> void:
	if actor == null:
		return

	var position: Vector2 = Vector2.ZERO
	if actor is Node2D:
		position = (actor as Node2D).global_position

	spawn_floating_text(
		"PERFECT!" if perfect else "BLOCK",
		position + Vector2(0.0, -26.0),
		Color(0.55, 0.86, 1.0, 1.0)
	)
	request_camera_shake(1.15 if perfect else 0.7, 0.055)

func report_dash(_actor: Node) -> void:
	# Movement feedback is carried by the afterimage itself, matching the
	# uncluttered GBA presentation.
	pass

func request_camera_shake(
	intensity: float,
	duration: float
) -> void:
	if intensity <= 0.0 or duration <= 0.0:
		return

	_shake_intensity = maxf(_shake_intensity, intensity)
	_shake_duration = maxf(_shake_duration, duration)
	_shake_time_left = maxf(_shake_time_left, duration)

func spawn_floating_text(
	text_value: String,
	world_position: Vector2,
	text_color: Color = Color.WHITE
) -> void:
	var instance: FloatingCombatText = (
		FLOATING_TEXT_SCENE.instantiate()
		as FloatingCombatText
	)
	if instance == null:
		return

	var world_container: Node = get_tree().get_first_node_in_group(
		"world_container"
	)
	if world_container == null:
		world_container = get_tree().current_scene

	if world_container == null:
		return

	world_container.add_child(instance)
	instance.global_position = world_position
	instance.setup(text_value, text_color)

func _get_camera() -> Camera2D:
	if _camera != null and is_instance_valid(_camera):
		return _camera

	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return null

	_camera = player.get_node_or_null("Camera2D") as Camera2D
	return _camera

func _reset_camera_offset() -> void:
	var camera: Camera2D = _get_camera()
	if camera != null and not camera.offset.is_zero_approx():
		camera.offset = Vector2.ZERO

	_shake_intensity = 0.0
	_shake_duration = 0.0

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
