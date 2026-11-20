class_name CombatHUD
extends Control

const DMI_SPRITE_SHEET_SCRIPT = preload(
	"res://core/assets/dmi_sprite_sheet.gd"
)
const HU2_EFFECT_DMI_PATH := (
	"res://assets/sprites/effects/hu2/Effects.dmi"
)
const HU2_GOKU_DMI_PATH := (
	"res://assets/sprites/characters/goku/hu2/Goku.dmi"
)
const SPECIAL_EFFECT_SHEET_PATH := (
	"res://assets/sprites/effects/legacy/special_attack_sfx.png"
)

const SPECIAL_DMI_STATES := {
	&"blue_beam": &"KameHead",
	&"special_beam": &"sbcHead",
	&"masenko": &"MasenkoHead",
	&"big_bang": &"BigBangAttackHead",
	&"burning_attack": &"BurningAttHead",
}

const SPECIAL_LEGACY_RECTS := {
	&"blue_orb": Rect2(51, 33, 28, 14),
	&"spirit_bomb": Rect2(80, 312, 32, 32),
	&"sword_blast": Rect2(8, 272, 32, 32),
}

const SPECIAL_CHARACTER_STATES := {
	&"cross_slash": &"punch1",
	&"energy_punch": &"punch1",
	&"flurry_punch": &"punch2",
	&"peace_sign_pose": &"face",
	&"spin_punch": &"punch2",
	&"super_kick": &"kick1",
	&"super_namek": &"transform",
	&"super_saiyan": &"transform",
	&"two_handed_smash": &"punch2",
}

@onready var player_panel: Control = $PlayerPanel
@onready var fallback: ColorRect = $PlayerPanel/Fallback
@onready var frame: TextureRect = $PlayerPanel/Frame
@onready var icon: TextureRect = $PlayerPanel/Icon
@onready var divider: TextureRect = $PlayerPanel/Divider
@onready var hp_fill: TextureRect = $PlayerPanel/HPFill
@onready var ki_fill: TextureRect = $PlayerPanel/KiFill
@onready var xp_fill: TextureRect = $PlayerPanel/XPFill

var _player_health: HealthComponent
var _player_ki: KiComponent
var _player_experience: ExperienceComponent
var _special: SpecialAttackComponent
var _xp_ratio: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_hud()
	call_deferred("_bind_player")

func _build_hud() -> void:
	# Original pixel geometry, independent of the borrowed legacy HUD sheet.
	player_panel.position = Vector2(8, 8)
	player_panel.size = Vector2(170, 46)
	player_panel.scale = Vector2(0.5, 0.5)
	fallback.hide()
	frame.hide()
	divider.hide()
	var plate := Panel.new()
	plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("111f2c")
	style.border_color = Color("506775")
	style.set_border_width_all(1)
	style.border_width_left = 3
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 2
	plate.add_theme_stylebox_override("panel", style)
	player_panel.add_child(plate)
	player_panel.move_child(plate, 0)
	_add_label("Identity", "GUERREIRO", Vector2(40, 3), Vector2(122, 11), Color("edc18a"), 8)
	_add_label("HPText", "VIDA", Vector2(40, 14), Vector2(122, 10), Color("edf2df"), 7)
	_add_label("KiText", "KI", Vector2(40, 27), Vector2(122, 10), Color("b7e9ed"), 7)
	icon.position = Vector2(7, 8)
	icon.size = Vector2(27, 30)
	icon.hide()
	# Character-neutral energy crest, usable by future custom characters.
	for layer in range(3):
		var crest := Polygon2D.new()
		var radius := 13 - layer * 4
		crest.polygon = PackedVector2Array([Vector2(0, -radius), Vector2(radius, 0), Vector2(0, radius), Vector2(-radius, 0)])
		crest.position = Vector2(21, 24)
		crest.color = [Color("e9ad65"), Color("203a4a"), Color("8fe5e6")][layer]
		crest.z_index = 2
		player_panel.add_child(crest)
	hp_fill.position = Vector2(40, 24)
	ki_fill.position = Vector2(40, 37)
	xp_fill.position = Vector2(7, 43)
	for bar in [hp_fill, ki_fill, xp_fill]:
		var back := ColorRect.new()
		back.position = bar.position - Vector2.ONE
		back.size = Vector2(124 if bar != xp_fill else 157, 5 if bar != xp_fill else 3)
		back.color = Color("080f19")
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		player_panel.add_child(back)
		player_panel.move_child(back, 1)
	_set_texture_bar(hp_fill, 1.0)
	_set_texture_bar(ki_fill, 1.0)
	_set_texture_bar(xp_fill, 0.0)

func _add_label(node_name: String, text: String, at: Vector2, extent: Vector2, tint: Color, font_size: int) -> void:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.position = at
	label.size = extent
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	player_panel.add_child(label)

func _bind_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return

	_player_health = player.get_node_or_null(
		"Components/HealthComponent"
	) as HealthComponent
	_player_ki = player.get_node_or_null(
		"Components/KiComponent"
	) as KiComponent
	_player_experience = player.get_node_or_null(
		"Components/ExperienceComponent"
	) as ExperienceComponent
	_special = player.get_node_or_null(
		"Components/SpecialAttackComponent"
	) as SpecialAttackComponent

	if _player_health != null:
		_player_health.health_changed.connect(_on_health_changed)
		_on_health_changed(
			_player_health.current_health,
			_player_health.max_health
		)

	if _player_ki != null:
		_player_ki.ki_changed.connect(_on_ki_changed)
		_on_ki_changed(
			_player_ki.current_ki,
			_player_ki.max_ki
		)

	if _player_experience != null:
		_player_experience.experience_changed.connect(
			_on_experience_changed
		)
		_on_experience_changed(
			_player_experience.current_experience,
			_player_experience.experience_to_next_level,
			_player_experience.current_level
		)

	if _special != null:
		_special.selection_changed.connect(
			_on_special_selection_changed
		)
		var selected: SpecialAttackData = _special.get_selected()
		if selected != null:
			_set_special_icon(selected)

