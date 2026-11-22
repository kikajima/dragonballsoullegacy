class_name SwordRack
extends Area2D

# Wall rack holding the sword in Kame House. Interacting gives the sword
# item once; the rack shows empty while the player carries it.

const SWORD_ID: StringName = &"sword"
const FULL_TEXTURE := preload("res://assets/sprites/equipment/sword/sword_rack_full.png")
const EMPTY_TEXTURE := preload("res://assets/sprites/equipment/sword/sword_rack_empty.png")

var _sprite: Sprite2D

func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = FULL_TEXTURE
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_refresh.call_deferred()

func get_interaction_label() -> String:
	return "Take Sword" if not _player_has_sword() else "Sword Rack"

func interact(actor: Node) -> void:
	var inventory := _inventory_of(actor)
	if inventory == null:
		return
	var dialogue := get_tree().get_first_node_in_group("dialogue_ui") as DialogueBox
	if inventory.has_item(SWORD_ID):
		if dialogue != null:
			dialogue.show_dialogue(
				["The rack is empty. You are carrying the sword."],
				"Sword Rack"
			)
		_refresh()
		return
	if inventory.add_item(SWORD_ID, 1) <= 0:
		if dialogue != null:
			dialogue.show_dialogue(
				["Your bag is full. Make some room to take the sword."],
				"Sword Rack"
			)
		return
	_refresh()
	if dialogue != null:
		dialogue.show_dialogue(
			[
				"You take the sword from the rack.",
				"Press F to equip or put it away, or open the inventory with Tab.",
			],
			"Sword Rack"
		)

func _refresh() -> void:
	if _sprite != null:
		_sprite.texture = EMPTY_TEXTURE if _player_has_sword() else FULL_TEXTURE

func _player_has_sword() -> bool:
	var inventory := _inventory_of(get_tree().get_first_node_in_group("player"))
	return inventory != null and inventory.has_item(SWORD_ID)

func _inventory_of(actor: Node) -> InventoryComponent:
	if actor == null:
		return null
	return actor.get_node_or_null("Components/InventoryComponent") as InventoryComponent
