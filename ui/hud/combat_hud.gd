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

@export_file("*.png")
var hud_sheet_path: String = "res://assets/ui/legacy/processed/hud.png"

@onready var player_panel: Control = $PlayerPanel
@onready var fallback: ColorRect = $PlayerPanel/Fallback
@onready var frame: TextureRect = $PlayerPanel/Frame
@onready var icon: TextureRect = $PlayerPanel/Icon
@onready var divider: TextureRect = $PlayerPanel/Divider
@onready var hp_fill: TextureRect = $PlayerPanel/HPFill
@onready var ki_fill: TextureRect = $PlayerPanel/KiFill
@onready var xp_fill: TextureRect = $PlayerPanel/XPFill

# Regiões medidas diretamente no hud.png transparente fornecido.
const FRAME_REGION := Rect2(8, 8, 80, 16)
const ICON_BLUE_REGION := Rect2(137, 13, 21, 13)
const ICON_YELLOW_REGION := Rect2(161, 13, 21, 13)
const DIVIDER_REGION := Rect2(95, 8, 7, 7)
const HP_REGION := Rect2(92, 18, 43, 3)
const KI_REGION := Rect2(88, 22, 43, 3)
const XP_REGION := Rect2(111, 9, 73, 2)

# Posições locais reconstruídas a partir do HUD no vídeo do jogo:
# frame nativo = 80x16.
const ICON_POSITION := Vector2(0, 0)
const DIVIDER_POSITION := Vector2(22, 3)
const HP_POSITION := Vector2(32, 3)
const KI_POSITION := Vector2(29, 7)
const XP_POSITION := Vector2(2, 12)

var _sheet: Texture2D
var _player_health: HealthComponent
var _player_ki: KiComponent
var _player_experience: ExperienceComponent
var _special: SpecialAttackComponent
var _xp_ratio: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load_hud_sheet()
	call_deferred("_bind_player")

func _load_hud_sheet() -> void:
	if not ResourceLoader.exists(hud_sheet_path):
		_show_fallback()
		return

	_sheet = load(hud_sheet_path) as Texture2D
	if _sheet == null:
		_show_fallback()
		return

	if _sheet.get_width() < 184 or _sheet.get_height() < 25:
		push_warning(
			"hud.png inesperado. Esperado ao menos 184x25 px, recebido %dx%d."
			% [_sheet.get_width(), _sheet.get_height()]
		)
		_show_fallback()
		return

	fallback.visible = false

	frame.texture = _atlas_region(FRAME_REGION)
	frame.visible = true

	# The old Ki Blast icon is intentionally gone. Ki Blast is a basic
	# attack now; this slot belongs to the currently selected special.
	icon.position = ICON_POSITION
	icon.visible = false

	divider.texture = _atlas_region(DIVIDER_REGION)
	divider.position = DIVIDER_POSITION
	divider.visible = true

	hp_fill.position = HP_POSITION
	ki_fill.position = KI_POSITION
	xp_fill.position = XP_POSITION

	_set_texture_bar(hp_fill, HP_REGION, 1.0)
	_set_texture_bar(ki_fill, KI_REGION, 1.0)
	_set_texture_bar(xp_fill, XP_REGION, _xp_ratio)

func _show_fallback() -> void:
	fallback.visible = true
	frame.visible = false
	icon.visible = false
	divider.visible = false
	hp_fill.visible = false
	ki_fill.visible = false
	xp_fill.visible = false

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
	_set_texture_bar(hp_fill, HP_REGION, ratio)

func _on_ki_changed(current_ki: float, max_ki: float) -> void:
	var safe_max := maxf(max_ki, 1.0)
	var ratio := clampf(current_ki / safe_max, 0.0, 1.0)
	_set_texture_bar(ki_fill, KI_REGION, ratio)

func _on_experience_changed(
	current_experience: int,
	experience_to_next_level: int,
	_current_level: int
) -> void:
	var safe_required := maxi(experience_to_next_level, 1)
	set_experience_ratio(
		float(current_experience) / float(safe_required)
	)

# A barra fina azul/ciano na parte inferior da moldura representa XP.
func set_experience_ratio(ratio: float) -> void:
	_xp_ratio = clampf(ratio, 0.0, 1.0)
	_set_texture_bar(xp_fill, XP_REGION, _xp_ratio)

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
	icon.texture = texture
	icon.visible = texture != null
	icon.tooltip_text = data.display_name

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
	source_region: Rect2,
	ratio: float
) -> void:
	if _sheet == null:
		return

	var safe_ratio := clampf(ratio, 0.0, 1.0)
	var width := floori(source_region.size.x * safe_ratio)

	if width <= 0:
		target.visible = false
		target.size = Vector2(0, source_region.size.y)
		return

	var visible_region := source_region
	visible_region.size.x = float(width)

	target.texture = _atlas_region(visible_region)
	target.size = Vector2(float(width), source_region.size.y)
	target.visible = true

func _atlas_region(region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = _sheet
	atlas.region = region
	return atlas
