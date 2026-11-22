class_name FlightComponent
extends Node

# HU2-style flight for any CharacterBody2D (player and enemies).
# - Visual: everything under Visuals is lifted above a ground FlightShadow
#   and gently bobs.
# - Mechanics: while airborne the body moves to the "Flying" physics layer
#   with no collision mask, so it passes over scenery, buildings and grounded
#   fighters. It stays inside the world bounds (WorldCameraBounds) and can
#   only land on free, walkable ground.
# - Melee only connects between fighters at the same height (see
#   HitboxComponent); ki blasts and beams still cross heights.

signal flight_changed(flying: bool)
signal landing_blocked

const FLYING_LAYER := 1024 # physics layer 11 "Flying"
const BOUNDS_MARGIN := 12.0
const LANDING_SEARCH_STEP := 16.0
const LANDING_SEARCH_RINGS := 40

@export var cruise_altitude: float = ElevationLevel.AIR_HEIGHT
# Pixels per second while taking off / landing.
@export var climb_speed: float = 70.0
@export var hover_bob_amplitude: float = 1.5
@export var hover_bob_speed: float = 3.4
@export var fly_speed_scale: float = 1.2
@export var fast_fly_speed_scale: float = 2.3
# Ki per second spent while flying fast (0 = free).
@export var fast_fly_ki_per_second: float = 9.0
# HU2 "FlightShadow" drawn on the ground under the flyer; it fades in with
# the altitude so the lift reads as height.
@export var shadow_alpha: float = 0.5
@export var shadow_offset: Vector2 = Vector2(0, 15)
@export var visuals_path: NodePath = ^"../../Visuals"
@export var body_path: NodePath = ^"../.."

const SHADOW_DMI_PATH := "res://assets/vendor/hu2/Icons/Other/Other.dmi"
const SHADOW_STATE: StringName = &"FlightShadow"
const SHADOW_NAME: StringName = &"FlightShadow"

var is_flying: bool = false
# Current lift (pixels above the ground) without the hover bob.
var altitude: float = 0.0

var _time: float = 0.0
var _lift: float = 0.0
var _base_y: Dictionary = {}
var _shadow: DmiEffectSprite2D
var _ground_layer: int = -1
var _ground_mask: int = -1

static func is_actor_airborne(actor: Node) -> bool:
	if actor == null:
		return false
	var flight := actor.get_node_or_null("Components/FlightComponent") as FlightComponent
	return flight != null and flight.is_flying

func _process(delta: float) -> void:
	tick(delta)

func _physics_process(_delta: float) -> void:
	if is_flying:
		_clamp_to_world_bounds()

func get_body() -> CollisionObject2D:
	return get_node_or_null(body_path) as CollisionObject2D

func take_off() -> bool:
	if is_flying:
		return false
	is_flying = true
	_set_airborne_collision(true)
	flight_changed.emit(true)
	return true

# Lands only on free walkable ground; otherwise keeps flying.
func land() -> bool:
	if not is_flying:
		return false
	var body := get_body() as Node2D
	if body != null and not can_land_at(body.global_position):
		landing_blocked.emit()
		return false
	is_flying = false
	_set_airborne_collision(false)
	flight_changed.emit(false)
	return true

func toggle() -> bool:
	if is_flying:
		land()
	else:
		take_off()
	return is_flying

# Instant forced landing (respawn, load, defeat): if the spot is blocked the
# body is moved to the nearest place it can stand.
func land_immediately() -> void:
	var was_flying := is_flying
	is_flying = false
	altitude = 0.0
	_set_airborne_collision(false)
	if was_flying:
		var body := get_body() as Node2D
		if body != null and not can_land_at(body.global_position):
			body.global_position = find_landing_spot(body.global_position)
	_apply_lift(0.0)
	_update_body_frames()
	if was_flying:
		flight_changed.emit(false)

func is_airborne() -> bool:
	return is_flying or altitude > 0.5

func get_ground_mask() -> int:
	var body := get_body()
	if _ground_mask >= 0:
		return _ground_mask
	return body.collision_mask if body != null else 1

func can_land_at(point: Vector2) -> bool:
	var body := get_body() as CharacterBody2D
	if body == null or not body.is_inside_tree():
		return true
	var world := _get_world_root()
	if world != null and world.has_method("is_landable_point"):
		if not world.is_landable_point(point):
			return false
	var bounds := get_world_bounds()
	if bounds.size != Vector2.ZERO and not bounds.grow(-BOUNDS_MARGIN).has_point(point):
		return false
	var shape_node := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or shape_node.shape == null:
		return true
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape_node.shape
	var xform := shape_node.global_transform
	xform.origin = point + (shape_node.global_position - body.global_position)
	query.transform = xform
	# Only scenery blocks a landing; overlapping fighters are pushed apart
	# by the body's own depenetration.
	query.collision_mask = get_ground_mask() & 1
	query.exclude = [body.get_rid()]
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return body.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()

