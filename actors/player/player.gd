class_name Player
extends CharacterBody2D

@export var move_speed: float = 90.0

@onready var input_controller: PlayerInputController = $PlayerInputController

func _physics_process(_delta: float) -> void:
	var move_direction := input_controller.get_move_vector()
	velocity = move_direction * move_speed
	move_and_slide()
