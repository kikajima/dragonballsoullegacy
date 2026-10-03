class_name SpecialAttackBeam
extends Node2D

const EFFECT_SHEET_PATH := (
	"res://assets/sprites/effects/legacy/special_attack_sfx.png"
)
const HU2_EFFECT_DMI_PATH := (
	"res://assets/sprites/effects/hu2/Effects.dmi"
)
const DMI_EFFECT_SCRIPT = preload(
	"res://core/assets/dmi_effect_sprite_2d.gd"
)
const HU2_BEAM_TILE_SIZE := 32.0
const KAME_START_STATE: StringName = &"KameStart"
const KAME_MID_STATE: StringName = &"KameMid"
const KAME_HEAD_STATE: StringName = &"KameHead"
const KAME_HIT_STATE: StringName = &"KameHit"
const KAME_BATTLE_STATE: StringName = &"KameBattle"

@onready var beam_line: Line2D = $BeamLine
@onready var beam_core: Line2D = $BeamCore
@onready var dmi_visuals: Node2D = $DmiVisuals
@onready var hit_area: Area2D = $HitArea
@onready var collision_shape: CollisionShape2D = (
	$HitArea/CollisionShape2D
)

var _source_actor: Node
var _damage: int = 8
var _stun_duration: float = 0.0
var _max_range: float = 190.0
var _beam_width: float = 7.0
var _tick_interval: float = 0.16
var _tick_left: float = 0.0
var _pierces_targets: bool = false
var _direction: Vector2 = Vector2.RIGHT
var _spawn_distance: float = 20.0
var _stopping: bool = false
var _effect_key: StringName = &""
var _resolved_length: float = 0.0
var _beam_impacting: bool = false
var _impact_visual_length: float = 0.0
var _beam_battle_visual: bool = false
var _kame_segments: Array[AnimatedSprite2D] = []

func setup(
	data: SpecialAttackData,
	direction: Vector2,
	source_actor: Node,
	spawn_distance: float,
	charge_ratio: float = 0.0
) -> void:
	_source_actor = source_actor

	var safe_charge: float = clampf(charge_ratio, 0.0, 1.0)
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
	var visual_scale: float = lerpf(
		1.0,
		maxf(data.charge_scale_multiplier, 1.0),
		safe_charge
	)

	_damage = maxi(
		roundi(float(data.damage) * damage_scale),
		0
	)
	_stun_duration = data.stun_duration
	_max_range = maxf(data.beam_range * range_scale, 1.0)
	_beam_width = maxf(data.beam_width * visual_scale, 2.0)
	_tick_interval = maxf(
		data.beam_tick_interval,
		0.05
	)
	_pierces_targets = data.beam_pierces_targets
	_direction = (
		Vector2.RIGHT
		if direction.is_zero_approx()
		else direction.normalized()
	)
	_spawn_distance = spawn_distance

	if (
		_source_actor != null
		and _source_actor.is_in_group("enemy")
	):
		hit_area.collision_mask = 2
	else:
		hit_area.collision_mask = 4

	_effect_key = data.effect_key
	_configure_beam_visual(_effect_key)

	if _source_actor is Node2D:
		follow_caster(
			_source_actor as Node2D,
			_direction,
			_spawn_distance
		)
	else:
		_refresh_geometry()

func _physics_process(delta: float) -> void:
	if _stopping:
		return

	_tick_left -= delta
	if _tick_left > 0.0:
		return

	_tick_left += _tick_interval
	_refresh_geometry()
	_apply_damage_tick()

func follow_caster(
	caster: Node2D,
	direction: Vector2,
	spawn_distance: float
) -> void:
	if caster == null:
		return

	_direction = (
		Vector2.RIGHT
		if direction.is_zero_approx()
		else direction.normalized()
	)
	_spawn_distance = spawn_distance
	global_position = (
		caster.global_position
		+ _direction * _spawn_distance
	)
	rotation = _direction.angle()
	_refresh_geometry()

