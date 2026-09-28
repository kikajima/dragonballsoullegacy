class_name KiBlastProjectile
extends Area2D

@export var speed: float = 300.0
@export var damage: int = 12
@export var lifetime: float = 1.6
@export var projectile_fps: float = 12.0
@export var impact_duration: float = 0.12
@export var clashes_with_projectiles: bool = true
@export var projectile_clash_radius: float = 3.5

@export_file("*.png")
var projectile_sheet_path: String = "res://assets/sprites/effects/processed/ki_blast_projectile.png"

@export_file("*.png")
var impact_sheet_path: String = "res://assets/sprites/effects/processed/ki_blast_impact.png"

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var core: Polygon2D = $Core
@onready var glow: Polygon2D = $Glow
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _direction: Vector2 = Vector2.RIGHT
var _lifetime_left: float
var _impact_time_left: float = 0.0
var _impacted: bool = false
var _source_actor: Node

func _ready() -> void:
	_lifetime_left = lifetime
	_build_sprite_frames()
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func setup(
	direction: Vector2,
	damage_override: int = -1,
	source_actor: Node = null
) -> void:
	_source_actor = source_actor
	_configure_collision_filter()

	if damage_override >= 0:
		damage = damage_override

	if direction.is_zero_approx():
		_direction = Vector2.RIGHT
	else:
		_direction = direction.normalized()

	rotation = _direction.angle()

func _physics_process(delta: float) -> void:
	if _impacted:
		_impact_time_left -= delta
		if _impact_time_left <= 0.0:
			queue_free()
		return

	var start_position: Vector2 = global_position
	var end_position: Vector2 = (
		start_position + _direction * speed * delta
	)

	var projectile_hit: Dictionary = _cast_against_projectiles(
		start_position,
		end_position
	)
	var solid_hit: Dictionary = _cast_against_solids(
		start_position,
		end_position
	)

	if _projectile_hit_happens_first(
		projectile_hit,
		solid_hit,
		start_position
	):
		var clash_position_value: Variant = projectile_hit.get(
			"position",
			end_position
		)
		var clash_position: Vector2 = clash_position_value as Vector2
		var other_value: Variant = projectile_hit.get(
			"projectile",
			null
		)
		var other_projectile := other_value as Node2D

		if other_projectile != null:
			resolve_projectile_clash(
				other_projectile,
				clash_position
			)
		else:
			_start_impact_at(clash_position)
		return

	if not solid_hit.is_empty():
		var hit_position_value: Variant = solid_hit.get(
			"position",
			end_position
		)
		global_position = hit_position_value as Vector2

		var collider_value: Variant = solid_hit.get(
			"collider",
			null
		)
		var collider := collider_value as Node2D
		if collider != null:
			_handle_solid_body(collider)
		else:
			_start_impact()
		return

	global_position = end_position

	_lifetime_left -= delta
	if _lifetime_left <= 0.0:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if _impacted or area == null:
		return

	if (
		clashes_with_projectiles
		and area != self
		and area.is_in_group("combat_projectile")
	):
		if area.has_method("is_active_projectile"):
			var active_value: Variant = area.call(
				"is_active_projectile"
			)
			if not bool(active_value):
				return

		var clash_position: Vector2 = (
			global_position + area.global_position
		) * 0.5
		resolve_projectile_clash(area, clash_position)
		return

	# Dedicated non-damage blockers are used by NPCs such as Master Roshi.
	# They stop Ki projectiles but never receive damage.
	if area.is_in_group("ki_blocker"):
		var npc: Node = area.get_parent()
		if npc != null and npc.has_method("on_ki_blast_blocked"):
			npc.call("on_ki_blast_blocked", _direction)
		_start_impact()
		return

	if not area.has_method("receive_hit"):
		return

	var result: Variant = area.call(
		"receive_hit",
		damage,
		global_position
	)
	var applied_damage: int = int(result)

	if (
		applied_damage > 0
		and _source_actor != null
		and is_instance_valid(_source_actor)
		and _source_actor.has_method("register_combat_hit")
	):
		_source_actor.call(
			"register_combat_hit",
			area,
			applied_damage
		)

	# Projectiles still collide visually with an invulnerable target,
	# but only confirmed damage contributes to combo/feedback.
	_start_impact()

func _on_body_entered(body: Node2D) -> void:
	if _impacted or body == null:
		return

	_handle_solid_body(body)

func _cast_against_projectiles(
	from_position: Vector2,
	to_position: Vector2
) -> Dictionary:
	if not clashes_with_projectiles:
		return {}

	var nearest: Node2D = null
	var nearest_position: Vector2 = Vector2.ZERO
	var nearest_distance: float = INF

	var projectiles: Array[Node] = get_tree().get_nodes_in_group(
		"combat_projectile"
	)

	for node in projectiles:
		var other := node as Node2D
		if other == null or other == self:
			continue

		if other.has_method("is_active_projectile"):
			var active_value: Variant = other.call(
				"is_active_projectile"
			)
			if not bool(active_value):
				continue

		var other_radius: float = projectile_clash_radius
		if other.has_method("get_projectile_clash_radius"):
			var radius_value: Variant = other.call(
				"get_projectile_clash_radius"
			)
			other_radius = maxf(float(radius_value), 0.0)

		var closest: Vector2 = _closest_point_on_segment(
			other.global_position,
			from_position,
			to_position
		)
		var combined_radius: float = maxf(
			projectile_clash_radius,
			0.0
		) + other_radius

		if closest.distance_to(other.global_position) > combined_radius:
			continue

		var distance: float = from_position.distance_to(closest)
		if distance >= nearest_distance:
			continue

		nearest = other
		nearest_position = (
			closest + other.global_position
		) * 0.5
		nearest_distance = distance

	if nearest == null:
		return {}

	return {
		"projectile": nearest,
		"position": nearest_position,
		"distance": nearest_distance,
	}

