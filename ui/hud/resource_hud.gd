class_name ResourceHUD
extends Control

const SENZU_ID: StringName = &"senzu_bean"

@onready var zeni_label: Label = $Panel/Zeni
@onready var item_label: Label = $Panel/QuickItem

var _inventory: InventoryComponent
var _wallet: WalletComponent

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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

	if _inventory != null:
		_inventory.inventory_changed.connect(_refresh)
	if _wallet != null:
		_wallet.currency_changed.connect(_on_currency_changed)

	_refresh()

func _on_currency_changed(_amount: int) -> void:
	_refresh()

func _refresh() -> void:
	var zeni: int = 0
	if _wallet != null:
		zeni = _wallet.current_amount

	var senzu: int = 0
	if _inventory != null:
		senzu = _inventory.get_quantity(SENZU_ID)

	zeni_label.text = "ZENI %d" % zeni
	item_label.text = "Q  SENZU x%d" % senzu
	item_label.modulate = (
		Color.WHITE
		if senzu > 0
		else Color(0.55, 0.58, 0.62, 1.0)
	)
