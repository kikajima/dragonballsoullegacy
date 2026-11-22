class_name WorldManager
extends Node

signal world_change_started(scene_path: String)
signal world_changed(scene_path: String, world: Node)
signal transition_finished

@export var world_container_path: NodePath
@export var player_container_path: NodePath
@export_file("*.tscn")
var initial_world_path: String = ""

@onready var world_container: Node = get_node(world_container_path)
@onready var player_container: Node = get_node(player_container_path)

var current_world_path: String = ""
var _transition_in_progress: bool = false

func is_transitioning() -> bool:
	return _transition_in_progress

func _ready() -> void:
	if not initial_world_path.is_empty():
		current_world_path = initial_world_path

func load_world(
	scene_path: String,
	spawn_position: Vector2 = Vector2.ZERO,
	use_spawn_position: bool = false
) -> bool:
	if scene_path.is_empty():
		return false

	if not ResourceLoader.exists(scene_path):
		push_warning("WorldManager: cena inexistente: %s" % scene_path)
		return false

	var packed_scene := load(scene_path) as PackedScene
	if packed_scene == null:
		push_warning("WorldManager: recurso não é PackedScene: %s" % scene_path)
		return false

	world_change_started.emit(scene_path)
	var player := get_player() as Player
	if player != null:
		player.special_attack_component.cancel_cast()
		player.ki_blast_component.cancel_cast()
		player.melee_combat_component.cancel_attack()
	# Projectiles are spawned under Bootstrap, not the outgoing map.
	for group in [&"combat_projectile", &"active_special_beam"]:
		for effect in get_tree().get_nodes_in_group(group):
			effect.process_mode = Node.PROCESS_MODE_DISABLED
			effect.queue_free()

	for child in world_container.get_children():
		world_container.remove_child(child)
		child.queue_free()

	var world := packed_scene.instantiate()
	world_container.add_child(world)
	current_world_path = scene_path

	if use_spawn_position:
		if player != null:
			player.global_position = spawn_position

	world_changed.emit(scene_path, world)
	return true

func get_player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D

func load_world_with_transition(
	scene_path: String,
	spawn_position: Vector2 = Vector2.ZERO,
	use_spawn_position: bool = false
) -> bool:
	# A second fade would kill the first tween and strand its awaiting caller.
	if _transition_in_progress:
		return false
	var player := get_player() as Player
	if player != null and (player._respawning or player.health_component.is_dead()):
		return false
	_transition_in_progress = true
	var transition := get_tree().get_first_node_in_group(
		"screen_transition"
	) as ScreenTransition

	if transition != null:
		await transition.fade_out()

	var loaded: bool = load_world(
		scene_path,
		spawn_position,
		use_spawn_position
	)

	if transition != null:
		await transition.fade_in()

	_transition_in_progress = false
	transition_finished.emit()
	return loaded

# Travel to another spot of the current world (e.g. the capsule ship between
# Kame Island and West City) with the usual fade, without reloading it.
func travel_within_world(spawn_position: Vector2) -> bool:
	if _transition_in_progress:
		return false
	var player := get_player() as Player
	if player != null and (player._respawning or player.health_component.is_dead()):
		return false
	_transition_in_progress = true
	var transition := get_tree().get_first_node_in_group(
		"screen_transition"
	) as ScreenTransition
	if transition != null:
		await transition.fade_out()
	if player != null:
		player.special_attack_component.cancel_cast()
		player.ki_blast_component.cancel_cast()
		player.melee_combat_component.cancel_attack()
		player.flight_component.land_immediately()
		player.global_position = spawn_position
		var camera := player.get_node_or_null("Camera2D") as Camera2D
		if camera != null:
			camera.reset_smoothing()
	if transition != null:
		await transition.fade_in()
	_transition_in_progress = false
	transition_finished.emit()
	return true

func is_in_sky() -> bool:
	return current_world_path == SkyWorld.SCENE_PATH

# Flying high over Earth: the sky shows the whole planet (SkyWorld).
func ascend_to_sky() -> bool:
	var player := get_player() as Player
	if player == null or not player.is_flying() or current_world_path != OpenWorld.SCENE_PATH:
		return false
	var training := get_tree().get_first_node_in_group("training_manager") as TrainingManager
	if training != null:
		training.reset_training_environment()
	return await load_world_with_transition(
		SkyWorld.SCENE_PATH, SkyWorld.to_sky(player.global_position), true
	)

# Coming down from the sky lands right below, on Earth.
func descend_to_earth() -> bool:
	var player := get_player() as Player
	if player == null or not is_in_sky():
		return false
	var ground := SkyWorld.to_ground(player.global_position)
	var loaded: bool = await load_world_with_transition(OpenWorld.SCENE_PATH, ground, true)
	if loaded and player.is_flying():
		var flight := player.flight_component
		player.global_position = flight.find_landing_spot(ground)
		flight.land()
	return loaded

func serialize_state() -> Dictionary:
	return {
		"current_world_path": current_world_path,
	}

func load_state(data: Dictionary) -> void:
	var scene_path: String = str(
		data.get("current_world_path", "")
	)
	if (
		scene_path.is_empty()
		or scene_path == current_world_path
		or not ResourceLoader.exists(scene_path)
	):
		return

	load_world(scene_path)
