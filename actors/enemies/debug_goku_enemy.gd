class_name DebugGokuEnemy
extends CharacterBody2D

const DMI_SPRITE_SHEET_SCRIPT = preload(
	"res://core/assets/dmi_sprite_sheet.gd"
)
const DMI_ANIMATION_FPS := 10.0
const DMI_STATE_MISSING: StringName = &"__missing__"

const STATE_IDLE: StringName = &"idle"
const STATE_WALK: StringName = &"walk"
const STATE_RUN: StringName = &"run"
const STATE_HURT: StringName = &"hurt"
const STATE_BLOCK: StringName = &"block"
const STATE_DEFEATED: StringName = &"defeated"

const DIRECTION_ROWS := {
	&"down": 0,
	&"left": 1,
	&"right": 2,
	&"up": 3,
}

@export_file("*.dmi")
var dmi_sprite_path: String = "res://assets/sprites/characters/goku/hu2/Goku.dmi"

@export var prefer_dmi_sprite: bool = true

@export_file("*.png")
var sprite_sheet_path: String = "res://assets/sprites/characters/goku/processed/goku_buus_fury_base.png"

@export_file("*.png")
var run_sheet_path: String = "res://assets/sprites/characters/goku/processed/goku_buus_fury_run.png"

@export_file("*.png")
var attack_sheet_path: String = "res://assets/sprites/characters/goku/processed/goku_buus_fury_attack.png"

@export_file("*.png")
var hurt_sheet_path: String = "res://assets/sprites/characters/goku/processed/goku_buus_fury_hurt.png"

@export_file("*.png")
var block_sheet_path: String = "res://assets/sprites/characters/goku/processed/goku_buus_fury_block.png"

@export_file("*.png")
var ki_blast_sheet_path: String = "res://assets/sprites/characters/goku/processed/goku_buus_fury_ki_blast.png"

@export var frame_size: Vector2i = Vector2i(32, 32)
@export var idle_column: int = 0
@export var walk_columns: PackedInt32Array = PackedInt32Array([2, 3, 4, 5])
@export var run_columns: PackedInt32Array = PackedInt32Array([0, 1, 2, 3])
@export var attack_1_columns: PackedInt32Array = PackedInt32Array([0, 1, 2, 3])
@export var attack_2_columns: PackedInt32Array = PackedInt32Array([4, 5, 6, 7])
@export var hurt_columns: PackedInt32Array = PackedInt32Array([0, 1])
@export var block_columns: PackedInt32Array = PackedInt32Array([0])
@export var ki_blast_prepare_columns: PackedInt32Array = PackedInt32Array([0])
@export var ki_blast_1_columns: PackedInt32Array = PackedInt32Array([1])
@export var ki_blast_2_columns: PackedInt32Array = PackedInt32Array([2])
@export var walk_fps: float = 8.0
@export var run_fps: float = 12.0
@export var attack_fps: float = 8.0
@export var hurt_fps: float = 10.0
@export var hurt_duration: float = 0.24

@export var detection_range: float = 170.0
@export var disengage_range: float = 220.0
@export var leash_range: float = 260.0
@export var return_home_tolerance: float = 3.0

# Aggro uses hysteresis: detection_range is only used to acquire the
# Player. Once engaged, the enemy keeps pursuing instead of bouncing
# between chase and return-home at an invisible distance boundary.
@export var persistent_aggro: bool = true
@export var use_spawn_leash: bool = false
@export var hard_disengage_range: float = 1200.0
@export var attack_range: float = 30.0
@export var attack_cooldown: float = 0.60
@export var facing_change_cooldown: float = 0.16

@export var ranged_min_distance: float = 58.0
@export var ranged_max_distance: float = 150.0
@export var ranged_attack_cooldown: float = 1.35
@export var ranged_decision_interval: float = 0.32

