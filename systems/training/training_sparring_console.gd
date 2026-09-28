class_name TrainingSparringConsole
extends Area2D

@export var partner_scene: PackedScene
@export var spawn_offset: Vector2 = Vector2(72.0, 0.0)
@export_range(0.25, 4.0, 0.25)
var difficulty_scale: float = 1.0

var _partner: Node2D

func get_interaction_label() -> String:
	if is_instance_valid(_partner):
		return "End Sparring"

	return "Start Sparring Partner"

func interact(_actor: Node) -> void:
	if is_instance_valid(_partner):
		_partner.queue_free()
		_partner = null
		var training := _get_training()
		if (
			training != null
			and training.active_mode
				== TrainingManager.MODE_SPARRING
		):
			training.stop_training()
		return

	_spawn_partner()

func _spawn_partner() -> void:
	if partner_scene == null:
		return

	var partner := partner_scene.instantiate() as DebugGokuEnemy
	if partner == null:
		return

	partner.respawn_for_debug = false
	partner.min_zeni_drop = 0
	partner.max_zeni_drop = 0
	partner.senzu_drop_chance = 0.0

	get_parent().add_child(partner)
	partner.global_position = global_position + spawn_offset
	_partner = partner

	var health := partner.get_node_or_null(
		"Components/HealthComponent"
	) as HealthComponent
	if health != null:
		health.max_health = maxi(
			roundi(float(health.max_health) * difficulty_scale),
			1
		)
		health.restore_full()
		health.died.connect(_on_partner_defeated)

	var melee := partner.get_node_or_null(
		"Components/MeleeCombatComponent"
	) as MeleeCombatComponent
	if melee != null:
		melee.damage = maxi(
			roundi(float(melee.damage) * difficulty_scale),
			1
		)
		melee.kick_damage = maxi(
			roundi(float(melee.kick_damage) * difficulty_scale),
			1
		)

	var reward := partner.get_node_or_null(
		"Components/ExperienceRewardComponent"
	) as ExperienceRewardComponent
	if reward != null:
		reward.experience_reward = 0

	var training := _get_training()
	if training != null:
		training.start_training(TrainingManager.MODE_SPARRING)
		training.set_prompt("DEFEAT THE SPAR BOT")

func _on_partner_defeated() -> void:
	var training := _get_training()
	if training != null:
		training.register_success(15)
		training.set_prompt("SPARRING COMPLETE")

	_partner = null

func _get_training() -> TrainingManager:
	return get_tree().get_first_node_in_group(
		"training_manager"
	) as TrainingManager
