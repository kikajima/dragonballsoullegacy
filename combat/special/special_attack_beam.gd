class_name SpecialAttackBeam
extends Node2D

const EFFECT_SHEET_PATH := (
	"res://assets/sprites/effects/legacy/special_attack_sfx.png"
)

@onready var beam_line: Line2D = $BeamLine
@onready var beam_core: Line2D = $BeamCore
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

func setup(
	data: SpecialAttackData,
	direction: Vector2,
	source_actor: Node,
	spawn_distance: float
) -> void:
	_source_actor = source_actor
	_damage = maxi(data.damage, 0)
	_stun_duration = data.stun_duration
	_max_range = maxf(data.beam_range, 1.0)
	_beam_width = maxf(data.beam_width, 2.0)
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

	queue_redraw()

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
	var applied: int = int(
		area.call(
			"receive_hit",
			_damage,
			global_position
		)
	)
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

func _configure_beam_visual(
	effect_key: StringName
) -> void:
	# Kamehameha uses a continuous two-layer beam instead of tiling a
	# non-seamless atlas strip. The previous tiled strip produced the thin,
	# broken yellow/green line visible in-game.
	if effect_key == &"blue_beam":
		beam_line.texture = null
		beam_line.default_color = Color(0.30, 0.78, 1.0, 1.0)
		beam_core.texture = null
		beam_core.default_color = Color(0.90, 0.98, 1.0, 1.0)
		beam_core.visible = true
		return

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

func _draw() -> void:
	if _effect_key != &"blue_beam" or _resolved_length <= 0.0:
		return

	# LoG2-style bright muzzle and terminal cap. These also visually bridge
	# the beam into the caster's hands instead of leaving a hard gap.
	var outer_radius: float = maxf(_beam_width * 0.72, 3.0)
	var inner_radius: float = maxf(_beam_width * 0.38, 1.5)
	var end_point := Vector2(_resolved_length, 0.0)

	draw_circle(
		Vector2.ZERO,
		outer_radius,
		Color(0.30, 0.78, 1.0, 1.0)
	)
	draw_circle(
		Vector2.ZERO,
		inner_radius,
		Color(0.94, 1.0, 1.0, 1.0)
	)
	draw_circle(
		end_point,
		outer_radius * 0.82,
		Color(0.30, 0.78, 1.0, 1.0)
	)
	draw_circle(
		end_point,
		inner_radius * 0.78,
		Color(0.94, 1.0, 1.0, 1.0)
	)
