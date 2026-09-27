class_name KiBlastProjectile
extends Area2D

@export var speed: float = 300.0
@export var damage: int = 12
@export var lifetime: float = 1.6
@export var projectile_fps: float = 12.0
@export var impact_duration: float = 0.12

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

	var solid_hit: Dictionary = _cast_against_solids(
		start_position,
		end_position
	)
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

func get_source_actor() -> Node:
	return _source_actor

func get_travel_direction() -> Vector2:
	return _direction

func get_projectile_speed() -> float:
	return speed

func is_active_projectile() -> bool:
	return not _impacted

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
