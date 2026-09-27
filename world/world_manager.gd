class_name WorldManager
extends Node

signal world_change_started(scene_path: String)
signal world_changed(scene_path: String, world: Node)

@export var world_container_path: NodePath
@export var player_container_path: NodePath

@onready var world_container: Node = get_node(world_container_path)
@onready var player_container: Node = get_node(player_container_path)

var current_world_path: String = ""

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

	for child in world_container.get_children():
		child.queue_free()

	var world := packed_scene.instantiate()
	world_container.add_child(world)
	current_world_path = scene_path

	if use_spawn_position:
		var player := get_tree().get_first_node_in_group("player") as Node2D
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

	return loaded
