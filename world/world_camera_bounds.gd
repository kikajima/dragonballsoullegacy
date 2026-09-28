class_name WorldCameraBounds
extends Node

@export var bounds: Rect2 = Rect2(0, 0, 640, 360)

func _ready() -> void:
	call_deferred("_apply_bounds")

func _apply_bounds() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return

	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return

	camera.limit_left = roundi(bounds.position.x)
	camera.limit_top = roundi(bounds.position.y)
	camera.limit_right = roundi(bounds.end.x)
	camera.limit_bottom = roundi(bounds.end.y)
	camera.limit_smoothed = false