@export var pickup_scene: PackedScene
@export_range(0, 9999, 1)
var min_zeni_drop: int = 8
@export_range(0, 9999, 1)
var max_zeni_drop: int = 18
@export_range(0.0, 1.0, 0.01)
var senzu_drop_chance: float = 0.10
@export var respawn_for_debug: bool = true
@export var respawn_delay: float = 1.2
@export var respawn_collision_grace: float = 0.20
@export var respawn_separation_distance: float = 24.0
@export var is_training_partner: bool = false

@export_enum("up", "down", "left", "right")
var initial_facing: String = "left"

@onready var sprite: AnimatedSprite2D = $Visuals/AnimatedSprite2D
@onready var placeholder: Polygon2D = $Visuals/Placeholder
@onready var health_component: HealthComponent = $Components/HealthComponent
@onready var movement_component: MovementComponent = $Components/MovementComponent
@onready var knockback_component: KnockbackComponent = $Components/KnockbackComponent
@onready var state_machine: StateMachine = $Components/StateMachine
@onready var melee_combat_component: MeleeCombatComponent = $Components/MeleeCombatComponent
@onready var guard_component: GuardComponent = $Components/GuardComponent
@onready var ai_component: EnemyAIComponent = $Components/EnemyAIComponent
@onready var ki_component: KiComponent = $Components/KiComponent
@onready var ki_blast_component: KiBlastComponent = $Components/KiBlastComponent
@onready var status_effect_component: StatusEffectComponent = $Components/StatusEffectComponent
@onready var experience_reward_component: ExperienceRewardComponent = $Components/ExperienceRewardComponent
@onready var hurtbox: HurtboxComponent = $Hurtbox
@onready var body_collision: CollisionShape2D = $CollisionShape2D

var _hurt_time_left: float = 0.0
var _attack_cooldown_left: float = 0.0
var _ranged_cooldown_left: float = 0.0
var _ranged_decision_left: float = 0.0
var _facing_change_time_left: float = 0.0
var _flash_tween: Tween
var _spawn_position: Vector2
var _current_facing: StringName = &"left"
var _target: Node2D
var _engaged: bool = false
var _returning_home: bool = false
var _defeated: bool = false
var _respawn_collision_pending: bool = false
var _respawn_collision_time_left: float = 0.0

func _ready() -> void:
	_spawn_position = global_position
	_current_facing = StringName(initial_facing)
	_target = get_tree().get_first_node_in_group("player") as Node2D

	_apply_tier_difficulty()
	_build_sprite_frames()
	_play_current_animation()

	hurtbox.hit_received.connect(_on_hit_received)
	health_component.damaged.connect(_on_damaged)
	health_component.died.connect(_on_died)

