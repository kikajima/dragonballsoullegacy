class_name WorldAmbientFX
extends Node

const SURFACE_TEXTURE = preload("res://core/assets/dmi_surface_texture.gd")
const EXISTING_SCENERY = preload("res://world/existing_asset_scenery.gd")

const MODE_NONE: StringName = &""
const MODE_KAME: StringName = &"kame"
const MODE_WASTES: StringName = &"wastes"
const MODE_CITY: StringName = &"city"

const DEPTH_BASE: int = 1000
const AIRBORNE_DEPTH_BONUS: int = 1000
# Slightly closer than the original project camera, but far less zoomed than
# the previous GBA pass. This keeps combat readable without making the island
# feel cramped.
const GBA_CAMERA_ZOOM := Vector2.ONE

const GBA_KAME_MAP_PATH := (
	"res://assets/vendor/dragon_ball_gba/dbzlog2/Backgrounds/"
	+ "Master Roshi Island__584997.png"
)
const DMI_SPRITE_SHEET_SCRIPT = preload(
	"res://core/assets/dmi_sprite_sheet.gd"
)
const FLOWERS_DMI_PATH := (
	"res://assets/vendor/hu2/Icons/Turfs/Flowers.dmi"
)
const PALM_TEXTURE = preload(
	"res://assets/vendor/hu2/Icons/Images/PalmTree.png"
)

var _world_manager: WorldManager
var _world: Node2D
var _player: Node2D
var _camera: Camera2D
var _fx_root: Node2D
var _detail_root: Node2D
var _mode: StringName = MODE_NONE
var _items: Array[Node2D] = []
var _base_positions: Array[Vector2] = []
# Mode of each item: the open world mixes regions (island glints, city
# lights, wastes dust) at the same time.
var _item_modes: Array[StringName] = []
var _roots: Array[Node2D] = []
var _kame_region: Node2D
var _time: float = 0.0

func _ready() -> void:
	call_deferred("_bind_world")
	call_deferred("_refresh_player_camera")

func _process(delta: float) -> void:
	_time += delta
	_refresh_player_camera()
	_update_depth_sorting()

	for index in range(_items.size()):
		var item: Node2D = _items[index]
		if item == null or not is_instance_valid(item):
			continue
		match _item_modes[index]:
			MODE_KAME:
				_animate_kame(item, index)
			MODE_WASTES:
				_animate_wastes(item, index, delta)
			MODE_CITY:
				_animate_city(item, index)

func _bind_world() -> void:
	_world_manager = get_tree().get_first_node_in_group(
		"world_manager"
	) as WorldManager
	if _world_manager == null:
		return

	if not _world_manager.world_changed.is_connected(_on_world_changed):
		_world_manager.world_changed.connect(_on_world_changed)

	var container: Node = get_tree().get_first_node_in_group(
		"world_container"
	)
	if container != null and container.get_child_count() > 0:
		_setup_for_world(container.get_child(0))

func _on_world_changed(
	_scene_path: String,
	world: Node
) -> void:
	_setup_for_world(world)

func _setup_for_world(world: Node) -> void:
	_clear_fx()
	if world == null:
		return
	for region in OpenWorld.regions_of(world):
		_setup_region(region)
	_world = null

