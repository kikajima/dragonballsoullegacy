class_name PickupActor
extends Area2D

signal collected

@export_enum("currency", "item")
var pickup_type: String = "currency"

@export var item_id: StringName = &""
@export_range(1, 9999, 1)
var amount: int = 1
@export var bob_height: float = 2.0
@export var bob_speed: float = 4.0
@export var magnet_radius: float = 42.0
@export var magnet_speed: float = 85.0
@export var lifetime: float = 20.0

@onready var visual: Node2D = $Visual
@onready var label: Label = $Visual/Label

var _elapsed: float = 0.0
var _base_visual_position: Vector2
var _player: Node2D

func _ready() -> void:
	_base_visual_position = visual.position
	_player = get_tree().get_first_node_in_group("player") as Node2D
	body_entered.connect(_on_body_entered)
	_refresh_visual()

func _process(delta: float) -> void:
	_elapsed += delta

	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D

	if is_instance_valid(_player):
		var to_player: Vector2 = _player.global_position - global_position
		if (
			to_player.length() <= magnet_radius
			and not to_player.is_zero_approx()
		):
			global_position += (
				to_player.normalized()
				* magnet_speed
				* delta
			)

	visual.position = _base_visual_position + Vector2(
		0.0,
		sin(_elapsed * bob_speed) * bob_height
	)

	if lifetime > 0.0 and _elapsed >= lifetime:
		queue_free()

func configure_currency(value: int) -> void:
	pickup_type = "currency"
	amount = maxi(value, 1)
	if is_node_ready():
		_refresh_visual()

func configure_item(
	new_item_id: StringName,
	new_amount: int = 1
) -> void:
	pickup_type = "item"
	item_id = new_item_id
	amount = maxi(new_amount, 1)
	if is_node_ready():
		_refresh_visual()

func _on_body_entered(body: Node2D) -> void:
	if body == null or not body.is_in_group("player"):
		return

	var collected_amount: int = 0

	if pickup_type == "currency":
		var wallet := body.get_node_or_null(
			"Components/WalletComponent"
		) as WalletComponent
		if wallet != null:
			collected_amount = wallet.add(amount)
	else:
		var inventory := body.get_node_or_null(
			"Components/InventoryComponent"
		) as InventoryComponent
		if inventory != null:
			collected_amount = inventory.add_item(
				item_id,
				amount
			)

	if collected_amount <= 0:
		return

	collected.emit()
	queue_free()

func _refresh_visual() -> void:
	if pickup_type == "currency":
		label.text = "Z"
		$Visual/Diamond.modulate = Color(1.0, 0.8, 0.2, 1.0)
	else:
		label.text = "+"
		$Visual/Diamond.modulate = Color(0.45, 1.0, 0.55, 1.0)
