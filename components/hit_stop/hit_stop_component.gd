class_name HitStopComponent
extends Node

@export_range(0.0, 0.2, 0.005)
var duration: float = 0.045

@export_range(0.01, 1.0, 0.01)
var time_scale: float = 0.08

var _request_id: int = 0

func trigger() -> void:
	_request_id += 1
	var request_id := _request_id

	Engine.time_scale = time_scale

	await get_tree().create_timer(duration, true, false, true).timeout

	if request_id == _request_id:
		Engine.time_scale = 1.0

func _exit_tree() -> void:
	_request_id += 1
	Engine.time_scale = 1.0
