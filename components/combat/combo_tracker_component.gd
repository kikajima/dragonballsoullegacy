class_name ComboTrackerComponent
extends Node

signal combo_changed(hit_count: int, total_damage: int)
signal combo_finished(hit_count: int, total_damage: int)

@export var combo_timeout: float = 1.25
@export_range(2, 99, 1)
var minimum_visible_hits: int = 2

var hit_count: int = 0
var total_damage: int = 0
var _time_left: float = 0.0

func _process(delta: float) -> void:
	if hit_count <= 0:
		return

	_time_left -= delta
	if _time_left <= 0.0:
		finish_combo()

func register_hit(damage: int) -> void:
	if damage <= 0:
		return

	hit_count += 1
	total_damage += damage
	_time_left = combo_timeout
	combo_changed.emit(hit_count, total_damage)

func break_combo() -> void:
	if hit_count <= 0:
		return

	finish_combo()

func finish_combo() -> void:
	if hit_count <= 0:
		return

	var finished_hits: int = hit_count
	var finished_damage: int = total_damage

	hit_count = 0
	total_damage = 0
	_time_left = 0.0

	combo_finished.emit(finished_hits, finished_damage)
	combo_changed.emit(0, 0)

func is_visible_combo() -> bool:
	return hit_count >= minimum_visible_hits
