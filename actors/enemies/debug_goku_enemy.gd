class_name DebugGokuEnemy
extends CharacterBody2D

const STATE_IDLE: StringName = &"idle"
const STATE_HURT: StringName = &"hurt"

@export_file("*.png")
var sprite_sheet_path: String = "res://assets/sprites/characters/goku/processed/goku_buus_fury_base.png"

@export var frame_size: Vector2i = Vector2i(32, 32)
@export var idle_column: int = 0
@export_range(0, 3, 1)
var facing_row: int = 1
@export var hurt_duration: float = 0.18

@onready var sprite: AnimatedSprite2D = $Visuals/AnimatedSprite2D
@onready var placeholder: Polygon2D = $Visuals/Placeholder
@onready var health_component: HealthComponent = $Components/HealthComponent
@onready var knockback_component: KnockbackComponent = $Components/KnockbackComponent
@onready var state_machine: StateMachine = $Components/StateMachine
@onready var hurtbox: HurtboxComponent = $Hurtbox

var _hurt_time_left: float = 0.0
var _flash_tween: Tween
var _spawn_position: Vector2

func _ready() -> void:
	_spawn_position = global_position
	_build_idle_sprite()

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

func _on_hit_received(_damage: int, source_position: Vector2) -> void:
	state_machine.change_state(STATE_HURT)
	_hurt_time_left = hurt_duration
	knockback_component.start(self, source_position)

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

func _flash() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()

	$Visuals.modulate = Color(1.0, 0.35, 0.35, 1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property($Visuals, "modulate", Color.WHITE, hurt_duration)

func _build_idle_sprite() -> void:
	if not ResourceLoader.exists(sprite_sheet_path):
		sprite.visible = false
		placeholder.visible = true
		return

	var sheet := load(sprite_sheet_path) as Texture2D
	if sheet == null:
		sprite.visible = false
		placeholder.visible = true
		return

	var required_width := (idle_column + 1) * frame_size.x
	var required_height := (facing_row + 1) * frame_size.y

	if sheet.get_width() < required_width or sheet.get_height() < required_height:
		sprite.visible = false
		placeholder.visible = true
		return

	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(
		Vector2(idle_column * frame_size.x, facing_row * frame_size.y),
		Vector2(frame_size.x, frame_size.y)
	)

	var frames := SpriteFrames.new()
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")

	frames.add_animation(&"idle")
	frames.set_animation_loop(&"idle", true)
	frames.add_frame(&"idle", atlas)

	sprite.sprite_frames = frames
	sprite.play(&"idle")
	sprite.visible = true
	placeholder.visible = false
