class_name ExperienceComponent
extends Node

signal experience_changed(
	current_experience: int,
	experience_to_next_level: int,
	current_level: int
)
signal experience_gained(amount: int)
signal leveled_up(new_level: int)

@export_range(1, 99, 1)
var starting_level: int = 1

@export_range(1, 1000000, 1)
var base_experience_to_next_level: int = 40

@export_range(1.0, 3.0, 0.05)
var experience_growth: float = 1.35

@export_range(1, 99, 1)
var max_level: int = 99

var current_level: int = 1
var current_experience: int = 0
var experience_to_next_level: int = 40

func _ready() -> void:
	current_level = clampi(starting_level, 1, max_level)
	experience_to_next_level = _experience_required_for_level(current_level)
	experience_changed.emit(
		current_experience,
		experience_to_next_level,
		current_level
	)

func add_experience(amount: int) -> int:
	if amount <= 0 or current_level >= max_level:
		return 0

	var remaining: int = amount
	experience_gained.emit(amount)

	while remaining > 0 and current_level < max_level:
		var needed: int = experience_to_next_level - current_experience
		var applied: int = mini(remaining, needed)

		current_experience += applied
		remaining -= applied

		if current_experience >= experience_to_next_level:
			current_experience -= experience_to_next_level
			current_level += 1

			if current_level < max_level:
				experience_to_next_level = _experience_required_for_level(
					current_level
				)

			leveled_up.emit(current_level)

	if current_level >= max_level:
		current_experience = 0
		experience_to_next_level = 1

	experience_changed.emit(
		current_experience,
		experience_to_next_level,
		current_level
	)

	return amount - remaining

func get_experience_ratio() -> float:
	if current_level >= max_level:
		return 1.0

	return clampf(
		float(current_experience) / float(maxi(experience_to_next_level, 1)),
		0.0,
		1.0
	)

func _experience_required_for_level(level: int) -> int:
	var exponent: int = maxi(level - 1, 0)
	var scaled: float = (
		float(base_experience_to_next_level)
		* pow(experience_growth, float(exponent))
	)
	return maxi(int(round(scaled)), 1)