func _on_health_changed(current_health: int, max_health: int) -> void:
	var safe_max := maxi(max_health, 1)
	var ratio := clampf(
		float(current_health) / float(safe_max),
		0.0,
		1.0
	)
	_set_texture_bar(hp_fill, ratio)
	player_panel.get_node("HPText").text = "VIDA   %d / %d" % [current_health, max_health]

func _on_ki_changed(current_ki: float, max_ki: float) -> void:
	var safe_max := maxf(max_ki, 1.0)
	var ratio := clampf(current_ki / safe_max, 0.0, 1.0)
	_set_texture_bar(ki_fill, ratio)
	player_panel.get_node("KiText").text = "KI      %d / %d" % [ceili(current_ki), ceili(max_ki)]

func _on_experience_changed(
	current_experience: int,
	experience_to_next_level: int,
	_current_level: int
) -> void:
	player_panel.get_node("Identity").text = "GUERREIRO   /   NV %02d" % _current_level
	var safe_required := maxi(experience_to_next_level, 1)
	set_experience_ratio(
		float(current_experience) / float(safe_required)
	)

# The thin copper line tracks progress toward the next level.
func set_experience_ratio(ratio: float) -> void:
	_xp_ratio = clampf(ratio, 0.0, 1.0)
	_set_texture_bar(xp_fill, _xp_ratio)

func _on_special_selection_changed(
	_ability_id: StringName,
	_display_name: String,
	_index: int
) -> void:
	if _special == null:
		return

	var data: SpecialAttackData = _special.get_selected()
	if data != null:
		_set_special_icon(data)

func _set_special_icon(data: SpecialAttackData) -> void:
	var texture: Texture2D = _resolve_special_icon(data)
	# Effect frames contain transparent padding sized for world animation.
	# Fit the visible art into the HUD slot instead of shrinking that padding.
	if texture != null:
		var source := texture.get_image()
		if source != null:
			var bounds := source.get_used_rect()
			if bounds.has_area():
				texture = ImageTexture.create_from_image(source.get_region(bounds))
	var skill_icon := get_node_or_null("../SpecialStatusHUD/Panel/Icon") as TextureRect
	if skill_icon != null:
		skill_icon.texture = texture
		skill_icon.visible = texture != null
		skill_icon.tooltip_text = data.display_name

func _resolve_special_icon(data: SpecialAttackData) -> Texture2D:
	if data == null:
		return null

	# Melee/pose/transformation specials often keep the default effect_key,
	# so ability-specific character art must win before effect fallbacks.
	var character_state_value: Variant = (
		SPECIAL_CHARACTER_STATES.get(
			data.ability_id,
			null
		)
	)
	if character_state_value != null:
		var character_icon: Texture2D = _dmi_icon(
			HU2_GOKU_DMI_PATH,
			StringName(String(character_state_value)),
			&"right"
		)
		if character_icon != null:
			return character_icon

	var dmi_state_value: Variant = SPECIAL_DMI_STATES.get(
		data.effect_key,
		null
	)
	if dmi_state_value != null:
		var effect_icon: Texture2D = _dmi_icon(
			HU2_EFFECT_DMI_PATH,
			StringName(String(dmi_state_value)),
			&"right"
		)
		if effect_icon != null:
			return effect_icon

	var rect_value: Variant = SPECIAL_LEGACY_RECTS.get(
		data.effect_key,
		null
	)
	if rect_value is Rect2:
		var legacy: Texture2D = _legacy_special_icon(
			rect_value as Rect2
		)
		if legacy != null:
			return legacy

	return _dmi_icon(
		HU2_EFFECT_DMI_PATH,
		&"BlueEnergy",
		&"right"
	)

func _dmi_icon(
	path: String,
	state: StringName,
	facing: StringName
) -> Texture2D:
	var dmi = DMI_SPRITE_SHEET_SCRIPT.load_file(path)
	if dmi == null or not dmi.has_state(state):
		return null

	return dmi.get_frame_texture(
		state,
		facing,
		0
	) as Texture2D

func _legacy_special_icon(region: Rect2) -> Texture2D:
	if not ResourceLoader.exists(SPECIAL_EFFECT_SHEET_PATH):
		return null

	var sheet: Texture2D = load(
		SPECIAL_EFFECT_SHEET_PATH
	) as Texture2D
	if sheet == null:
		return null

	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = region
	return atlas

func _set_texture_bar(
	target: TextureRect,
	ratio: float
) -> void:
	var bar_width := 155 if target == xp_fill else 122
	var height := 1 if target == xp_fill else 3
	var width := floori(bar_width * clampf(ratio, 0.0, 1.0))
	var tint := Color("e9ad65") if target == xp_fill else (Color("8dce91") if target == hp_fill else Color("65cbd6"))
	if target == hp_fill and ratio <= 0.25:
		tint = Color("ef7b70")
	var pixels := Image.create(1, height, false, Image.FORMAT_RGBA8)
	pixels.fill(tint)
	pixels.set_pixel(0, 0, tint.lightened(0.25))
	target.texture = ImageTexture.create_from_image(pixels)
	target.size = Vector2(width, height)
	target.visible = width > 0
