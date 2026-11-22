class_name Player
extends CharacterBody2D

const STATE_IDLE: StringName = &"idle"
const STATE_WALK: StringName = &"walk"
const STATE_RUN: StringName = &"run"
const STATE_HURT: StringName = &"hurt"
const STATE_BLOCK: StringName = &"block"
const STATE_CHARGE_KI: StringName = &"charge_ki"
const STATE_SWORD_EQUIP: StringName = &"sword_equip"
# Flight: hovering in place, cruising (like walking) and fast (like running).
const STATE_FLY_HOVER: StringName = &"fly_hover"
const STATE_FLY: StringName = &"fly"
const STATE_FLY_FAST: StringName = &"fly_fast"
# Focus activities: still, trained over time, cancelled by any action.
const STATE_MEDITATE: StringName = &"meditate"
const STATE_STUDY: StringName = &"study"
# Analyze (T) reaches beings within this distance.
const ANALYZE_RANGE := 180.0

@export_range(1.0, 3.0, 0.05)
var run_speed_scale: float = 1.333333

@export_range(0.0, 1.0, 0.05)
var attack_move_speed_scale: float = 0.85

@export_range(0.0, 1.0, 0.05)
var kick_move_speed_scale: float = 0.70

@export var hurt_duration: float = 0.24
@export var ki_charge_per_second: float = 28.0
@export var respawn_invulnerability_duration: float = 1.0
# Short "draw the sword" pose played when a sword is equipped.
@export var sword_equip_pose_duration: float = 0.34

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
@onready var equipment_component: EquipmentComponent = $Components/EquipmentComponent
@onready var sword_sheath: SwordSheathVisual = $Visuals/SwordSheath
@onready var flight_component: FlightComponent = $Components/FlightComponent
@onready var power_aura: PowerAuraComponent = $Visuals/PowerAura
@onready var character_stats: CharacterStatsComponent = $Components/CharacterStats
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
var _equip_pose_left: float = 0.0
# Current focus activity (STATE_MEDITATE / STATE_STUDY) and its study spot.
var _focus: StringName = &""
var _study_spot: Node
var _blink_tween: Tween

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
	equipment_component.equipment_changed.connect(_on_equipment_changed)
	equipment_component.equip_failed.connect(_on_equip_failed)
	inventory_component.inventory_full.connect(_on_inventory_full)
	flight_component.flight_changed.connect(_on_flight_changed)
	flight_component.landing_blocked.connect(_notify.bind("Can't land here"))
	power_aura.aura_changed.connect(_on_aura_changed)
	character_stats.stats_changed.connect(_refresh_transformation_state)
	character_stats.stat_leveled_up.connect(_on_stat_leveled_up)
	melee_combat_component.attack_hitbox.hit_confirmed.connect(_on_melee_hit_for_training)
	ki_blast_component.projectile_fired.connect(_on_ki_blast_fired)
	special_attack_component.cast_started.connect(_on_special_cast_started)
	_refresh_transformation_state()
	_refresh_equipment_state()

