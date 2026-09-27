class_name LootTableComponent
extends Node

@export var entries: Array[LootEntryData] = []

func roll_loot() -> Dictionary:
	var result: Dictionary = {}

	for entry in entries:
		if entry == null or entry.item_id == &"":
			continue

		if randf() > clampf(entry.chance, 0.0, 1.0):
			continue

		var minimum: int = maxi(entry.min_amount, 1)
		var maximum: int = maxi(entry.max_amount, minimum)
		var amount: int = randi_range(minimum, maximum)
		var key := String(entry.item_id)

		result[key] = int(result.get(key, 0)) + amount

	return result

func grant_to_inventory(inventory: InventoryComponent) -> Dictionary:
	var loot := roll_loot()
	if inventory == null:
		return loot

	for key in loot.keys():
		inventory.add_item(
			StringName(str(key)),
			int(loot[key])
		)

	return loot
