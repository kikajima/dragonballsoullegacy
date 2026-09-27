class_name PlayerInputController
extends Node

func get_move_intent() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")

func is_attack_pressed() -> bool:
	return Input.is_action_just_pressed("attack")

func is_kick_pressed() -> bool:
	return Input.is_action_just_pressed("kick")

func is_ki_blast_pressed() -> bool:
	return Input.is_action_just_pressed("ki_blast")

func is_ki_blast_held() -> bool:
	return Input.is_action_pressed("ki_blast")

func is_dash_pressed() -> bool:
	return Input.is_action_just_pressed("dash")

func is_block_pressed() -> bool:
	return Input.is_action_pressed("block")

func is_charge_ki_pressed() -> bool:
	return Input.is_action_pressed("charge_ki")

func is_interact_pressed() -> bool:
	return Input.is_action_just_pressed("interact")
