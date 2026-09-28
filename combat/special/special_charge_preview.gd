class_name SpecialChargePreview
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
const KAME_CHARGE_STATE: StringName = &"KameStart"

const PREVIEW_RECTS := {
	&"big_bang": Rect2i(82, 196, 33, 24),
	&"spirit_bomb": Rect2i(80, 312, 32, 32),
}

@onready var sprite: Sprite2D = $Sprite2D

var _dmi_sprite: AnimatedSprite2D

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

	if _effect_key == &"blue_beam":
		if is_instance_valid(_dmi_sprite):
			# Keep HU2's original 32px art, but fade it in as the hands
			# settle into the charge pose.
			_dmi_sprite.modulate.a = lerpf(0.45, 1.0, _ratio)
		return

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
		rotation = 0.0
		global_position = (
			_caster.global_position
			+ Vector2(0.0, -22.0)
		)
	elif _effect_key == &"blue_beam":
		# During HU2's charge state the hands are pulled behind the body.
		# Put the animated Kame start glow on that hand position, then the
		# beam itself will take over from the front when the cast fires.
		rotation = 0.0
		global_position = (
			_caster.global_position
			- _direction * 7.0
			+ Vector2(0.0, -2.0)
		)
	else:
		rotation = 0.0
		global_position = (
			_caster.global_position
			+ _direction * _spawn_distance
			+ Vector2(0.0, -4.0)
		)

func _facing_from_direction(direction: Vector2) -> String:
	if absf(direction.x) > absf(direction.y):
		return "right" if direction.x >= 0.0 else "left"
	return "down" if direction.y >= 0.0 else "up"

func _build_visual() -> void:
	if _effect_key == &"blue_beam":
		sprite.visible = false

		if not is_instance_valid(_dmi_sprite):
			_dmi_sprite = DMI_EFFECT_SCRIPT.new() as AnimatedSprite2D
			if _dmi_sprite == null:
				return
			_dmi_sprite.z_index = 1
			add_child(_dmi_sprite)

		_dmi_sprite.visible = true
		_dmi_sprite.modulate = Color(1.0, 1.0, 1.0, 0.45)
		_dmi_sprite.call(
			"configure",
			HU2_EFFECT_DMI_PATH,
			KAME_CHARGE_STATE,
			_facing_from_direction(_direction),
			true,
			true
		)
		return

	if is_instance_valid(_dmi_sprite):
		_dmi_sprite.visible = false

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
