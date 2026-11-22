class_name ConsumableComponent
extends Node

signal item_used(item_id: StringName)
signal item_use_failed(item_id: StringName)

@export var inventory_component_path: NodePath
@export var health_component_path: NodePath
@export var ki_component_path: NodePath

@onready var inventory: InventoryComponent = (
	get_node(inventory_component_path) as InventoryComponent
)
@onready var health: HealthComponent = (
	get_node(health_component_path) as HealthComponent
)
@onready var ki: KiComponent = (
	get_node(ki_component_path) as KiComponent
)

func use_item(item_id: StringName) -> bool:
	if item_id == &"" or not inventory.has_item(item_id):
		item_use_failed.emit(item_id)
		return false

	if item_id == &"senzu_bean":
		if health.current_health >= health.max_health and ki.current_ki >= ki.max_ki:
			item_use_failed.emit(item_id)
			return false
		if inventory.remove_item(item_id, 1) <= 0:
			item_use_failed.emit(item_id)
			return false
		health.restore_full()
		ki.restore_full()
		item_used.emit(item_id)
		return true

	# Food and drink: whatever HP and Ki the item restores.
	var data := ItemCatalog.get_item(item_id)
	if data == null or not data.consumable:
		item_use_failed.emit(item_id)
		return false
	var needs_health := data.heal_amount > 0 and health.current_health < health.max_health
	var needs_ki := data.ki_restore_amount > 0.0 and ki.current_ki < ki.max_ki - 0.001
	if not needs_health and not needs_ki:
		item_use_failed.emit(item_id)
		return false
	if inventory.remove_item(item_id, 1) <= 0:
		item_use_failed.emit(item_id)
		return false
	if data.heal_amount > 0:
		health.heal(data.heal_amount)
	if data.ki_restore_amount > 0.0:
		ki.restore(data.ki_restore_amount)
	item_used.emit(item_id)
	return true
