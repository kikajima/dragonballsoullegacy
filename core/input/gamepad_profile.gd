class_name GamepadProfile
extends Node

func _ready() -> void:
	_add_axis("move_left", 0, -1.0)
	_add_axis("move_right", 0, 1.0)
	_add_axis("move_up", 1, -1.0)
	_add_axis("move_down", 1, 1.0)

	_add_button("move_up", 11)
	_add_button("move_down", 12)
	_add_button("move_left", 13)
	_add_button("move_right", 14)

	_add_button("interact", 0)
	_add_button("ki_blast", 1)
	_add_button("attack", 2)
	_add_button("kick", 3)

	_add_button("block", 9)
	_add_button("dash", 10)

	_add_axis("quick_item", 4, 1.0)
	_add_axis("charge_ki", 5, 1.0)

	_add_button("ui_cancel", 6)

func _add_button(action_name: StringName, button_index: int) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	var event := InputEventJoypadButton.new()
	event.button_index = button_index

	if InputMap.action_has_event(action_name, event):
		return

	InputMap.action_add_event(action_name, event)

func _add_axis(
	action_name: StringName,
	axis_index: int,
	axis_value: float
) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	var event := InputEventJoypadMotion.new()
	event.axis = axis_index
	event.axis_value = axis_value

	if InputMap.action_has_event(action_name, event):
		return

	InputMap.action_add_event(action_name, event)
