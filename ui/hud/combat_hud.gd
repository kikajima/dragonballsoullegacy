class_name CombatHUD
extends Control

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

	# O vídeo de referência começa usando o ícone amarelo.
	# O azul fica disponível para o futuro sistema de seleção de técnicas.
	icon.texture = _atlas_region(ICON_YELLOW_REGION)
	icon.position = ICON_POSITION
	icon.visible = true

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

# Preparado para o sistema de experiência. O vídeo mostra esta barra
# fina azul/ciano na parte inferior da moldura.
func set_experience_ratio(ratio: float) -> void:
	_xp_ratio = clampf(ratio, 0.0, 1.0)
	_set_texture_bar(xp_fill, XP_REGION, _xp_ratio)

# Preparado para o futuro seletor de técnica/ícone.
func set_energy_icon_blue(use_blue: bool) -> void:
	if _sheet == null:
		return

	icon.texture = _atlas_region(
		ICON_BLUE_REGION if use_blue else ICON_YELLOW_REGION
	)

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
