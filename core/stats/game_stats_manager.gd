class_name GameStatsManager
extends Node

signal stats_changed

var play_time_seconds: float = 0.0
var damage_dealt: int = 0
var damage_taken: int = 0
var enemies_defeated: int = 0
var items_received: int = 0
var zeni_received: int = 0

func _ready() -> void:
	call_deferred("_bind_sources")

func _process(delta: float) -> void:
	if not get_tree().paused:
		play_time_seconds += delta

func register_enemy_defeat() -> void:
	enemies_defeated += 1
	stats_changed.emit()

func _bind_sources() -> void:
	var feedback := get_tree().get_first_node_in_group(
		"combat_feedback"
	) as CombatFeedbackManager
	if feedback != null:
		feedback.hit_reported.connect(_on_hit_reported)

	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return

	var health := player.get_node_or_null(
		"Components/HealthComponent"
	) as HealthComponent
	if health != null:
		health.damaged.connect(_on_player_damaged)

	var inventory := player.get_node_or_null(
		"Components/InventoryComponent"
	) as InventoryComponent
	if inventory != null:
		inventory.item_added.connect(_on_item_added)

	var wallet := player.get_node_or_null(
		"Components/WalletComponent"
	) as WalletComponent
	if wallet != null:
		wallet.currency_gained.connect(_on_currency_gained)

func _on_hit_reported(_target: Node, damage: int) -> void:
	if damage <= 0:
		return

	damage_dealt += damage
	stats_changed.emit()

func _on_player_damaged(
	amount: int,
	_current_health: int,
	_max_health: int
) -> void:
	if amount <= 0:
		return

	damage_taken += amount
	stats_changed.emit()

func _on_item_added(
	_item_id: StringName,
	amount: int,
	_new_total: int
) -> void:
	if amount <= 0:
		return

	items_received += amount
	stats_changed.emit()

func _on_currency_gained(amount: int) -> void:
	if amount <= 0:
		return

	zeni_received += amount
	stats_changed.emit()

func serialize_state() -> Dictionary:
	return {
		"play_time_seconds": play_time_seconds,
		"damage_dealt": damage_dealt,
		"damage_taken": damage_taken,
		"enemies_defeated": enemies_defeated,
		"items_received": items_received,
		"zeni_received": zeni_received,
	}

func load_state(data: Dictionary) -> void:
	play_time_seconds = maxf(
		float(data.get("play_time_seconds", 0.0)),
		0.0
	)
	damage_dealt = maxi(int(data.get("damage_dealt", 0)), 0)
	damage_taken = maxi(int(data.get("damage_taken", 0)), 0)
	enemies_defeated = maxi(
		int(data.get("enemies_defeated", 0)),
		0
	)
	items_received = maxi(
		int(data.get("items_received", 0)),
		0
	)
	zeni_received = maxi(
		int(data.get("zeni_received", 0)),
		0
	)

	stats_changed.emit()