func _projectile_hit_happens_first(
	projectile_hit: Dictionary,
	solid_hit: Dictionary,
	start_position: Vector2
) -> bool:
	if projectile_hit.is_empty():
		return false

	if solid_hit.is_empty():
		return true

	var projectile_position_value: Variant = projectile_hit.get(
		"position",
		start_position
	)
	var solid_position_value: Variant = solid_hit.get(
		"position",
		start_position
	)

	var projectile_position: Vector2 = projectile_position_value as Vector2
	var solid_position: Vector2 = solid_position_value as Vector2

	return (
		start_position.distance_squared_to(projectile_position)
		<= start_position.distance_squared_to(solid_position)
	)

func _closest_point_on_segment(
	point: Vector2,
	segment_start: Vector2,
	segment_end: Vector2
) -> Vector2:
	var segment: Vector2 = segment_end - segment_start
	var length_squared: float = segment.length_squared()

	if length_squared <= 0.000001:
		return segment_start

	var ratio: float = clampf(
		(point - segment_start).dot(segment) / length_squared,
		0.0,
		1.0
	)

	return segment_start + segment * ratio

func _cast_against_solids(
	from_position: Vector2,
	to_position: Vector2
) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(
		from_position,
		to_position
	)
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false

	return get_world_2d().direct_space_state.intersect_ray(query)

func _handle_solid_body(body: Node2D) -> void:
	if _impacted or body == null:
		return

	var collision_body := body as CollisionObject2D
	if collision_body == null:
		return

	var npc: Node = null

	if collision_body.is_in_group("npc"):
		npc = collision_body
	else:
		var parent: Node = collision_body.get_parent()
		if parent != null and parent.is_in_group("npc"):
			npc = parent

	if npc != null:
		if npc.has_method("on_ki_blast_blocked"):
			npc.call("on_ki_blast_blocked", _direction)

		_start_impact()
		return

	if collision_body.collision_layer & 1 != 0:
		_start_impact()

func _configure_collision_filter() -> void:
	if _source_actor == null:
		return

	if _source_actor.is_in_group("enemy"):
		# World + Player/Hurtbox + Projectiles.
		collision_mask = 35
	elif _source_actor.is_in_group("player"):
		# World + Enemy/Hurtbox + Projectiles.
		collision_mask = 37

func get_projectile_clash_radius() -> float:
	return projectile_clash_radius

func resolve_projectile_clash(
	other_projectile: Node2D,
	clash_position: Vector2
) -> void:
	if _impacted or other_projectile == null:
		return

	if (
		other_projectile.has_method("is_active_projectile")
		and not bool(
			other_projectile.call("is_active_projectile")
		)
	):
		return

	_start_impact_at(clash_position)

	if other_projectile.has_method("receive_projectile_clash"):
		other_projectile.call(
			"receive_projectile_clash",
			self,
			clash_position
		)

func receive_projectile_clash(
	_other_projectile: Node,
	clash_position: Vector2
) -> void:
	if _impacted:
		return

	_start_impact_at(clash_position)

func get_source_actor() -> Node:
	return _source_actor

func get_travel_direction() -> Vector2:
	return _direction

func get_projectile_speed() -> float:
	return speed

func is_active_projectile() -> bool:
	return not _impacted

func _start_impact_at(impact_position: Vector2) -> void:
	global_position = impact_position
	_start_impact()

func _start_impact() -> void:
	if _impacted:
		return

	_impacted = true
	_impact_time_left = impact_duration
	collision_shape.set_deferred("disabled", true)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)

	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"impact"):
		core.visible = false
		glow.visible = false
		sprite.visible = true
		sprite.play(&"impact")
	else:
		core.scale = Vector2(1.5, 1.5)
		glow.scale = Vector2(1.5, 1.5)

func _build_sprite_frames() -> void:
	var frames := SpriteFrames.new()
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")

	var built_projectile := false

	if ResourceLoader.exists(projectile_sheet_path):
		var projectile_sheet := load(projectile_sheet_path) as Texture2D
		if projectile_sheet != null and projectile_sheet.get_width() >= 64 and projectile_sheet.get_height() >= 16:
			frames.add_animation(&"fly")
			frames.set_animation_loop(&"fly", true)
			frames.set_animation_speed(&"fly", projectile_fps)

			for column in range(4):
				frames.add_frame(
					&"fly",
					_atlas_frame(projectile_sheet, column, 0, Vector2i(16, 16))
				)

			built_projectile = true

	if ResourceLoader.exists(impact_sheet_path):
		var impact_sheet := load(impact_sheet_path) as Texture2D
		if impact_sheet != null and impact_sheet.get_width() >= 16 and impact_sheet.get_height() >= 16:
			frames.add_animation(&"impact")
			frames.set_animation_loop(&"impact", false)
			frames.set_animation_speed(&"impact", 1.0)
			frames.add_frame(
				&"impact",
				_atlas_frame(impact_sheet, 0, 0, Vector2i(16, 16))
			)

	if built_projectile:
		sprite.sprite_frames = frames
		sprite.visible = true
		core.visible = false
		glow.visible = false
		sprite.play(&"fly")
	else:
		sprite.visible = false
		core.visible = true
		glow.visible = true

func _atlas_frame(
	sheet: Texture2D,
	column: int,
	row: int,
	frame_size: Vector2i
) -> AtlasTexture:
	var frame := AtlasTexture.new()
	frame.atlas = sheet
	frame.region = Rect2(
		Vector2(column * frame_size.x, row * frame_size.y),
		Vector2(frame_size.x, frame_size.y)
	)
	return frame
