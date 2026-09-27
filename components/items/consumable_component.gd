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

	match item_id:
		&"senzu_bean":
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
		_:
			item_use_failed.emit(item_id)
			return false
