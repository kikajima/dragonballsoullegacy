class_name Player
extends CharacterBody2D

const STATE_IDLE: StringName = &"idle"
const STATE_WALK: StringName = &"walk"
const STATE_HURT: StringName = &"hurt"
const STATE_BLOCK: StringName = &"block"
const STATE_KI_BLAST: StringName = &"ki_blast"
const STATE_CHARGE_KI: StringName = &"charge_ki"

@export_range(0.0, 1.0, 0.05)
var attack_move_speed_scale: float = 0.85

@export_range(0.0, 1.0, 0.05)
var kick_move_speed_scale: float = 0.70

@export_range(0.0, 1.0, 0.05)
var block_move_speed_scale: float = 0.35

@export_range(0.0, 1.0, 0.05)
var ki_blast_move_speed_scale: float = 0.45

@export var hurt_duration: float = 0.24
@export var ki_charge_per_second: float = 28.0

@onready var input_controller: PlayerInputController = $Controllers/PlayerInputController
@onready var movement_component: MovementComponent = $Components/MovementComponent
@onready var facing_component: FacingComponent = $Components/FacingComponent
@onready var state_machine: StateMachine = $Components/StateMachine
@onready var melee_combat_component: MeleeCombatComponent = $Components/MeleeCombatComponent
@onready var hit_stop_component: HitStopComponent = $Components/HitStopComponent
@onready var health_component: HealthComponent = $Components/HealthComponent
@onready var knockback_component: KnockbackComponent = $Components/KnockbackComponent
@onready var guard_component: GuardComponent = $Components/GuardComponent
@onready var ki_component: KiComponent = $Components/KiComponent
@onready var ki_blast_component: KiBlastComponent = $Components/KiBlastComponent
@onready var attack_hitbox: HitboxComponent = $Combat/AttackHitbox
@onready var hurtbox: HurtboxComponent = $Hurtbox
@onready var animation_controller: PlayerAnimationController = $Visuals/AnimationController
@onready var charge_aura: Polygon2D = $Visuals/ChargeAura

var _hurt_time_left: float = 0.0
var _spawn_position: Vector2
var _flash_tween: Tween

func _ready() -> void:
	_spawn_position = global_position
	charge_aura.visible = false

	attack_hitbox.hit_confirmed.connect(_on_attack_hit_confirmed)
	hurtbox.hit_received.connect(_on_hit_received)
	health_component.damaged.connect(_on_damaged)
	health_component.died.connect(_on_died)

func _physics_process(delta: float) -> void:
	var move_intent := input_controller.get_move_intent()

	if state_machine.is_state(STATE_HURT):
		_process_hurt(delta)
		return

	facing_component.update_from_direction(move_intent)

	if ki_blast_component.is_casting():
		_process_ki_blast(move_intent, delta)
		return

	if melee_combat_component.is_attacking():
		_process_melee(move_intent, delta)
		return

	if input_controller.is_block_pressed():
		_process_block(move_intent, delta)
		return

	guard_component.set_guarding(false)

	if input_controller.is_charge_ki_pressed():
		_process_charge_ki(delta)
		return

	charge_aura.visible = false

	if input_controller.is_ki_blast_pressed():
		if ki_blast_component.start_cast(facing_component.current_facing):
			state_machine.change_state(STATE_KI_BLAST)
			movement_component.move(self, move_intent, ki_blast_move_speed_scale)
			animation_controller.update_visual(
				STATE_KI_BLAST,
				ki_blast_component.get_cast_facing(),
				delta
			)
			return

	if input_controller.is_kick_pressed():
		if melee_combat_component.start_attack(
			facing_component.current_facing,
			MeleeCombatComponent.ATTACK_KICK
		):
			_update_active_melee(move_intent, delta)
			return

	if input_controller.is_attack_pressed():
		if melee_combat_component.start_attack(
			facing_component.current_facing,
			MeleeCombatComponent.ATTACK_PUNCH
		):
			_update_active_melee(move_intent, delta)
			return

	_update_movement_state(move_intent)
	movement_component.move(self, move_intent)
	animation_controller.update_visual(
		state_machine.current_state,
		facing_component.current_facing,
		delta
	)

