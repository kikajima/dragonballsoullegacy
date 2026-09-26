class_name Player
extends CharacterBody2D

@onready var input_controller: PlayerInputController = $Controllers/PlayerInputController
@onready var movement_component: MovementComponent = $Components/MovementComponent

func _physics_process(_delta: float) -> void:
	var move_intent := input_controller.get_move_intent()
	movement_component.move(self, move_intent)
