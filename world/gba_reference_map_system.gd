class_name GbaReferenceMapSystem
extends Node

const LOG2_ROSHI_MAP_PATH := (
	"res://assets/vendor/dragon_ball_gba/dbzlog2/Backgrounds/"
	+ "Master Roshi Island__584997.png"
)
const LOG2_ROSHI_REGION := Rect2(67, 3, 1280, 768)
const LOG2_ROSHI_SCALE := Vector2(0.75, 0.75)
const LOG2_ROSHI_CENTER := Vector2(480, 288)

var _world_manager: WorldManager

func _ready() -> void:
	call_deferred("_bind_world")

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
		_apply_to_world(container.get_child(0))

func _on_world_changed(
	_scene_path: String,
	world: Node
) -> void:
	_apply_to_world(world)

func _apply_to_world(world: Node) -> void:
	if world == null or not world is Node2D:
		return

	var world_name: String = String(world.name).to_lower()
	if not world_name.contains("kame"):
		return

	if not ResourceLoader.exists(LOG2_ROSHI_MAP_PATH):
		return

	var source: Texture2D = load(LOG2_ROSHI_MAP_PATH) as Texture2D
	if source == null:
		return

	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = source
	atlas.region = LOG2_ROSHI_REGION

	var map_sprite: Sprite2D = Sprite2D.new()
	map_sprite.name = "OriginalGbaKameIsland"
	map_sprite.texture = atlas
	map_sprite.position = LOG2_ROSHI_CENTER
	map_sprite.scale = LOG2_ROSHI_SCALE
	map_sprite.z_index = -30
	map_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var world_2d: Node2D = world as Node2D
	world_2d.add_child(map_sprite)
	world_2d.move_child(map_sprite, 0)

	# The reference map already contains the full coastline, house, palms,
	# umbrella/chair and incidental ground detail. Hide our fallback artwork so
	# it never stacks on top and creates duplicate trees, stones or props.
	_hide_node(world, ^"Terrain")
	_hide_node(world, ^"KameHouse/Sprite2D")
	_hide_node(world, ^"PalmTreeLeft")
	_hide_node(world, ^"PalmTreeRight")
	_hide_node(world, ^"PalmTreeSouth")
	_hide_node(world, ^"PalmTreeNorthWest")
	_hide_node(world, ^"PalmTreeNorthEast")
	_hide_node(world, ^"BeachUmbrella")
	_hide_node(world, ^"BeachChair")
	_hide_node(world, ^"BeachRock")
	_hide_node(world, ^"FlowerPatches")
	_hide_node(world, ^"TrainingRing")
	_hide_node(world, ^"BeachGuide/Sign")
	_hide_node(world, ^"BeachGuide/Paper")

	var entrance: Node2D = world.get_node_or_null(
		^"KameHouseEntrance"
	) as Node2D
	if entrance != null:
		entrance.position = Vector2(512, 318)

	# Extra foliage may be created by older/fallback ambience in the same
	# frame. Defer one cleanup pass; current WorldAmbientFX also skips creating
	# it entirely when this reference map is present.
	call_deferred("_hide_runtime_foliage", world)

func _hide_runtime_foliage(world: Node) -> void:
	if world == null or not is_instance_valid(world):
		return
	_hide_node(world, ^"GbaVisualDetails")
	_hide_node(world, ^"FlowerPatches")

func _hide_node(root: Node, path: NodePath) -> void:
	var item: CanvasItem = root.get_node_or_null(path) as CanvasItem
	if item != null:
		item.visible = false
