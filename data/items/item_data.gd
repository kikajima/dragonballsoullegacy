class_name ItemData
extends Resource

@export var item_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export_range(1, 999, 1) var max_stack: int = 99
@export var consumable: bool = false
@export var heal_amount: int = 0
@export var ki_restore_amount: float = 0.0
@export var sell_value: int = 0

# Equipment. An item with an equipment slot can be worn through the
# EquipmentComponent; it stays in the inventory while equipped.
@export var equipment_slot: StringName = &""
# Attack style the item gives to the basic attack button (&"sword", ...).
@export var weapon_style: StringName = &""
@export var melee_damage_bonus: int = 0
# Bags (equipment_slot "bag"): total bag spaces while this bag is worn. With
# no bag the character carries InventoryComponent.BASE_CAPACITY spaces.
@export_range(0, 99, 1) var bag_capacity: int = 0
# Damage taken is reduced by the summed defense of everything worn.
@export var defense_bonus: int = 0
@export var icon: Texture2D
# Icon read from a HU2 .dmi state when `icon` is empty (see ItemCatalog).
@export var icon_dmi: String = ""
@export var icon_state: String = ""
# "material", "food", "gear", "key"... Shown in shops and the crafting menu.
@export var category: StringName = &""
# Shop price; 0 means "sell_value x 2".
@export var buy_price: int = 0

func is_equipment() -> bool:
	return equipment_slot != &""

func get_buy_price() -> int:
	return buy_price if buy_price > 0 else maxi(sell_value * 2, 1)

func is_bag() -> bool:
	return equipment_slot == &"bag" and bag_capacity > 0
