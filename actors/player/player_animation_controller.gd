class_name PlayerAnimationController
extends Node

const DIRECTION_ROWS := {
	&"down": 0,
	&"left": 1,
	&"right": 2,
	&"up": 3,
}

@export_file("*.png")
var sprite_sheet_path: String = "res://assets/sprites/characters/goku/processed/goku_buus_fury_base.png"

@export_file("*.png")
var attack_sheet_path: String = "res://assets/sprites/characters/goku/processed/goku_buus_fury_attack.png"

@export_file("*.png")
var hurt_sheet_path: String = "res://assets/sprites/characters/goku/processed/goku_buus_fury_hurt.png"

@export_file("*.png")
var block_sheet_path: String = "res://assets/sprites/characters/goku/processed/goku_buus_fury_block.png"

@export_file("*.png")
var ki_blast_sheet_path: String = "res://assets/sprites/characters/goku/processed/goku_buus_fury_ki_blast.png"

@export_file("*.png")
var kick_sheet_path: String = "res://assets/sprites/characters/goku/processed/goku_buus_fury_kick.png"

@export_file("*.png")
var charge_ki_sheet_path: String = "res://assets/sprites/characters/goku/processed/goku_buus_fury_charge_ki.png"

@export var frame_size: Vector2i = Vector2i(32, 32)
@export var idle_column: int = 0
@export var walk_columns: PackedInt32Array = PackedInt32Array([2, 3, 4, 5])
@export var attack_1_columns: PackedInt32Array = PackedInt32Array([0, 1, 2, 3])
@export var attack_2_columns: PackedInt32Array = PackedInt32Array([4, 5, 6, 7])
@export var hurt_columns: PackedInt32Array = PackedInt32Array([0, 1])
@export var block_columns: PackedInt32Array = PackedInt32Array([0])
@export var ki_blast_columns: PackedInt32Array = PackedInt32Array([0, 1, 2, 3])
@export var kick_1_columns: PackedInt32Array = PackedInt32Array([0, 1, 0])
@export var kick_2_columns: PackedInt32Array = PackedInt32Array([2, 3, 2])
@export var charge_ki_columns: PackedInt32Array = PackedInt32Array([0, 1])

@export var walk_fps: float = 8.0
@export var attack_fps: float = 10.0
@export var hurt_fps: float = 10.0
@export var ki_blast_fps: float = 10.0
@export var kick_fps: float = 7.0
@export var charge_ki_fps: float = 5.0
@export var walk_bob_amplitude: float = 1.0
@export var walk_bob_speed: float = 12.0

@onready var visuals: Node2D = get_parent() as Node2D
@onready var sprite: AnimatedSprite2D = visuals.get_node("AnimatedSprite2D") as AnimatedSprite2D
@onready var placeholder: Polygon2D = visuals.get_node("Placeholder") as Polygon2D
@onready var facing_marker: Polygon2D = placeholder.get_node("FacingMarker") as Polygon2D

var _bob_phase: float = 0.0

func _ready() -> void:
	_try_build_sprite_frames()

func update_visual(state: StringName, facing: StringName, delta: float) -> void:
	var animation_name := (
		&"charge_ki"
		if state == &"charge_ki"
		else StringName("%s_%s" % [state, facing])
	)

	if _has_animation(animation_name):
		_show_sprite_animation(animation_name, state)
		return

	var fallback_name := StringName("idle_%s" % facing)
	if _has_animation(fallback_name):
		_show_sprite_animation(fallback_name, &"idle")
		return

	sprite.stop()
	sprite.visible = false
	placeholder.visible = true
	_update_placeholder_facing(facing)
	_update_placeholder_motion(state, delta)

func _show_sprite_animation(animation_name: StringName, state: StringName) -> void:
	visuals.position = Vector2.ZERO
	placeholder.visible = false
	sprite.visible = true

	if sprite.animation != animation_name:
		sprite.play(animation_name)
	elif not _is_one_shot_state(state) and not sprite.is_playing():
		sprite.play(animation_name)

