class_name SpecialStatusHUD
extends Control

@onready var name_label: Label = $Panel/Name
@onready var status_label: Label = $Panel/Status
@onready var meter_back: ColorRect = $Panel/MeterBack
@onready var meter_fill: ColorRect = $Panel/MeterBack/MeterFill

var _special: SpecialAttackComponent
var _loadout: AbilityLoadoutComponent
var _selected: SpecialAttackData
var _charge_ratio: float = 0.0
var _cooldown_left: float = 0.0

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	call_deferred("_bind_player")

func _bind_player() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return

	_special = player.get_node_or_null(
		"Components/SpecialAttackComponent"
	) as SpecialAttackComponent
	_loadout = player.get_node_or_null(
		"Components/AbilityLoadoutComponent"
	) as AbilityLoadoutComponent

	if _special == null or _loadout == null:
		return

	_special.selection_changed.connect(_on_selection_changed)
	_special.charge_changed.connect(_on_charge_changed)
	_special.cast_started.connect(_on_cast_started)
	_special.cast_finished.connect(_on_cast_finished)
	_loadout.cooldown_changed.connect(_on_cooldown_changed)

	_selected = _special.get_selected()
	if _selected != null:
		_cooldown_left = _loadout.get_cooldown_left(
			_selected.ability_id
		)
	_refresh()

func _on_selection_changed(
	_ability_id: StringName,
	_display_name: String,
	_index: int
) -> void:
	if _special == null or _loadout == null:
		return

	_selected = _special.get_selected()
	_charge_ratio = 0.0
	_cooldown_left = 0.0
	if _selected != null:
		_cooldown_left = _loadout.get_cooldown_left(
			_selected.ability_id
		)
	_refresh()

func _on_charge_changed(
	ability_id: StringName,
	ratio: float
) -> void:
	if _selected == null or ability_id != _selected.ability_id:
		return

	_charge_ratio = clampf(ratio, 0.0, 1.0)
	_refresh()

func _on_cast_started(ability_id: StringName) -> void:
	if _selected == null or ability_id != _selected.ability_id:
		return

	_charge_ratio = 0.0
	_refresh()

func _on_cast_finished(ability_id: StringName) -> void:
	if _selected == null or ability_id != _selected.ability_id:
		return

	_charge_ratio = 0.0
	if _loadout != null:
		_cooldown_left = _loadout.get_cooldown_left(ability_id)
	_refresh()

func _on_cooldown_changed(
	ability_id: StringName,
	time_left: float
) -> void:
	if _selected == null or ability_id != _selected.ability_id:
		return

	_cooldown_left = maxf(time_left, 0.0)
	_refresh()

func _refresh() -> void:
	if _selected == null or _special == null:
		visible = false
		return

	visible = true
	name_label.text = _selected.display_name

	var meter_ratio: float = 0.0
	var show_meter: bool = false

	if _cooldown_left > 0.0:
		var duration: float = maxf(_selected.cooldown, 0.001)
		meter_ratio = clampf(
			1.0 - _cooldown_left / duration,
			0.0,
			1.0
		)
		status_label.text = "CD %.1fs   R NEXT" % _cooldown_left
		show_meter = true
	elif _special.is_charging() or _charge_ratio > 0.0:
		meter_ratio = _charge_ratio
		status_label.text = "CHARGE %d%%" % roundi(
			_charge_ratio * 100.0
		)
		show_meter = true
	elif _selected.is_transformation():
		if _special.is_transformation_active(
			_selected.transformation_id
		):
			status_label.text = "ACTIVE   O REVERT   R NEXT"
		else:
			status_label.text = "O TRANSFORM   R NEXT"
	elif _selected.is_charge_attack():
		status_label.text = "HOLD O   R NEXT"
	elif _selected.is_continuous():
		status_label.text = "HOLD O   R NEXT"
	else:
		status_label.text = "O USE   R NEXT"

	meter_back.visible = show_meter
	if show_meter:
		var max_width: float = 130.0
		meter_fill.size = Vector2(
			floorf(max_width * meter_ratio),
			3.0
		)
