class_name KiComponent
extends Node

signal ki_changed(current_ki: float, max_ki: float)
signal ki_consumed(amount: float)
signal ki_restored(amount: float)

@export_range(1.0, 100000.0, 1.0)
var max_ki: float = 100.0

@export_range(0.0, 100000.0, 1.0)
var starting_ki: float = 100.0

var current_ki: float

func _ready() -> void:
	current_ki = clampf(starting_ki, 0.0, max_ki)
	ki_changed.emit(current_ki, max_ki)

func can_consume(amount: float) -> bool:
	return amount <= 0.0 or current_ki >= amount

func consume(amount: float) -> bool:
	if amount <= 0.0:
		return true

	if current_ki < amount:
		return false

	current_ki -= amount
	ki_consumed.emit(amount)
	ki_changed.emit(current_ki, max_ki)
	return true

func consume_up_to(amount: float, reserve: float = 0.0) -> float:
	if amount <= 0.0:
		return 0.0

	var available: float = maxf(
		current_ki - maxf(reserve, 0.0),
		0.0
	)
	var consumed: float = minf(amount, available)
	if consumed <= 0.0:
		return 0.0

	current_ki -= consumed
	ki_consumed.emit(consumed)
	ki_changed.emit(current_ki, max_ki)
	return consumed

func restore(amount: float) -> float:
	if amount <= 0.0:
		return 0.0

	var previous_ki := current_ki
	current_ki = minf(current_ki + amount, max_ki)
	var restored := current_ki - previous_ki

	if restored > 0.0:
		ki_restored.emit(restored)
		ki_changed.emit(current_ki, max_ki)

	return restored

func restore_full() -> void:
	current_ki = max_ki
	ki_changed.emit(current_ki, max_ki)

func increase_max_ki(amount: float, restore_added: bool = true) -> void:
	if amount <= 0.0:
		return

	max_ki += amount

	if restore_added:
		current_ki = minf(current_ki + amount, max_ki)
	else:
		current_ki = minf(current_ki, max_ki)

	ki_changed.emit(current_ki, max_ki)

func get_ki_ratio() -> float:
	return current_ki / max_ki
