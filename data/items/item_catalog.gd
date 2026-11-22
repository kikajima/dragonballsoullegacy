class_name ItemCatalog
extends RefCounted

# Static registry of item definitions, keyed by item_id: the .tres items
# below plus the code-defined ones in item_table.gd.

const TABLE = preload("res://data/items/item_table.gd")

const ITEM_PATHS: Array[String] = [
	"res://data/items/senzu_bean.tres",
	"res://data/items/sword.tres",
	"res://data/items/small_pouch.tres",
	"res://data/items/travel_bag.tres",
	"res://data/items/capsule_case.tres",
]

# Prices for the .tres items, which predate the price fields.
const TRES_PRICES := {
	"senzu_bean": [500, 120, &"food"],
	"small_pouch": [80, 40, &"gear"],
	"travel_bag": [260, 120, &"gear"],
	"capsule_case": [900, 400, &"gear"],
	"sword": [0, 0, &"gear"],
}

static var _items: Dictionary = {}

static func get_item(item_id: StringName) -> ItemData:
	_ensure_loaded()
	var data := _items.get(String(item_id)) as ItemData
	if data != null and data.icon == null and not data.icon_dmi.is_empty():
		data.icon = _dmi_icon(data.icon_dmi, data.icon_state)
		data.icon_dmi = ""
	return data

static func has_item(item_id: StringName) -> bool:
	_ensure_loaded()
	return _items.has(String(item_id))

static func get_all_ids() -> Array[StringName]:
	_ensure_loaded()
	var ids: Array[StringName] = []
	for key in _items.keys():
		ids.append(StringName(key))
	return ids

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
			var prices: Array = TRES_PRICES.get(String(data.item_id), [])
			if prices.size() == 3:
				data.buy_price = prices[0]
				data.sell_value = maxi(data.sell_value, prices[1])
				data.category = prices[2]
			_items[String(data.item_id)] = data
	for entry: Dictionary in TABLE.ITEMS:
		var data := _from_entry(entry)
		_items[String(data.item_id)] = data

static func _from_entry(entry: Dictionary) -> ItemData:
	var data := ItemData.new()
	data.item_id = entry["id"]
	data.display_name = entry.get("name", "")
	data.description = entry.get("description", "")
	data.category = entry.get("category", &"")
	data.consumable = entry.get("consumable", false)
	data.heal_amount = entry.get("heal", 0)
	data.ki_restore_amount = entry.get("ki", 0.0)
	data.sell_value = entry.get("sell", 0)
	data.buy_price = entry.get("buy", 0)
	data.equipment_slot = entry.get("slot", &"")
	data.melee_damage_bonus = entry.get("melee", 0)
	data.defense_bonus = entry.get("defense", 0)
	data.max_stack = entry.get("stack", 1 if data.is_equipment() else 99)
	data.icon_dmi = entry.get("dmi", "")
	data.icon_state = entry.get("state", "")
	return data

# The state's first frame cropped to its pixels, so it sits centered in a
# bag cell.
static func _dmi_icon(path: String, state: String) -> Texture2D:
	var dmi := DmiSpriteSheet.load_file(path)
	if dmi == null or not dmi.has_state(StringName(state)):
		return null
	var frame := dmi.get_frame_texture(StringName(state), &"down", 0)
	if frame == null:
		return null
	var image := frame.get_image()
	if image == null:
		return frame
	image.convert(Image.FORMAT_RGBA8)
	var used := image.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return frame
	return ImageTexture.create_from_image(image.get_region(used))