# Nearest free walkable spot around `point` (rings of 8 probes).
func find_landing_spot(point: Vector2) -> Vector2:
	if can_land_at(point):
		return point
	for ring in range(1, LANDING_SEARCH_RINGS + 1):
		var radius := ring * LANDING_SEARCH_STEP
		var probes := mini(8 * ring, 64)
		for i in probes:
			var candidate := point + Vector2.RIGHT.rotated(TAU * i / probes) * radius
			if can_land_at(candidate):
				return candidate
	return point

func get_world_bounds() -> Rect2:
	var body := get_body()
	if body == null or not body.is_inside_tree():
		return Rect2()
	for node in body.get_tree().get_nodes_in_group("world_bounds"):
		if node is WorldCameraBounds and node.is_inside_tree():
			return (node as WorldCameraBounds).bounds
	return Rect2()

func _get_world_root() -> Node:
	var body := get_body()
	if body == null or not body.is_inside_tree():
		return null
	for node in body.get_tree().get_nodes_in_group("world_bounds"):
		if node.is_inside_tree():
			return node.get_parent()
	return null

func _clamp_to_world_bounds() -> void:
	var body := get_body() as Node2D
	var bounds := get_world_bounds()
	if body == null or bounds.size == Vector2.ZERO:
		return
	var inner := bounds.grow(-BOUNDS_MARGIN)
	body.global_position = body.global_position.clamp(inner.position, inner.end)

func _set_airborne_collision(airborne: bool) -> void:
	var body := get_body()
	if body == null:
		return
	if airborne:
		if _ground_layer < 0:
			_ground_layer = body.collision_layer
			_ground_mask = body.collision_mask
		body.collision_layer = FLYING_LAYER
		body.collision_mask = 0
	elif _ground_layer >= 0:
		body.collision_layer = _ground_layer
		body.collision_mask = _ground_mask
		_ground_layer = -1
		_ground_mask = -1

func get_lift() -> float:
	return _lift

func tick(delta: float) -> void:
	var target := cruise_altitude if is_flying else 0.0
	altitude = move_toward(altitude, target, climb_speed * delta)
	_time += delta
	var bob := 0.0
	if cruise_altitude > 0.0:
		bob = (
			sin(_time * hover_bob_speed)
			* hover_bob_amplitude
			* (altitude / cruise_altitude)
		)
	_apply_lift(roundf(altitude + bob))
	_update_body_frames()

# The body sprite's baked ground shadow would float with it; while airborne
# use the shadowless copy of its frames (the FlightShadow replaces it).
func _update_body_frames() -> void:
	var visuals := get_node_or_null(visuals_path) as Node2D
	if visuals == null:
		return
	var sprite := visuals.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		return
	var wanted := (
		BakedShadowStripper.airborne_set(sprite.sprite_frames)
		if is_airborne()
		else BakedShadowStripper.ground_set(sprite.sprite_frames)
	)
	BakedShadowStripper.swap(sprite, wanted)

func get_shadow() -> CanvasItem:
	return _shadow

func _apply_lift(lift: float) -> void:
	_lift = lift
	var visuals := get_node_or_null(visuals_path) as Node2D
	if visuals == null:
		return
	_ensure_shadow(visuals)
	for child in visuals.get_children():
		var node := child as Node2D
		if node == null or node == _shadow:
			continue
		var id := node.get_instance_id()
		if not _base_y.has(id):
			_base_y[id] = node.position.y
		node.position.y = float(_base_y[id]) - lift
	var t := 0.0
	if cruise_altitude > 0.0:
		t = clampf(altitude / cruise_altitude, 0.0, 1.0)
	_shadow.visible = t > 0.0
	_shadow.modulate.a = shadow_alpha * t

func _ensure_shadow(visuals: Node2D) -> void:
	if _shadow != null and is_instance_valid(_shadow):
		return
	_shadow = DmiEffectSprite2D.new()
	_shadow.name = SHADOW_NAME
	_shadow.position = shadow_offset
	_shadow.z_index = -5
	_shadow.visible = false
	_shadow.loop_animation = false
	_shadow.dmi_path = SHADOW_DMI_PATH
	_shadow.dmi_state = SHADOW_STATE
	visuals.add_child(_shadow)
