class_name InventoryComponent
extends Node

signal inventory_changed
signal item_added(item_id: StringName, amount: int, new_total: int)
signal item_removed(item_id: StringName, amount: int, new_total: int)

var _items: Dictionary = {}

func add_item(item_id: StringName, amount: int = 1) -> int:
	if item_id == &"" or amount <= 0:
		return 0

	var key := String(item_id)
	var current: int = int(_items.get(key, 0))
	var new_total: int = current + amount

	_items[key] = new_total
	item_added.emit(item_id, amount, new_total)
	inventory_changed.emit()
	return amount

func remove_item(item_id: StringName, amount: int = 1) -> int:
	if item_id == &"" or amount <= 0:
		return 0

	var key := String(item_id)
	var current: int = int(_items.get(key, 0))
	if current <= 0:
		return 0

	var removed: int = mini(amount, current)
	var new_total: int = current - removed

	if new_total <= 0:
		_items.erase(key)
	else:
		_items[key] = new_total

	item_removed.emit(item_id, removed, new_total)
	inventory_changed.emit()
	return removed

func has_item(item_id: StringName, amount: int = 1) -> bool:
	return get_quantity(item_id) >= maxi(amount, 1)

func get_quantity(item_id: StringName) -> int:
	return int(_items.get(String(item_id), 0))

func get_all_items() -> Dictionary:
	return _items.duplicate(true)

func clear() -> void:
	_items.clear()
	inventory_changed.emit()

func serialize_state() -> Dictionary:
	return {
		"items": _items.duplicate(true),
	}

func load_state(data: Dictionary) -> void:
	_items.clear()

	var items_value: Variant = data.get("items", {})
	if items_value is Dictionary:
		var items: Dictionary = items_value as Dictionary
		for key in items.keys():
			var quantity: int = maxi(int(items[key]), 0)
			if quantity > 0:
				_items[String(key)] = quantity

	inventory_changed.emit()
