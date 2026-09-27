class_name TransformationComponent
extends Node

signal transformation_unlocked(transformation_id: StringName)
signal transformation_started(transformation_id: StringName)
signal transformation_ended(transformation_id: StringName)

@export var ki_component_path: NodePath

@onready var ki_component: KiComponent = (
	get_node(ki_component_path) as KiComponent
)

var _unlocked: Dictionary = {}
var _definitions: Dictionary = {}
var active_transformation: StringName = &""

func _process(delta: float) -> void:
	if active_transformation == &"":
		return

	var definition := get_definition(active_transformation)
	if definition == null:
		end_transformation()
		return

	if definition.ki_drain_per_second <= 0.0:
		return

	var drain: float = definition.ki_drain_per_second * delta
	if not ki_component.consume(drain):
		end_transformation()

func register_transformation(
	definition: TransformationData
) -> void:
	if definition == null or definition.transformation_id == &"":
		return

	_definitions[String(definition.transformation_id)] = definition

func unlock(transformation_id: StringName) -> bool:
	if transformation_id == &"":
		return false

	var key := String(transformation_id)
	if bool(_unlocked.get(key, false)):
		return false

	_unlocked[key] = true
	transformation_unlocked.emit(transformation_id)
	return true

func is_unlocked(transformation_id: StringName) -> bool:
	return bool(_unlocked.get(String(transformation_id), false))

func start_transformation(
	transformation_id: StringName,
	current_level: int
) -> bool:
	if not is_unlocked(transformation_id):
		return false

	var definition := get_definition(transformation_id)
	if definition == null:
		return false

	if current_level < definition.minimum_level:
		return false

	if not ki_component.consume(definition.ki_activation_cost):
		return false

	if active_transformation != &"":
		end_transformation()

	active_transformation = transformation_id
	transformation_started.emit(transformation_id)
	return true

func end_transformation() -> void:
	if active_transformation == &"":
		return

	var previous := active_transformation
	active_transformation = &""
	transformation_ended.emit(previous)

func get_definition(
	transformation_id: StringName
) -> TransformationData:
	var value: Variant = _definitions.get(
		String(transformation_id),
		null
	)
	return value as TransformationData

func get_damage_multiplier() -> float:
	var definition := get_definition(active_transformation)
	return definition.damage_multiplier if definition != null else 1.0

func get_movement_multiplier() -> float:
	var definition := get_definition(active_transformation)
	return definition.movement_multiplier if definition != null else 1.0

func serialize_state() -> Dictionary:
	var unlocked: Array[String] = []
	for key in _unlocked.keys():
		if bool(_unlocked[key]):
			unlocked.append(String(key))

	return {
		"unlocked": unlocked,
		"active": String(active_transformation),
	}

func load_state(data: Dictionary) -> void:
	_unlocked.clear()

	var unlocked_value: Variant = data.get("unlocked", [])
	if unlocked_value is Array:
		for value in unlocked_value as Array:
			_unlocked[str(value)] = true

	active_transformation = StringName(
		str(data.get("active", ""))
	)