func _physics_process(delta: float) -> void:
	if _defeated:
		return

	if _respawn_collision_pending:
		_process_respawn_collision(delta)
		return

	if status_effect_component.has_status(&"stun"):
		_process_stunned()
		return

	_attack_cooldown_left = maxf(
		_attack_cooldown_left - delta,
		0.0
	)
	_ranged_cooldown_left = maxf(
		_ranged_cooldown_left - delta,
		0.0
	)
	_ranged_decision_left = maxf(
		_ranged_decision_left - delta,
		0.0
	)
	_facing_change_time_left = maxf(
		_facing_change_time_left - delta,
		0.0
	)
	ai_component.tick(delta)

	if state_machine.is_state(STATE_HURT):
		guard_component.set_guarding(false)
		ki_blast_component.cancel_cast()
		_process_hurt(delta)
		return

	if not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group(
			"player"
		) as Node2D

	if not is_instance_valid(_target):
		guard_component.set_guarding(false)
		_set_idle()
		return

	if ki_blast_component.is_casting():
		_process_ranged_attack(delta)
		return

	if ai_component.is_rushing():
		_process_ai_rush()
		return

	var defense_action: int = ai_component.choose_defensive_action(
		self,
		_target
	)

	if (
		defense_action == EnemyAIComponent.DefensiveAction.BLOCK
		or ai_component.is_guarding()
	):
		melee_combat_component.cancel_attack()
		ki_blast_component.cancel_cast()
		_process_ai_guard()
		return

	if (
		defense_action == EnemyAIComponent.DefensiveAction.DODGE
		or ai_component.is_dodging()
	):
		melee_combat_component.cancel_attack()
		ki_blast_component.cancel_cast()
		_process_ai_dodge()
		return

	guard_component.set_guarding(false)

	if melee_combat_component.is_attacking():
		_process_attack(delta)
		return

	var to_target: Vector2 = (
		_target.global_position - global_position
	)
	var distance_to_target: float = to_target.length()
	var distance_from_spawn: float = global_position.distance_to(
		_spawn_position
	)

	if _returning_home:
		if distance_from_spawn <= return_home_tolerance:
			_returning_home = false
			_set_idle()
		else:
			_return_home()
		return

	if not _engaged:
		if distance_to_target > detection_range:
			_set_idle()
			return

		_engaged = true

	if (
		use_spawn_leash
		and distance_from_spawn > leash_range
	):
		_begin_return_home()
		return

	if (
		not persistent_aggro
		and distance_to_target > disengage_range
	):
		_begin_return_home()
		return

	if distance_to_target > hard_disengage_range:
		_begin_return_home()
		return

	_update_facing_from_direction(to_target)

	if (
		distance_to_target <= attack_range * 1.25
		and _attack_cooldown_left <= 0.0
		and ai_component.consume_counterattack()
	):
		_start_attack()
		return

	if ai_component.try_begin_rush(distance_to_target):
		_process_ai_rush()
		return

	if _should_start_ranged_attack(distance_to_target):
		_start_ranged_attack()
		return

	if distance_to_target <= attack_range:
		movement_component.stop(self)
		_current_facing = _facing_toward(
			_target.global_position
		)

		if _attack_cooldown_left <= 0.0:
			_start_attack()
		else:
			state_machine.change_state(STATE_IDLE)
			_play_current_animation()
		return

	var approach_direction: Vector2 = (
		ai_component.get_approach_direction(
			to_target,
			distance_to_target
		)
	)

	state_machine.change_state(STATE_WALK)
	movement_component.move(
		self,
		approach_direction,
		ai_component.get_chase_speed_scale()
	)
	_play_current_animation()

func _process_ai_rush() -> void:
	if not is_instance_valid(_target):
		ai_component.cancel_rush()
		_set_idle()
		return

	var to_target: Vector2 = (
		_target.global_position - global_position
	)
	var distance_to_target: float = to_target.length()

	if distance_to_target <= attack_range:
		ai_component.cancel_rush()
		movement_component.stop(self)
		_current_facing = _facing_toward(
			_target.global_position
		)

		if _attack_cooldown_left <= 0.0:
			_start_attack()
		else:
			state_machine.change_state(STATE_IDLE)
			_play_current_animation()
		return

	_update_facing_from_direction(to_target)
	state_machine.change_state(STATE_RUN)
	movement_component.move(
		self,
		to_target.normalized(),
		ai_component.get_rush_speed_scale()
	)
	_play_current_animation()

func _should_start_ranged_attack(distance_to_target: float) -> bool:
	if (
		distance_to_target < ranged_min_distance
		or distance_to_target > ranged_max_distance
	):
		return false

	if _ranged_cooldown_left > 0.0 or _ranged_decision_left > 0.0:
		return false

	_ranged_decision_left = maxf(ranged_decision_interval, 0.05)

	if ai_component.profile == null:
		return false

	if not _has_clear_line_to_target():
		return false

	return randf() <= ai_component.profile.ranged_attack_chance

func _has_clear_line_to_target() -> bool:
	if not is_instance_valid(_target):
		return false

	var query := PhysicsRayQueryParameters2D.create(
		global_position,
		_target.global_position
	)
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var result: Dictionary = (
		get_world_2d().direct_space_state.intersect_ray(query)
	)

	return result.is_empty()

func _start_ranged_attack() -> void:
	if not is_instance_valid(_target):
		return

	movement_component.stop(self)
	guard_component.set_guarding(false)
	melee_combat_component.cancel_attack()
	_current_facing = _facing_toward(_target.global_position)

	var aim_direction: Vector2 = (
		_target.global_position - global_position
	).normalized()

	if ki_blast_component.start_cast(
		_current_facing,
		aim_direction
	):
		state_machine.change_state(
			ki_blast_component.get_cast_state()
		)
		_play_current_animation()

