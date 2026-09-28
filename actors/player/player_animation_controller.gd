class_name PlayerAnimationController
extends Node

const DMI_SPRITE_SHEET_SCRIPT = preload(
	"res://core/assets/dmi_sprite_sheet.gd"
)
const DMI_ANIMATION_FPS := 10.0
const DMI_STATE_MISSING: StringName = &"__missing__"

const DIRECTION_ROWS := {
	&"down": 0,
	&"left": 1,
	&"right": 2,
	&"up": 3,
}

@export_file("*.dmi")
var dmi_sprite_path: String = "res://assets/sprites/characters/goku/hu2/Goku.dmi"

@export var prefer_dmi_sprite: bool = true

@export_file("*.png")
var sprite_sheet_path: String = "res://assets/sprites/characters/goku/processed/goku_buus_fury_base.png"

@export_file("*.png")
var run_sheet_path: String = "res://assets/sprites/characters/goku/processed/goku_buus_fury_run.png"

@export_file("*.png")
var attack_sheet_path: String = "res://assets/sprites/characters/goku/processed/goku_buus_fury_attack.png"

@export_file("*.png")
var hurt_sheet_path: String = "res://assets/sprites/characters/goku/processed/goku_buus_fury_hurt.png"

@export_file("*.png")
var block_sheet_path: String = "res://assets/sprites/characters/goku/processed/goku_buus_fury_block.png"

@export_file("*.png")
var ki_blast_sheet_path: String = "res://assets/sprites/characters/goku/processed/goku_buus_fury_ki_blast.png"

@export_file("*.png")
var beam_cast_sheet_path: String = "res://assets/sprites/characters/goku/processed/goku_buus_fury_beam_cast.png"

@export_file("*.png")
var kick_sheet_path: String = "res://assets/sprites/characters/goku/processed/goku_buus_fury_kick.png"

@export_file("*.png")
var charge_ki_sheet_path: String = "res://assets/sprites/characters/goku/processed/goku_buus_fury_charge_ki.png"

@export var frame_size: Vector2i = Vector2i(32, 32)
@export var idle_column: int = 0
@export var walk_columns: PackedInt32Array = PackedInt32Array([2, 3, 4, 5])
@export var run_columns: PackedInt32Array = PackedInt32Array([0, 1, 2, 3])
@export var attack_1_columns: PackedInt32Array = PackedInt32Array([0, 1, 2, 3])
@export var attack_2_columns: PackedInt32Array = PackedInt32Array([4, 5, 6, 7])
@export var hurt_columns: PackedInt32Array = PackedInt32Array([0, 1])
@export var block_columns: PackedInt32Array = PackedInt32Array([0])
@export var ki_blast_prepare_columns: PackedInt32Array = PackedInt32Array([0])
@export var ki_blast_1_columns: PackedInt32Array = PackedInt32Array([1])
@export var ki_blast_2_columns: PackedInt32Array = PackedInt32Array([2])
@export var special_projectile_columns: PackedInt32Array = PackedInt32Array([1])
@export var special_beam_columns: PackedInt32Array = PackedInt32Array([0])
@export var kick_1_columns: PackedInt32Array = PackedInt32Array([0, 1, 0])
@export var kick_2_columns: PackedInt32Array = PackedInt32Array([2, 3, 2])
@export var charge_ki_columns: PackedInt32Array = PackedInt32Array([0, 1])

