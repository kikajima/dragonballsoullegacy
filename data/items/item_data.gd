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