func stop_beam() -> void:
	if _stopping:
		return

	_stopping = true
	hit_area.set_deferred("monitoring", false)
	hit_area.set_deferred("collision_mask", 0)

	var tween := create_tween()
	tween.tween_property(
		self,
		"modulate:a",
		0.0,
		0.08
	)
	tween.tween_callback(queue_free)

func _refresh_geometry() -> void:
	var length: float = _resolve_beam_length(
		_max_range
	)
	_resolved_length = length

	if _effect_key != &"blue_beam":
		beam_line.width = _beam_width
		beam_line.points = PackedVector2Array([
			Vector2.ZERO,
			Vector2(length, 0.0),
		])

		beam_core.width = maxf(_beam_width * 0.42, 2.0)
		beam_core.points = PackedVector2Array([
			Vector2.ZERO,
			Vector2(length, 0.0),
		])
	else:
		_refresh_kamehameha_visual(length)

	var source_rect := (
		collision_shape.shape as RectangleShape2D
	)
	if source_rect != null:
		var rect := (
			source_rect.duplicate() as RectangleShape2D
		)
		if rect != null:
			rect.size = Vector2(
				length,
				_beam_width
			)
			collision_shape.shape = rect

	collision_shape.position = Vector2(
		length * 0.5,
		0.0
	)

func _apply_damage_tick() -> void:
	var candidates: Array[Area2D] = []

	for area in hit_area.get_overlapping_areas():
		if (
			area == null
			or not area.has_method("receive_hit")
			or not _is_live_damage_receiver(area)
		):
			continue
		candidates.append(area)

	if candidates.is_empty():
		return

	if _pierces_targets:
		for area in candidates:
			_damage_area(area)
		return

	var nearest: Area2D = null
	var nearest_x: float = INF

	for area in candidates:
		var local_position: Vector2 = to_local(
			area.global_position
		)
		if local_position.x < 0.0:
			continue

		if local_position.x < nearest_x:
			nearest_x = local_position.x
			nearest = area

	if nearest != null:
		_damage_area(nearest)

func _damage_area(area: Area2D) -> void:
	# HU2 beams repeatedly put the victim in HitStun but do not throw the
	# target backward on every damage pulse. Suppressing knockback keeps the
	# victim anchored and prevents the visual beam endpoint from jumping.
	var suppressed_knockback: KnockbackComponent = (
		_suppress_receiver_knockback(area)
	)

	var applied: int = int(
		area.call(
			"receive_hit",
			_damage,
			global_position
		)
	)

	if suppressed_knockback != null:
		suppressed_knockback.clear_start_suppression()

	if applied <= 0:
		return

	_apply_stun(area)

	if (
		_source_actor != null
		and is_instance_valid(_source_actor)
		and _source_actor.has_method("register_combat_hit")
	):
		_source_actor.call(
			"register_combat_hit",
			area,
			applied
	)

func _suppress_receiver_knockback(
	receiver: Area2D
) -> KnockbackComponent:
	var actor: Node = receiver.get_parent()
	if actor == null:
		return null

	var knockback: KnockbackComponent = actor.get_node_or_null(
		"Components/KnockbackComponent"
	) as KnockbackComponent

	if knockback != null:
		knockback.suppress_next_start()

	return knockback

func _apply_stun(receiver: Area2D) -> void:
	if _stun_duration <= 0.0:
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
			_stun_duration,
			1.0
		)

func _resolve_beam_length(max_range: float) -> float:
	_beam_impacting = false
	_impact_visual_length = 0.0

	var environment_length: float = _resolve_environment_length(max_range)
	if environment_length < max_range - 0.5:
		_beam_impacting = true

	if _pierces_targets:
		return environment_length

	var target_length: float = _resolve_nearest_target_length(
		environment_length
	)
	if target_length < environment_length - 0.5:
		_beam_impacting = true

	return minf(
		environment_length,
		target_length
	)

func _resolve_environment_length(max_range: float) -> float:
	var end_position: Vector2 = (
		global_position
		+ _direction * max_range
	)
	var query := PhysicsRayQueryParameters2D.create(
		global_position,
		end_position
	)
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var result: Dictionary = (
		get_world_2d()
		.direct_space_state
		.intersect_ray(query)
	)

	if result.is_empty():
		return max_range

	var hit_position: Vector2 = result.get(
		"position",
		global_position
	) as Vector2

	return global_position.distance_to(hit_position)