func _process_melee(move_intent: Vector2, delta: float) -> void:
	guard_component.set_guarding(false)
	charge_aura.visible = false

	movement_component.move(
		self,
		move_intent,
		_get_current_melee_speed_scale()
	)

	if input_controller.is_kick_pressed():
		melee_combat_component.buffer_attack(
			facing_component.current_facing,
			MeleeCombatComponent.ATTACK_KICK
		)
	elif input_controller.is_attack_pressed():
		melee_combat_component.buffer_attack(
			facing_component.current_facing,
			MeleeCombatComponent.ATTACK_PUNCH
		)

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

func _update_active_melee(move_intent: Vector2, delta: float) -> void:
	state_machine.change_state(melee_combat_component.get_attack_state())
	movement_component.move(
		self,
		move_intent,
		_get_current_melee_speed_scale()
	)
	animation_controller.update_visual(
		state_machine.current_state,
		melee_combat_component.get_attack_facing(),
		delta
	)

func _get_current_melee_speed_scale() -> float:
	if melee_combat_component.get_attack_kind() == MeleeCombatComponent.ATTACK_KICK:
		return kick_move_speed_scale

	return attack_move_speed_scale

func _process_block(move_intent: Vector2, delta: float) -> void:
	charge_aura.visible = false
	guard_component.set_guarding(true)
	state_machine.change_state(STATE_BLOCK)
	movement_component.move(self, move_intent, block_move_speed_scale)
	animation_controller.update_visual(
		STATE_BLOCK,
		facing_component.current_facing,
		delta
	)

func _process_charge_ki(delta: float) -> void:
	guard_component.set_guarding(false)
	charge_aura.visible = true
	state_machine.change_state(STATE_CHARGE_KI)
	movement_component.stop(self)
	ki_component.restore(ki_charge_per_second * delta)
	animation_controller.update_visual(
		STATE_CHARGE_KI,
		facing_component.current_facing,
		delta
	)

func _process_ki_blast(move_intent: Vector2, delta: float) -> void:
	guard_component.set_guarding(false)
	charge_aura.visible = false

	movement_component.move(self, move_intent, ki_blast_move_speed_scale)
	ki_blast_component.tick_cast(self, delta)

	if ki_blast_component.is_casting():
		state_machine.change_state(STATE_KI_BLAST)
		animation_controller.update_visual(
			STATE_KI_BLAST,
			ki_blast_component.get_cast_facing(),
			delta
		)
	else:
		_update_movement_state(move_intent)
		animation_controller.update_visual(
			state_machine.current_state,
			facing_component.current_facing,
			delta
		)

func _process_hurt(delta: float) -> void:
	guard_component.set_guarding(false)
	charge_aura.visible = false
	ki_blast_component.cancel_cast()

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

func modify_incoming_damage(damage: int, source_position: Vector2) -> int:
	return guard_component.resolve_damage(
		damage,
		global_position,
		source_position,
		facing_component.current_facing
	)

func _on_attack_hit_confirmed(_target: Node, _damage: int) -> void:
	hit_stop_component.trigger()

func _on_hit_received(_damage: int, source_position: Vector2) -> void:
	if guard_component.was_last_hit_blocked():
		hit_stop_component.trigger()
		return

	melee_combat_component.cancel_attack()
	ki_blast_component.cancel_cast()

	var toward_source := source_position - global_position
	facing_component.update_from_direction(toward_source)

	state_machine.change_state(STATE_HURT)
	_hurt_time_left = hurt_duration
	knockback_component.start(self, source_position)
	hit_stop_component.trigger()

func _on_damaged(damage: int, current_health: int, max_health: int) -> void:
	if guard_component.was_last_hit_blocked():
		print(
			"Player bloqueou o golpe. Dano recebido: %d. HP: %d/%d"
			% [damage, current_health, max_health]
		)
		_flash(Color(0.55, 0.8, 1.0, 1.0))
		return

	print(
		"Player recebeu %d de dano. HP: %d/%d"
		% [damage, current_health, max_health]
	)
	_flash(Color(1.0, 0.55, 0.55, 1.0))

func _on_died() -> void:
	print("Player derrotado. HP, Ki e posição restaurados para continuar os testes.")
	call_deferred("_reset_after_defeat")

func _reset_after_defeat() -> void:
	health_component.restore_full()
	ki_component.restore_full()
	melee_combat_component.cancel_attack()
	ki_blast_component.cancel_cast()
	knockback_component.stop(self)
	guard_component.set_guarding(false)
	charge_aura.visible = false
	global_position = _spawn_position
	state_machine.change_state(STATE_IDLE)

func _flash(color: Color) -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()

	$Visuals.modulate = color
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
