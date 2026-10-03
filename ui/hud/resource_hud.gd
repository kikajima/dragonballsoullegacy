class_name ResourceHUD
extends Control

const SENZU_ID: StringName = &"senzu_bean"

@onready var level_label: Label = $Panel/Level
@onready var zeni_label: Label = $Panel/Zeni
@onready var item_label: Label = $Panel/QuickItem

var _inventory: InventoryComponent
var _wallet: WalletComponent
var _experience: ExperienceComponent

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(10.0, 53.0)
	size = Vector2(126.0, 26.0)
	call_deferred("_bind_player")

func _bind_player() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return

	_inventory = player.get_node_or_null(
		"Components/InventoryComponent"
	) as InventoryComponent
	_wallet = player.get_node_or_null(
		"Components/WalletComponent"
	) as WalletComponent
	_experience = player.get_node_or_null(
		"Components/ExperienceComponent"
	) as ExperienceComponent

	if _inventory != null:
		_inventory.inventory_changed.connect(_refresh)
	if _wallet != null:
		_wallet.currency_changed.connect(_on_currency_changed)
	if _experience != null:
		_experience.experience_changed.connect(_on_experience_changed)

	_refresh()

func _on_currency_changed(_amount: int) -> void:
	_refresh()

func _on_experience_changed(
	_current_experience: int,
	_experience_to_next_level: int,
	_current_level: int
) -> void:
	_refresh()

func _refresh() -> void:
	var level: int = 1
	if _experience != null:
		level = _experience.current_level

	var zeni: int = 0
	if _wallet != null:
		zeni = _wallet.current_amount

	var senzu: int = 0
	if _inventory != null:
		senzu = _inventory.get_quantity(SENZU_ID)

	level_label.text = "LV %d" % level
	zeni_label.text = "ZENI %d" % zeni
	item_label.text = "Q  SENZU x%d" % senzu
	item_label.modulate = (
		Color.WHITE
		if senzu > 0
		else Color(0.55, 0.58, 0.62, 1.0)
	)
