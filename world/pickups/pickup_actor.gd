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
@export var magnet_radius: float = 52.0
@export var magnet_speed: float = 105.0
@export var lifetime: float = 20.0

@onready var visual: Node2D = $Visual
@onready var label: Label = $Visual/Label

var _elapsed: float = 0.0
var _base_visual_position: Vector2
var _player: Node2D
var _collecting: bool = false

func _ready() -> void:
	_base_visual_position = visual.position
	_player = get_tree().get_first_node_in_group("player") as Node2D
	body_entered.connect(_on_body_entered)
	_refresh_visual()

func _process(delta: float) -> void:
	_elapsed += delta

	if _collecting:
		return

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
	visual.rotation = sin(_elapsed * 2.2) * 0.10
	var pulse: float = 1.0 + sin(_elapsed * 5.0) * 0.04
	visual.scale = Vector2(pulse, pulse)

	if lifetime > 0.0 and _elapsed >= lifetime:
		_fade_out()

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
	if (
		_collecting
		or body == null
		or not body.is_in_group("player")
	):
		return

	var collected_amount: int = 0

	if pickup_type == "currency":
		var wallet: WalletComponent = body.get_node_or_null(
			"Components/WalletComponent"
		) as WalletComponent
		if wallet != null:
			collected_amount = wallet.add(amount)
	else:
		var inventory: InventoryComponent = body.get_node_or_null(
			"Components/InventoryComponent"
		) as InventoryComponent
		if inventory != null:
			collected_amount = inventory.add_item(
				item_id,
				amount
			)

	if collected_amount <= 0:
		return

	_collecting = true
	set_deferred("monitoring", false)
	collected.emit()
	_show_collection_feedback(collected_amount)
	_play_collect_animation()

func _show_collection_feedback(collected_amount: int) -> void:
	var feedback: CombatFeedbackManager = (
		get_tree().get_first_node_in_group("combat_feedback")
		as CombatFeedbackManager
	)
	if feedback == null:
		return

	var text_value: String = ""
	var text_color: Color = Color.WHITE
	if pickup_type == "currency":
		text_value = "+%d ZENI" % collected_amount
		text_color = Color(1.0, 0.86, 0.28, 1.0)
	else:
		var item_name: String = String(item_id).replace("_", " ").capitalize()
		text_value = "+%d %s" % [collected_amount, item_name]
		text_color = Color(0.48, 1.0, 0.58, 1.0)

	feedback.spawn_floating_text(
		text_value,
		global_position + Vector2(0, -14),
		text_color
	)

func _play_collect_animation() -> void:
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(
		visual,
		"scale",
		Vector2(1.55, 1.55),
		0.12
	)
	tween.tween_property(
		visual,
		"modulate",
		Color(1, 1, 1, 0),
		0.12
	)
	tween.tween_property(
		visual,
		"position",
		_base_visual_position + Vector2(0, -10),
		0.12
	)
	tween.set_parallel(false)
	tween.tween_callback(Callable(self, "queue_free"))

func _fade_out() -> void:
	if _collecting:
		return
	_collecting = true
	set_deferred("monitoring", false)

	var tween: Tween = create_tween()
	tween.tween_property(
		visual,
		"modulate",
		Color(1, 1, 1, 0),
		0.25
	)
	tween.tween_callback(Callable(self, "queue_free"))

func _refresh_visual() -> void:
	if pickup_type == "currency":
		label.text = "Z"
		$Visual/Diamond.modulate = Color(1.0, 0.8, 0.2, 1.0)
		var currency_scale: float = clampf(
			1.0 + log(float(maxi(amount, 1))) * 0.08,
			1.0,
			1.35
		)
		visual.scale = Vector2.ONE * currency_scale
	else:
		label.text = "+"
		$Visual/Diamond.modulate = Color(0.45, 1.0, 0.55, 1.0)