func _process_ranged_attack(delta: float) -> void:
	if not is_instance_valid(_target):
		ki_blast_component.cancel_cast()
		return

	movement_component.stop(self)
	guard_component.set_guarding(false)
	_current_facing = _facing_toward(_target.global_position)

	ki_blast_component.tick_cast(
		self,
		delta,
		false,
		_current_facing
	)

	if ki_blast_component.is_casting():
		state_machine.change_state(
			ki_blast_component.get_cast_state()
		)
	else:
		var cooldown_scale: float = 1.0
		if ai_component.profile != null:
			cooldown_scale = ai_component.profile.ranged_cooldown_scale

		_ranged_cooldown_left = maxf(
			ranged_attack_cooldown * cooldown_scale,
			0.10
		)
		state_machine.change_state(STATE_IDLE)

	_play_current_animation()

func _process_stunned() -> void:
	movement_component.stop(self)
	guard_component.set_guarding(false)
	ai_component.cancel_rush()
	melee_combat_component.cancel_attack()
	ki_blast_component.cancel_cast()
	state_machine.change_state(STATE_IDLE)
	_play_current_animation()

func _process_ai_guard() -> void:
	ai_component.cancel_rush()
	movement_component.stop(self)
	guard_component.set_guarding(true)

	var threat_position: Vector2 = ai_component.get_threat_position()
	_current_facing = _facing_toward(threat_position)

	state_machine.change_state(STATE_BLOCK)
	_play_current_animation()

func _process_ai_dodge() -> void:
	ai_component.cancel_rush()
	guard_component.set_guarding(false)

	if is_instance_valid(_target):
		_update_facing_from_direction(
			_target.global_position - global_position
		)

	state_machine.change_state(STATE_WALK)
	movement_component.move(
		self,
		ai_component.get_dodge_direction(),
		ai_component.get_dodge_speed_scale()
	)
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
	guard_component.set_guarding(false)
	movement_component.stop(self)
	melee_combat_component.tick_attack(delta)

	if melee_combat_component.is_attacking():
		state_machine.change_state(melee_combat_component.get_attack_state())
		_current_facing = melee_combat_component.get_attack_facing()
	else:
		_attack_cooldown_left = (
			attack_cooldown
			* ai_component.get_attack_cooldown_scale()
		)
		state_machine.change_state(STATE_IDLE)

	_play_current_animation()

func _start_attack() -> void:
	guard_component.set_guarding(false)
	ki_blast_component.cancel_cast()
	if melee_combat_component.start_attack(_current_facing):
		state_machine.change_state(melee_combat_component.get_attack_state())
		_play_current_animation()

func _set_idle() -> void:
	guard_component.set_guarding(false)
	movement_component.stop(self)
	state_machine.change_state(STATE_IDLE)
	_play_current_animation()

func _begin_return_home() -> void:
	_engaged = false
	_returning_home = true
	_return_home()

func _return_home() -> void:
	ai_component.cancel_rush()
	guard_component.set_guarding(false)
	ki_blast_component.cancel_cast()
	var to_home: Vector2 = _spawn_position - global_position
	if to_home.length() <= return_home_tolerance:
		global_position = _spawn_position
		_returning_home = false
		_set_idle()
		return

	_update_facing_from_direction(to_home)
	state_machine.change_state(STATE_WALK)
	movement_component.move(self, to_home.normalized())
	_play_current_animation()

func modify_incoming_damage(
	damage: int,
	source_position: Vector2
) -> int:
	return guard_component.resolve_damage(
		damage,
		global_position,
		source_position,
		_current_facing
	)

