class_name SpecialAttackBeam
extends Node2D

const EFFECT_SHEET_PATH := (
	"res://assets/sprites/effects/legacy/special_attack_sfx.png"
)

@onready var beam_line: Line2D = $BeamLine
@onready var hit_area: Area2D = $HitArea
@onready var collision_shape: CollisionShape2D = $HitArea/CollisionShape2D

var _source_actor: Node
var _damage: int = 20
var _stun_duration: float = 0.0
var _time_left: float = 0.0
var _hit_targets: Dictionary = {}

func _ready() -> void:
	hit_area.area_entered.connect(_on_area_entered)

func setup(
	data: SpecialAttackData,
	direction: Vector2,
	source_actor: Node
) -> void:
	_source_actor = source_actor
	_damage = data.damage
	_stun_duration = data.stun_duration
	_time_left = data.beam_duration

	var safe_direction: Vector2 = (
		Vector2.RIGHT
		if direction.is_zero_approx()
		else direction.normalized()
	)
	rotation = safe_direction.angle()

	var length: float = _resolve_beam_length(
		data.beam_range
	)
	var width: float = maxf(data.beam_width, 2.0)

	beam_line.width = width
	beam_line.points = PackedVector2Array([
		Vector2.ZERO,
		Vector2(length, 0.0),
	])
	_apply_beam_texture(data.effect_key)

	var rect := collision_shape.shape as RectangleShape2D
	if rect != null:
		rect.size = Vector2(length, width)

	collision_shape.position = Vector2(length * 0.5, 0.0)

	if _source_actor != null and _source_actor.is_in_group("enemy"):
		hit_area.collision_mask = 2
	else:
		hit_area.collision_mask = 4

func _physics_process(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area == null or not area.has_method("receive_hit"):
		return

	var id: int = area.get_instance_id()
	if _hit_targets.has(id):
		return
	_hit_targets[id] = true

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
	var query := PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + Vector2.RIGHT.rotated(rotation) * max_range
	)
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var result: Dictionary = (
		get_world_2d().direct_space_state.intersect_ray(query)
	)

	if result.is_empty():
		return max_range

	var hit_position: Vector2 = result.get(
		"position",
		global_position
	) as Vector2

	return global_position.distance_to(hit_position)

func _apply_beam_texture(effect_key: StringName) -> void:
	if not ResourceLoader.exists(EFFECT_SHEET_PATH):
		return

	var sheet := load(EFFECT_SHEET_PATH) as Texture2D
	if sheet == null:
		return

	var rect := Rect2(176, 33, 32, 6)
	if effect_key == &"special_beam":
		rect = Rect2(176, 169, 64, 6)

	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = rect

	beam_line.texture = atlas
	beam_line.texture_mode = Line2D.LINE_TEXTURE_TILE