func _setup_region(world: Node2D) -> void:
	_world = world
	var first_item := _items.size()

	_fx_root = Node2D.new()
	_fx_root.name = "AmbientFX"
	_fx_root.z_index = -5
	_world.add_child(_fx_root)

	_detail_root = Node2D.new()
	_detail_root.name = "GbaVisualDetails"
	_world.add_child(_detail_root)
	_roots.append(_fx_root)
	_roots.append(_detail_root)

	var world_name: String = String(world.name).to_lower()
	if world is KameIsland:
		_mode = MODE_KAME
		_kame_region = world
		_build_kame_glints()
		# Kame Island owns its authored foliage and flower placement. Do not
		# layer fallback props over it, since that creates visual duplication.
	elif world_name.contains("rocky") or world_name.contains("wastes"):
		_mode = MODE_WASTES
		_texture_surface("Ground", "MineCraft", &"Dirt")
		_tint_surface("Ground", Color("d9b78c"))
		for rock in ["RockA/Visual", "RockB/Visual", "RockC/Visual"]:
			_texture_surface(rock, "MineCraft", &"Stone")
			(_world.get_node(rock) as Polygon2D).modulate = Color(0.83, 0.72, 0.57)
			_add_surface_relief(rock)
		_build_waste_dust()
	elif world_name.contains("west") or world_name.contains("city"):
		_mode = MODE_CITY
		_texture_surface("Ground", "CityTurfs", &"Tile")
		_tint_surface("Ground", Color("e1e5e3"))
		_texture_surface("RoadHorizontal", "CityTurfs", &"Road")
		_texture_surface("RoadVertical", "CityTurfs", &"Road")
		_texture_surface("CityPark/Visual", "NewTurfs", &"Grass1")
		_build_city_lights()
		_add_surface_relief("CapsuleBuilding/Visual")
		_add_surface_relief("CityPark/Visual")
	else:
		_mode = MODE_NONE
		if world_name.contains("kamehouse") or world_name.contains("interior"):
			_tint_surface("Floor", Color("d9b5b0"))
		elif world is CapsuleTrainingChamber:
			_texture_surface("Floor", "ApartmentInts", &"BaseTile")
			(_world.get_node("Floor") as Polygon2D).modulate = Color(0.48, 0.55, 0.65)
			_texture_surface("TrainingFloor", "DbzTurfs", &"GrayTile")
			_texture_surface("CenterPlatform/Visual", "ApartmentInts", &"BaseTile")
	for index in range(first_item, _items.size()):
		_item_modes.append(_mode)
	EXISTING_SCENERY.apply(_world)

func _texture_surface(path: String, sheet_name: String, state: StringName) -> void:
	SURFACE_TEXTURE.apply(_world.get_node_or_null(path) as Polygon2D, sheet_name, state)

func _tint_surface(path: String, color: Color) -> void:
	var surface := _world.get_node_or_null(path) as Polygon2D
	if surface != null:
		surface.modulate = color

func _add_surface_relief(path: String) -> void:
	var surface := _world.get_node_or_null(path) as Polygon2D
	if surface == null or surface.polygon.size() < 3:
		return
	var shadow := Polygon2D.new()
	shadow.name = "GroundShadow"
	shadow.polygon = surface.polygon
	shadow.position = Vector2(4, 6)
	shadow.color = Color(0.09, 0.12, 0.17, 0.38)
	shadow.show_behind_parent = true
	surface.add_child(shadow)
	var outline := Line2D.new()
	outline.points = surface.polygon
	outline.closed = true
	outline.width = 2.0
	outline.default_color = Color(0.16, 0.19, 0.22, 0.85)
	surface.add_child(outline)
	var rim := Line2D.new()
	rim.points = PackedVector2Array([surface.polygon[0] + Vector2(2, 2), surface.polygon[1] + Vector2(-2, 2)])
	rim.width = 2.0
	rim.default_color = Color(0.96, 0.87, 0.64, 0.65)
	surface.add_child(rim)

func _clear_fx() -> void:
	_items.clear()
	_base_positions.clear()
	_item_modes.clear()
	_mode = MODE_NONE
	_world = null
	_kame_region = null

	for root in _roots:
		if root != null and is_instance_valid(root):
			root.queue_free()
	_roots.clear()
	_fx_root = null
	_detail_root = null

func _refresh_player_camera() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		_camera = null

	if _player == null:
		return

	if _camera == null or not is_instance_valid(_camera):
		_camera = _player.get_node_or_null("Camera2D") as Camera2D
		if _camera != null:
			_camera.zoom = GBA_CAMERA_ZOOM
			_camera.position_smoothing_enabled = false
			_camera.limit_smoothed = false