func _on_hit_received(_damage: int, source_position: Vector2) -> void:
	if _defeated:
		return

	# Being hit always establishes aggro, even if the attacker started
	# outside the normal detection radius.
	_engaged = true
	_returning_home = false

	if guard_component.was_last_hit_blocked():
		_current_facing = _facing_toward(source_position)
		knockback_component.stop(self)
		ai_component.register_successful_block()
		state_machine.change_state(STATE_BLOCK)
		_play_current_animation()
		return

	guard_component.set_guarding(false)
	ai_component.clear_defense()
	ai_component.cancel_rush()
	ki_blast_component.cancel_cast()
	melee_combat_component.cancel_attack()
	_current_facing = _facing_toward(source_position)
	state_machine.change_state(STATE_HURT)
	_hurt_time_left = hurt_duration
	knockback_component.start(self, source_position)
	_play_current_animation()

func _on_damaged(
	damage: int,
	current_health: int,
	max_health: int
) -> void:
	if guard_component.was_last_hit_blocked():
		print(
			"Training Fighter blocked. Damage: %d. HP: %d/%d"
			% [damage, current_health, max_health]
		)
		_flash(Color(0.55, 0.8, 1.0, 1.0))
		return

	print(
		"Training Fighter took %d damage. HP: %d/%d"
		% [damage, current_health, max_health]
	)
	_flash(Color(1.0, 0.55, 0.55, 1.0))

func _on_died() -> void:
	if _defeated:
		return

	_defeated = true
	guard_component.set_guarding(false)
	ai_component.clear_defense()
	ki_blast_component.cancel_cast()
	melee_combat_component.cancel_attack()
	knockback_component.stop(self)
	movement_component.stop(self)
	state_machine.change_state(STATE_DEFEATED)

	hurtbox.set_deferred("monitorable", false)
	body_collision.set_deferred("disabled", true)

	if not is_training_partner:
		var quest_manager := get_tree().get_first_node_in_group(
			"quest_manager"
		) as QuestManager
		if quest_manager != null:
			quest_manager.advance_objective(
				&"defeat_training_dummy",
				1
			)

		_drop_loot()

		var stats := get_tree().get_first_node_in_group(
			"game_stats"
		) as GameStatsManager
		if stats != null:
			stats.register_enemy_defeat()

	var awarded_xp: int = 0
	if is_instance_valid(_target):
		awarded_xp = experience_reward_component.grant_to(_target)

	print(
		"DebugGokuEnemy derrotado. +%d XP."
		% awarded_xp
	)

	_show_defeated_pose()

	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()

	_flash_tween = create_tween()
	_flash_tween.tween_interval(0.35)
	_flash_tween.tween_property(
		$Visuals,
		"modulate",
		Color(1.0, 1.0, 1.0, 0.0),
		0.35
	)

	if respawn_for_debug:
		_flash_tween.tween_interval(respawn_delay)
		_flash_tween.tween_callback(_reset_after_defeat)
	else:
		_flash_tween.tween_callback(queue_free)

func _drop_loot() -> void:
	if pickup_scene == null:
		return

	# Death can be triggered from an Area2D overlap callback while the
	# PhysicsServer2D is still flushing collision queries. Adding a pickup
	# (also an Area2D) at that moment attempts to change monitoring state and
	# produces "Can't change this state while flushing queries".
	#
	# Defer the complete spawn operation so the pickup enters the scene tree
	# only after the current physics query has finished.
	call_deferred("_spawn_loot_deferred", global_position)

func _spawn_loot_deferred(drop_position: Vector2) -> void:
	if pickup_scene == null or not is_inside_tree():
		return

	var loot_parent := get_parent()
	if loot_parent == null:
		return

	var minimum: int = maxi(min_zeni_drop, 0)
	var maximum: int = maxi(max_zeni_drop, minimum)

	if maximum > 0:
		var zeni_drop := pickup_scene.instantiate() as PickupActor
		if zeni_drop != null:
			loot_parent.add_child(zeni_drop)
			zeni_drop.global_position = drop_position + Vector2(-6.0, 0.0)
			zeni_drop.configure_currency(
				randi_range(maxi(minimum, 1), maximum)
			)

	if randf() <= clampf(senzu_drop_chance, 0.0, 1.0):
		var item_drop := pickup_scene.instantiate() as PickupActor
		if item_drop != null:
			loot_parent.add_child(item_drop)
			item_drop.global_position = drop_position + Vector2(6.0, 0.0)
			item_drop.configure_item(&"senzu_bean", 1)

