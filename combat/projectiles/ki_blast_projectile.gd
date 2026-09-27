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

func _ready() -> void:
	_lifetime_left = lifetime
	_build_sprite_frames()
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func setup(direction: Vector2, damage_override: int = -1) -> void:
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

	global_position += _direction * speed * delta

	_lifetime_left -= delta
	if _lifetime_left <= 0.0:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if _impacted or area == null or not area.has_method("receive_hit"):
		return

	area.call("receive_hit", damage, global_position)
	_start_impact()

func _on_body_entered(body: Node2D) -> void:
	if _impacted or body == null or not body is CollisionObject2D:
		return

	var collision_body := body as CollisionObject2D
	if collision_body.collision_layer & 1 != 0:
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