func _try_build_sprite_frames() -> void:
	var frames := SpriteFrames.new()
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")

	var built_any_animation := false

	var movement_sheet := _load_valid_sheet(
		sprite_sheet_path,
		_required_columns(idle_column, walk_columns)
	)
	if movement_sheet != null:
		_add_movement_animations(frames, movement_sheet)
		built_any_animation = true

	var max_attack_columns := PackedInt32Array()
	max_attack_columns.append_array(attack_1_columns)
	max_attack_columns.append_array(attack_2_columns)

	var attack_sheet := _load_valid_sheet(
		attack_sheet_path,
		_required_columns(-1, max_attack_columns)
	)
	if attack_sheet != null:
		_add_directional_animation(frames, attack_sheet, &"attack_1", attack_1_columns, attack_fps, false)
		_add_directional_animation(frames, attack_sheet, &"attack_2", attack_2_columns, attack_fps, false)
		built_any_animation = true

	var max_kick_columns := PackedInt32Array()
	max_kick_columns.append_array(kick_1_columns)
	max_kick_columns.append_array(kick_2_columns)

	var kick_sheet := _load_valid_sheet(
		kick_sheet_path,
		_required_columns(-1, max_kick_columns)
	)
	if kick_sheet != null:
		_add_directional_animation(frames, kick_sheet, &"kick_1", kick_1_columns, kick_fps, false)
		_add_directional_animation(frames, kick_sheet, &"kick_2", kick_2_columns, kick_fps, false)
		built_any_animation = true

	var hurt_sheet := _load_valid_sheet(
		hurt_sheet_path,
		_required_columns(-1, hurt_columns)
	)
	if hurt_sheet != null:
		_add_directional_animation(frames, hurt_sheet, &"hurt", hurt_columns, hurt_fps, false)
		built_any_animation = true

	var block_sheet := _load_valid_sheet(
		block_sheet_path,
		_required_columns(-1, block_columns)
	)
	if block_sheet != null:
		_add_directional_animation(frames, block_sheet, &"block", block_columns, 1.0, true)
		built_any_animation = true

	var ki_blast_sheet := _load_valid_sheet(
		ki_blast_sheet_path,
		_required_columns(-1, ki_blast_columns)
	)
	if ki_blast_sheet != null:
		_add_directional_animation(
			frames,
			ki_blast_sheet,
			&"ki_blast",
			ki_blast_columns,
			ki_blast_fps,
			false
		)
		built_any_animation = true

	var charge_ki_sheet := _load_valid_single_row_sheet(
		charge_ki_sheet_path,
		_required_columns(-1, charge_ki_columns)
	)
	if charge_ki_sheet != null:
		_add_single_row_animation(
			frames,
			charge_ki_sheet,
			&"charge_ki",
			charge_ki_columns,
			charge_ki_fps,
			false
		)
		built_any_animation = true

	if built_any_animation:
		sprite.sprite_frames = frames

func _add_movement_animations(frames: SpriteFrames, sheet: Texture2D) -> void:
	for facing in DIRECTION_ROWS:
		var row: int = DIRECTION_ROWS[facing]
		var idle_name := StringName("idle_%s" % facing)
		var walk_name := StringName("walk_%s" % facing)

		frames.add_animation(idle_name)
		frames.set_animation_loop(idle_name, true)
		frames.set_animation_speed(idle_name, 1.0)
		frames.add_frame(idle_name, _atlas_frame(sheet, idle_column, row))

		frames.add_animation(walk_name)
		frames.set_animation_loop(walk_name, true)
		frames.set_animation_speed(walk_name, walk_fps)

		for column in walk_columns:
			frames.add_frame(walk_name, _atlas_frame(sheet, column, row))

