class_name TrainingSparringConsole
extends Area2D

@export var partner_scene: PackedScene
@export var spawn_offset: Vector2 = Vector2(72.0, 0.0)
@export_range(0.25, 4.0, 0.25)
var difficulty_scale: float = 1.0

var _partner: Node2D
var _active_difficulty: float = 1.0

func get_interaction_label() -> String:
	if is_instance_valid(_partner):
		return "End Sparring"

	var training: TrainingManager = _get_training()
	if training == null:
		return "Start Sparring Partner"

	return "Spar %.0fx Gravity" % training.gravity_multiplier

func interact(_actor: Node) -> void:
	if is_instance_valid(_partner):
		_partner.queue_free()
		_partner = null
		var active_training: TrainingManager = _get_training()
		if (
			active_training != null
			and active_training.active_mode
				== TrainingManager.MODE_SPARRING
		):
			active_training.stop_training()
		return

	_spawn_partner()

func _spawn_partner() -> void:
	if partner_scene == null:
		return

	var training: TrainingManager = _get_training()
	var gravity: float = 1.0
	if training != null:
		gravity = maxf(training.gravity_multiplier, 1.0)

	_active_difficulty = clampf(
		difficulty_scale * sqrt(gravity),
		0.5,
		4.0
	)

	var partner: DebugGokuEnemy = (
		partner_scene.instantiate() as DebugGokuEnemy
	)
	if partner == null:
		return

	partner.respawn_for_debug = false
	partner.is_training_partner = true
	partner.min_zeni_drop = 0
	partner.max_zeni_drop = 0
	partner.senzu_drop_chance = 0.0
	partner.difficulty_scale = _active_difficulty
	partner.reward_scale = 0.0
	partner.display_name = "Gravity Sparring Partner"
	partner.enemy_rank = "Training %.0fx" % gravity

	get_parent().add_child(partner)
	partner.global_position = global_position + spawn_offset
	_partner = partner

	var health: HealthComponent = partner.get_node_or_null(
		"Components/HealthComponent"
	) as HealthComponent
	if health != null:
		health.died.connect(_on_partner_defeated)

	var reward: ExperienceRewardComponent = partner.get_node_or_null(
		"Components/ExperienceRewardComponent"
	) as ExperienceRewardComponent
	if reward != null:
		reward.experience_reward = 0

	if training != null:
		training.start_training(TrainingManager.MODE_SPARRING)
		training.set_prompt(
			"DEFEAT THE %.0fx SPAR PARTNER" % gravity
		)

func _on_partner_defeated() -> void:
	var training: TrainingManager = _get_training()
	if training != null:
		var reward_xp: int = maxi(
			roundi(15.0 * _active_difficulty),
			15
		)
		training.register_success(reward_xp)
		training.set_prompt("SPARRING COMPLETE")

	_partner = null

func _get_training() -> TrainingManager:
	return get_tree().get_first_node_in_group(
		"training_manager"
	) as TrainingManager