func _update_depth_sorting() -> void:
	if _player != null and is_instance_valid(_player):
		WorldDepth.follow(get_tree(), _player.global_position.y)
		_apply_actor_depth(_player)

	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemy")
	for enemy: Node in enemies:
		var enemy_2d: Node2D = enemy as Node2D
		if enemy_2d != null:
			_apply_actor_depth(enemy_2d)

	var npcs: Array[Node] = get_tree().get_nodes_in_group("npc")
	for npc: Node in npcs:
		var npc_2d: Node2D = npc as Node2D
		if npc_2d != null:
			_apply_actor_depth(npc_2d)

	if _kame_region != null and is_instance_valid(_kame_region):
		_apply_prop_depth(&"KameHouse", 130.0)
		_apply_prop_depth(&"PalmTreeLeft", 42.0)
		_apply_prop_depth(&"PalmTreeRight", 42.0)
		_apply_prop_depth(&"PalmTreeSouth", 42.0)
		_apply_prop_depth(&"PalmTreeNorthWest", 42.0)
		_apply_prop_depth(&"PalmTreeNorthEast", 42.0)
		_apply_prop_depth(&"BeachUmbrella", 30.0)
		_apply_prop_depth(&"BeachChair", 14.0)
		_apply_prop_depth(&"BeachRock", 12.0)
		_apply_prop_depth(&"TravelCapsule", 24.0)

func _apply_actor_depth(actor: Node2D) -> void:
	# Actor origins sit above their feet. Sorting by the origin put the torso
	# behind scenery even at physical contact with its south-facing edge.
	var foot_y := actor.global_position.y
	for path in ["CollisionShape2D", "BodyCollision"]:
		var collision := actor.get_node_or_null(path) as CollisionShape2D
		if collision != null and collision.shape != null:
			var bounds: Rect2 = collision.global_transform * collision.shape.get_rect()
			foot_y = bounds.end.y
			break
	actor.z_as_relative = false
	actor.z_index = WorldDepth.z_for(foot_y)
	# Flyers are drawn above every ground actor and piece of scenery.
	var flight := actor.get_node_or_null("Components/FlightComponent") as FlightComponent
	if flight != null and flight.is_airborne():
		actor.z_index += AIRBORNE_DEPTH_BONUS

func _apply_prop_depth(node_name: StringName, foot_offset: float) -> void:
	if _kame_region == null:
		return

	var node: Node2D = _kame_region.get_node_or_null(
		NodePath(String(node_name))
	) as Node2D
	if node == null:
		return

	node.z_as_relative = false
	node.z_index = WorldDepth.z_for(node.to_global(Vector2(0, foot_offset)).y)

func _build_kame_foliage() -> void:
	if _detail_root == null:
		return

	# Sparse fallback only. The original GBA reference map supplies the dense
	# vegetation whenever it is available.
	var positions: Array[Vector2] = [
		Vector2(248, 210),
		Vector2(680, 206),
		Vector2(704, 350),
		Vector2(284, 360),
	]
	var scales: Array[float] = [0.62, 0.68, 0.58, 0.60]

	for index in range(positions.size()):
		var palm: Sprite2D = Sprite2D.new()
		palm.name = "GbaPalm%02d" % index
		palm.texture = PALM_TEXTURE
		palm.position = positions[index]
		var scale_value: float = scales[index]
		palm.scale = Vector2(scale_value, scale_value)
		palm.flip_h = index % 2 == 1
		palm.z_index = WorldDepth.z_for(palm.position.y + 38.0)
		_detail_root.add_child(palm)

func _build_kame_flower_density() -> void:
	if _detail_root == null:
		return

	var dmi = DMI_SPRITE_SHEET_SCRIPT.load_file(FLOWERS_DMI_PATH)
	if dmi == null:
		return

	var state_keys: Array = dmi.states.keys()
	if state_keys.is_empty():
		return

	var flower_state: StringName = StringName(String(state_keys[0]))
	var frame_count: int = dmi.get_frame_count(flower_state)
	if frame_count <= 0:
		return

	var positions: Array[Vector2] = [
		Vector2(320, 212), Vector2(388, 176), Vector2(566, 182),
		Vector2(636, 226), Vector2(654, 362), Vector2(548, 410),
		Vector2(404, 414), Vector2(310, 348), Vector2(390, 326),
		Vector2(530, 304), Vector2(584, 338), Vector2(454, 370),
	]

	for index in range(positions.size()):
		var texture: Texture2D = dmi.get_frame_texture(
			flower_state,
			&"down",
			index % frame_count
		)
		if texture == null:
			continue

		var flower: Sprite2D = Sprite2D.new()
		flower.texture = texture
		flower.position = positions[index]
		var scale_value: float = 0.46 + float(index % 3) * 0.06
		flower.scale = Vector2(scale_value, scale_value)
		flower.z_index = -1
		_detail_root.add_child(flower)

