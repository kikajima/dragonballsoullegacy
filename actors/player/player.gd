class_name Player
extends CharacterBody2D

const STATE_IDLE: StringName = &"idle"
const STATE_WALK: StringName = &"walk"
const STATE_ATTACK: StringName = &"attack"

@onready var input_controller: PlayerInputController = $Controllers/PlayerInputController
@onready var movement_component: MovementComponent = $Components/MovementComponent
@onready var facing_component: FacingComponent = $Components/FacingComponent
@onready var state_machine: StateMachine = $Components/StateMachine
@onready var melee_combat_component: MeleeCombatComponent = $Components/MeleeCombatComponent
@onready var animation_controller: PlayerAnimationController = $Visuals/AnimationController

func _physics_process(delta: float) -> void:
	var move_intent := input_controller.get_move_intent()

	if melee_combat_component.is_attacking():
		movement_component.stop(self)
		melee_combat_component.tick_attack(delta)

		if not melee_combat_component.is_attacking():
			_update_movement_state(move_intent)

		animation_controller.update_visual(
			state_machine.current_state,
			facing_component.current_facing,
			delta
		)
		return

	facing_component.update_from_direction(move_intent)

	if input_controller.is_attack_pressed():
		if melee_combat_component.start_attack(facing_component.current_facing):
			state_machine.change_state(STATE_ATTACK)
			movement_component.stop(self)
			animation_controller.update_visual(
				state_machine.current_state,
				facing_component.current_facing,
				delta
			)
			return

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
