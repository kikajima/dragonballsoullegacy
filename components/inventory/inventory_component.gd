class_name InventoryComponent
extends Node

# Carried items. Items that are not worn live in the bag, which has a limited
# number of spaces: BASE_CAPACITY without a bag, or the worn bag's
# bag_capacity. Each stack (up to the item's max_stack) takes one space.
# Worn items stay in the item count but take no bag space; the
# EquipmentComponent reports them through set_worn().

signal inventory_changed
signal item_added(item_id: StringName, amount: int, new_total: int)
signal item_removed(item_id: StringName, amount: int, new_total: int)
signal capacity_changed(capacity: int)
# Some or all of an add_item() did not fit in the bag.
signal inventory_full(item_id: StringName, rejected: int)

const BASE_CAPACITY := 5
const DEFAULT_MAX_STACK := 99

var _items: Dictionary = {}
var _worn: Dictionary = {} # item key -> count worn (outside the bag)
var _capacity: int = BASE_CAPACITY

# Adds up to `amount`, as much as fits in the bag. Returns the amount added.
func add_item(item_id: StringName, amount: int = 1) -> int:
	if item_id == &"" or amount <= 0:
		return 0

	var accepted := mini(amount, get_room_for(item_id))
	if accepted < amount:
		inventory_full.emit(item_id, amount - accepted)
	if accepted <= 0:
		return 0

	var key := String(item_id)
	var new_total: int = int(_items.get(key, 0)) + accepted
	_items[key] = new_total
	item_added.emit(item_id, accepted, new_total)
	inventory_changed.emit()
	return accepted

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

# Total carried, worn copies included.
func get_quantity(item_id: StringName) -> int:
	return int(_items.get(String(item_id), 0))

# Copies in the bag (not worn).
func get_bag_quantity(item_id: StringName) -> int:
	return maxi(get_quantity(item_id) - int(_worn.get(String(item_id), 0)), 0)

func get_all_items() -> Dictionary:
	return _items.duplicate(true)

# Bag contents only: item key -> quantity not worn.
func get_bag_items() -> Dictionary:
	var result := {}
	for key in _items.keys():
		var quantity := get_bag_quantity(StringName(key))
		if quantity > 0:
			result[key] = quantity
	return result

# Bag spaces in display order: [{"item_id": StringName, "quantity": int}].
func get_bag_stacks() -> Array[Dictionary]:
	var stacks: Array[Dictionary] = []
	var keys := get_bag_items().keys()
	keys.sort()
	for key in keys:
		var item_id := StringName(key)
		var left := get_bag_quantity(item_id)
		var stack_size := max_stack_of(item_id)
		while left > 0:
			stacks.append({"item_id": item_id, "quantity": mini(left, stack_size)})
			left -= stack_size
	return stacks

func get_capacity() -> int:
	return _capacity

func set_capacity(value: int) -> void:
	value = maxi(value, 0)
	if value == _capacity:
		return
	_capacity = value
	capacity_changed.emit(_capacity)
	inventory_changed.emit()

func get_used_slots() -> int:
	return get_used_slots_with(_worn)

# Spaces the bag would use if `worn` (item key -> count) were worn.
func get_used_slots_with(worn: Dictionary) -> int:
	var used := 0
	for key in _items.keys():
		var in_bag: int = int(_items[key]) - int(worn.get(key, 0))
		used += slots_for(StringName(key), in_bag)
	return used

func get_free_slots() -> int:
	return maxi(_capacity - get_used_slots(), 0)

func is_full() -> bool:
	return get_free_slots() <= 0

# How many more copies of the item fit in the bag.
func get_room_for(item_id: StringName) -> int:
	var stack_size := max_stack_of(item_id)
	var in_bag := get_bag_quantity(item_id)
	var others := get_used_slots() - slots_for(item_id, in_bag)
	return maxi((_capacity - others) * stack_size - in_bag, 0)

func can_add(item_id: StringName, amount: int = 1) -> bool:
	return amount <= get_room_for(item_id)

static func max_stack_of(item_id: StringName) -> int:
	var data := ItemCatalog.get_item(item_id)
	return maxi(data.max_stack, 1) if data != null else DEFAULT_MAX_STACK

static func slots_for(item_id: StringName, quantity: int) -> int:
	if quantity <= 0:
		return 0
	var stack_size := max_stack_of(item_id)
	return int(ceil(float(quantity) / float(stack_size)))

func get_worn() -> Dictionary:
	return _worn.duplicate()

# Called by the EquipmentComponent: item key -> count worn.
func set_worn(worn: Dictionary) -> void:
	var clean := {}
	for key in worn.keys():
		if int(worn[key]) > 0:
			clean[String(key)] = int(worn[key])
	if clean == _worn:
		return
	_worn = clean
	inventory_changed.emit()

func clear() -> void:
	_items.clear()
	inventory_changed.emit()

func serialize_state() -> Dictionary:
	return {
		"items": _items.duplicate(true),
	}

# Saved items are restored even past the capacity (nothing is lost); the bag
# then refuses new items until there is room again.
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