@export var walk_fps: float = 8.0
@export var run_fps: float = 12.0
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
	var animation_name: StringName = _animation_name_for_state(
		state,
		facing
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

func restart_visual(state: StringName, facing: StringName) -> void:
	var animation_name: StringName = _animation_name_for_state(
		state,
		facing
	)

	if not _has_animation(animation_name):
		return

	visuals.position = Vector2.ZERO
	placeholder.visible = false
	sprite.visible = true
	sprite.stop()
	sprite.play(animation_name)
	sprite.frame = 0

func freeze_charge_complete(facing: StringName = &"down") -> void:
	var animation_name := StringName("charge_ki_%s" % facing)
	if not _has_animation(animation_name):
		animation_name = &"charge_ki"

	if not _has_animation(animation_name):
		return

	visuals.position = Vector2.ZERO
	placeholder.visible = false
	sprite.visible = true
	sprite.animation = animation_name

	var last_frame := (
		sprite.sprite_frames.get_frame_count(animation_name) - 1
	)
	sprite.frame = maxi(last_frame, 0)
	sprite.pause()

func _animation_name_for_state(
	state: StringName,
	facing: StringName
) -> StringName:
	if state == &"charge_ki":
		var charge_name := StringName("charge_ki_%s" % facing)
		if _has_animation(charge_name):
			return charge_name
		return &"charge_ki"

	if state == &"special_transform":
		var transform_name := StringName("transform_%s" % facing)
		if _has_animation(transform_name):
			return transform_name

		var charge_name := StringName("charge_ki_%s" % facing)
		if _has_animation(charge_name):
			return charge_name
		return &"charge_ki"

	match state:
		&"special_melee":
			return StringName("attack_1_%s" % facing)
		&"special_kick":
			return StringName("kick_1_%s" % facing)
		&"special_pose":
			return StringName("idle_%s" % facing)

	return StringName("%s_%s" % [state, facing])

func _show_sprite_animation(animation_name: StringName, state: StringName) -> void:
	visuals.position = Vector2.ZERO
	placeholder.visible = false
	sprite.visible = true

	if sprite.animation != animation_name:
		sprite.play(animation_name)
	elif not _is_one_shot_state(state) and not sprite.is_playing():
		sprite.play(animation_name)

func _try_build_sprite_frames() -> void:
	if prefer_dmi_sprite and _try_build_dmi_sprite_frames():
		return

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

	var run_sheet := _load_valid_sheet(
		run_sheet_path,
		_required_columns(-1, run_columns)
	)
	if run_sheet != null:
		_add_directional_animation(
			frames,
			run_sheet,
			&"run",
			run_columns,
			run_fps,
			true
		)
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

	var max_ki_blast_columns := PackedInt32Array()
	max_ki_blast_columns.append_array(ki_blast_prepare_columns)
	max_ki_blast_columns.append_array(ki_blast_1_columns)
	max_ki_blast_columns.append_array(ki_blast_2_columns)

	var ki_blast_sheet := _load_valid_sheet(
		ki_blast_sheet_path,
		_required_columns(-1, max_ki_blast_columns)
	)
	if ki_blast_sheet != null:
		_add_directional_animation(
			frames,
			ki_blast_sheet,
			&"ki_blast_prepare",
			ki_blast_prepare_columns,
			1.0,
			false
		)
		_add_directional_animation(
			frames,
			ki_blast_sheet,
			&"ki_blast_1",
			ki_blast_1_columns,
			1.0,
			false
		)
		_add_directional_animation(
			frames,
			ki_blast_sheet,
			&"ki_blast_2",
			ki_blast_2_columns,
			1.0,
			false
		)
		_add_directional_animation(
			frames,
			ki_blast_sheet,
			&"special_projectile",
			special_projectile_columns,
			1.0,
			false
		)
		built_any_animation = true

	var beam_cast_sheet := _load_valid_sheet(
		beam_cast_sheet_path,
		_required_columns(-1, special_beam_columns)
	)
	if beam_cast_sheet != null:
		_add_directional_animation(
			frames,
			beam_cast_sheet,
			&"special_beam",
			special_beam_columns,
			1.0,
			true
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

func _try_build_dmi_sprite_frames() -> bool:
	if not FileAccess.file_exists(dmi_sprite_path):
		return false

	var dmi = DMI_SPRITE_SHEET_SCRIPT.load_file(dmi_sprite_path)
	if dmi == null:
		return false

	var frames := SpriteFrames.new()
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")

	var built_any := false

	var movement_state := _find_dmi_state(
		dmi,
		[&"", &"movement", &"walk"]
	)
	if movement_state != DMI_STATE_MISSING:
		built_any = _add_dmi_directional_animation(
			frames,
			dmi,
			movement_state,
			&"idle",
			true,
			true
		) or built_any
		built_any = _add_dmi_directional_animation(
			frames,
			dmi,
			movement_state,
			&"walk",
			true
		) or built_any

	var run_state := _find_dmi_state(
		dmi,
		[&"Sprint", &"sprint", &"fly"]
	)
	built_any = _add_dmi_directional_animation(
		frames,
		dmi,
		run_state,
		&"run",
		true
	) or built_any

	var attack_1_state := _find_dmi_state(dmi, [&"punch1"])
	built_any = _add_dmi_directional_animation(
		frames,
		dmi,
		attack_1_state,
		&"attack_1",
		false
	) or built_any

	var attack_2_state := _find_dmi_state(
		dmi,
		[&"punch2", &"punch1"]
	)
	built_any = _add_dmi_directional_animation(
		frames,
		dmi,
		attack_2_state,
		&"attack_2",
		false
	) or built_any

	var kick_state := _find_dmi_state(dmi, [&"kick1"])
	built_any = _add_dmi_directional_animation(
		frames,
		dmi,
		kick_state,
		&"kick_1",
		false
	) or built_any
	built_any = _add_dmi_directional_animation(
		frames,
		dmi,
		kick_state,
		&"kick_2",
		false
	) or built_any

	var hurt_state := _find_dmi_state(
		dmi,
		[&"HitStun", &"hitstun"]
	)
	built_any = _add_dmi_directional_animation(
		frames,
		dmi,
		hurt_state,
		&"hurt",
		false
	) or built_any

	var guard_state := _find_dmi_state(
		dmi,
		[&"Guard", &"guard"]
	)
	built_any = _add_dmi_directional_animation(
		frames,
		dmi,
		guard_state,
		&"block",
		true
	) or built_any

	var ki_charge_state := _find_dmi_state(
		dmi,
		[&"KiBlastCharge", &"kiblast"]
	)
	built_any = _add_dmi_directional_animation(
		frames,
		dmi,
		ki_charge_state,
		&"ki_blast_prepare",
		false
	) or built_any

	var ki_blast_1_state := _find_dmi_state(
		dmi,
		[&"kiblast", &"KiBlast"]
	)
	built_any = _add_dmi_directional_animation(
		frames,
		dmi,
		ki_blast_1_state,
		&"ki_blast_1",
		false
	) or built_any
	built_any = _add_dmi_directional_animation(
		frames,
		dmi,
		ki_blast_1_state,
		&"special_projectile",
		false
	) or built_any

	var ki_blast_2_state := _find_dmi_state(
		dmi,
		[&"KiBlast2", &"kiblast"]
	)
	built_any = _add_dmi_directional_animation(
		frames,
		dmi,
		ki_blast_2_state,
		&"ki_blast_2",
		false
	) or built_any

	var beam_charge_state := _find_dmi_state(
		dmi,
		[&"charge", &"BeamCharge"]
	)
	built_any = _add_dmi_directional_animation(
		frames,
		dmi,
		beam_charge_state,
		&"special_beam_charge",
		true
	) or built_any

	var beam_state := _find_dmi_state(dmi, [&"Beam", &"beam"])
	built_any = _add_dmi_directional_animation(
		frames,
		dmi,
		beam_state,
		&"special_beam",
		true
	) or built_any

	var power_state := _find_dmi_state(
		dmi,
		[&"powerup", &"charge"]
	)
	built_any = _add_dmi_directional_animation(
		frames,
		dmi,
		power_state,
		&"charge_ki",
		true
	) or built_any

	var transform_state := _find_dmi_state(dmi, [&"transform"])
	built_any = _add_dmi_directional_animation(
		frames,
		dmi,
		transform_state,
		&"transform",
		false
	) or built_any

	var knockback_state := _find_dmi_state(
		dmi,
		[&"KnockBack", &"knockback"]
	)
	built_any = _add_dmi_directional_animation(
		frames,
		dmi,
		knockback_state,
		&"knockback",
		false
	) or built_any

	var ko_state := _find_dmi_state(dmi, [&"koed", &"KO"])
	built_any = _add_dmi_directional_animation(
		frames,
		dmi,
		ko_state,
		&"koed",
		true
	) or built_any

	var land_state := _find_dmi_state(dmi, [&"Land", &"land"])
	built_any = _add_dmi_directional_animation(
		frames,
		dmi,
		land_state,
		&"land",
		false
	) or built_any

	if not built_any:
		return false

	frame_size = dmi.frame_size
	sprite.sprite_frames = frames
	return true

func _find_dmi_state(dmi, candidates: Array) -> StringName:
	for candidate in candidates:
		var state_name := StringName(String(candidate))
		if dmi.has_state(state_name):
			return state_name
	return DMI_STATE_MISSING

func _add_dmi_directional_animation(
	frames: SpriteFrames,
	dmi,
	dmi_state: StringName,
	animation_state: StringName,
	loop: bool,
	first_frame_only: bool = false
) -> bool:
	if (
		dmi_state == DMI_STATE_MISSING
		or not dmi.has_state(dmi_state)
	):
		return false

	var source_frame_count: int = dmi.get_frame_count(dmi_state)
	if source_frame_count <= 0:
		return false

	var frame_count := (
		1 if first_frame_only else source_frame_count
	)
	var added_any := false

	for facing in DIRECTION_ROWS:
		var animation_name := StringName(
			"%s_%s" % [animation_state, facing]
		)

		frames.add_animation(animation_name)
		frames.set_animation_loop(animation_name, loop)
		frames.set_animation_speed(
			animation_name,
			DMI_ANIMATION_FPS
		)

		for frame_index in range(frame_count):
			var frame_texture: AtlasTexture = dmi.get_frame_texture(
				dmi_state,
				StringName(String(facing)),
				frame_index
			)
			if frame_texture == null:
				continue

			frames.add_frame(
				animation_name,
				frame_texture,
				dmi.get_frame_delay(
					dmi_state,
					frame_index
				)
			)
			added_any = true

	return added_any

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
		or String(state).begins_with("ki_blast_")
		or String(state).begins_with("special_")
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
