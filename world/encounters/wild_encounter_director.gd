class_name WildEncounterDirector
extends Node

# Wild fighters on Earth (child of OpenWorld). Small groups appear on
# walkable ground around the player, out of sight, chosen by the zone they
# stand in (EnemyCatalog.ZONE_SPAWNS). Far away ones are removed.
#
# Nothing spawns while the Kame Island tutorial runs (the world becomes
# dangerous once the player may leave the island), inside or near a region
# (cities and Kame Island stay safe) or in the air above the sea.

const MAX_ALIVE := 6
const SPAWN_INTERVAL := 2.5
const MIN_DISTANCE := 380.0
const MAX_DISTANCE := 760.0
const DESPAWN_DISTANCE := 1500.0
# Tiles kept free around each region.
const SAFE_MARGIN := 6.0
const UNLOCK_QUEST: StringName = &"kame_flight"
const GROUP := &"wild_enemy"

# Tests and tools may turn spawning on regardless of the story.
static var force_enabled: bool = false

var world: OpenWorld
var _spawn_left: float = 1.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	world = get_parent() as OpenWorld

func _process(delta: float) -> void:
	if world == null or world.terrain == null:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var alive := _alive()
	for enemy in alive:
		if enemy.global_position.distance_to(player.global_position) > DESPAWN_DISTANCE:
			enemy.queue_free()
	_spawn_left -= delta
	if _spawn_left > 0.0:
		return
	_spawn_left = SPAWN_INTERVAL
	if not is_enabled() or alive.size() >= MAX_ALIVE:
		return
	if world.region_at(player.global_position) != null:
		return
	spawn_group_near(player.global_position)

func is_enabled() -> bool:
	if force_enabled:
		return true
	var quests := get_tree().get_first_node_in_group("quest_manager") as QuestManager
	return quests != null and quests.is_completed(UNLOCK_QUEST)

# Spawns one group (1 or 2 fighters) somewhere around `center`. Returns the
# fighters spawned.
func spawn_group_near(center: Vector2) -> Array[DebugGokuEnemy]:
	var spawned: Array[DebugGokuEnemy] = []
	for attempt in 8:
		var angle := _rng.randf() * TAU
		var point := center + Vector2.from_angle(angle) * _rng.randf_range(MIN_DISTANCE, MAX_DISTANCE)
		if not can_spawn_at(point):
			continue
		var zone := world.zone_at(point)
		var enemy_id := EnemyCatalog.pick_for_zone(zone, _rng)
		var count := 1 if _rng.randf() < 0.6 else 2
		for index in count:
			var offset := Vector2(index * 40.0, index * 18.0)
			if index > 0 and not can_spawn_at(point + offset):
				break
			var enemy := _spawn(enemy_id, point + offset)
			if enemy != null:
				spawned.append(enemy)
		break
	return spawned

func can_spawn_at(point: Vector2) -> bool:
	if not world.get_bounds().has_point(point):
		return false
	var cell := Vector2i(floori(point.x / OpenWorld.TILE), floori(point.y / OpenWorld.TILE))
	if not world.terrain.is_walkable_cell(cell):
		return false
	var margin := SAFE_MARGIN * OpenWorld.TILE
	for region in world.get_regions():
		if world.get_region_rect(region).grow(margin).has_point(point):
			return false
	return true

func _spawn(enemy_id: StringName, point: Vector2) -> DebugGokuEnemy:
	var enemy := EnemyCatalog.create(enemy_id)
	if enemy == null:
		return null
	enemy.is_wild = true
	enemy.add_to_group(GROUP)
	enemy.initial_facing = ["up", "down", "left", "right"][_rng.randi_range(0, 3)]
	enemy.position = world.to_local(point)
	world.add_child(enemy)
	return enemy

func _alive() -> Array[Node2D]:
	var result: Array[Node2D] = []
	for node in get_tree().get_nodes_in_group(GROUP):
		if world.is_ancestor_of(node) and not node.is_queued_for_deletion():
			result.append(node as Node2D)
	return result