func _apply_tier_difficulty() -> void:
	if ai_component.profile == null:
		return

	var profile: EnemyAIProfile = ai_component.profile

	health_component.max_health = maxi(
		roundi(
			float(health_component.max_health)
			* profile.health_multiplier
		),
		1
	)
	health_component.restore_full()

	movement_component.move_speed *= profile.move_speed_multiplier

	melee_combat_component.damage = maxi(
		roundi(
			float(melee_combat_component.damage)
			* profile.damage_multiplier
		),
		1
	)
	melee_combat_component.kick_damage = maxi(
		roundi(
			float(melee_combat_component.kick_damage)
			* profile.damage_multiplier
		),
		1
	)
	ki_blast_component.projectile_damage = maxi(
		roundi(
			float(ki_blast_component.projectile_damage)
			* profile.damage_multiplier
		),
		1
	)

	experience_reward_component.experience_reward = maxi(
		roundi(
			float(experience_reward_component.experience_reward)
			* profile.experience_multiplier
		),
		1
	)

	min_zeni_drop = maxi(
		roundi(
			float(min_zeni_drop)
			* profile.loot_multiplier
		),
		0
	)
	max_zeni_drop = maxi(
		roundi(
			float(max_zeni_drop)
			* profile.loot_multiplier
		),
		min_zeni_drop
	)

func get_display_name() -> String:
	return "Training Fighter"

func get_intelligence_tier_name() -> String:
	return ai_component.get_tier_name()

func _show_defeated_pose() -> void:
	if sprite.sprite_frames == null:
		return

	var hurt_animation := StringName("hurt_%s" % _current_facing)
	if not sprite.sprite_frames.has_animation(hurt_animation):
		return

	sprite.play(hurt_animation)
	var last_frame: int = (
		sprite.sprite_frames.get_frame_count(hurt_animation) - 1
	)
	sprite.frame = maxi(last_frame, 0)
	sprite.pause()

func _process_respawn_collision(delta: float) -> void:
	movement_component.stop(self)

	_respawn_collision_time_left = maxf(
		_respawn_collision_time_left - delta,
		0.0
	)

	if _respawn_collision_time_left > 0.0:
		return

	# The fighter becomes hittable again after the short overlap grace even
	# if a beam is currently crossing the spawn point. Sustained attacks
	# must be able to damage a newly respawned target instead of freezing it.
	_resolve_respawn_overlap()

	_respawn_collision_pending = false
	body_collision.set_deferred("disabled", false)
	hurtbox.set_deferred("monitorable", true)

func _resolve_respawn_overlap() -> void:
	var player := get_tree().get_first_node_in_group(
		"player"
	) as Node2D

	if player == null:
		return

	var offset: Vector2 = global_position - player.global_position
	var distance: float = offset.length()
	var required_distance: float = maxf(
		respawn_separation_distance,
		1.0
	)

	if distance >= required_distance:
		return

	var separation_direction: Vector2 = offset.normalized()

	if separation_direction.is_zero_approx():
		separation_direction = _fallback_respawn_direction(player)

	global_position = (
		player.global_position
		+ separation_direction * required_distance
	)

func _fallback_respawn_direction(player: Node2D) -> Vector2:
	if player.has_method("get_facing"):
		var facing_value: Variant = player.call("get_facing")
		var facing_name: StringName = StringName(str(facing_value))

		match facing_name:
			&"up":
				return Vector2.DOWN
			&"down":
				return Vector2.UP
			&"left":
				return Vector2.RIGHT
			&"right":
				return Vector2.LEFT

	return Vector2.RIGHT

