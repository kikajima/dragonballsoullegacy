class_name DragonBallManager
extends Node

# The seven Dragon Balls.
#
# Each ball lies somewhere on Earth (a walkable tile away from the regions)
# until the player picks it up. With all seven the player can summon Shenron
# (Journal, N) and make one wish. Afterwards the balls scatter to new places
# and stay stone for STONE_SECONDS of play: they can be seen but not taken.

signal balls_changed
signal ball_collected(index: int, held: int)
signal wish_granted(wish_id: StringName)

const COUNT := 7
const STONE_SECONDS := 600.0
const MIN_SPACING := 22.0 # tiles between two balls
const REGION_MARGIN := 4.0 # tiles kept free around regions

const WISHES := [
	{"id": &"power", "text": "I want to be stronger",
		"result": "Every trained stat rises by 3 levels."},
	{"id": &"riches", "text": "Give me riches",
		"result": "You receive 10,000 Zeni."},
	{"id": &"experience", "text": "Make me a better fighter",
		"result": "You gain a large amount of experience."},
	{"id": &"senzu", "text": "A bag of Senzu Beans",
		"result": "You receive 5 Senzu Beans."},
]

# Tile of each ball on Earth; Vector2i(-1, -1) while held or not placed.
var _tiles: Array[Vector2i] = []
var _held: Array[bool] = []
var _stone_left: float = 0.0
var _wishes_made: int = 0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	add_to_group("dragon_ball_manager")
	_rng.randomize()
	_reset()

func _process(delta: float) -> void:
	if _stone_left > 0.0 and not get_tree().paused:
		_stone_left = maxf(_stone_left - delta, 0.0)
		if _stone_left <= 0.0:
			balls_changed.emit()
			_notify("The Dragon Balls shine again!")

func _reset() -> void:
	_tiles.clear()
	_held.clear()
	for index in COUNT:
		_tiles.append(Vector2i(-1, -1))
		_held.append(false)

# --- Queries -----------------------------------------------------------------

func held_count() -> int:
	return _held.count(true)

func is_held(index: int) -> bool:
	return index >= 0 and index < COUNT and _held[index]

func is_stone() -> bool:
	return _stone_left > 0.0

func stone_seconds_left() -> float:
	return _stone_left

func wishes_made() -> int:
	return _wishes_made

func get_ball_tile(index: int) -> Vector2i:
	return _tiles[index]

# Balls lying on the ground: index -> tile.
func get_ground_balls() -> Dictionary:
	var result := {}
	for index in COUNT:
		if not _held[index] and _tiles[index].x >= 0:
			result[index] = _tiles[index]
	return result

func can_summon() -> bool:
	return held_count() == COUNT and not is_stone()

# Nearest ball on the ground to a world point: {index, point} or {}.
func nearest_ball(point: Vector2) -> Dictionary:
	var best := {}
	var best_distance := INF
	var balls := get_ground_balls()
	for index in balls:
		var ball_point := (Vector2(balls[index]) + Vector2(0.5, 0.5)) * OpenWorld.TILE
		var distance := ball_point.distance_to(point)
		if distance < best_distance:
			best_distance = distance
			best = {"index": index, "point": ball_point, "distance": distance}
	return best

# --- Placement ---------------------------------------------------------------

# Places every ball that has no tile yet (new game or after a wish).
func ensure_placed(world: OpenWorld) -> void:
	if world == null or world.terrain == null:
		return
	var placed := false
	for index in COUNT:
		if _held[index] or _tiles[index].x >= 0:
			continue
		_tiles[index] = _pick_tile(world)
		placed = true
	if placed:
		balls_changed.emit()

func _pick_tile(world: OpenWorld) -> Vector2i:
	var size := Vector2i(OpenWorld.world_size() / OpenWorld.TILE)
	var fallback := Vector2i(-1, -1)
	for attempt in 600:
		var cell := Vector2i(_rng.randi_range(2, size.x - 3), _rng.randi_range(2, size.y - 3))
		if not world.terrain.is_walkable_cell(cell):
			continue
		var point := (Vector2(cell) + Vector2(0.5, 0.5)) * OpenWorld.TILE
		var near_region := false
		for region in world.get_regions():
			if world.get_region_rect(region).grow(REGION_MARGIN * OpenWorld.TILE).has_point(point):
				near_region = true
				break
		if near_region:
			continue
		fallback = cell
		var spaced := true
		for other in _tiles:
			if other.x >= 0 and Vector2(other).distance_to(Vector2(cell)) < MIN_SPACING:
				spaced = false
				break
		if spaced:
			return cell
	return fallback

