class_name ItemCatalog
extends RefCounted

# Static registry of item definitions, keyed by item_id.

const ITEM_PATHS: Array[String] = [
	"res://data/items/senzu_bean.tres",
	"res://data/items/sword.tres",
]

static var _items: Dictionary = {}

static func get_item(item_id: StringName) -> ItemData:
	_ensure_loaded()
	return _items.get(String(item_id)) as ItemData

static func get_display_name(item_id: StringName) -> String:
	var data := get_item(item_id)
	if data != null and not data.display_name.is_empty():
		return data.display_name
	return String(item_id).replace("_", " ").capitalize()

static func _ensure_loaded() -> void:
	if not _items.is_empty():
		return
	for path in ITEM_PATHS:
		var data := load(path) as ItemData
		if data != null and data.item_id != &"":
			_items[String(data.item_id)] = data