func _reset_after_defeat() -> void:
	health_component.restore_full()
	experience_reward_component.reset_reward()
	guard_component.set_guarding(false)
	ai_component.clear_defense()
	melee_combat_component.cancel_attack()
	knockback_component.stop(self)

	global_position = _spawn_position
	_engaged = false
	_returning_home = false
	_attack_cooldown_left = attack_cooldown
	_ranged_cooldown_left = ranged_attack_cooldown
	_ranged_decision_left = 0.0
	ki_component.restore_full()
	_defeated = false

	$Visuals.modulate = Color.WHITE

	# Respawn is never blocked by the Player. The fighter appears at the
	# spawn point immediately, stays briefly intangible, then separates
	# itself if the Player is occupying the same space.
	hurtbox.set_deferred("monitorable", false)
	body_collision.set_deferred("disabled", true)
	_respawn_collision_pending = true
	_respawn_collision_time_left = maxf(
		respawn_collision_grace,
		0.0
	)

	state_machine.change_state(STATE_IDLE)
	_play_current_animation()

func _flash(color: Color) -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()

	$Visuals.modulate = color
	_flash_tween = create_tween()
	_flash_tween.tween_property(
		$Visuals,
		"modulate",
		Color.WHITE,
		0.10
	)

func _build_sprite_frames() -> void:
	if prefer_dmi_sprite and _try_build_dmi_sprite_frames():
		sprite.visible = true
		placeholder.visible = false
		return

	var frames := SpriteFrames.new()
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")

	var built_any := false

	if ResourceLoader.exists(sprite_sheet_path):
		var movement_sheet := load(sprite_sheet_path) as Texture2D
		if movement_sheet != null:
			_add_movement_animations(frames, movement_sheet)
			built_any = true

	if ResourceLoader.exists(run_sheet_path):
		var run_sheet := load(run_sheet_path) as Texture2D
		if run_sheet != null:
			_add_directional_animation(
				frames,
				run_sheet,
				&"run",
				run_columns,
				run_fps,
				true
			)
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

	if ResourceLoader.exists(block_sheet_path):
		var block_sheet := load(block_sheet_path) as Texture2D
		if block_sheet != null:
			_add_directional_animation(
				frames,
				block_sheet,
				&"block",
				block_columns,
				1.0,
				true
			)
			built_any = true

	if ResourceLoader.exists(ki_blast_sheet_path):
		var ki_sheet := load(ki_blast_sheet_path) as Texture2D
		if ki_sheet != null:
			_add_directional_animation(
				frames,
				ki_sheet,
				&"ki_blast_prepare",
				ki_blast_prepare_columns,
				1.0,
				true
			)
			_add_directional_animation(
				frames,
				ki_sheet,
				&"ki_blast_1",
				ki_blast_1_columns,
				1.0,
				false
			)
			_add_directional_animation(
				frames,
				ki_sheet,
				&"ki_blast_2",
				ki_blast_2_columns,
				1.0,
				false
			)
			built_any = true

	if built_any:
		sprite.sprite_frames = frames
		sprite.visible = true
		placeholder.visible = false
	else:
		sprite.visible = false
		placeholder.visible = true

