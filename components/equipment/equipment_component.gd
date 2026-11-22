class_name EquipmentComponent
extends Node

# Worn equipment. Items stay in the InventoryComponent count while worn but
# leave the bag: the component reports worn items to the inventory so they
# take no bag space, and the worn bag sets the bag capacity.
# Equipping or unequipping fails with REASON_BAG_FULL when the bag could not
# hold what would come back into it.

signal equipment_changed(slot: StringName, item_id: StringName)
signal equip_failed(item_id: StringName, reason: String)

const SLOT_HELMET: StringName = &"helmet"
const SLOT_AMULET: StringName = &"amulet"
const SLOT_ARMOR: StringName = &"armor"
const SLOT_GLOVES: StringName = &"gloves"
const SLOT_RING: StringName = &"ring"
const SLOT_WEAPON: StringName = &"weapon"
const SLOT_PANTS: StringName = &"pants"
const SLOT_BOOTS: StringName = &"boots"
const SLOT_BAG: StringName = &"bag"

const SLOTS: Array[StringName] = [
	SLOT_HELMET, SLOT_AMULET, SLOT_ARMOR, SLOT_GLOVES, SLOT_RING,
	SLOT_WEAPON, SLOT_PANTS, SLOT_BOOTS, SLOT_BAG,
]
const SLOT_NAMES := {
	&"helmet": "Helmet", &"amulet": "Amulet", &"armor": "Armor",
	&"gloves": "Gloves", &"ring": "Ring", &"weapon": "Weapon",
	&"pants": "Pants", &"boots": "Boots", &"bag": "Bag",
}

const REASON_NOT_EQUIPPABLE := "NOT EQUIPPABLE"
const REASON_MISSING := "MISSING ITEM"
const REASON_BAG_FULL := "BAG FULL"

@export var inventory_component_path: NodePath

@onready var inventory: InventoryComponent = (
	get_node_or_null(inventory_component_path) as InventoryComponent
)

var _slots: Dictionary = {}

func _ready() -> void:
	if inventory != null:
		inventory.inventory_changed.connect(_on_inventory_changed)
	_sync_inventory()

static func slot_name(slot: StringName) -> String:
	return SLOT_NAMES.get(slot, String(slot).capitalize())

func equip(item_id: StringName) -> bool:
	var data := ItemCatalog.get_item(item_id)
	if data == null or not data.is_equipment():
		equip_failed.emit(item_id, REASON_NOT_EQUIPPABLE)
		return false
	if inventory != null and not inventory.has_item(item_id):
		equip_failed.emit(item_id, REASON_MISSING)
		return false
	if get_equipped(data.equipment_slot) == item_id:
		return true
	var after := _slots.duplicate()
	after[String(data.equipment_slot)] = String(item_id)
	if not _bag_fits(after):
		equip_failed.emit(item_id, REASON_BAG_FULL)
		return false
	_slots = after
	_sync_inventory()
	equipment_changed.emit(data.equipment_slot, item_id)
	return true

# Puts the slot's item back in the bag. Fails when the bag has no room for
# it (or, for the bag slot, when the items would not fit without the bag).
func unequip(slot: StringName) -> bool:
	if not _slots.has(String(slot)):
		return false
	var item_id := get_equipped(slot)
	var after := _slots.duplicate()
	after.erase(String(slot))
	if not _bag_fits(after):
		equip_failed.emit(item_id, REASON_BAG_FULL)
		return false
	_slots = after
	_sync_inventory()
	equipment_changed.emit(slot, &"")
	return true

# Equip the item, or unequip it when it is already worn. Returns true when
# the item ends up equipped.
func toggle(item_id: StringName) -> bool:
	var data := ItemCatalog.get_item(item_id)
	if data == null or not data.is_equipment():
		equip_failed.emit(item_id, REASON_NOT_EQUIPPABLE)
		return false
	if get_equipped(data.equipment_slot) == item_id:
		return not unequip(data.equipment_slot)
	return equip(item_id)

func get_equipped(slot: StringName) -> StringName:
	return StringName(str(_slots.get(String(slot), "")))

func get_equipped_data(slot: StringName) -> ItemData:
	var item_id := get_equipped(slot)
	return ItemCatalog.get_item(item_id) if item_id != &"" else null

