class_name WorldAmbientFX
extends Node

const MODE_NONE: StringName = &""
const MODE_KAME: StringName = &"kame"
const MODE_WASTES: StringName = &"wastes"
const MODE_CITY: StringName = &"city"

var _world_manager: WorldManager
var _fx_root: Node2D
var _mode: StringName = MODE_NONE
var _items: Array[Node2D] = []
var _base_positions: Array[Vector2] = []
var _time: float = 0.0

func _ready() -> void:
	call_deferred("_bind_world")

func _process(delta: float) -> void:
	_time += delta

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

	_fx_root = Node2D.new()
	_fx_root.name = "AmbientFX"
	_fx_root.z_index = -5
	(world as Node2D).add_child(_fx_root)

	var world_name: String = String(world.name).to_lower()
	if world_name.contains("kame"):
		_mode = MODE_KAME
		_build_kame_glints()
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

	if _fx_root != null and is_instance_valid(_fx_root):
		_fx_root.queue_free()
	_fx_root = null

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
