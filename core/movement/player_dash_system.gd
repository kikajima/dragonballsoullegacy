class_name PlayerDashSystem
extends Node

@export var dash_action: StringName = &"dash"
@export var dash_duration: float = 0.14
@export var dash_cooldown: float = 0.38
@export var dash_speed_multiplier: float = 2.35
@export var dash_ki_cost: float = 6.0
@export var dash_invulnerability: float = 0.12
@export var afterimage_interval: float = 0.035
@export var afterimage_lifetime: float = 0.18

var _player: Player
var _movement: MovementComponent
var _ki: KiComponent
var _hurtbox: HurtboxComponent
var _sprite: AnimatedSprite2D

var _base_move_speed: float = 0.0
var _dash_left: float = 0.0
var _cooldown_left: float = 0.0
var _afterimage_left: float = 0.0

func _ready() -> void:
	call_deferred("_bind_player")

func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_bind_player()
		return

	_cooldown_left = maxf(_cooldown_left - delta, 0.0)

	if _dash_left > 0.0:
		_dash_left = maxf(_dash_left - delta, 0.0)
		_afterimage_left -= delta
		if _afterimage_left <= 0.0:
			_afterimage_left += afterimage_interval
			_spawn_afterimage()

		if _dash_left <= 0.0:
			_finish_dash()
		return

	if Input.is_action_just_pressed(dash_action):
		_try_start_dash()

func _bind_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player
	if _player == null:
		return

	_movement = _player.get_node_or_null(
		"Components/MovementComponent"
	) as MovementComponent
	_ki = _player.get_node_or_null(
		"Components/KiComponent"
	) as KiComponent
	_hurtbox = _player.get_node_or_null(
		"Hurtbox"
	) as HurtboxComponent
	_sprite = _player.get_node_or_null(
		"Visuals/AnimatedSprite2D"
	) as AnimatedSprite2D

	if _movement != null:
		_base_move_speed = _movement.move_speed

func _try_start_dash() -> void:
	if (
		_player == null
		or _movement == null
		or _ki == null
		or _cooldown_left > 0.0
	):
		return

	var move_intent: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)
	if move_intent.is_zero_approx():
		return

	var state: StringName = _player.get_current_state()
	var can_dash: bool = (
		state == &"idle"
		or state == &"walk"
		or state == &"run"
	)
	if not can_dash:
		return

	if not _ki.consume(dash_ki_cost):
		return

	_base_move_speed = _movement.move_speed
	_movement.move_speed = _base_move_speed * dash_speed_multiplier
	_dash_left = dash_duration
	_cooldown_left = dash_cooldown
	_afterimage_left = 0.0

	if _hurtbox != null:
		_hurtbox.grant_invulnerability(dash_invulnerability)

	_spawn_afterimage()

	var feedback: CombatFeedbackManager = (
		get_tree().get_first_node_in_group("combat_feedback")
		as CombatFeedbackManager
	)
	if feedback != null:
		feedback.request_camera_shake(0.55, 0.045)

func _finish_dash() -> void:
	if _movement != null:
		_movement.move_speed = _base_move_speed

func _spawn_afterimage() -> void:
	if (
		_sprite == null
		or _sprite.sprite_frames == null
		or _sprite.animation == &""
	):
		return

	var frames: SpriteFrames = _sprite.sprite_frames
	if not frames.has_animation(_sprite.animation):
		return

	var frame_count: int = frames.get_frame_count(_sprite.animation)
	if frame_count <= 0:
		return

	var frame_index: int = clampi(
		_sprite.frame,
		0,
		frame_count - 1
	)
	var texture: Texture2D = frames.get_frame_texture(
		_sprite.animation,
		frame_index
	)
	if texture == null:
		return

	var world_container: Node = get_tree().get_first_node_in_group(
		"world_container"
	)
	if world_container == null:
		return

	var ghost: Sprite2D = Sprite2D.new()
	ghost.texture = texture
	ghost.flip_h = _sprite.flip_h
	ghost.flip_v = _sprite.flip_v
	ghost.z_index = -1
	ghost.modulate = Color(0.55, 0.9, 1.0, 0.42)
	world_container.add_child(ghost)

	ghost.global_position = _sprite.global_position
	ghost.global_rotation = _sprite.global_rotation
	ghost.global_scale = _sprite.global_scale

	var tween: Tween = ghost.create_tween()
	tween.set_parallel(true)
	tween.tween_property(
		ghost,
		"modulate",
		Color(0.55, 0.9, 1.0, 0.0),
		afterimage_lifetime
	)
	tween.tween_property(
		ghost,
		"scale",
		ghost.scale * 1.06,
		afterimage_lifetime
	)
	tween.set_parallel(false)
	tween.tween_callback(Callable(ghost, "queue_free"))
