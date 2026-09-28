class_name Player
extends CharacterBody2D

const STATE_IDLE: StringName = &"idle"
const STATE_WALK: StringName = &"walk"
const STATE_RUN: StringName = &"run"
const STATE_HURT: StringName = &"hurt"
const STATE_BLOCK: StringName = &"block"
const STATE_CHARGE_KI: StringName = &"charge_ki"

@export_range(1.0, 3.0, 0.05)
var run_speed_scale: float = 1.333333

@export_range(0.0, 1.0, 0.05)
var attack_move_speed_scale: float = 0.85

@export_range(0.0, 1.0, 0.05)
var kick_move_speed_scale: float = 0.70

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
@onready var experience_component: ExperienceComponent = $Components/ExperienceComponent
@onready var inventory_component: InventoryComponent = $Components/InventoryComponent
@onready var ability_loadout_component: AbilityLoadoutComponent = $Components/AbilityLoadoutComponent
@onready var consumable_component: ConsumableComponent = $Components/ConsumableComponent
@onready var combo_tracker_component: ComboTrackerComponent = $Components/ComboTrackerComponent
@onready var ki_blast_component: KiBlastComponent = $Components/KiBlastComponent
@onready var special_attack_component: SpecialAttackComponent = $Components/SpecialAttackComponent
@onready var status_effect_component: StatusEffectComponent = $Components/StatusEffectComponent
@onready var transformation_component: TransformationComponent = $Components/TransformationComponent
@onready var attack_hitbox: HitboxComponent = $Combat/AttackHitbox
@onready var hurtbox: HurtboxComponent = $Hurtbox
@onready var animation_controller: PlayerAnimationController = $Visuals/AnimationController
@onready var charge_aura: AnimatedSprite2D = $Visuals/ChargeAura
@onready var transformation_aura: Polygon2D = $Visuals/TransformationAura
@onready var interaction_sensor: InteractionSensor = $InteractionSensor

var _hurt_time_left: float = 0.0
var _spawn_position: Vector2
var _flash_tween: Tween
var _respawning: bool = false
var _ki_quest_second_accumulator: float = 0.0

func _ready() -> void:
	_spawn_position = global_position
	charge_aura.visible = false

	attack_hitbox.hit_confirmed.connect(_on_attack_hit_confirmed)
	hurtbox.hit_received.connect(_on_hit_received)
	health_component.damaged.connect(_on_damaged)
	health_component.died.connect(_on_died)
	experience_component.leveled_up.connect(_on_leveled_up)
	transformation_component.transformation_started.connect(
		_on_transformation_started
	)
	transformation_component.transformation_ended.connect(
		_on_transformation_ended
	)
	_refresh_transformation_state()

