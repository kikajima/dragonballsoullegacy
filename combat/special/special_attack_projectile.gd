class_name SpecialAttackProjectile
extends Area2D

const EFFECT_SHEET_PATH := (
	"res://assets/sprites/effects/legacy/special_attack_sfx.png"
)

const EFFECT_RECTS := {
	&"blue_orb": [
		Rect2i(9, 33, 6, 6),
		Rect2i(19, 35, 10, 10),
		Rect2i(33, 33, 14, 14),
		Rect2i(51, 33, 28, 14),
	],
	&"orange_orb": [
		Rect2i(9, 57, 6, 6),
		Rect2i(17, 57, 14, 14),
		Rect2i(35, 57, 28, 14),
		Rect2i(64, 56, 32, 16),
	],
	&"energy_ring": [
		Rect2i(9, 89, 6, 6),
		Rect2i(19, 91, 10, 10),
		Rect2i(33, 89, 14, 14),
		Rect2i(54, 88, 20, 16),
	],
	&"masenko": [
		Rect2i(8, 122, 46, 16),
		Rect2i(56, 122, 30, 16),
		Rect2i(88, 136, 16, 16),
		Rect2i(107, 131, 26, 26),
	],
	&"big_bang": [
		Rect2i(9, 201, 6, 6),
		Rect2i(19, 203, 10, 10),
		Rect2i(33, 201, 14, 14),
		Rect2i(50, 196, 30, 24),
		Rect2i(82, 196, 33, 24),
	],
	&"burning_attack": [
		Rect2i(9, 233, 6, 6),
		Rect2i(19, 232, 12, 16),
		Rect2i(37, 232, 21, 28),
		Rect2i(69, 234, 22, 26),
	],
	&"sword_blast": [
		Rect2i(8, 272, 32, 32),
		Rect2i(42, 274, 12, 12),
		Rect2i(64, 280, 16, 16),
	],
	&"spirit_bomb": [
		Rect2i(9, 321, 6, 6),
		Rect2i(19, 323, 10, 10),
		Rect2i(33, 321, 14, 14),
		Rect2i(52, 316, 24, 24),
		Rect2i(80, 312, 32, 32),
	],
}

@export var impact_duration: float = 0.16

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _direction: Vector2 = Vector2.RIGHT
var _speed: float = 260.0
var _damage: int = 18
var _stun_duration: float = 0.0
var _explosion_radius: float = 0.0
var _screen_stun_on_impact: bool = false
var _max_distance: float = 220.0
var _distance_travelled: float = 0.0
var _impact_time_left: float = 0.0
var _impacted: bool = false
var _source_actor: Node
var _clash_radius: float = 4.0
var _effect_key: StringName = &"blue_orb"

var _is_arc: bool = false
var _arc_elapsed: float = 0.0
var _arc_duration: float = 0.55
var _arc_height: float = 20.0
var _arc_start: Vector2 = Vector2.ZERO
var _arc_end: Vector2 = Vector2.ZERO

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func setup(
	data: SpecialAttackData,
	direction: Vector2,
	source_actor: Node,
	charge_ratio: float = 0.0
) -> void:
	_source_actor = source_actor
	_direction = (
		Vector2.RIGHT
		if direction.is_zero_approx()
		else direction.normalized()
	)

	var safe_charge: float = clampf(
		charge_ratio,
		0.0,
		1.0
	)
	var damage_scale: float = lerpf(
		1.0,
		maxf(data.charge_damage_multiplier, 1.0),
		safe_charge
	)
	var range_scale: float = lerpf(
		1.0,
		maxf(data.charge_range_multiplier, 1.0),
		safe_charge
	)
	var charge_visual_scale: float = lerpf(
		1.0,
		maxf(data.charge_scale_multiplier, 1.0),
		safe_charge
	)

	_damage = maxi(
		roundi(float(data.damage) * damage_scale),
		0
	)
	_stun_duration = data.stun_duration
	_explosion_radius = maxf(
		data.explosion_radius * charge_visual_scale,
		0.0
	)
	_screen_stun_on_impact = data.screen_stun_on_impact
	_speed = maxf(data.projectile_speed, 1.0)
	_max_distance = maxf(
		data.projectile_range * range_scale,
		1.0
	)
	_effect_key = data.effect_key

	var visual_scale: float = (
		maxf(data.projectile_scale, 0.25)
		* charge_visual_scale
	)
	_clash_radius = maxf(
		data.projectile_radius * charge_visual_scale,
		1.0
	)
	sprite.scale = Vector2.ONE * visual_scale
	rotation = _direction.angle()

	var source_shape := (
		collision_shape.shape as CircleShape2D
	)
	if source_shape != null:
		var shape := (
			source_shape.duplicate() as CircleShape2D
		)
		if shape != null:
			shape.radius = _clash_radius
			collision_shape.shape = shape

	_is_arc = (
		data.attack_type
		== SpecialAttackData.AttackType.ARC_GRENADE
	)
	if _is_arc:
		_arc_duration = maxf(data.arc_duration, 0.1)
		_arc_height = maxf(
			data.arc_height * charge_visual_scale,
			0.0
		)
		_arc_start = global_position
		_arc_end = (
			global_position
			+ _direction * _max_distance
		)

	_configure_collision_filter()
	_build_visual(_effect_key)

