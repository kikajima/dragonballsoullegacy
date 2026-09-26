class_name PlayerAnimationController
extends Node

@export var walk_bob_amplitude: float = 1.0
@export var walk_bob_speed: float = 12.0

@onready var visuals: Node2D = get_parent() as Node2D
@onready var sprite: AnimatedSprite2D = visuals.get_node("AnimatedSprite2D") as AnimatedSprite2D
@onready var placeholder: Polygon2D = visuals.get_node("Placeholder") as Polygon2D
@onready var facing_marker: Polygon2D = placeholder.get_node("FacingMarker") as Polygon2D

var _bob_phase: float = 0.0

func update_visual(state: StringName, facing: StringName, delta: float) -> void:
	var animation_name := StringName("%s_%s" % [state, facing])

	if _has_animation(animation_name):
		visuals.position = Vector2.ZERO
		placeholder.visible = false
		sprite.visible = true

		if sprite.animation != animation_name or not sprite.is_playing():
			sprite.play(animation_name)
		return

	sprite.stop()
	sprite.visible = false
	placeholder.visible = true
	_update_placeholder_facing(facing)
	_update_placeholder_motion(state, delta)

func _has_animation(animation_name: StringName) -> bool:
	if sprite.sprite_frames == null:
		return false

	return (
		sprite.sprite_frames.has_animation(animation_name)
		and sprite.sprite_frames.get_frame_count(animation_name) > 0
	)

func _update_placeholder_motion(state: StringName, delta: float) -> void:
	if state == &"walk":
		_bob_phase += delta * walk_bob_speed
		visuals.position.y = roundf(sin(_bob_phase) * walk_bob_amplitude)
		return

	_bob_phase = 0.0
	visuals.position = Vector2.ZERO

func _update_placeholder_facing(facing: StringName) -> void:
	match facing:
		&"up":
			facing_marker.position = Vector2(0, -10)
			facing_marker.rotation = 0.0
		&"down":
			facing_marker.position = Vector2(0, 10)
			facing_marker.rotation = PI
		&"left":
			facing_marker.position = Vector2(-9, 0)
			facing_marker.rotation = -PI / 2.0
		&"right":
			facing_marker.position = Vector2(9, 0)
			facing_marker.rotation = PI / 2.0
