class_name Player
extends CharacterBody2D

const STATE_IDLE: StringName = &"idle"
const STATE_WALK: StringName = &"walk"

@onready var input_controller: PlayerInputController = $Controllers/PlayerInputController
@onready var movement_component: MovementComponent = $Components/MovementComponent
@onready var facing_component: FacingComponent = $Components/FacingComponent
@onready var state_machine: StateMachine = $Components/StateMachine
@onready var animation_controller: PlayerAnimationController = $Visuals/AnimationController

func _physics_process(delta: float) -> void:
	var move_intent := input_controller.get_move_intent()

	facing_component.update_from_direction(move_intent)
	_update_movement_state(move_intent)
	movement_component.move(self, move_intent)
	animation_controller.update_visual(
		state_machine.current_state,
		facing_component.current_facing,
		delta
	)

func _update_movement_state(move_intent: Vector2) -> void:
	if move_intent.is_zero_approx():
		state_machine.change_state(STATE_IDLE)
	else:
		state_machine.change_state(STATE_WALK)

func get_current_state() -> StringName:
	return state_machine.current_state

func get_facing() -> StringName:
	return facing_component.current_facing
