class_name DebugGokuEnemy
extends CharacterBody2D

const STATE_IDLE: StringName = &"idle"
const STATE_WALK: StringName = &"walk"
const STATE_HURT: StringName = &"hurt"

const DIRECTION_ROWS := {
	&"down": 0,
	&"left": 1,
	&"right": 2,
	&"up": 3,
}

@export_file("*.png")
var sprite_sheet_path: String = "res://assets/sprites/characters/goku/processed/goku_buus_fury_base.png"

@export_file("*.png")
var attack_sheet_path: String = "res://assets/sprites/characters/goku/processed/goku_buus_fury_attack.png"

@export_file("*.png")
var hurt_sheet_path: String = "res://assets/sprites/characters/goku/processed/goku_buus_fury_hurt.png"

@export var frame_size: Vector2i = Vector2i(32, 32)
@export var idle_column: int = 0
@export var walk_columns: PackedInt32Array = PackedInt32Array([2, 3, 4, 5])
@export var attack_1_columns: PackedInt32Array = PackedInt32Array([0, 1, 2, 3])
@export var attack_2_columns: PackedInt32Array = PackedInt32Array([4, 5, 6, 7])
@export var hurt_columns: PackedInt32Array = PackedInt32Array([0, 1])
@export var walk_fps: float = 8.0
@export var attack_fps: float = 8.0
@export var hurt_fps: float = 10.0
@export var hurt_duration: float = 0.24

@export var detection_range: float = 170.0
@export var attack_range: float = 25.0
@export var attack_cooldown: float = 0.55

@export_enum("up", "down", "left", "right")
var initial_facing: String = "left"

@onready var sprite: AnimatedSprite2D = $Visuals/AnimatedSprite2D
@onready var placeholder: Polygon2D = $Visuals/Placeholder
@onready var health_component: HealthComponent = $Components/HealthComponent
@onready var movement_component: MovementComponent = $Components/MovementComponent
@onready var knockback_component: KnockbackComponent = $Components/KnockbackComponent
@onready var state_machine: StateMachine = $Components/StateMachine
@onready var melee_combat_component: MeleeCombatComponent = $Components/MeleeCombatComponent
@onready var hurtbox: HurtboxComponent = $Hurtbox

var _hurt_time_left: float = 0.0
var _attack_cooldown_left: float = 0.0
var _flash_tween: Tween
var _spawn_position: Vector2
var _current_facing: StringName = &"left"
var _target: Node2D

func _ready() -> void:
	_spawn_position = global_position
	_current_facing = StringName(initial_facing)
	_target = get_tree().get_first_node_in_group("player") as Node2D

	_build_sprite_frames()
	_play_current_animation()

	hurtbox.hit_received.connect(_on_hit_received)
	health_component.damaged.connect(_on_damaged)
	health_component.died.connect(_on_died)

func _physics_process(delta: float) -> void:
	_attack_cooldown_left = maxf(_attack_cooldown_left - delta, 0.0)

	if state_machine.is_state(STATE_HURT):
		_process_hurt(delta)
		return

	if melee_combat_component.is_attacking():
		_process_attack(delta)
		return

	if not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("player") as Node2D

	if not is_instance_valid(_target):
		_set_idle()
		return

	var to_target := _target.global_position - global_position
	var distance_to_target := to_target.length()

	if distance_to_target > detection_range:
		_set_idle()
		return

	_update_facing_from_direction(to_target)

	if distance_to_target <= attack_range:
		movement_component.stop(self)

		if _attack_cooldown_left <= 0.0:
			_start_attack()
		else:
			state_machine.change_state(STATE_IDLE)
			_play_current_animation()
		return

	state_machine.change_state(STATE_WALK)
	movement_component.move(self, to_target.normalized())
	_play_current_animation()

func _process_hurt(delta: float) -> void:
	if knockback_component.is_active():
		knockback_component.tick(self, delta)
	else:
		movement_component.stop(self)

	_hurt_time_left -= delta

	if _hurt_time_left <= 0.0:
		state_machine.change_state(STATE_IDLE)
		_play_current_animation()

func _process_attack(delta: float) -> void:
	movement_component.stop(self)
	melee_combat_component.tick_attack(delta)

	if melee_combat_component.is_attacking():
		state_machine.change_state(melee_combat_component.get_attack_state())
		_current_facing = melee_combat_component.get_attack_facing()
	else:
		_attack_cooldown_left = attack_cooldown
		state_machine.change_state(STATE_IDLE)

	_play_current_animation()

func _start_attack() -> void:
	if melee_combat_component.start_attack(_current_facing):
		state_machine.change_state(melee_combat_component.get_attack_state())
		_play_current_animation()

func _set_idle() -> void:
	movement_component.stop(self)
	state_machine.change_state(STATE_IDLE)
	_play_current_animation()

func _on_hit_received(_damage: int, source_position: Vector2) -> void:
	melee_combat_component.cancel_attack()
	_current_facing = _facing_toward(source_position)
	state_machine.change_state(STATE_HURT)
	_hurt_time_left = hurt_duration
	knockback_component.start(self, source_position)
	_play_current_animation()

