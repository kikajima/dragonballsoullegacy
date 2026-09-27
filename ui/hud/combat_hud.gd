class_name CombatHUD
extends Control

@export_file("*.png")
var player_panel_path: String = "res://assets/ui/legacy/processed/player_hud_panel.png"

@export_file("*.png")
var enemy_panel_path: String = "res://assets/ui/legacy/processed/enemy_hud_panel.png"

@onready var player_panel_texture: TextureRect = $PlayerPanel/PanelTexture
@onready var player_fallback: ColorRect = $PlayerPanel/Fallback
@onready var player_hp_fill: ColorRect = $PlayerPanel/HPFill
@onready var player_ki_fill: ColorRect = $PlayerPanel/KiFill

@onready var enemy_panel: Control = $EnemyPanel
@onready var enemy_panel_texture: TextureRect = $EnemyPanel/PanelTexture
@onready var enemy_fallback: ColorRect = $EnemyPanel/Fallback
@onready var enemy_hp_fill: ColorRect = $EnemyPanel/HPFill

const PLAYER_HP_BAR_WIDTH: float = 39.0
const PLAYER_KI_BAR_WIDTH: float = 43.0
const ENEMY_BAR_WIDTH: float = 60.0

var _player_health: HealthComponent
var _player_ki: KiComponent
var _enemy_health: HealthComponent

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_panel.visible = false
	_load_local_hud_textures()
	call_deferred("_bind_targets")

func _load_local_hud_textures() -> void:
	if ResourceLoader.exists(player_panel_path):
		var texture := load(player_panel_path) as Texture2D
		if texture != null:
			player_panel_texture.texture = texture
			player_panel_texture.visible = true
			player_fallback.visible = false

	if ResourceLoader.exists(enemy_panel_path):
		var texture := load(enemy_panel_path) as Texture2D
		if texture != null:
			enemy_panel_texture.texture = texture
			enemy_panel_texture.visible = true
			enemy_fallback.visible = false

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

	# A HUD normal do GBA mostra somente o status do jogador.
	# A barra do canto direito fica reservada para futuros inimigos marcados
	# explicitamente como "boss", em vez de aparecer para qualquer inimigo.
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
