class_name ItemStash
extends Area2D

# A spot holding one item (e.g. a bag on a wall hook). Interacting gives the
# item once; the spot shows empty while the player carries it.

@export var item_id: StringName = &"small_pouch"
@export var place_name: String = "Wall Hook"

var _sprite: Sprite2D

func _ready() -> void:
	_sprite = Sprite2D.new()
	var data := ItemCatalog.get_item(item_id)
	_sprite.texture = data.icon if data != null else null
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_refresh.call_deferred()

func get_interaction_label() -> String:
	return place_name if _player_has_item() else "Take %s" % ItemCatalog.get_display_name(item_id)

func interact(actor: Node) -> void:
	var inventory := actor.get_node_or_null("Components/InventoryComponent") as InventoryComponent
	if inventory == null:
		return
	var dialogue := get_tree().get_first_node_in_group("dialogue_ui") as DialogueBox
	var item_name := ItemCatalog.get_display_name(item_id)
	if inventory.has_item(item_id):
		_say(dialogue, ["It's empty. You already carry the %s." % item_name])
	elif inventory.add_item(item_id, 1) <= 0:
		_say(dialogue, ["Your bag is full. Make some room to take the %s." % item_name])
	else:
		_say(dialogue, [
			"You take the %s." % item_name,
			"Open the inventory with Tab and equip it in the Bag slot for more space.",
		])
	_refresh()

func _say(dialogue: DialogueBox, pages: Array[String]) -> void:
	if dialogue != null:
		dialogue.show_dialogue(pages, place_name)

func _refresh() -> void:
	if _sprite != null:
		_sprite.visible = not _player_has_item()

func _process(_delta: float) -> void:
	if Engine.get_process_frames() % 30 == 0:
		_refresh()

func _player_has_item() -> bool:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return false
	var inventory := player.get_node_or_null("Components/InventoryComponent") as InventoryComponent
	return inventory != null and inventory.has_item(item_id)