func _on_damaged(damage: int, current_health: int, max_health: int) -> void:
	print(
		"DebugGokuEnemy recebeu %d de dano. HP: %d/%d"
		% [damage, current_health, max_health]
	)
	_flash()

func _on_died() -> void:
	print("DebugGokuEnemy derrotado. HP restaurado para continuar os testes.")
	call_deferred("_reset_after_defeat")

func _reset_after_defeat() -> void:
	health_component.restore_full()
	melee_combat_component.cancel_attack()
	knockback_component.stop(self)
	global_position = _spawn_position
	_attack_cooldown_left = attack_cooldown
	state_machine.change_state(STATE_IDLE)
	_play_current_animation()

func _flash() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()

	$Visuals.modulate = Color(1.0, 0.55, 0.55, 1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property($Visuals, "modulate", Color.WHITE, 0.10)

func _build_sprite_frames() -> void:
	var frames := SpriteFrames.new()
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")

	var built_any := false

	if ResourceLoader.exists(sprite_sheet_path):
		var movement_sheet := load(sprite_sheet_path) as Texture2D
		if movement_sheet != null:
			_add_movement_animations(frames, movement_sheet)
			built_any = true

	if ResourceLoader.exists(attack_sheet_path):
		var attack_sheet := load(attack_sheet_path) as Texture2D
		if attack_sheet != null:
			_add_directional_animation(frames, attack_sheet, &"attack_1", attack_1_columns, attack_fps, false)
			_add_directional_animation(frames, attack_sheet, &"attack_2", attack_2_columns, attack_fps, false)
			built_any = true

	if ResourceLoader.exists(hurt_sheet_path):
		var hurt_sheet := load(hurt_sheet_path) as Texture2D
		if hurt_sheet != null:
			_add_directional_animation(frames, hurt_sheet, &"hurt", hurt_columns, hurt_fps, false)
			built_any = true

	if built_any:
		sprite.sprite_frames = frames
		sprite.visible = true
		placeholder.visible = false
	else:
		sprite.visible = false
		placeholder.visible = true

func _add_movement_animations(frames: SpriteFrames, sheet: Texture2D) -> void:
	for facing in DIRECTION_ROWS:
		var row: int = DIRECTION_ROWS[facing]
		var idle_name := StringName("idle_%s" % facing)
		var walk_name := StringName("walk_%s" % facing)

		frames.add_animation(idle_name)
		frames.set_animation_loop(idle_name, true)
		frames.set_animation_speed(idle_name, 1.0)
		frames.add_frame(idle_name, _atlas_frame(sheet, idle_column, row))

		frames.add_animation(walk_name)
		frames.set_animation_loop(walk_name, true)
		frames.set_animation_speed(walk_name, walk_fps)

		for column in walk_columns:
			frames.add_frame(walk_name, _atlas_frame(sheet, column, row))

func _add_directional_animation(
	frames: SpriteFrames,
	sheet: Texture2D,
	state_name: StringName,
	columns: PackedInt32Array,
	fps: float,
	loop: bool
) -> void:
	for facing in DIRECTION_ROWS:
		var row: int = DIRECTION_ROWS[facing]
		var animation_name := StringName("%s_%s" % [state_name, facing])

		frames.add_animation(animation_name)
		frames.set_animation_loop(animation_name, loop)
		frames.set_animation_speed(animation_name, fps)

		for column in columns:
			frames.add_frame(animation_name, _atlas_frame(sheet, column, row))

func _play_current_animation() -> void:
	if sprite.sprite_frames == null:
		return

	var facing := _current_facing
	if melee_combat_component.is_attacking():
		facing = melee_combat_component.get_attack_facing()

	var animation_name := StringName(
		"%s_%s" % [state_machine.current_state, facing]
	)

	if not sprite.sprite_frames.has_animation(animation_name):
		animation_name = StringName("idle_%s" % facing)

	if not sprite.sprite_frames.has_animation(animation_name):
		return

	var is_one_shot := (
		String(state_machine.current_state).begins_with("attack_")
		or state_machine.is_state(STATE_HURT)
	)

	if sprite.animation != animation_name:
		sprite.play(animation_name)
	elif not is_one_shot and not sprite.is_playing():
		sprite.play(animation_name)

func _update_facing_from_direction(direction: Vector2) -> void:
	if direction.is_zero_approx():
		return

	if absf(direction.x) > absf(direction.y):
		_current_facing = &"right" if direction.x > 0.0 else &"left"
	else:
		_current_facing = &"down" if direction.y > 0.0 else &"up"

func _facing_toward(source_position: Vector2) -> StringName:
	var direction := source_position - global_position

	if direction.is_zero_approx():
		return _current_facing

	if absf(direction.x) > absf(direction.y):
		return &"right" if direction.x > 0.0 else &"left"

	return &"down" if direction.y > 0.0 else &"up"

func _atlas_frame(sheet: Texture2D, column: int, row: int) -> AtlasTexture:
	var frame := AtlasTexture.new()
	frame.atlas = sheet
	frame.region = Rect2(
		Vector2(column * frame_size.x, row * frame_size.y),
		Vector2(frame_size.x, frame_size.y)
	)
	return frame
