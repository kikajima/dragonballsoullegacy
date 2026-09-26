class_name StateMachine
extends Node

signal state_changed(previous_state: StringName, current_state: StringName)

@export var initial_state: StringName = &"idle"

var current_state: StringName = &"idle"

func _ready() -> void:
	current_state = initial_state

func change_state(next_state: StringName) -> void:
	if next_state == &"" or next_state == current_state:
		return

	var previous_state := current_state
	current_state = next_state
	state_changed.emit(previous_state, current_state)

func is_state(state_name: StringName) -> bool:
	return current_state == state_name
