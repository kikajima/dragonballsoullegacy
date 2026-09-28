class_name SpecialAttackHUD
extends Control

@onready var name_label: Label = $Panel/Name
@onready var info_label: Label = $Panel/Info

var _special: SpecialAttackComponent

func _ready() -> void:
	call_deferred("_bind_player")

func _process(_delta: float) -> void:
	if _special == null:
		return

	var data: SpecialAttackData = _special.get_selected()
	if data == null:
		return

	var player := get_tree().get_first_node_in_group(
		"player"
	)
	if player == null:
		return

	var loadout := player.get_node_or_null(
		"Components/AbilityLoadoutComponent"
	) as AbilityLoadoutComponent

	var cooldown: float = 0.0
	if loadout != null:
		cooldown = loadout.get_cooldown_left(
			data.ability_id
		)

	if _special.is_casting():
		if _special.is_charging():
			info_label.text = (
				"HOLD O  %d%%  RELEASE"
				% roundi(
					_special.get_charge_ratio() * 100.0
				)
			)
			return

		if data.is_continuous():
			info_label.text = (
				"HOLD O  %.0f KI/s"
				% data.ki_drain_per_second
			)
			return

		info_label.text = "CASTING..."
		return

	if cooldown > 0.0:
		info_label.text = "O  %.1fs   R NEXT" % cooldown
		return

	if data.is_transformation():
		if _special.is_transformation_active(
			data.transformation_id
		):
			info_label.text = "ACTIVE  O REVERT   R NEXT"
		else:
			info_label.text = "O TRANSFORM   R NEXT"
		return

	if data.is_charge_attack():
		info_label.text = (
			"HOLD O  %.0f KI   R NEXT"
			% data.ki_cost
		)
		return

	if data.is_continuous():
		info_label.text = (
			"HOLD O  %.0f+%.0f/s  R"
			% [
				data.ki_cost,
				data.ki_drain_per_second,
			]
		)
		return

	info_label.text = (
		"O  %.0f KI   R NEXT"
		% data.ki_cost
	)

func _bind_player() -> void:
	var player := get_tree().get_first_node_in_group(
		"player"
	)
	if player == null:
		visible = false
		return

	_special = player.get_node_or_null(
		"Components/SpecialAttackComponent"
	) as SpecialAttackComponent
	if _special == null:
		visible = false
		return

	_special.selection_changed.connect(
		_on_selection_changed
	)

	var data: SpecialAttackData = _special.get_selected()
	if data != null:
		_on_selection_changed(
			data.ability_id,
			data.display_name,
			0
		)

func _on_selection_changed(
	_ability_id: StringName,
	display_name: String,
	_index: int
) -> void:
	visible = true
	name_label.text = display_name
