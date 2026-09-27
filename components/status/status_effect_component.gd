class_name StatusEffectComponent
extends Node

signal status_applied(
	status_id: StringName,
	duration: float,
	magnitude: float
)
signal status_removed(status_id: StringName)
signal statuses_changed

var _statuses: Dictionary = {}

func _process(delta: float) -> void:
	if _statuses.is_empty():
		return

	var expired: Array[String] = []

	for key in _statuses.keys():
		var value: Variant = _statuses[key]
		if not value is Dictionary:
			expired.append(String(key))
			continue

		var state: Dictionary = value as Dictionary
		var time_left: float = maxf(
			float(state.get("time_left", 0.0)) - delta,
			0.0
		)
		state["time_left"] = time_left
		_statuses[key] = state

		if time_left <= 0.0:
			expired.append(String(key))

	for key in expired:
		_statuses.erase(key)
		status_removed.emit(StringName(key))

	if not expired.is_empty():
		statuses_changed.emit()

func apply_status(
	status_id: StringName,
	duration: float,
	magnitude: float = 1.0
) -> void:
	if status_id == &"" or duration <= 0.0:
		return

	_statuses[String(status_id)] = {
		"time_left": duration,
		"duration": duration,
		"magnitude": magnitude,
	}

	status_applied.emit(status_id, duration, magnitude)
	statuses_changed.emit()

func remove_status(status_id: StringName) -> void:
	var key := String(status_id)
	if not _statuses.erase(key):
		return

	status_removed.emit(status_id)
	statuses_changed.emit()

func has_status(status_id: StringName) -> bool:
	return _statuses.has(String(status_id))

func get_magnitude(
	status_id: StringName,
	fallback: float = 1.0
) -> float:
	var value: Variant = _statuses.get(String(status_id), {})
	if value is Dictionary:
		return float((value as Dictionary).get("magnitude", fallback))
	return fallback

func get_time_left(status_id: StringName) -> float:
	var value: Variant = _statuses.get(String(status_id), {})
	if value is Dictionary:
		return float((value as Dictionary).get("time_left", 0.0))
	return 0.0

func clear_all() -> void:
	var keys := _statuses.keys()
	_statuses.clear()

	for key in keys:
		status_removed.emit(StringName(str(key)))

	statuses_changed.emit()
