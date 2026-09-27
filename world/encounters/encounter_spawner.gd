class_name EncounterSpawner
extends Node2D

signal enemy_spawned(enemy: Node2D)
signal enemy_removed

@export var enemy_scene: PackedScene
@export_range(1, 32, 1)
var max_alive: int = 1
@export var respawn_delay: float = 4.0
@export var spawn_on_ready: bool = true

var _alive: Array[Node2D] = []
var _respawn_time_left: float = 0.0

func _ready() -> void:
	if spawn_on_ready:
		call_deferred("_fill_encounter")

func _process(delta: float) -> void:
	_cleanup_invalid()

	if _alive.size() >= max_alive:
		return

	_respawn_time_left -= delta
	if _respawn_time_left <= 0.0:
		_fill_encounter()
		_respawn_time_left = respawn_delay

func _fill_encounter() -> void:
	if enemy_scene == null:
		return

	while _alive.size() < max_alive:
		if not _spawn_one():
			break

func _spawn_one() -> bool:
	var enemy := enemy_scene.instantiate() as Node2D
	if enemy == null:
		return false

	get_parent().add_child(enemy)
	enemy.global_position = _choose_spawn_position()
	enemy.tree_exited.connect(_on_enemy_tree_exited)

	_alive.append(enemy)
	enemy_spawned.emit(enemy)
	return true

func _choose_spawn_position() -> Vector2:
	var markers: Array[Marker2D] = []

	for child in get_children():
		if child is Marker2D:
			markers.append(child as Marker2D)

	if markers.is_empty():
		return global_position

	var index: int = randi_range(0, markers.size() - 1)
	var marker: Marker2D = markers[index]
	return marker.global_position

func _on_enemy_tree_exited() -> void:
	_cleanup_invalid()
	_respawn_time_left = respawn_delay
	enemy_removed.emit()

func _cleanup_invalid() -> void:
	var valid: Array[Node2D] = []

	for enemy in _alive:
		if is_instance_valid(enemy):
			valid.append(enemy)

	_alive = valid