func _physics_process(delta: float) -> void:
	if _respawning:
		movement_component.stop(self)
		return

	var move_intent := input_controller.get_move_intent()

	if status_effect_component.has_status(&"stun"):
		_process_stunned(delta)
		return

	if state_machine.is_state(STATE_HURT):
		_process_hurt(delta)
		return

	facing_component.update_from_direction(move_intent)

	var training := _get_training_manager()
	if training != null and training.is_treadmill_active():
		_process_treadmill_training(training, move_intent, delta)
		return

	if special_attack_component.is_casting():
		_process_special_attack(delta)
		return

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

	if input_controller.is_next_special_pressed():
		special_attack_component.select_next()

	if input_controller.is_quick_item_pressed():
		use_inventory_item(&"senzu_bean")

	if input_controller.is_interact_pressed():
		movement_component.stop(self)
		if interaction_sensor.try_interact(self):
			state_machine.change_state(STATE_IDLE)
			animation_controller.update_visual(
				STATE_IDLE,
				facing_component.current_facing,
				delta
			)
			return

	if input_controller.is_special_attack_pressed():
		if special_attack_component.start_cast(
			facing_component.current_facing,
			_facing_vector(facing_component.current_facing)
		):
			_advance_quest_objective(&"use_special_attack", 1)
			var special_state := special_attack_component.get_cast_state()
			state_machine.change_state(special_state)
			movement_component.stop(self)
			animation_controller.update_visual(
				special_state,
				special_attack_component.get_cast_facing(),
				delta
			)
			return

	if input_controller.is_ki_blast_pressed():
		if ki_blast_component.start_cast(facing_component.current_facing):
			var cast_state := ki_blast_component.get_cast_state()
			state_machine.change_state(cast_state)
			movement_component.stop(self)
			animation_controller.update_visual(
				cast_state,
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
	movement_component.move(
		self,
		move_intent,
		_get_locomotion_speed_scale()
	)
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
	var base_scale: float = attack_move_speed_scale
	if melee_combat_component.get_attack_kind() == MeleeCombatComponent.ATTACK_KICK:
		base_scale = kick_move_speed_scale

	return (
		base_scale
		* transformation_component.get_movement_multiplier()
		* _get_training_movement_multiplier()
	)

func _get_locomotion_speed_scale() -> float:
	var base_scale: float = 1.0
	if state_machine.is_state(STATE_RUN):
		base_scale = run_speed_scale

	return (
		base_scale
		* transformation_component.get_movement_multiplier()
		* _get_training_movement_multiplier()
	)

func _process_treadmill_training(
	training: TrainingManager,
	move_intent: Vector2,
	delta: float
) -> void:
	guard_component.set_guarding(false)
	charge_aura.visible = false
	ki_blast_component.cancel_cast()
	special_attack_component.cancel_cast()
	melee_combat_component.cancel_attack()
	movement_component.stop(self)

	global_position = training.get_treadmill_anchor()

	if input_controller.is_interact_pressed():
		training.stop_training()
		state_machine.change_state(STATE_IDLE)
		animation_controller.update_visual(
			STATE_IDLE,
			facing_component.current_facing,
			delta
		)
		return

	var input_strength: float = clampf(
		move_intent.length(),
		0.0,
		1.0
	)
	var running: bool = (
		input_strength > 0.05
		and input_controller.is_run_pressed()
	)

	if input_strength <= 0.05:
		state_machine.change_state(STATE_IDLE)
	else:
		facing_component.update_from_direction(Vector2.RIGHT)
		state_machine.change_state(
			STATE_RUN if running else STATE_WALK
		)

	training.tick_treadmill(
		input_strength,
		running,
		delta
	)
	animation_controller.update_visual(
		state_machine.current_state,
		facing_component.current_facing,
		delta
	)

func _get_training_manager() -> TrainingManager:
	return get_tree().get_first_node_in_group(
		"training_manager"
	) as TrainingManager

func _get_training_movement_multiplier() -> float:
	var training := _get_training_manager()
	if training == null:
		return 1.0
	return training.get_movement_multiplier()

func _process_block(_move_intent: Vector2, delta: float) -> void:
	charge_aura.visible = false
	guard_component.set_guarding(true)
	state_machine.change_state(STATE_BLOCK)

	# Defender trava completamente o deslocamento.
	# A direção ainda pode mudar porque o FacingComponent é atualizado
	# antes de entrar neste estado.
	movement_component.stop(self)

	animation_controller.update_visual(
		STATE_BLOCK,
		facing_component.current_facing,
		delta
	)

func _process_charge_ki(delta: float) -> void:
	guard_component.set_guarding(false)
	movement_component.stop(self)

	var ki_is_full := ki_component.current_ki >= ki_component.max_ki - 0.001

	# Se o Ki já estava cheio antes de iniciar o carregamento, não entra na pose.
	if ki_is_full and not state_machine.is_state(STATE_CHARGE_KI):
		charge_aura.visible = false
		state_machine.change_state(STATE_IDLE)
		animation_controller.update_visual(
			STATE_IDLE,
			facing_component.current_facing,
			delta
		)
		return

	state_machine.change_state(STATE_CHARGE_KI)

	if not ki_is_full:
		charge_aura.visible = true
		ki_component.restore(ki_charge_per_second * delta)

		_ki_quest_second_accumulator += delta
		while _ki_quest_second_accumulator >= 1.0:
			_ki_quest_second_accumulator -= 1.0
			_advance_quest_objective(&"charge_ki_second", 1)

		ki_is_full = ki_component.current_ki >= ki_component.max_ki - 0.001
	else:
		charge_aura.visible = false

	animation_controller.update_visual(
		STATE_CHARGE_KI,
		facing_component.current_facing,
		delta
	)

	if ki_is_full:
		# Ao completar o Ki, força o segundo quadro e congela nele.
		charge_aura.visible = false
		animation_controller.freeze_charge_complete(
			facing_component.current_facing
		)

func _process_stunned(delta: float) -> void:
	guard_component.set_guarding(false)
	charge_aura.visible = false
	movement_component.stop(self)
	melee_combat_component.cancel_attack()
	ki_blast_component.cancel_cast()
	special_attack_component.cancel_cast()
	state_machine.change_state(STATE_IDLE)
	animation_controller.update_visual(
		STATE_IDLE,
		facing_component.current_facing,
		delta
	)

func _process_special_attack(delta: float) -> void:
	guard_component.set_guarding(false)
	charge_aura.visible = false
	movement_component.stop(self)

	if input_controller.is_attack_pressed():
		special_attack_component.add_flurry_bonus_hit()

	special_attack_component.tick_cast(
		self,
		delta,
		input_controller.is_special_attack_held()
	)

	if special_attack_component.is_casting():
		var cast_state := special_attack_component.get_cast_state()
		state_machine.change_state(cast_state)
		animation_controller.update_visual(
			cast_state,
			special_attack_component.get_cast_facing(),
			delta
		)
	else:
		state_machine.change_state(STATE_IDLE)
		animation_controller.update_visual(
			STATE_IDLE,
			facing_component.current_facing,
			delta
		)

func _process_ki_blast(move_intent: Vector2, delta: float) -> void:
	guard_component.set_guarding(false)
	charge_aura.visible = false

	# O personagem fica estático enquanto dispara. K pode ser mantido
	# pressionado para uma sequência contínua ou tocado novamente para
	# armazenar disparos no buffer.
	if input_controller.is_ki_blast_pressed():
		ki_blast_component.buffer_cast(facing_component.current_facing)

	movement_component.stop(self)
	ki_blast_component.tick_cast(
		self,
		delta,
		input_controller.is_ki_blast_held(),
		facing_component.current_facing
	)

	if ki_blast_component.is_casting():
		var cast_state := ki_blast_component.get_cast_state()
		state_machine.change_state(cast_state)
		animation_controller.update_visual(
			cast_state,
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
	special_attack_component.cancel_cast()

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

func _on_attack_hit_confirmed(target: Node, damage: int) -> void:
	hit_stop_component.trigger()
	register_combat_hit(target, damage)

func register_combat_hit(target: Node, damage: int) -> void:
	if damage <= 0:
		return

	combo_tracker_component.register_hit(damage)

	var feedback := get_tree().get_first_node_in_group(
		"combat_feedback"
	) as CombatFeedbackManager
	if feedback != null:
		feedback.report_hit(
			target,
			damage,
			global_position
		)

func _on_hit_received(_damage: int, source_position: Vector2) -> void:
	if guard_component.was_last_hit_blocked():
		hit_stop_component.trigger()
		return

	combo_tracker_component.break_combo()
	melee_combat_component.cancel_attack()
	ki_blast_component.cancel_cast()
	special_attack_component.cancel_cast()

	var toward_source := source_position - global_position
	facing_component.update_from_direction(toward_source)

	state_machine.change_state(STATE_HURT)
	_hurt_time_left = hurt_duration
	knockback_component.start(self, source_position)
	hit_stop_component.trigger()

func _on_damaged(damage: int, current_health: int, max_health: int) -> void:
	var feedback := get_tree().get_first_node_in_group(
		"combat_feedback"
	) as CombatFeedbackManager
	if feedback != null:
		feedback.report_damage_taken(self, damage)

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

func _on_leveled_up(new_level: int) -> void:
	print("Player chegou ao nível %d." % new_level)
	_flash(Color(1.0, 0.92, 0.35, 1.0))

func _on_transformation_started(
	_transformation_id: StringName
) -> void:
	_refresh_transformation_state()

func _on_transformation_ended(
	_transformation_id: StringName
) -> void:
	_refresh_transformation_state()

func _refresh_transformation_state() -> void:
	var damage_multiplier: float = (
		transformation_component.get_damage_multiplier()
	)
	melee_combat_component.set_damage_multiplier(
		damage_multiplier
	)
	ki_blast_component.set_damage_multiplier(
		damage_multiplier
	)
	special_attack_component.set_damage_multiplier(
		damage_multiplier
	)

	var definition := transformation_component.get_definition(
		transformation_component.active_transformation
	)
	if definition == null:
		transformation_aura.visible = false
		return

	transformation_aura.color = definition.aura_color
	transformation_aura.visible = true

func _on_died() -> void:
	if _respawning:
		return

	_respawning = true
	call_deferred("_respawn_sequence")

func _respawn_sequence() -> void:
	var transition := get_tree().get_first_node_in_group(
		"screen_transition"
	) as ScreenTransition

	if transition != null:
		await transition.fade_out(0.28)

	_reset_after_defeat()

	if transition != null:
		await transition.fade_in(0.32)

	_respawning = false

func _reset_after_defeat() -> void:
	health_component.restore_full()
	ki_component.restore_full()
	melee_combat_component.cancel_attack()
	ki_blast_component.cancel_cast()
	special_attack_component.cancel_cast()
	transformation_component.end_transformation()
	knockback_component.stop(self)
	guard_component.set_guarding(false)
	charge_aura.visible = false
	var respawn_position := _spawn_position
	var checkpoint_manager := get_tree().get_first_node_in_group(
		"checkpoint_manager"
	) as CheckpointManager
	if checkpoint_manager != null:
		var checkpoint_world: String = (
			checkpoint_manager.get_checkpoint_world_path()
		)
		if not checkpoint_world.is_empty():
			var world := get_tree().get_first_node_in_group(
				"world_manager"
			) as WorldManager
			if (
				world != null
				and world.current_world_path != checkpoint_world
			):
				world.load_world(checkpoint_world)

		respawn_position = checkpoint_manager.get_respawn_position(
			_spawn_position
		)

	global_position = respawn_position
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
	elif input_controller.is_run_pressed():
		state_machine.change_state(STATE_RUN)
	else:
		state_machine.change_state(STATE_WALK)

func _advance_quest_objective(
	objective_id: StringName,
	amount: int = 1
) -> void:
	var quests := get_tree().get_first_node_in_group(
		"quest_manager"
	) as QuestManager
	if quests != null:
		quests.advance_objective(objective_id, amount)

func _facing_vector(facing: StringName) -> Vector2:
	match facing:
		&"up":
			return Vector2.UP
		&"down":
			return Vector2.DOWN
		&"left":
			return Vector2.LEFT
		&"right":
			return Vector2.RIGHT

	return Vector2.DOWN

func get_current_state() -> StringName:
	return state_machine.current_state

func use_inventory_item(item_id: StringName) -> bool:
	return consumable_component.use_item(item_id)

func get_facing() -> StringName:
	return facing_component.current_facing
