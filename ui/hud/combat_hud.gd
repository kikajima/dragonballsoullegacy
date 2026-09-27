class_name CombatHUD
extends Control

@export_file("*.png")
var hud_sheet_path: String = "res://assets/ui/legacy/processed/hud.png"

@onready var player_panel: Control = $PlayerPanel
@onready var player_fallback: ColorRect = $PlayerPanel/Fallback
@onready var player_frame: TextureRect = $PlayerPanel/Frame
@onready var player_icon: TextureRect = $PlayerPanel/Icon
@onready var player_hp_fill: ColorRect = $PlayerPanel/HPFill
@onready var player_ki_fill: ColorRect = $PlayerPanel/KiFill

@onready var enemy_panel: Control = $EnemyPanel
@onready var enemy_hp_fill: ColorRect = $EnemyPanel/HPFill

const PLAYER_FRAME_REGION := Rect2(8, 8, 80, 16)
const PLAYER_ICON_REGION := Rect2(137, 13, 21, 13)

const PLAYER_HP_BAR_WIDTH: float = 43.0
const PLAYER_KI_BAR_WIDTH: float = 45.0
const ENEMY_BAR_WIDTH: float = 60.0

var _player_health: HealthComponent
var _player_ki: KiComponent
var _enemy_health: HealthComponent

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_panel.visible = false
	_load_hud_sheet()
	call_deferred("_bind_targets")

func _load_hud_sheet() -> void:
	if not ResourceLoader.exists(hud_sheet_path):
		player_fallback.visible = true
		player_frame.visible = false
		player_icon.visible = false
		return

	var sheet := load(hud_sheet_path) as Texture2D
	if sheet == null:
		player_fallback.visible = true
		player_frame.visible = false
		player_icon.visible = false
		return

	if (
		sheet.get_width() < 158
		or sheet.get_height() < 26
	):
		push_warning(
			"hud.png inesperado. Esperado ao menos 158x26 px, recebido %dx%d."
			% [sheet.get_width(), sheet.get_height()]
		)
		player_fallback.visible = true
		player_frame.visible = false
		player_icon.visible = false
		return

	player_frame.texture = _atlas_region(sheet, PLAYER_FRAME_REGION)
	player_icon.texture = _atlas_region(sheet, PLAYER_ICON_REGION)

	player_fallback.visible = false
	player_frame.visible = true
	player_icon.visible = true

func _atlas_region(sheet: Texture2D, region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = region
	return atlas

func _bind_targets() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		_player_health = player.get_node_or_null("Components/HealthComponent") as HealthComponent
		_player_ki = player.get_node_or_null("Components/KiComponent") as KiComponent

	if _player_health != null:
		_player_health.health_changed.connect(_on_player_health_changed)
		_on_player_health_changed(
			_player_health.current_health,
			_player_health.max_health
		)

	if _player_ki != null:
		_player_ki.ki_changed.connect(_on_player_ki_changed)
		_on_player_ki_changed(
			_player_ki.current_ki,
			_player_ki.max_ki
		)

	# O layout normal replica o HUD compacto do GBA.
	# A barra da direita só aparece para entidades explicitamente no grupo "boss".
	var boss := get_tree().get_first_node_in_group("boss")
	if boss != null:
		_enemy_health = boss.get_node_or_null("Components/HealthComponent") as HealthComponent

	if _enemy_health != null:
		enemy_panel.visible = true
		_enemy_health.health_changed.connect(_on_enemy_health_changed)
		_on_enemy_health_changed(
			_enemy_health.current_health,
			_enemy_health.max_health
		)
	else:
		enemy_panel.visible = false

func _on_player_health_changed(current_health: int, max_health: int) -> void:
	var safe_max := maxi(max_health, 1)
	var ratio := clampf(float(current_health) / float(safe_max), 0.0, 1.0)
	player_hp_fill.size.x = roundf(PLAYER_HP_BAR_WIDTH * ratio)

func _on_player_ki_changed(current_ki: float, max_ki: float) -> void:
	var safe_max := maxf(max_ki, 1.0)
	var ratio := clampf(current_ki / safe_max, 0.0, 1.0)
	player_ki_fill.size.x = roundf(PLAYER_KI_BAR_WIDTH * ratio)

func _on_enemy_health_changed(current_health: int, max_health: int) -> void:
	var safe_max := maxi(max_health, 1)
	var ratio := clampf(float(current_health) / float(safe_max), 0.0, 1.0)
	enemy_hp_fill.size.x = roundf(ENEMY_BAR_WIDTH * ratio)
