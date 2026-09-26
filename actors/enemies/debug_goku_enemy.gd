class_name DebugGokuEnemy
extends CharacterBody2D

const STATE_IDLE: StringName = &"idle"
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
var hurt_sheet_path: String = "res://assets/sprites/characters/goku/processed/goku_buus_fury_hurt.png"

@export var frame_size: Vector2i = Vector2i(32, 32)
@export var idle_column: int = 0
@export var hurt_columns: PackedInt32Array = PackedInt32Array([0, 1])
@export var hurt_fps: float = 10.0
@export var hurt_duration: float = 0.24
@export_enum("up", "down", "left", "right")
var initial_facing: String = "left"

@onready var sprite: AnimatedSprite2D = $Visuals/AnimatedSprite2D
@onready var placeholder: Polygon2D = $Visuals/Placeholder
@onready var health_component: HealthComponent = $Components/HealthComponent
@onready var knockback_component: KnockbackComponent = $Components/KnockbackComponent
@onready var state_machine: StateMachine = $Components/StateMachine
@onready var hurtbox: HurtboxComponent = $Hurtbox

var _hurt_time_left: float = 0.0
var _flash_tween: Tween
var _spawn_position: Vector2
var _current_facing: StringName = &"left"

func _ready() -> void:
	_spawn_position = global_position
	_current_facing = StringName(initial_facing)
	_build_sprite_frames()
	_play_current_animation()

	hurtbox.hit_received.connect(_on_hit_received)
	health_component.damaged.connect(_on_damaged)
	health_component.died.connect(_on_died)

func _physics_process(delta: float) -> void:
	if knockback_component.is_active():
		knockback_component.tick(self, delta)
	else:
		velocity = Vector2.ZERO

	if state_machine.is_state(STATE_HURT):
		_hurt_time_left -= delta
		if _hurt_time_left <= 0.0:
			state_machine.change_state(STATE_IDLE)
			_play_current_animation()

func _on_hit_received(_damage: int, source_position: Vector2) -> void:
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
	health_component.restore_full()
	state_machine.change_state(STATE_IDLE)
	global_position = _spawn_position
	knockback_component.stop(self)
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
		var idle_sheet := load(sprite_sheet_path) as Texture2D
		if idle_sheet != null:
			for facing in DIRECTION_ROWS:
				var row: int = DIRECTION_ROWS[facing]
				var animation_name := StringName("idle_%s" % facing)

				frames.add_animation(animation_name)
				frames.set_animation_loop(animation_name, true)
				frames.set_animation_speed(animation_name, 1.0)
				frames.add_frame(
					animation_name,
					_atlas_frame(idle_sheet, idle_column, row)
				)
			built_any = true

	if ResourceLoader.exists(hurt_sheet_path):
		var hurt_sheet := load(hurt_sheet_path) as Texture2D
		if hurt_sheet != null:
			for facing in DIRECTION_ROWS:
				var row: int = DIRECTION_ROWS[facing]
				var animation_name := StringName("hurt_%s" % facing)

				frames.add_animation(animation_name)
				frames.set_animation_loop(animation_name, false)
				frames.set_animation_speed(animation_name, hurt_fps)

				for column in hurt_columns:
					frames.add_frame(
						animation_name,
						_atlas_frame(hurt_sheet, column, row)
					)
			built_any = true

	if built_any:
		sprite.sprite_frames = frames
		sprite.visible = true
		placeholder.visible = false
	else:
		sprite.visible = false
		placeholder.visible = true

func _play_current_animation() -> void:
	if sprite.sprite_frames == null:
		return

	var animation_name := StringName(
		"%s_%s" % [state_machine.current_state, _current_facing]
	)

	if not sprite.sprite_frames.has_animation(animation_name):
		animation_name = StringName("idle_%s" % _current_facing)

	if sprite.sprite_frames.has_animation(animation_name):
		sprite.play(animation_name)

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