func _add_directional_animation(
	frames: SpriteFrames,
	sheet: Texture2D,
	state_name: StringName,
	columns: PackedInt32Array,
	fps: float,
	loop: bool
) -> void:
	for facing in DIRECTION_ROWS:
		var row: int = DIRECTION_ROWS[facing]
		var animation_name := StringName("%s_%s" % [state_name, facing])

		frames.add_animation(animation_name)
		frames.set_animation_loop(animation_name, loop)
		frames.set_animation_speed(animation_name, fps)

		for column in columns:
			frames.add_frame(animation_name, _atlas_frame(sheet, column, row))

func _add_single_row_animation(
	frames: SpriteFrames,
	sheet: Texture2D,
	animation_name: StringName,
	columns: PackedInt32Array,
	fps: float,
	loop: bool
) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_loop(animation_name, loop)
	frames.set_animation_speed(animation_name, fps)

	for column in columns:
		frames.add_frame(animation_name, _atlas_frame(sheet, column, 0))

func _load_valid_single_row_sheet(path: String, required_columns: int) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null

	var sheet := load(path) as Texture2D
	if sheet == null:
		return null

	var required_width := required_columns * frame_size.x
	if sheet.get_width() < required_width or sheet.get_height() < frame_size.y:
		push_warning(
			"Sprite sheet de carga inesperado em %s. Esperado ao menos %dx%d, recebido %dx%d."
			% [
				path,
				required_width,
				frame_size.y,
				sheet.get_width(),
				sheet.get_height(),
			]
		)
		return null

	return sheet

func _load_valid_sheet(path: String, required_columns: int) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null

	var sheet := load(path) as Texture2D
	if sheet == null:
		return null

	var required_width := required_columns * frame_size.x
	var required_height := DIRECTION_ROWS.size() * frame_size.y

	if sheet.get_width() < required_width or sheet.get_height() < required_height:
		push_warning(
			"Sprite sheet inesperado em %s. Esperado ao menos %dx%d, recebido %dx%d."
			% [
				path,
				required_width,
				required_height,
				sheet.get_width(),
				sheet.get_height(),
			]
		)
		return null

	return sheet

func _required_columns(single_column: int, columns: PackedInt32Array) -> int:
	var max_column := single_column
	for column in columns:
		if column > max_column:
			max_column = column
	return max_column + 1

func _atlas_frame(sheet: Texture2D, column: int, row: int) -> AtlasTexture:
	var frame := AtlasTexture.new()
	frame.atlas = sheet
	frame.region = Rect2(
		Vector2(column * frame_size.x, row * frame_size.y),
		Vector2(frame_size.x, frame_size.y)
	)
	return frame

func _has_animation(animation_name: StringName) -> bool:
	if sprite.sprite_frames == null:
		return false

	return (
		sprite.sprite_frames.has_animation(animation_name)
		and sprite.sprite_frames.get_frame_count(animation_name) > 0
	)

func _is_one_shot_state(state: StringName) -> bool:
	return (
		String(state).begins_with("attack_")
		or String(state).begins_with("kick_")
		or state == &"hurt"
		or state == &"ki_blast"
		or state == &"charge_ki"
	)

func _update_placeholder_motion(state: StringName, delta: float) -> void:
	if state == &"walk":
		_bob_phase += delta * walk_bob_speed
		visuals.position.y = roundf(sin(_bob_phase) * walk_bob_amplitude)
		return

	_bob_phase = 0.0
	visuals.position = Vector2.ZERO

func _update_placeholder_facing(facing: StringName) -> void:
	match facing:
		&"up":
			facing_marker.position = Vector2(0, -10)
			facing_marker.rotation = 0.0
		&"down":
			facing_marker.position = Vector2(0, 10)
			facing_marker.rotation = PI
		&"left":
			facing_marker.position = Vector2(-9, 0)
			facing_marker.rotation = -PI / 2.0
		&"right":
			facing_marker.position = Vector2(9, 0)
			facing_marker.rotation = PI / 2.0