# --- Collecting and wishing --------------------------------------------------

func collect(index: int) -> bool:
	if index < 0 or index >= COUNT or _held[index] or is_stone():
		return false
	_held[index] = true
	_tiles[index] = Vector2i(-1, -1)
	var held := held_count()
	ball_collected.emit(index, held)
	balls_changed.emit()
	var quests := get_tree().get_first_node_in_group("quest_manager") as QuestManager
	if quests != null:
		quests.advance_objective(&"dragon_ball", 1)
	if held == COUNT:
		_notify("All seven Dragon Balls! Summon Shenron from the Journal (N).")
	else:
		_notify("Dragon Ball %d found! (%d/%d)" % [index + 1, held, COUNT])
	return true

func grant_wish(wish_id: StringName) -> bool:
	if not can_summon():
		return false
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return false
	match wish_id:
		&"power":
			var stats := player.get_node_or_null("Components/CharacterStats") as CharacterStatsComponent
			if stats == null:
				return false
			for stat in CharacterStatsComponent.STATS:
				stats.set_level(stat, mini(stats.get_level(stat) + 3, CharacterStatsComponent.MAX_LEVEL))
		&"riches":
			var wallet := player.get_node_or_null("Components/WalletComponent") as WalletComponent
			if wallet == null:
				return false
			wallet.add(10000)
		&"experience":
			var experience := player.get_node_or_null("Components/ExperienceComponent") as ExperienceComponent
			if experience == null:
				return false
			experience.add_experience(1500 + experience.current_level * 300)
		&"senzu":
			var inventory := player.get_node_or_null("Components/InventoryComponent") as InventoryComponent
			if inventory == null:
				return false
			var added := inventory.add_item(&"senzu_bean", 5)
			if added < 5:
				_drop_senzu(player as Node2D, 5 - added)
		_:
			return false
	_wishes_made += 1
	_scatter()
	wish_granted.emit(wish_id)
	return true

func _scatter() -> void:
	_reset()
	_stone_left = STONE_SECONDS
	var world := get_tree().get_first_node_in_group("open_world") as OpenWorld
	ensure_placed(world)
	balls_changed.emit()

func _drop_senzu(player: Node2D, amount: int) -> void:
	var scene := load("res://world/pickups/pickup_actor.tscn") as PackedScene
	if scene == null or player == null or player.get_parent() == null:
		return
	var pickup := scene.instantiate() as PickupActor
	pickup.lifetime = 0.0
	player.get_parent().add_child(pickup)
	pickup.global_position = player.global_position + Vector2(0, 14)
	pickup.configure_item(&"senzu_bean", amount)

func _notify(message: String) -> void:
	var feed := get_tree().get_first_node_in_group("notification_feed")
	if feed != null and feed.has_method("push_message"):
		feed.push_message(message)

# --- Save --------------------------------------------------------------------

func serialize_state() -> Dictionary:
	var tiles: Array = []
	for tile in _tiles:
		tiles.append([tile.x, tile.y])
	return {
		"tiles": tiles,
		"held": _held.duplicate(),
		"stone_left": _stone_left,
		"wishes_made": _wishes_made,
	}

func load_state(data: Dictionary) -> void:
	_reset()
	var tiles: Array = data.get("tiles", [])
	var held: Array = data.get("held", [])
	for index in COUNT:
		if index < tiles.size() and tiles[index] is Array and (tiles[index] as Array).size() == 2:
			_tiles[index] = Vector2i(int(tiles[index][0]), int(tiles[index][1]))
		if index < held.size():
			_held[index] = bool(held[index])
			if _held[index]:
				_tiles[index] = Vector2i(-1, -1)
	_stone_left = maxf(float(data.get("stone_left", 0.0)), 0.0)
	_wishes_made = int(data.get("wishes_made", 0))
	ensure_placed(get_tree().get_first_node_in_group("open_world") as OpenWorld)
	balls_changed.emit()