func _resolve_nearest_target_length(max_length: float) -> float:
	if max_length <= 0.0:
		return 0.0

	var probe := RectangleShape2D.new()
	probe.size = Vector2(
		max_length,
		maxf(_beam_width, 2.0)
	)

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = probe
	query.transform = Transform2D(
		_direction.angle(),
		global_position + _direction * max_length * 0.5
	)
	query.collision_mask = hit_area.collision_mask
	query.collide_with_bodies = false
	query.collide_with_areas = true

	var hits: Array[Dictionary] = (
		get_world_2d()
		.direct_space_state
		.intersect_shape(query, 32)
	)

	var nearest: float = max_length

	for hit in hits:
		var collider := hit.get("collider") as Area2D
		if (
			collider == null
			or not collider.has_method("receive_hit")
			or not _is_live_damage_receiver(collider)
		):
			continue

		var forward_distance: float = (
			collider.global_position - global_position
		).dot(_direction)

		if forward_distance <= 0.0:
			continue

		# Keep a tiny overlap with the hurtbox so the shortened collision
		# rectangle still registers the target at the visual endpoint.
		var front_edge_offset: float = maxf(
			_beam_width * 0.45,
			2.0
		)
		var collision_length := clampf(
			forward_distance - front_edge_offset,
			1.0,
			max_length
		)
		if collision_length < nearest:
			nearest = collision_length
			# HU2 changes the beam object occupying the victim's tile to
			# KameHit. Keep the collision at the target's front edge, but
			# render the impact animation over the target center.
			_impact_visual_length = _snap_kame_tile_center(
				forward_distance
			)

	return nearest

func _is_live_damage_receiver(receiver: Area2D) -> bool:
	if receiver == null:
		return false

	if receiver.has_method("can_receive_hit"):
		return bool(receiver.call("can_receive_hit"))

	var actor: Node = receiver.get_parent()
	if actor == null:
		return true

	var health := actor.get_node_or_null(
		"Components/HealthComponent"
	) as HealthComponent
	if health == null:
		return true

	return not health.is_dead()

func get_source_actor() -> Node:
	return _source_actor

func affects_global_point(
	point: Vector2,
	padding: float = 0.0
) -> bool:
	if _stopping or _resolved_length <= 0.0:
		return false

	var local_point: Vector2 = to_local(point)
	var safe_padding: float = maxf(padding, 0.0)

	return (
		local_point.x >= -safe_padding
		and local_point.x <= _resolved_length + safe_padding
		and absf(local_point.y)
			<= _beam_width * 0.5 + safe_padding
	)

func set_beam_battle_visual(active: bool) -> void:
	_beam_battle_visual = active
	if _effect_key == &"blue_beam":
		_refresh_kamehameha_visual(_resolved_length)

func _configure_beam_visual(
	effect_key: StringName
) -> void:
	if effect_key == &"blue_beam":
		beam_line.visible = false
		beam_core.visible = false
		dmi_visuals.visible = true
		return

	_clear_kamehameha_visual()
	dmi_visuals.visible = false
	beam_line.visible = true
	beam_core.visible = false

	if not ResourceLoader.exists(EFFECT_SHEET_PATH):
		beam_line.texture = null
		beam_line.default_color = Color.WHITE
		return

	var sheet := load(EFFECT_SHEET_PATH) as Texture2D
	if sheet == null:
		beam_line.texture = null
		beam_line.default_color = Color.WHITE
		return

	var rect := Rect2(176, 33, 32, 6)
	if effect_key == &"special_beam":
		rect = Rect2(176, 169, 64, 6)

	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = rect

	beam_line.texture = atlas
	beam_line.texture_mode = (
		Line2D.LINE_TEXTURE_TILE
	)

