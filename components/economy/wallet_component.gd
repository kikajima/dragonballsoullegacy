class_name WalletComponent
extends Node

signal currency_changed(current_amount: int)
signal currency_gained(amount: int)
signal currency_spent(amount: int)

@export var starting_amount: int = 0

var current_amount: int = 0

func _ready() -> void:
	current_amount = maxi(starting_amount, 0)
	currency_changed.emit(current_amount)

func add(amount: int) -> int:
	if amount <= 0:
		return 0

	current_amount += amount
	currency_gained.emit(amount)
	currency_changed.emit(current_amount)
	return amount

func can_afford(amount: int) -> bool:
	return amount <= 0 or current_amount >= amount

func spend(amount: int) -> bool:
	if amount <= 0:
		return true

	if current_amount < amount:
		return false

	current_amount -= amount
	currency_spent.emit(amount)
	currency_changed.emit(current_amount)
	return true

func serialize_state() -> Dictionary:
	return {
		"current_amount": current_amount,
	}

func load_state(data: Dictionary) -> void:
	current_amount = maxi(
		int(data.get("current_amount", 0)),
		0
	)
	currency_changed.emit(current_amount)