func _try_build_dmi_sprite_frames() -> bool:
	if not FileAccess.file_exists(dmi_sprite_path):
		return false

	var dmi = DMI_SPRITE_SHEET_SCRIPT.load_file(dmi_sprite_path)
	if dmi == null:
		return false

	var frames := SpriteFrames.new()
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")

	var built_any := false

	var movement_state := _find_dmi_state(
		dmi,
		[&"", &"movement", &"walk"]
	)
	if movement_state != DMI_STATE_MISSING:
		built_any = _add_dmi_animation(
			frames, dmi, movement_state, &"idle", true, true
		) or built_any
		built_any = _add_dmi_animation(
			frames, dmi, movement_state, &"walk", true
		) or built_any

	var run_state := _find_dmi_state(
		dmi,
		[&"Sprint", &"sprint", &"fly"]
	)
	built_any = _add_dmi_animation(
		frames, dmi, run_state, &"run", true
	) or built_any

	built_any = _add_dmi_animation(
		frames,
		dmi,
		_find_dmi_state(dmi, [&"punch1"]),
		&"attack_1",
		false
	) or built_any

	built_any = _add_dmi_animation(
		frames,
		dmi,
		_find_dmi_state(dmi, [&"punch2", &"punch1"]),
		&"attack_2",
		false
	) or built_any

	built_any = _add_dmi_animation(
		frames,
		dmi,
		_find_dmi_state(dmi, [&"HitStun", &"hitstun"]),
		&"hurt",
		false
	) or built_any

	built_any = _add_dmi_animation(
		frames,
		dmi,
		_find_dmi_state(dmi, [&"Guard", &"guard"]),
		&"block",
		true
	) or built_any

	built_any = _add_dmi_animation(
		frames,
		dmi,
		_find_dmi_state(dmi, [&"KiBlastCharge", &"kiblast"]),
		&"ki_blast_prepare",
		true
	) or built_any

	built_any = _add_dmi_animation(
		frames,
		dmi,
		_find_dmi_state(dmi, [&"kiblast", &"KiBlast"]),
		&"ki_blast_1",
		false
	) or built_any

	built_any = _add_dmi_animation(
		frames,
		dmi,
		_find_dmi_state(dmi, [&"KiBlast2", &"kiblast"]),
		&"ki_blast_2",
		false
	) or built_any

	if not built_any:
		return false

	frame_size = dmi.frame_size
	sprite.sprite_frames = frames
	return true

func _find_dmi_state(dmi, candidates: Array) -> StringName:
	for candidate in candidates:
		var state_name := StringName(String(candidate))
		if dmi.has_state(state_name):
			return state_name
	return DMI_STATE_MISSING

func _add_dmi_animation(
	frames: SpriteFrames,
	dmi,
	dmi_state: StringName,
	animation_state: StringName,
	loop: bool,
	first_frame_only: bool = false
) -> bool:
	if (
		dmi_state == DMI_STATE_MISSING
		or not dmi.has_state(dmi_state)
	):
		return false

	var source_frame_count: int = dmi.get_frame_count(dmi_state)
	if source_frame_count <= 0:
		return false

	var frame_count := 1 if first_frame_only else source_frame_count
	var added_any := false

	for facing in DIRECTION_ROWS:
		var animation_name := StringName(
			"%s_%s" % [animation_state, facing]
		)

		frames.add_animation(animation_name)
		frames.set_animation_loop(animation_name, loop)
		frames.set_animation_speed(
			animation_name,
			DMI_ANIMATION_FPS
		)

		for frame_index in range(frame_count):
			var frame_texture: AtlasTexture = dmi.get_frame_texture(
				dmi_state,
				StringName(String(facing)),
				frame_index
			)
			if frame_texture == null:
				continue

			frames.add_frame(
				animation_name,
				frame_texture,
				dmi.get_frame_delay(dmi_state, frame_index)
			)
			added_any = true

	return added_any

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

	if (
		state_machine.is_state(STATE_RUN)
		and not sprite.sprite_frames.has_animation(animation_name)
	):
		animation_name = StringName("walk_%s" % facing)

	if not sprite.sprite_frames.has_animation(animation_name):
		animation_name = StringName("idle_%s" % facing)

	if not sprite.sprite_frames.has_animation(animation_name):
		return

	var state_text: String = String(state_machine.current_state)
	var is_one_shot := (
		state_text.begins_with("attack_")
		or state_text.begins_with("ki_blast_")
		or state_machine.is_state(STATE_HURT)
	)

	if sprite.animation != animation_name:
		sprite.play(animation_name)
	elif not is_one_shot and not sprite.is_playing():
		sprite.play(animation_name)

	sprite.speed_scale = 1.0

func _update_facing_from_direction(direction: Vector2) -> void:
	if direction.is_zero_approx():
		return

	var next_facing: StringName

	if absf(direction.x) > absf(direction.y):
		next_facing = &"right" if direction.x > 0.0 else &"left"
	else:
		next_facing = &"down" if direction.y > 0.0 else &"up"

	if next_facing == _current_facing:
		return

	if _facing_change_time_left > 0.0:
		return

	_current_facing = next_facing
	_facing_change_time_left = maxf(
		facing_change_cooldown,
		0.0
	)

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
