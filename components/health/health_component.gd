class_name HealthComponent
extends Node

signal health_changed(current_health: int, max_health: int)
signal damaged(amount: int, current_health: int, max_health: int)
signal healed(amount: int, current_health: int, max_health: int)
signal died

@export_range(1, 100000, 1)
var max_health: int = 100

var current_health: int

func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)

func take_damage(amount: int) -> int:
	if amount <= 0 or current_health <= 0:
		return 0

	var applied_damage := mini(amount, current_health)
	current_health -= applied_damage
	damaged.emit(applied_damage, current_health, max_health)
	health_changed.emit(current_health, max_health)

	if current_health <= 0:
		died.emit()

	return applied_damage

func heal(amount: int) -> int:
	if amount <= 0 or current_health <= 0:
		return 0

	var previous_health := current_health
	current_health = mini(current_health + amount, max_health)
	var applied_heal := current_health - previous_health

	if applied_heal > 0:
		healed.emit(applied_heal, current_health, max_health)
		health_changed.emit(current_health, max_health)

	return applied_heal

func restore_full() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)

func increase_max_health(amount: int, restore_added: bool = true) -> void:
	if amount <= 0:
		return

	max_health += amount

	if restore_added:
		current_health = mini(current_health + amount, max_health)
	else:
		current_health = mini(current_health, max_health)

	health_changed.emit(current_health, max_health)

func is_dead() -> bool:
	return current_health <= 0

func get_health_ratio() -> float:
	return float(current_health) / float(max_health)