func is_equipped(item_id: StringName) -> bool:
	return item_id != &"" and _slots.values().has(String(item_id))

# Melee damage added by everything worn (weapon, armbands...).
func get_total_melee_bonus() -> int:
	var total := 0
	for slot in SLOTS:
		var data := get_equipped_data(slot)
		if data != null:
			total += data.melee_damage_bonus
	return total

# Damage taken off every hit by everything worn.
func get_total_defense() -> int:
	var total := 0
	for slot in SLOTS:
		var data := get_equipped_data(slot)
		if data != null:
			total += data.defense_bonus
	return total

func get_weapon_data() -> ItemData:
	return get_equipped_data(SLOT_WEAPON)

func get_weapon_style() -> StringName:
	var data := get_weapon_data()
	return data.weapon_style if data != null else &""

func has_weapon_style(style: StringName) -> bool:
	return style != &"" and get_weapon_style() == style

# Bag spaces given by the worn bag (BASE_CAPACITY without one).
func get_bag_capacity() -> int:
	return _capacity_for(_slots)

# First weapon in the bag (used by the quick-equip key).
func find_inventory_weapon() -> StringName:
	if inventory == null:
		return &""
	for key in inventory.get_bag_items().keys():
		var data := ItemCatalog.get_item(StringName(key))
		if data != null and data.equipment_slot == SLOT_WEAPON:
			return data.item_id
	return &""

func clear() -> void:
	var slots := _slots.keys()
	_slots.clear()
	_sync_inventory()
	for slot in slots:
		equipment_changed.emit(StringName(slot), &"")

func serialize_state() -> Dictionary:
	return {"slots": _slots.duplicate(true)}

func load_state(data: Dictionary) -> void:
	var previous := _slots.duplicate()
	_slots.clear()
	var slots_value: Variant = data.get("slots", {})
	if slots_value is Dictionary:
		for slot in (slots_value as Dictionary).keys():
			var item_id := StringName(str(slots_value[slot]))
			var item := ItemCatalog.get_item(item_id)
			if item == null or item.equipment_slot != StringName(slot):
				continue
			if inventory != null and not inventory.has_item(item_id):
				continue
			_slots[String(slot)] = String(item_id)
	_sync_inventory()
	for slot in previous.keys():
		if not _slots.has(slot):
			equipment_changed.emit(StringName(slot), &"")
	for slot in _slots.keys():
		if str(previous.get(slot, "")) != str(_slots[slot]):
			equipment_changed.emit(StringName(slot), StringName(_slots[slot]))

# The change is allowed when the bag fits after it, or at least does not get
# more overfull (a save restored past the capacity can still be sorted out).
func _bag_fits(after: Dictionary) -> bool:
	if inventory == null:
		return true
	var bonus := inventory.get_bonus_capacity()
	var over_after := inventory.get_used_slots_with(_worn_of(after)) - _capacity_for(after) - bonus
	var over_now := inventory.get_used_slots_with(_worn_of(_slots)) - _capacity_for(_slots) - bonus
	return over_after <= 0 or over_after <= over_now

func _worn_of(slots: Dictionary) -> Dictionary:
	var worn := {}
	for slot in slots.keys():
		var key := str(slots[slot])
		worn[key] = int(worn.get(key, 0)) + 1
	return worn

func _capacity_for(slots: Dictionary) -> int:
	var bag := ItemCatalog.get_item(StringName(str(slots.get(String(SLOT_BAG), ""))))
	if bag != null and bag.is_bag():
		return bag.bag_capacity
	return InventoryComponent.BASE_CAPACITY

func _sync_inventory() -> void:
	if inventory == null:
		return
	inventory.set_worn(_worn_of(_slots))
	inventory.set_capacity(_capacity_for(_slots))

func _on_inventory_changed() -> void:
	if inventory == null:
		return
	var dropped: Array[StringName] = []
	for slot in _slots.keys():
		if not inventory.has_item(StringName(_slots[slot])):
			dropped.append(StringName(slot))
	if dropped.is_empty():
		return
	for slot in dropped:
		_slots.erase(String(slot))
	_sync_inventory()
	for slot in dropped:
		equipment_changed.emit(slot, &"")
