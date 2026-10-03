class_name WorldAmbientFX
extends Node

const MODE_NONE: StringName = &""
const MODE_KAME: StringName = &"kame"
const MODE_WASTES: StringName = &"wastes"
const MODE_CITY: StringName = &"city"

const DEPTH_BASE: int = 1000
# Slightly closer than the original project camera, but far less zoomed than
# the previous GBA pass. This keeps combat readable without making the island
# feel cramped.
const GBA_CAMERA_ZOOM := Vector2(1.10, 1.10)

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
var _time: float = 0.0

func _ready() -> void:
	call_deferred("_bind_world")
	call_deferred("_refresh_player_camera")

func _process(delta: float) -> void:
	_time += delta
	_refresh_player_camera()
	_update_depth_sorting()

	match _mode:
		MODE_KAME:
			_animate_kame()
		MODE_WASTES:
			_animate_wastes(delta)
		MODE_CITY:
			_animate_city()

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
	if world == null or not world is Node2D:
		return

	_world = world as Node2D

	_fx_root = Node2D.new()
	_fx_root.name = "AmbientFX"
	_fx_root.z_index = -5
	_world.add_child(_fx_root)

	_detail_root = Node2D.new()
	_detail_root.name = "GbaVisualDetails"
	_world.add_child(_detail_root)

	var world_name: String = String(world.name).to_lower()
	if world_name.contains("kame"):
		_mode = MODE_KAME
		_build_kame_glints()
		# Kame Island owns its authored foliage and flower placement. Do not
		# layer fallback props over it, since that creates visual duplication.
	elif world_name.contains("rocky") or world_name.contains("wastes"):
		_mode = MODE_WASTES
		_build_waste_dust()
	elif world_name.contains("west") or world_name.contains("city"):
		_mode = MODE_CITY
		_build_city_lights()
	else:
		_mode = MODE_NONE

func _clear_fx() -> void:
	_items.clear()
	_base_positions.clear()
	_mode = MODE_NONE
	_world = null

	if _fx_root != null and is_instance_valid(_fx_root):
		_fx_root.queue_free()
	_fx_root = null

	if _detail_root != null and is_instance_valid(_detail_root):
		_detail_root.queue_free()
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
		_player.z_index = DEPTH_BASE + roundi(_player.global_position.y)

	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemy")
	for enemy: Node in enemies:
		var enemy_2d: Node2D = enemy as Node2D
		if enemy_2d != null:
			enemy_2d.z_index = DEPTH_BASE + roundi(enemy_2d.global_position.y)

	var npcs: Array[Node] = get_tree().get_nodes_in_group("npc")
	for npc: Node in npcs:
		var npc_2d: Node2D = npc as Node2D
		if npc_2d != null:
			npc_2d.z_index = DEPTH_BASE + roundi(npc_2d.global_position.y)

	if _mode == MODE_KAME and _world != null:
		_apply_prop_depth(&"KameHouse", 105.0)
		_apply_prop_depth(&"PalmTreeLeft", 42.0)
		_apply_prop_depth(&"PalmTreeRight", 42.0)
		_apply_prop_depth(&"PalmTreeSouth", 42.0)
		_apply_prop_depth(&"PalmTreeNorthWest", 42.0)
		_apply_prop_depth(&"PalmTreeNorthEast", 42.0)
		_apply_prop_depth(&"BeachUmbrella", 30.0)
		_apply_prop_depth(&"BeachChair", 14.0)
		_apply_prop_depth(&"BeachRock", 12.0)
		_apply_prop_depth(&"TravelCapsule", 24.0)

func _apply_prop_depth(node_name: StringName, foot_offset: float) -> void:
	if _world == null:
		return

	var node: Node2D = _world.get_node_or_null(
		NodePath(String(node_name))
	) as Node2D
	if node == null:
		return

	node.z_index = DEPTH_BASE + roundi(
		node.global_position.y + foot_offset
	)

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
		palm.z_index = DEPTH_BASE + roundi(palm.position.y + 38.0)
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

func _animate_kame() -> void:
	for index in range(_items.size()):
		var item: Node2D = _items[index]
		if item == null or not is_instance_valid(item):
			continue
		var phase: float = _time * 1.8 + float(index) * 0.67
		item.position = _base_positions[index] + Vector2(
			sin(phase) * 1.5,
			cos(phase * 0.8) * 1.0
		)
		item.modulate = Color(
			1.0, 1.0, 1.0,
			0.28 + (sin(phase * 1.4) + 1.0) * 0.24
		)

func _animate_wastes(delta: float) -> void:
	for index in range(_items.size()):
		var item: Node2D = _items[index]
		if item == null or not is_instance_valid(item):
			continue

		var speed: float = 8.0 + float(index % 5) * 3.0
		item.position.x += speed * delta
		item.position.y = (
			_base_positions[index].y
			+ sin(_time * 0.9 + float(index)) * 4.0
		)
		if item.position.x > 1260.0:
			item.position.x = 20.0

func _animate_city() -> void:
	for index in range(_items.size()):
		var item: Node2D = _items[index]
		if item == null or not is_instance_valid(item):
			continue
		var pulse: float = (
			0.35
			+ (sin(_time * 2.2 + float(index) * 0.8) + 1.0) * 0.22
		)
		item.modulate = Color(1.0, 1.0, 1.0, pulse)
