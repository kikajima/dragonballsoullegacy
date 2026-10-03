class_name SpecialAttackBeamContactFix
extends SpecialAttackBeam

# Kamehameha is non-piercing. The base beam already finds the nearest
# receiver, but HU2's 32 px visual grid can round the final tile past a
# character that is not aligned to that grid. This subclass keeps physics
# and visuals separate:
#
# - the collision rectangle enters the hurtbox by only a few pixels so the
#   damage tick remains reliable;
# - KameHit is rendered at the actual front face of the hurtbox;
# - no KameMid segment is ever placed beyond that impact point.

const CONTACT_TILE_SIZE: float = 32.0
const CONTACT_FIRST_CENTER: float = 16.0
const CONTACT_MIN_SEGMENT_GAP: float = 8.0
const CONTACT_DMI_PATH := "res://assets/sprites/effects/hu2/Effects.dmi"
const CONTACT_START_STATE: StringName = &"KameStart"
const CONTACT_MID_STATE: StringName = &"KameMid"
const CONTACT_HIT_STATE: StringName = &"KameHit"
const CONTACT_BATTLE_STATE: StringName = &"KameBattle"

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

	var nearest_collision: float = max_length
	var nearest_visual: float = 0.0

	for hit in hits:
		var collider: Area2D = hit.get("collider") as Area2D
		if (
			collider == null
			or not collider.has_method("receive_hit")
			or not _is_live_damage_receiver(collider)
		):
			continue

		var front_distance: float = _receiver_front_distance(collider)
		if front_distance <= 0.0 or front_distance > max_length:
			continue

		# Physics must overlap the hurtbox slightly or Area2D may report no
		# overlap on the exact boundary. Keep that overlap small and invisible.
		var overlap_depth: float = clampf(
			_beam_width * 0.35,
			2.0,
			4.0
		)
		var collision_length: float = clampf(
			front_distance + overlap_depth,
			1.0,
			max_length
		)

		if collision_length < nearest_collision:
			nearest_collision = collision_length
			nearest_visual = front_distance

	if nearest_visual > 0.0:
		_impact_visual_length = nearest_visual

	return nearest_collision

func _receiver_front_distance(receiver: Area2D) -> float:
	var fallback: float = (
		receiver.global_position - global_position
	).dot(_direction)
	var nearest_front: float = fallback
	var found_shape: bool = false

	for child in receiver.get_children():
		var shape_node: CollisionShape2D = child as CollisionShape2D
		if (
			shape_node == null
			or shape_node.disabled
			or shape_node.shape == null
		):
			continue

		found_shape = true
		var shape_center: float = (
			shape_node.global_position - global_position
		).dot(_direction)
		var extent: float = _shape_forward_extent(shape_node)
		nearest_front = minf(
			nearest_front,
			shape_center - extent
		)

	if not found_shape:
		# Conservative fallback for custom hurtboxes.
		nearest_front = fallback - maxf(_beam_width * 0.5, 4.0)

	return maxf(nearest_front, 1.0)

func _shape_forward_extent(shape_node: CollisionShape2D) -> float:
	var shape: Shape2D = shape_node.shape
	var local_direction: Vector2 = _direction.rotated(
		-shape_node.global_rotation
	)
	var scale_abs: Vector2 = Vector2(
		absf(shape_node.global_scale.x),
		absf(shape_node.global_scale.y)
	)

	var rectangle: RectangleShape2D = shape as RectangleShape2D
	if rectangle != null:
		return (
			absf(local_direction.x)
				* rectangle.size.x * 0.5 * scale_abs.x
			+ absf(local_direction.y)
				* rectangle.size.y * 0.5 * scale_abs.y
		)

	var circle: CircleShape2D = shape as CircleShape2D
	if circle != null:
		return circle.radius * maxf(scale_abs.x, scale_abs.y)

	var capsule: CapsuleShape2D = shape as CapsuleShape2D
	if capsule != null:
		var radius: float = capsule.radius
		var half_line: float = maxf(
			capsule.height * 0.5 - radius,
			0.0
		)
		return (
			radius * maxf(scale_abs.x, scale_abs.y)
			+ absf(local_direction.y) * half_line * scale_abs.y
		)

	return maxf(_beam_width * 0.5, 4.0)

func _refresh_kamehameha_visual(length: float) -> void:
	# For free-flight and wall impacts, preserve the original HU2 grid logic.
	if not _beam_impacting or _impact_visual_length <= 0.0:
		super._refresh_kamehameha_visual(length)
		return

	var impact_position: float = maxf(
		_impact_visual_length,
		1.0
	)
	var segment_positions: Array[float] = []
	var cursor: float = CONTACT_FIRST_CENTER

	# Add complete Start/Mid tiles only while their centers remain in front of
	# the impact. The final KameHit is then placed at the exact hurtbox face.
	while cursor + CONTACT_MIN_SEGMENT_GAP < impact_position:
		segment_positions.append(cursor)
		cursor += CONTACT_TILE_SIZE

	segment_positions.append(impact_position)
	_ensure_kame_segment_count(segment_positions.size())

	for index in range(segment_positions.size()):
		var segment: AnimatedSprite2D = _kame_segments[index]
		var is_last: bool = index == segment_positions.size() - 1
		var state: StringName = CONTACT_MID_STATE

		if is_last and _beam_battle_visual:
			state = CONTACT_BATTLE_STATE
		elif is_last:
			state = CONTACT_HIT_STATE
		elif index == 0:
			state = CONTACT_START_STATE

		segment.position = Vector2(
			segment_positions[index],
			0.0
		)
		segment.rotation = -rotation
		segment.visible = true
		segment.call(
			"configure",
			CONTACT_DMI_PATH,
			state,
			_facing_from_direction(_direction),
			true,
			true
		)

	_synchronize_kame_segments()