func _physics_process(delta: float) -> void:
	if _impacted:
		_impact_time_left -= delta
		if _impact_time_left <= 0.0:
			queue_free()
		return

	if _is_arc:
		_process_arc(delta)
		return

	_process_straight(delta)

func _process_arc(delta: float) -> void:
	_arc_elapsed += delta
	var ratio: float = clampf(
		_arc_elapsed / _arc_duration,
		0.0,
		1.0
	)

	global_position = _arc_start.lerp(
		_arc_end,
		ratio
	)
	sprite.position.y = -sin(ratio * PI) * _arc_height

	if ratio >= 1.0:
		sprite.position = Vector2.ZERO
		_resolve_impact(global_position)

func _process_straight(delta: float) -> void:
	var start_position: Vector2 = global_position
	var travel: Vector2 = _direction * _speed * delta
	var end_position: Vector2 = start_position + travel

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
		var clash_position: Vector2 = projectile_hit.get(
			"position",
			end_position
		) as Vector2
		var other := projectile_hit.get(
			"projectile",
			null
		) as Node2D

		if other != null:
			resolve_projectile_clash(
				other,
				clash_position
			)
		else:
			_start_impact_at(clash_position)
		return

	if not solid_hit.is_empty():
		var hit_position: Vector2 = solid_hit.get(
			"position",
			end_position
		) as Vector2
		global_position = hit_position
		_resolve_impact(hit_position)
		return

	global_position = end_position
	_distance_travelled += travel.length()

	if _distance_travelled >= _max_distance:
		_resolve_impact(global_position)

func _on_area_entered(area: Area2D) -> void:
	if _impacted or _is_arc or area == null:
		return

	if (
		area != self
		and area.is_in_group("combat_projectile")
	):
		if _is_friendly_projectile(area):
			return

		resolve_projectile_clash(
			area,
			(global_position + area.global_position) * 0.5
		)
		return

	if area.is_in_group("ki_blocker"):
		_resolve_impact(global_position)
		return

	if not area.has_method("receive_hit"):
		return

	if _explosion_radius > 0.0:
		_resolve_impact(global_position)
		return

	var applied: int = _damage_receiver(
		area,
		_damage
	)
	if applied > 0:
		_apply_status(area, _stun_duration)
		_report_hit(area, applied)

	_start_impact()

func _on_body_entered(body: Node2D) -> void:
	if _impacted or _is_arc or body == null:
		return

	if (
		body.is_in_group("npc")
		or body.collision_layer & 1 != 0
	):
		_resolve_impact(global_position)

func _resolve_impact(position_value: Vector2) -> void:
	global_position = position_value

	if _explosion_radius > 0.0:
		_explode(position_value)

	if _screen_stun_on_impact:
		_apply_screen_stun()

	_start_impact()

func _explode(center: Vector2) -> void:
	var shape := CircleShape2D.new()
	shape.radius = maxf(_explosion_radius, 1.0)

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, center)
	query.collision_mask = _target_collision_mask()
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var results: Array[Dictionary] = (
		get_world_2d()
		.direct_space_state
		.intersect_shape(query, 64)
	)

	var hit_ids: Dictionary = {}
	for result in results:
		var collider_value: Variant = result.get(
			"collider",
			null
		)
		var receiver := collider_value as Area2D
		if (
			receiver == null
			or not receiver.has_method("receive_hit")
		):
			continue

		var receiver_id: int = receiver.get_instance_id()
		if hit_ids.has(receiver_id):
			continue
		hit_ids[receiver_id] = true

		var applied: int = _damage_receiver(
			receiver,
			_damage
		)
		if applied <= 0:
			continue

		_apply_status(receiver, _stun_duration)
		_report_hit(receiver, applied)

func _apply_screen_stun() -> void:
	if _stun_duration <= 0.0:
		return

	var target_group: StringName = (
		&"player"
		if (
			_source_actor != null
			and _source_actor.is_in_group("enemy")
		)
		else &"enemy"
	)

	for node in get_tree().get_nodes_in_group(target_group):
		var actor := node as Node2D
		if actor == null:
			continue

		# Approximate the original "on-screen" stun using the playable
		# 480x270 viewport footprint around the impact.
		if global_position.distance_to(
			actor.global_position
		) > 300.0:
			continue

		var status := actor.get_node_or_null(
			"Components/StatusEffectComponent"
		) as StatusEffectComponent
		if status != null:
			status.apply_status(
				&"stun",
				_stun_duration,
				1.0
			)

func _damage_receiver(
	receiver: Area2D,
	damage_value: int
) -> int:
	return int(
		receiver.call(
			"receive_hit",
			damage_value,
			global_position
		)
	)

