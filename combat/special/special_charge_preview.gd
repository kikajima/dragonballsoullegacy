class_name SpecialChargePreview
extends Node2D

const EFFECT_SHEET_PATH := (
	"res://assets/sprites/effects/legacy/special_attack_sfx.png"
)

const PREVIEW_RECTS := {
	&"big_bang": Rect2i(82, 196, 33, 24),
	&"spirit_bomb": Rect2i(80, 312, 32, 32),
}

@onready var sprite: Sprite2D = $Sprite2D

var _caster: Node2D
var _direction: Vector2 = Vector2.DOWN
var _effect_key: StringName = &""
var _base_scale: float = 0.35
var _max_scale: float = 1.0
var _ratio: float = 0.0
var _spawn_distance: float = 16.0

func setup(
	effect_key: StringName,
	caster: Node2D,
	direction: Vector2,
	spawn_distance: float,
	max_scale: float
) -> void:
	_effect_key = effect_key
	_caster = caster
	_direction = (
		Vector2.DOWN
		if direction.is_zero_approx()
		else direction.normalized()
	)
	_spawn_distance = spawn_distance
	_max_scale = maxf(max_scale, 1.0)
	_build_visual()
	_update_transform()

func _process(_delta: float) -> void:
	if not is_instance_valid(_caster):
		queue_free()
		return

	_update_transform()

func set_charge_ratio(ratio: float) -> void:
	_ratio = clampf(ratio, 0.0, 1.0)
	var visual_scale: float = lerpf(
		_base_scale,
		_max_scale,
		_ratio
	)
	sprite.scale = Vector2.ONE * visual_scale

func _update_transform() -> void:
	if _caster == null:
		return

	if _effect_key == &"spirit_bomb":
		global_position = (
			_caster.global_position
			+ Vector2(0.0, -22.0)
		)
	else:
		global_position = (
			_caster.global_position
			+ _direction * _spawn_distance
			+ Vector2(0.0, -4.0)
		)

func _build_visual() -> void:
	if not ResourceLoader.exists(EFFECT_SHEET_PATH):
		sprite.visible = false
		return

	var sheet := load(EFFECT_SHEET_PATH) as Texture2D
	if sheet == null:
		sprite.visible = false
		return

	var rect_value: Variant = PREVIEW_RECTS.get(
		_effect_key,
		Rect2i()
	)
	var rect: Rect2i = rect_value as Rect2i
	if rect.size == Vector2i.ZERO:
		sprite.visible = false
		return

	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(rect)
	sprite.texture = atlas
	sprite.visible = true
