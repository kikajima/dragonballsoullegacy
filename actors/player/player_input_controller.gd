class_name PlayerInputController
extends Node

func get_move_vector() -> Vector2:
	return Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