func _apply_status(
	receiver: Area2D,
	duration: float
) -> void:
	if duration <= 0.0:
		return

	var actor: Node = receiver.get_parent()
	if actor == null:
		return

	var status := actor.get_node_or_null(
		"Components/StatusEffectComponent"
	) as StatusEffectComponent
	if status != null:
		status.apply_status(
			&"stun",
			duration,
			1.0
		)

func _report_hit(target: Node, damage: int) -> void:
	if (
		_source_actor != null
		and is_instance_valid(_source_actor)
		and _source_actor.has_method("register_combat_hit")
	):
		_source_actor.call(
			"register_combat_hit",
			target,
			damage
		)

func _configure_collision_filter() -> void:
	collision_layer = 32
	monitorable = true

	if (
		_source_actor != null
		and _source_actor.is_in_group("enemy")
	):
		collision_mask = 35
	else:
		collision_mask = 37

func _build_visual(effect_key: StringName) -> void:
	var frames := SpriteFrames.new()
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")

	if not ResourceLoader.exists(EFFECT_SHEET_PATH):
		sprite.visible = false
		return

	var sheet := load(EFFECT_SHEET_PATH) as Texture2D
	if sheet == null:
		sprite.visible = false
		return

	var rects_value: Variant = EFFECT_RECTS.get(
		effect_key,
		[]
	)
	if not rects_value is Array:
		sprite.visible = false
		return

	var rects: Array = rects_value as Array
	if rects.is_empty():
		sprite.visible = false
		return

	frames.add_animation(&"fly")
	frames.set_animation_loop(&"fly", true)
	frames.set_animation_speed(&"fly", 10.0)

	for rect_value in rects:
		var rect: Rect2i = rect_value as Rect2i
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(rect)
		frames.add_frame(&"fly", atlas)

	sprite.sprite_frames = frames
	sprite.visible = true
	sprite.play(&"fly")

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
	return get_world_2d().direct_space_state.intersect_ray(
		query
	)

func _cast_against_projectiles(
	from_position: Vector2,
	to_position: Vector2
) -> Dictionary:
	var nearest: Node2D = null
	var nearest_position: Vector2 = Vector2.ZERO
	var nearest_distance: float = INF

	for node in get_tree().get_nodes_in_group(
		"combat_projectile"
	):
		var other := node as Node2D
		if other == null or other == self:
			continue

		if other.has_method("is_active_projectile"):
			if not bool(
				other.call("is_active_projectile")
			):
				continue

		if _is_friendly_projectile(other):
			continue

		var other_radius: float = 4.0
		if other.has_method("get_projectile_clash_radius"):
			other_radius = maxf(
				float(
					other.call(
						"get_projectile_clash_radius"
					)
				),
				0.0
			)

		var closest: Vector2 = _closest_point_on_segment(
			other.global_position,
			from_position,
			to_position
		)
		var combined: float = _clash_radius + other_radius

		if (
			closest.distance_to(other.global_position)
			> combined
		):
			continue

		var distance: float = (
			from_position.distance_to(closest)
		)
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

	var p: Vector2 = projectile_hit.get(
		"position",
		start_position
	) as Vector2
	var s: Vector2 = solid_hit.get(
		"position",
		start_position
	) as Vector2

	return (
		start_position.distance_squared_to(p)
		<= start_position.distance_squared_to(s)
	)

func _closest_point_on_segment(
	point: Vector2,
	start: Vector2,
	end: Vector2
) -> Vector2:
	var segment: Vector2 = end - start
	var length_squared: float = segment.length_squared()
	if length_squared <= 0.000001:
		return start

	var ratio: float = clampf(
		(point - start).dot(segment) / length_squared,
		0.0,
		1.0
	)
	return start + segment * ratio

func _is_friendly_projectile(other: Node) -> bool:
	if (
		_source_actor == null
		or other == null
		or not other.has_method("get_source_actor")
	):
		return false

	var source_value: Variant = other.call(
		"get_source_actor"
	)
	var other_source := source_value as Node

	return (
		other_source != null
		and other_source == _source_actor
	)

func _target_collision_mask() -> int:
	if (
		_source_actor != null
		and _source_actor.is_in_group("enemy")
	):
		return 2

	return 4

func get_source_actor() -> Node:
	return _source_actor

func get_travel_direction() -> Vector2:
	return _direction

func get_projectile_speed() -> float:
	return _speed

func get_projectile_clash_radius() -> float:
	return _clash_radius

func is_active_projectile() -> bool:
	return not _impacted

func resolve_projectile_clash(
	other_projectile: Node2D,
	clash_position: Vector2
) -> void:
	if _impacted or other_projectile == null:
		return

	_start_impact_at(clash_position)

	if other_projectile.has_method(
		"receive_projectile_clash"
	):
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

func _start_impact_at(position_value: Vector2) -> void:
	global_position = position_value
	_start_impact()

func _start_impact() -> void:
	if _impacted:
		return

	_impacted = true
	_impact_time_left = impact_duration
	collision_shape.set_deferred("disabled", true)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)

	sprite.position = Vector2.ZERO
	sprite.stop()
	sprite.modulate.a = 0.75
	sprite.scale *= 1.18