func _physics_process(delta: float) -> void:
	if _respawning:
		movement_component.stop(self)
		return

	var move_intent := input_controller.get_move_intent()

	if input_controller.is_toggle_aura_pressed():
		power_aura.toggle()

	if status_effect_component.has_status(&"stun"):
		_process_stunned(delta)
		return

	if state_machine.is_state(STATE_HURT):
		_process_hurt(delta)
		return

	if _equip_pose_left > 0.0:
		_process_equip_pose(delta)
		return

	if _focus != &"":
		if _process_focus(move_intent, delta):
			return

	if input_controller.is_analyze_pressed():
		analyze_nearest()

	facing_component.update_from_direction(move_intent)

	if input_controller.is_sky_travel_pressed():
		travel_sky()
	if _get_world_manager_node() != null and _get_world_manager_node().is_in_sky():
		_process_sky(move_intent, delta)
		return

	var training := _get_training_manager()
	if training != null and training.is_treadmill_active():
		if flight_component.is_flying:
			flight_component.land_immediately()
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

	if input_controller.is_toggle_flight_pressed():
		toggle_flight()

	if input_controller.is_meditate_pressed():
		if start_meditation():
			# Not _process_focus: this same M press would cancel it.
			animation_controller.update_visual(_focus, facing_component.current_facing, delta)
			return

	if input_controller.is_toggle_weapon_pressed():
		toggle_weapon()
		if _equip_pose_left > 0.0:
			_process_equip_pose(delta)
			return

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
			_basic_attack_kind()
		):
			_update_active_melee(move_intent, delta)
			return

	_update_movement_state(move_intent)
	movement_component.move(
		self,
		move_intent,
		_get_locomotion_speed_scale()
	)
	if state_machine.is_state(STATE_FLY_FAST):
		_drain_fast_flight_ki(delta)
	_train_movement(delta)
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
			_basic_attack_kind()
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
	elif state_machine.is_state(STATE_FLY):
		base_scale = flight_component.fly_speed_scale
	elif state_machine.is_state(STATE_FLY_FAST):
		base_scale = flight_component.fast_fly_speed_scale

	return (
		base_scale
		* character_stats.move_speed_multiplier()
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

	move_and_collide(training.get_treadmill_anchor() - global_position)

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
	if _try_evade():
		return 0
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
	stop_focus()
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
	# Strength drives melee, Wisdom drives ki techniques.
	melee_combat_component.set_damage_multiplier(
		damage_multiplier * character_stats.melee_damage_multiplier()
	)
	ki_blast_component.set_damage_multiplier(
		damage_multiplier * character_stats.magic_damage_multiplier()
	)
	special_attack_component.set_damage_multiplier(
		damage_multiplier * character_stats.magic_damage_multiplier()
	)
	special_attack_component.cooldown_multiplier = (
		character_stats.special_cooldown_multiplier()
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
	# Cancel immediately; the respawn fade must not leave a damaging cast.
	melee_combat_component.cancel_attack()
	ki_blast_component.cancel_cast()
	special_attack_component.cancel_cast()
	movement_component.stop(self)
	call_deferred("_respawn_sequence")

func _respawn_sequence() -> void:
	# Travel already owns the fade. Finish it before returning to checkpoint.
	var world := get_tree().get_first_node_in_group("world_manager") as WorldManager
	if world != null and world.is_transitioning():
		await world.transition_finished
	var transition := get_tree().get_first_node_in_group(
		"screen_transition"
	) as ScreenTransition

	if transition != null:
		await transition.fade_out(0.28)

	_reset_after_defeat()

	if transition != null:
		await transition.fade_in(0.32)

	_respawning = false

func reset_runtime_after_load() -> void:
	melee_combat_component.cancel_attack()
	ki_blast_component.cancel_cast()
	special_attack_component.cancel_cast()
	status_effect_component.clear_all()
	combo_tracker_component.break_combo()
	knockback_component.stop(self)
	knockback_component.clear_start_suppression()
	guard_component.set_guarding(false)
	_hurt_time_left = 0.0
	_ki_quest_second_accumulator = 0.0
	charge_aura.visible = false
	stop_focus()
	flight_component.land_immediately()
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	$Visuals.modulate = Color.WHITE
	var dash := get_tree().get_first_node_in_group("player_dash_system") as PlayerDashSystem
	if dash != null:
		dash.reset_after_load()
	state_machine.change_state(STATE_IDLE)
	animation_controller.update_visual(STATE_IDLE, facing_component.current_facing, 0.0)

func _reset_after_defeat() -> void:
	status_effect_component.clear_all()
	combo_tracker_component.break_combo()
	_hurt_time_left = 0.0
	health_component.restore_full()
	ki_component.restore_full()
	# Health returns before fade-in ends; protect the arrival at the checkpoint.
	hurtbox.grant_invulnerability(respawn_invulnerability_duration)
	melee_combat_component.cancel_attack()
	ki_blast_component.cancel_cast()
	special_attack_component.cancel_cast()
	transformation_component.end_transformation()
	stop_focus()
	flight_component.land_immediately()
	knockback_component.stop(self)
	guard_component.set_guarding(false)
	charge_aura.visible = false
	# Defeat shuts the gravity room down, like leaving through a portal does;
	# otherwise the player would come back still crushed by it.
	var training := get_tree().get_first_node_in_group("training_manager") as TrainingManager
	if training != null:
		training.reset_training_environment()
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
	if flight_component.is_flying:
		if move_intent.is_zero_approx():
			state_machine.change_state(STATE_FLY_HOVER)
		elif input_controller.is_run_pressed() and _can_fly_fast():
			state_machine.change_state(STATE_FLY_FAST)
		else:
			state_machine.change_state(STATE_FLY)
		return
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

# With a sword equipped the attack button slashes (Trunks' sword combo);
# the kick button still kicks.
func _basic_attack_kind() -> StringName:
	if equipment_component.has_weapon_style(&"sword"):
		return MeleeCombatComponent.ATTACK_SWORD
	return MeleeCombatComponent.ATTACK_PUNCH

func has_sword_equipped() -> bool:
	return equipment_component.has_weapon_style(&"sword")

# Quick equip/unequip of the first weapon carried. Returns true if a weapon
# is equipped afterwards.
func toggle_weapon() -> bool:
	var equipped := equipment_component.get_equipped(
		EquipmentComponent.SLOT_WEAPON
	)
	if equipped != &"":
		# Fails (stays equipped) when the bag has no room for the weapon.
		return not equipment_component.unequip(EquipmentComponent.SLOT_WEAPON)
	var weapon := equipment_component.find_inventory_weapon()
	if weapon == &"":
		var feed := get_tree().get_first_node_in_group("notification_feed")
		if feed != null and feed.has_method("push_message"):
			feed.push_message("No weapon to equip")
		return false
	return equipment_component.equip(weapon)

func _on_equipment_changed(slot: StringName, item_id: StringName) -> void:
	_refresh_equipment_state()
	if slot != EquipmentComponent.SLOT_WEAPON:
		return
	if item_id == &"":
		# A sword string must not continue once the blade is put away.
		if melee_combat_component.get_attack_kind() == MeleeCombatComponent.ATTACK_SWORD:
			melee_combat_component.cancel_attack()
		_equip_pose_left = 0.0
		_flash(Color(0.75, 0.75, 0.8))
		return
	if has_sword_equipped() and is_inside_tree() and not _respawning:
		_equip_pose_left = sword_equip_pose_duration
		_flash(Color(1.0, 1.0, 0.85))

func _refresh_equipment_state() -> void:
	var weapon := equipment_component.get_weapon_data()
	melee_combat_component.set_weapon_damage_bonus(
		weapon.melee_damage_bonus if weapon != null else 0
	)
	sword_sheath.equipped = has_sword_equipped()

func _process_equip_pose(delta: float) -> void:
	_equip_pose_left -= delta
	movement_component.stop(self)
	state_machine.change_state(STATE_SWORD_EQUIP)
	animation_controller.update_visual(
		STATE_SWORD_EQUIP,
		facing_component.current_facing,
		delta
	)
	if _equip_pose_left <= 0.0:
		_equip_pose_left = 0.0
		state_machine.change_state(STATE_IDLE)

func get_current_state() -> StringName:
	return state_machine.current_state

func use_inventory_item(item_id: StringName) -> bool:
	return consumable_component.use_item(item_id)

func get_facing() -> StringName:
	return facing_component.current_facing

func is_flying() -> bool:
	return flight_component.is_flying

func _get_world_manager_node() -> WorldManager:
	return get_tree().get_first_node_in_group("world_manager") as WorldManager

# U: go up to the sky (while flying over Earth) or come back down.
func travel_sky() -> void:
	var world := _get_world_manager_node()
	if world == null or world.is_transitioning():
		return
	if world.is_in_sky():
		world.descend_to_earth()
	elif world.current_world_path != OpenWorld.SCENE_PATH:
		_notify("Can't fly that high from here")
	elif not is_flying():
		_notify("Take off first (V)")
	else:
		world.ascend_to_sky()

# In the sky only flying matters: no fights, no ki cost, V comes back down.
func _process_sky(move_intent: Vector2, delta: float) -> void:
	guard_component.set_guarding(false)
	charge_aura.visible = false
	if not flight_component.is_flying:
		flight_component.take_off()
	if input_controller.is_toggle_flight_pressed():
		travel_sky()
	_update_movement_state(move_intent)
	movement_component.move(self, move_intent, _get_locomotion_speed_scale())
	animation_controller.update_visual(
		state_machine.current_state,
		facing_component.current_facing,
		delta
	)

# Take off / land (V). Returns true while flying.
func toggle_flight() -> bool:
	var flying := flight_component.toggle()
	_update_movement_state(input_controller.get_move_intent())
	return flying

# Fast flight burns ki; with an empty tank the player keeps cruising.
func _can_fly_fast() -> bool:
	return (
		flight_component.fast_fly_ki_per_second <= 0.0
		or ki_component.current_ki > 0.5
	)

func _drain_fast_flight_ki(delta: float) -> void:
	var cost := flight_component.fast_fly_ki_per_second * delta
	if cost <= 0.0:
		return
	if ki_component.consume_up_to(cost) < cost - 0.0001:
		_notify("Out of ki")

func _on_flight_changed(flying: bool) -> void:
	_notify("Flying" if flying else "Landed")

func _on_aura_changed(enabled: bool, color_id: StringName) -> void:
	if not is_inside_tree():
		return
	_notify(
		"Aura: %s" % PowerAuraComponent.get_color_name(color_id)
		if enabled else "Aura off"
	)

func _on_equip_failed(_item_id: StringName, reason: String) -> void:
	if reason == EquipmentComponent.REASON_BAG_FULL:
		_notify("Bag full")

func _on_inventory_full(item_id: StringName, _rejected: int) -> void:
	_notify("Bag full: no room for %s" % ItemCatalog.get_display_name(item_id))

func _notify(message: String) -> void:
	var feed := get_tree().get_first_node_in_group("notification_feed")
	if feed != null and feed.has_method("push_message"):
		feed.push_message(message)


# --- Character stats ----------------------------------------------------------

func get_stats() -> CharacterStatsComponent:
	return character_stats

func is_meditating() -> bool:
	return _focus == STATE_MEDITATE

func is_studying() -> bool:
	return _focus == STATE_STUDY

# Punches, kicks and sword cuts that connect train Strength.
func _on_melee_hit_for_training(_target: Node, damage: int) -> void:
	if damage > 0:
		character_stats.add_xp(CharacterStatsComponent.STRENGTH, character_stats.xp_melee_hit)

func _on_ki_blast_fired(_facing: StringName, _variant: int) -> void:
	character_stats.add_xp(CharacterStatsComponent.WISDOM, character_stats.xp_ki_blast)

# Ki techniques train Wisdom in proportion to the ki they cost.
func _on_special_cast_started(ability_id: StringName) -> void:
	for data in special_attack_component.abilities:
		if data != null and data.ability_id == ability_id:
			character_stats.add_xp(
				CharacterStatsComponent.WISDOM,
				maxf(data.ki_cost, 4.0) * character_stats.xp_special_per_ki
			)
			return

# Running and fast flight train Agility (only while actually moving).
func _train_movement(delta: float) -> void:
	if velocity.length() < 1.0:
		return
	if state_machine.is_state(STATE_RUN):
		character_stats.add_xp(CharacterStatsComponent.AGILITY, character_stats.xp_run_per_second * delta)
	elif state_machine.is_state(STATE_FLY_FAST):
		character_stats.add_xp(CharacterStatsComponent.AGILITY, character_stats.xp_fast_flight_per_second * delta)

func _on_stat_leveled_up(stat: StringName, new_level: int) -> void:
	_notify("%s Lv %d" % [CharacterStatsComponent.stat_name(stat), new_level])
	var feedback := get_tree().get_first_node_in_group("combat_feedback") as CombatFeedbackManager
	if feedback != null and is_inside_tree():
		feedback.spawn_floating_text(
			"%s UP" % CharacterStatsComponent.stat_name(stat).to_upper(),
			global_position + Vector2(0, -30),
			Color(1.0, 0.85, 0.35)
		)

# Agility: a dodged hit does no damage. The fighter blinks out and back in
# on the same spot (zanzoken), showing they were simply too fast.
func _try_evade() -> bool:
	if (
		_respawning
		or health_component.is_dead()
		or _focus != &""
		or status_effect_component.has_status(&"stun")
		or state_machine.is_state(STATE_HURT)
		or guard_component.is_guarding()
	):
		return false
	if randf() >= character_stats.dodge_chance():
		return false
	character_stats.add_xp(CharacterStatsComponent.AGILITY, character_stats.xp_evade)
	play_evade_blink()
	return true

func play_evade_blink() -> void:
	var visuals := $Visuals as Node2D
	_spawn_evade_afterimage()
	if _blink_tween != null and _blink_tween.is_valid():
		_blink_tween.kill()
	visuals.modulate.a = 1.0
	_blink_tween = create_tween()
	_blink_tween.tween_property(visuals, "modulate:a", 0.0, 0.03)
	_blink_tween.tween_interval(0.07)
	_blink_tween.tween_property(visuals, "modulate:a", 1.0, 0.02)
	_blink_tween.tween_property(visuals, "modulate:a", 0.25, 0.03)
	_blink_tween.tween_property(visuals, "modulate:a", 1.0, 0.03)
	var feedback := get_tree().get_first_node_in_group("combat_feedback") as CombatFeedbackManager
	if feedback != null:
		feedback.spawn_floating_text("DODGE", global_position + Vector2(0, -26), Color(0.6, 0.95, 1.0))

func _spawn_evade_afterimage() -> void:
	var sprite := animation_controller.sprite
	if sprite == null or sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(sprite.animation):
		return
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if texture == null:
		return
	var ghost := Sprite2D.new()
	ghost.name = "EvadeAfterimage"
	ghost.texture = texture
	ghost.flip_h = sprite.flip_h
	ghost.top_level = true
	ghost.z_as_relative = false
	ghost.z_index = z_index
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.modulate = Color(1, 1, 1, 0.75)
	add_child(ghost)
	ghost.global_position = sprite.global_position
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.22)
	tween.tween_callback(ghost.queue_free)

# --- Focus: meditation (M) and study ------------------------------------------

func start_meditation() -> bool:
	if _focus == STATE_MEDITATE:
		stop_focus()
		return false
	if flight_component.is_flying:
		_notify("Land to meditate")
		return false
	_begin_focus(STATE_MEDITATE)
	_notify("Meditating (M or move to stop)")
	return true

# Called by a StudySpot. Returns false when the player can't study now.
func start_study(spot: Node) -> bool:
	if flight_component.is_flying:
		_notify("Land to study")
		return false
	_study_spot = spot
	_begin_focus(STATE_STUDY)
	return true

func stop_focus() -> void:
	if _focus == &"":
		return
	var previous := _focus
	_focus = &""
	_study_spot = null
	if is_inside_tree() and state_machine.is_state(previous):
		state_machine.change_state(STATE_IDLE)

func _begin_focus(kind: StringName) -> void:
	_focus = kind
	movement_component.stop(self)
	velocity = Vector2.ZERO
	charge_aura.visible = false
	guard_component.set_guarding(false)
	state_machine.change_state(kind)

# Returns true while the focus keeps the player busy this frame.
func _process_focus(move_intent: Vector2, delta: float) -> bool:
	var cancel := (
		not move_intent.is_zero_approx()
		or input_controller.is_attack_pressed()
		or input_controller.is_kick_pressed()
		or input_controller.is_ki_blast_pressed()
		or input_controller.is_special_attack_pressed()
		or input_controller.is_block_pressed()
		or input_controller.is_charge_ki_pressed()
		or input_controller.is_toggle_flight_pressed()
		or (_focus == STATE_MEDITATE and input_controller.is_meditate_pressed())
		or (_focus == STATE_STUDY and input_controller.is_interact_pressed())
		or (_focus == STATE_STUDY and not is_instance_valid(_study_spot))
	)
	if cancel:
		stop_focus()
		return false
	if input_controller.is_analyze_pressed():
		analyze_nearest()
	movement_component.stop(self)
	state_machine.change_state(_focus)
	if _focus == STATE_MEDITATE:
		character_stats.add_xp(CharacterStatsComponent.WISDOM, character_stats.xp_meditation_per_second * delta)
		ki_component.restore(ki_charge_per_second * 0.35 * delta)
	elif _focus == STATE_STUDY:
		var rate: float = 1.0
		if _study_spot != null and "xp_multiplier" in _study_spot:
			rate = float(_study_spot.get("xp_multiplier"))
		character_stats.add_xp(CharacterStatsComponent.INTELLIGENCE, character_stats.xp_study_per_second * rate * delta)
	animation_controller.update_visual(_focus, facing_component.current_facing, delta)
	return true

# --- Analyze (T) ------------------------------------------------------------------

# Reads the closest being in range; how much is revealed depends on
# Intelligence (CharacterStatsComponent.analyze_tier).
func analyze_nearest() -> Node2D:
	var target := find_analyze_target()
	if target == null:
		_notify("Nothing to analyze nearby")
		return null
	var tier := character_stats.analyze_tier()
	target.set_meta(&"analyzed_tier", maxi(int(target.get_meta(&"analyzed_tier", -1)), tier))
	var panel := get_tree().get_first_node_in_group("analyze_panel")
	if panel != null and panel.has_method("show_analysis"):
		panel.show_analysis(target, tier)
	return target

func find_analyze_target() -> Node2D:
	var best: Node2D = null
	var best_score := INF
	var facing_vector := _facing_vector(facing_component.current_facing)
	for group in [&"enemy", &"npc"]:
		for node in get_tree().get_nodes_in_group(group):
			var being := node as Node2D
			if being == null or being == self or not being.is_inside_tree():
				continue
			var offset := being.global_position - global_position
			var distance := offset.length()
			if distance > ANALYZE_RANGE:
				continue
			var health := being.get_node_or_null("Components/HealthComponent") as HealthComponent
			if health != null and health.is_dead():
				continue
			# Prefer fighters, then what the player is facing.
			var score := distance - 40.0 * offset.normalized().dot(facing_vector)
			if group == &"npc":
				score += 120.0
			if score < best_score:
				best_score = score
				best = being
	return best

# Intelligence: a chance to see an enemy attack coming ("!" over it).
func on_enemy_attack_started(enemy: Node2D, _kind: StringName) -> void:
	if enemy == null or not is_instance_valid(enemy) or health_component.is_dead():
		return
	if enemy.global_position.distance_to(global_position) > 260.0:
		return
	if randf() >= character_stats.attack_read_chance():
		return
	var feedback := get_tree().get_first_node_in_group("combat_feedback") as CombatFeedbackManager
	if feedback != null:
		feedback.spawn_floating_text("!", enemy.global_position + Vector2(0, -34), Color(1.0, 0.9, 0.25))