func _refresh_kamehameha_visual(length: float) -> void:
	if length <= 0.0:
		_clear_kamehameha_visual()
		return

	# HU2 does not place the beam endpoint at arbitrary pixel coordinates.
	# Every beam object occupies one 32x32 BYOND tile:
	#
	#   Start -> Mid -> Mid -> ... -> Head/Hit
	#
	# Keeping every center on this exact grid is critical. If KameHit is
	# allowed to sit between tiles it overlaps the preceding KameMid and the
	# two animations visually mix.
	var first_center: float = HU2_BEAM_TILE_SIZE * 0.5
	var last_center: float = _snap_kame_tile_center(length)

	if _beam_impacting and _impact_visual_length > 0.0:
		last_center = _impact_visual_length

	last_center = maxf(last_center, first_center)

	var last_tile_index: int = maxi(
		roundi(
			(last_center - first_center)
			/ HU2_BEAM_TILE_SIZE
		),
		0
	)
	var segment_count: int = last_tile_index + 1

	_ensure_kame_segment_count(segment_count)

	for index in range(segment_count):
		var segment: AnimatedSprite2D = _kame_segments[index]
		var is_first: bool = index == 0
		var is_last: bool = index == segment_count - 1
		var state: StringName = KAME_MID_STATE

		if is_last and _beam_battle_visual:
			state = KAME_BATTLE_STATE
		elif is_last and _beam_impacting:
			state = KAME_HIT_STATE
		elif is_last:
			state = KAME_HEAD_STATE
		elif is_first:
			state = KAME_START_STATE

		segment.position = Vector2(
			first_center
				+ HU2_BEAM_TILE_SIZE * float(index),
			0.0
		)
		# The parent rotates tile positions along the beam. The DMI state
		# itself already contains the proper NORTH/SOUTH/EAST/WEST art.
		segment.rotation = -rotation
		segment.visible = true
		segment.call(
			"configure",
			HU2_EFFECT_DMI_PATH,
			state,
			_facing_from_direction(_direction),
			true,
			true
		)

	_synchronize_kame_segments()

func _snap_kame_tile_center(distance: float) -> float:
	var first_center: float = HU2_BEAM_TILE_SIZE * 0.5
	if distance <= first_center:
		return first_center

	var tile_index: int = maxi(
		roundi(
			(distance - first_center)
			/ HU2_BEAM_TILE_SIZE
		),
		0
	)

	return (
		first_center
		+ HU2_BEAM_TILE_SIZE * float(tile_index)
	)

func _synchronize_kame_segments() -> void:
	if _kame_segments.is_empty():
		return

	var reference: AnimatedSprite2D = _kame_segments[0]
	if (
		reference == null
		or reference.sprite_frames == null
		or not reference.sprite_frames.has_animation(&"effect")
	):
		return

	var shared_frame: int = reference.frame
	var shared_progress: float = reference.frame_progress

	for segment in _kame_segments:
		if (
			segment == null
			or segment == reference
			or segment.sprite_frames == null
			or not segment.sprite_frames.has_animation(&"effect")
		):
			continue

		var count: int = segment.sprite_frames.get_frame_count(&"effect")
		if count <= 0:
			continue

		segment.set_frame_and_progress(
			clampi(shared_frame, 0, count - 1),
			shared_progress
		)

func _facing_from_direction(direction: Vector2) -> String:
	if absf(direction.x) > absf(direction.y):
		return "right" if direction.x >= 0.0 else "left"
	return "down" if direction.y >= 0.0 else "up"

func _ensure_kame_segment_count(count: int) -> void:
	while _kame_segments.size() < count:
		var segment: AnimatedSprite2D = (
			DMI_EFFECT_SCRIPT.new() as AnimatedSprite2D
		)
		if segment == null:
			return

		segment.centered = true
		segment.z_index = 1
		dmi_visuals.add_child(segment)
		_kame_segments.append(segment)

	while _kame_segments.size() > count:
		var segment: AnimatedSprite2D = (
			_kame_segments.pop_back() as AnimatedSprite2D
		)
		if is_instance_valid(segment):
			segment.queue_free()

func _clear_kamehameha_visual() -> void:
	for segment in _kame_segments:
		if is_instance_valid(segment):
			segment.queue_free()

	_kame_segments.clear()
