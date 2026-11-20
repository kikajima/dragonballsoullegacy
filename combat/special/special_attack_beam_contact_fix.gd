class_name SpecialAttackBeamContactFix
extends SpecialAttackBeam

# Fit visible DMI pixels to the physical contact boundary. KameHit occupies
# only part of its transparent 32px cell, so full-cell bounds leave a gap.

const CONTACT_TILE_SIZE: float = 32.0
const CONTACT_DMI_PATH := "res://assets/sprites/effects/hu2/Effects.dmi"

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
			_contact_receiver = collider
			_had_target_contact = true

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

var _visual_bounds: Dictionary = {}

func _state_bounds(state: StringName, facing: StringName) -> Rect2:
	var key := String(state) + ":" + String(facing)
	if _visual_bounds.has(key):
		return _visual_bounds[key]
	var sheet := DmiSpriteSheet.load_file(CONTACT_DMI_PATH)
	var bounds := Rect2i()
	for frame in range(sheet.get_frame_count(state)):
		var used := sheet.get_frame_texture(state, facing, frame).get_image().get_used_rect()
		bounds = used if frame == 0 else bounds.merge(used)
	var result := Rect2(bounds)
	_visual_bounds[key] = result
	return result

func _refresh_kamehameha_visual(length: float) -> void:
	if length <= 0.0:
		_clear_kamehameha_visual()
		return
	var end: float = _impact_visual_length if _impact_visual_length > 0.0 else length
	var facing := StringName(_facing_from_direction(_direction))
	var cardinal := Vector2.RIGHT
	match facing:
		&"left": cardinal = Vector2.LEFT
		&"up": cardinal = Vector2.UP
		&"down": cardinal = Vector2.DOWN
	var terminal: StringName = KAME_HEAD_STATE
	if _beam_battle_visual:
		terminal = KAME_BATTLE_STATE
	elif _beam_impacting:
		terminal = KAME_HIT_STATE
	var bounds := _state_bounds(terminal, facing)
	var terminal_span: float = bounds.size.x if cardinal.x != 0 else bounds.size.y
	var terminal_length: float = minf(end, terminal_span)
	var body_end: float = end - terminal_length
	var pieces: Array[Vector2] = []
	var cursor: float = 0.0
	while cursor < body_end - 0.001:
		var next: float = minf(cursor + CONTACT_TILE_SIZE, body_end)
		pieces.append(Vector2(cursor, next))
		cursor = next
	pieces.append(Vector2(body_end, end))
	_ensure_kame_segment_count(pieces.size())
	for index in range(pieces.size()):
		var state: StringName = KAME_MID_STATE
		if index == pieces.size() - 1:
			state = terminal
		elif index == 0:
			state = KAME_START_STATE
		var segment := _kame_segments[index]
		bounds = _state_bounds(state, facing)
		var axis_start: float
		var span: float
		if cardinal.x != 0:
			span = bounds.size.x
			axis_start = bounds.position.x - 16.0 if cardinal.x > 0 else 16.0 - bounds.end.x
		else:
			span = bounds.size.y
			axis_start = bounds.position.y - 16.0 if cardinal.y > 0 else 16.0 - bounds.end.y
		var axis_scale: float = (pieces[index].y - pieces[index].x) / maxf(span, 1.0)
		segment.position = Vector2(pieces[index].x - axis_start * axis_scale, 0)
		segment.scale = Vector2(axis_scale, 1) if cardinal.x != 0 else Vector2(1, axis_scale)
		segment.rotation = -cardinal.angle()
		segment.visible = true
		segment.call("configure", CONTACT_DMI_PATH, state, String(facing), true, true)
	_synchronize_kame_segments()
