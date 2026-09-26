class_name Player
extends CharacterBody2D

const STATE_IDLE: StringName = &"idle"
const STATE_WALK: StringName = &"walk"
const STATE_HURT: StringName = &"hurt"

@export_range(0.0, 1.0, 0.05)
var attack_move_speed_scale: float = 0.85
@export var hurt_duration: float = 0.24

@onready var input_controller: PlayerInputController = $Controllers/PlayerInputController
@onready var movement_component: MovementComponent = $Components/MovementComponent
@onready var facing_component: FacingComponent = $Components/FacingComponent
@onready var state_machine: StateMachine = $Components/StateMachine
@onready var melee_combat_component: MeleeCombatComponent = $Components/MeleeCombatComponent
@onready var hit_stop_component: HitStopComponent = $Components/HitStopComponent
@onready var health_component: HealthComponent = $Components/HealthComponent
@onready var knockback_component: KnockbackComponent = $Components/KnockbackComponent
@onready var attack_hitbox: HitboxComponent = $Combat/AttackHitbox
@onready var hurtbox: HurtboxComponent = $Hurtbox
@onready var animation_controller: PlayerAnimationController = $Visuals/AnimationController

var _hurt_time_left: float = 0.0
var _spawn_position: Vector2
var _flash_tween: Tween

func _ready() -> void:
	_spawn_position = global_position
	attack_hitbox.hit_confirmed.connect(_on_attack_hit_confirmed)
	hurtbox.hit_received.connect(_on_hit_received)
	health_component.damaged.connect(_on_damaged)
	health_component.died.connect(_on_died)

func _physics_process(delta: float) -> void:
	var move_intent := input_controller.get_move_intent()

	if state_machine.is_state(STATE_HURT):
		_process_hurt(delta)
		return

	# Facing de movimento é atualizado sempre, inclusive durante ataques.
	# O golpe atual mantém sua própria direção até o próximo soco da sequência.
	facing_component.update_from_direction(move_intent)

	if melee_combat_component.is_attacking():
		movement_component.move(self, move_intent, attack_move_speed_scale)

		if input_controller.is_attack_pressed():
			melee_combat_component.buffer_attack(facing_component.current_facing)

		melee_combat_component.tick_attack(delta)

		if melee_combat_component.is_attacking():
			state_machine.change_state(melee_combat_component.get_attack_state())
			animation_controller.update_visual(
				state_machine.current_state,
				melee_combat_component.get_attack_facing(),
				delta
			)
		else:
			_update_movement_state(move_intent)
			animation_controller.update_visual(
				state_machine.current_state,
				facing_component.current_facing,
				delta
			)
		return

	if input_controller.is_attack_pressed():
		if melee_combat_component.start_attack(facing_component.current_facing):
			state_machine.change_state(melee_combat_component.get_attack_state())
			movement_component.move(self, move_intent, attack_move_speed_scale)
			animation_controller.update_visual(
				state_machine.current_state,
				melee_combat_component.get_attack_facing(),
				delta
			)
			return

	_update_movement_state(move_intent)
	movement_component.move(self, move_intent)
	animation_controller.update_visual(
		state_machine.current_state,
		facing_component.current_facing,
		delta
	)

func _process_hurt(delta: float) -> void:
	if knockback_component.is_active():
		knockback_component.tick(self, delta)
	else:
		movement_component.stop(self)

	_hurt_time_left -= delta
	animation_controller.update_visual(
		STATE_HURT,
		facing_component.current_facing,
		delta
	)

	if _hurt_time_left <= 0.0:
		state_machine.change_state(STATE_IDLE)

func _on_attack_hit_confirmed(_target: Node, _damage: int) -> void:
	hit_stop_component.trigger()

func _on_hit_received(_damage: int, source_position: Vector2) -> void:
	melee_combat_component.cancel_attack()

	var toward_source := source_position - global_position
	facing_component.update_from_direction(toward_source)

	state_machine.change_state(STATE_HURT)
	_hurt_time_left = hurt_duration
	knockback_component.start(self, source_position)
	hit_stop_component.trigger()

func _on_damaged(damage: int, current_health: int, max_health: int) -> void:
	print(
		"Player recebeu %d de dano. HP: %d/%d"
		% [damage, current_health, max_health]
	)
	_flash()

func _on_died() -> void:
	print("Player derrotado. HP e posição restaurados para continuar os testes.")
	call_deferred("_reset_after_defeat")

func _reset_after_defeat() -> void:
	health_component.restore_full()
	melee_combat_component.cancel_attack()
	knockback_component.stop(self)
	global_position = _spawn_position
	state_machine.change_state(STATE_IDLE)

func _flash() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()

	$Visuals.modulate = Color(1.0, 0.55, 0.55, 1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property($Visuals, "modulate", Color.WHITE, 0.10)

func _update_movement_state(move_intent: Vector2) -> void:
	if move_intent.is_zero_approx():
		state_machine.change_state(STATE_IDLE)
	else:
		state_machine.change_state(STATE_WALK)

func get_current_state() -> StringName:
	return state_machine.current_state

func get_facing() -> StringName:
	return facing_component.current_facing
