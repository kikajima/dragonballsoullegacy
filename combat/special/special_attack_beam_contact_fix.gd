class_name SpecialAttackBeamContactFix
extends SpecialAttackBeam

# Kamehameha is non-piercing. The base beam finds the nearest receiver, but
# HU2's visual pieces are full 32 px tiles. Centering KameHit directly on the
# front face of a hurtbox makes half of that tile appear behind the victim.
# Keep physics and art separate:
#
# - physics overlaps the hurtbox by only a few pixels so damage is reliable;
# - the *front edge* of KameHit is aligned to the front face of the hurtbox;
# - no KameMid is allowed to continue beyond the KameHit tile.

const CONTACT_TILE_SIZE: float = 32.0
const CONTACT_FIRST_CENTER: float = 16.0
const CONTACT_MIN_SEGMENT_GAP: float = 4.0
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
	var nearest_visual_front: float = 0.0

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

		# Area2D needs a tiny overlap to keep reporting the victim on each
		# damage pulse. This part is physics-only and is never rendered.
		var overlap_depth: float = clampf(
			_beam_width * 0.25,
			1.5,
			3.0
		)
		var collision_length: float = clampf(
			front_distance + overlap_depth,
			1.0,
			max_length
		)

		if collision_length < nearest_collision:
			nearest_collision = collision_length

			# Store the contact edge; rendering fits the terminal tile into
			# the available distance, including point-blank contact.
			nearest_visual_front = front_distance

	if nearest_visual_front > 0.0:
		_impact_visual_length = nearest_visual_front

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
		nearest_front = fallback - maxf(_beam_width * 0.5, 4.0)

	return maxf(nearest_front, 1.0)

func _receiver_hit_distance(receiver: Area2D) -> float:
	return _receiver_front_distance(receiver)

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
	# Free flight and wall collisions still use the base HU2 tile logic.
	if not _beam_impacting or _impact_visual_length <= 0.0:
		super._refresh_kamehameha_visual(length)
		return

	# At point-blank range a full tile would extend through the victim.
	var hit_length: float = minf(_impact_visual_length, CONTACT_TILE_SIZE)
	var hit_center: float = _impact_visual_length - hit_length * 0.5
	var segment_positions: Array[float] = []

	# Build complete tiles from the caster forward, but reserve the final
	# 32 px interval exclusively for KameHit. A final Mid may be nudged so
	# it joins the hit cleanly, but no Mid can overlap the victim side.
	var cursor: float = CONTACT_FIRST_CENTER
	var pre_hit_center: float = hit_center - CONTACT_TILE_SIZE

	while cursor <= pre_hit_center:
		segment_positions.append(cursor)
		cursor += CONTACT_TILE_SIZE

	if (
		pre_hit_center > CONTACT_FIRST_CENTER
		and not segment_positions.is_empty()
	):
		var last_mid: float = segment_positions[segment_positions.size() - 1]
		if pre_hit_center - last_mid >= CONTACT_MIN_SEGMENT_GAP:
			segment_positions.append(pre_hit_center)

	segment_positions.append(hit_center)
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
		segment.scale = Vector2.ONE
		if is_last:
			if absf(_direction.x) > absf(_direction.y):
				segment.scale.x = hit_length / CONTACT_TILE_SIZE
			else:
				segment.scale.y = hit_length / CONTACT_TILE_SIZE
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