func _build_kame_glints() -> void:
	var positions: Array[Vector2] = [
		Vector2(96, 120), Vector2(154, 82), Vector2(258, 60),
		Vector2(356, 52), Vector2(612, 66), Vector2(732, 92),
		Vector2(848, 142), Vector2(882, 230), Vector2(858, 354),
		Vector2(792, 492), Vector2(658, 514), Vector2(544, 520),
		Vector2(390, 516), Vector2(266, 504), Vector2(126, 458),
		Vector2(86, 346), Vector2(80, 236),
	]

	for index in range(positions.size()):
		var glint: Polygon2D = Polygon2D.new()
		var size: float = 1.5 + float(index % 3) * 0.5
		glint.polygon = PackedVector2Array([
			Vector2(0, -size),
			Vector2(size * 0.45, 0),
			Vector2(0, size),
			Vector2(-size * 0.45, 0),
		])
		glint.color = Color(0.9, 0.98, 1.0, 0.65)
		glint.position = positions[index]
		_fx_root.add_child(glint)
		_items.append(glint)
		_base_positions.append(positions[index])

func _build_waste_dust() -> void:
	for index in range(22):
		var mote: Polygon2D = Polygon2D.new()
		var size: float = 0.8 + float(index % 4) * 0.35
		mote.polygon = PackedVector2Array([
			Vector2(-size, -size * 0.4),
			Vector2(size, -size * 0.4),
			Vector2(size, size * 0.4),
			Vector2(-size, size * 0.4),
		])
		mote.color = Color(0.86, 0.68, 0.42, 0.3)
		mote.position = Vector2(
			80.0 + float((index * 79) % 1120),
			70.0 + float((index * 47) % 570)
		)
		_fx_root.add_child(mote)
		_items.append(mote)
		_base_positions.append(mote.position)

func _build_city_lights() -> void:
	var positions: Array[Vector2] = [
		Vector2(690, 344), Vector2(722, 344), Vector2(754, 344),
		Vector2(690, 462), Vector2(722, 462), Vector2(754, 462),
		Vector2(900, 330), Vector2(940, 330), Vector2(980, 330),
	]
	for index in range(positions.size()):
		var light: Polygon2D = Polygon2D.new()
		light.polygon = PackedVector2Array([
			Vector2(-2, -1), Vector2(2, -1),
			Vector2(2, 1), Vector2(-2, 1),
		])
		light.color = Color(0.55, 0.9, 1.0, 0.45)
		light.position = positions[index]
		_fx_root.add_child(light)
		_items.append(light)
		_base_positions.append(positions[index])

func _animate_kame(item: Node2D, index: int) -> void:
	var phase: float = _time * 1.8 + float(index) * 0.67
	item.position = _base_positions[index] + Vector2(
		sin(phase) * 1.5,
		cos(phase * 0.8) * 1.0
	)
	item.modulate = Color(
		1.0, 1.0, 1.0,
		0.28 + (sin(phase * 1.4) + 1.0) * 0.24
	)

func _animate_wastes(item: Node2D, index: int, delta: float) -> void:
	var speed: float = 8.0 + float(index % 5) * 3.0
	item.position.x += speed * delta
	item.position.y = (
		_base_positions[index].y
		+ sin(_time * 0.9 + float(index)) * 4.0
	)
	if item.position.x > 1260.0:
		item.position.x = 20.0

func _animate_city(item: Node2D, index: int) -> void:
	var pulse: float = (
		0.35
		+ (sin(_time * 2.2 + float(index) * 0.8) + 1.0) * 0.22
	)
	item.modulate = Color(1.0, 1.0, 1.0, pulse)
