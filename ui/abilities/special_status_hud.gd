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
var _linger_left: float = 0.0
var _rejection: String = ""

func _ready() -> void:
	_layout_hud()
	get_viewport().size_changed.connect(_layout_hud)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	call_deferred("_bind_player")

func _layout_hud() -> void:
	size = Vector2(224, 46)
	scale = Vector2(0.5, 0.5)
	var vitals := get_node_or_null("../CombatHUD/PlayerPanel") as Control
	position = Vector2(8, 35)
	if vitals != null:
		var bounds := vitals.get_global_rect()
		position = Vector2(bounds.position.x, bounds.end.y + 4)

func _process(delta: float) -> void:
	_linger_left = maxf(_linger_left - delta, 0.0)
	if _linger_left <= 0.0:
		_rejection = ""
	_refresh()

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
	_special.cast_rejected.connect(_on_cast_rejected)
	_loadout.cooldown_changed.connect(_on_cooldown_changed)

	_selected = _special.get_selected()
	if _selected != null:
		_cooldown_left = _loadout.get_cooldown_left(
			_selected.ability_id
		)
	_linger_left = 1.6
	_refresh()

func _on_selection_changed(
	_ability_id: StringName,
	_display_name: String,
	_index: int
) -> void:
	if _special == null or _loadout == null:
		return

	_selected = _special.get_selected()
	_rejection = ""
	_charge_ratio = 0.0
	_cooldown_left = 0.0
	if _selected != null:
		_cooldown_left = _loadout.get_cooldown_left(
			_selected.ability_id
		)
	_linger_left = 1.6
	_refresh()

func _on_charge_changed(
	ability_id: StringName,
	ratio: float
) -> void:
	if _selected == null or ability_id != _selected.ability_id:
		return

	_charge_ratio = clampf(ratio, 0.0, 1.0)
	if _charge_ratio > 0.0:
		_linger_left = 0.35
	_refresh()

func _on_cast_started(ability_id: StringName) -> void:
	if _selected == null or ability_id != _selected.ability_id:
		return

	_rejection = ""
	_charge_ratio = 0.0
	_linger_left = 0.8
	_refresh()

func _on_cast_finished(ability_id: StringName) -> void:
	if _selected == null or ability_id != _selected.ability_id:
		return

	_charge_ratio = 0.0
	if _loadout != null:
		_cooldown_left = _loadout.get_cooldown_left(ability_id)
	_linger_left = 0.65
	_refresh()

func _on_cooldown_changed(
	ability_id: StringName,
	time_left: float
) -> void:
	if _selected == null or ability_id != _selected.ability_id:
		return

	_cooldown_left = maxf(time_left, 0.0)
	_refresh()

func _on_cast_rejected(reason: String) -> void:
	_rejection = reason
	_linger_left = 1.6
	_refresh()

func _refresh() -> void:
	if _selected == null or _special == null:
		visible = false
		return

	visible = true

	name_label.text = _selected.display_name
	name_label.add_theme_font_size_override("font_size", 9 if _selected.display_name.length() > 24 else 10)
	name_label.tooltip_text = _selected.display_name

	var meter_ratio: float = 0.0
	var show_meter: bool = false
	var blocked_reason := _special.get_cast_block_reason(_selected)
	var status_color := Color("b7cedb")
	var unavailable := false
	meter_fill.color = Color("65cbd6")

	if not _rejection.is_empty():
		status_label.text = _rejection
		status_color = Color("ef9b88")
		unavailable = true
	elif _special.is_charging():
		meter_ratio = _charge_ratio
		var instruction := "SEGURE O" if _selected.is_continuous() else "SOLTE O"
		status_label.text = "CARGA %d%% - %s" % [roundi(_charge_ratio * 100.0), instruction]
		status_color = Color("8fe5e6")
		show_meter = true
	elif _special.is_casting():
		status_label.text = "CANALIZANDO - SOLTE O" if _selected.is_continuous() else "EM USO"
		status_color = Color("8fe5e6")
	elif _cooldown_left > 0.0:
		var duration: float = maxf(_selected.cooldown, 0.001)
		meter_ratio = clampf(
			1.0 - _cooldown_left / duration,
			0.0,
			1.0
		)
		status_label.text = "RECARGA %.1fs" % _cooldown_left
		status_color = Color("edc18a")
		meter_fill.color = status_color
		unavailable = true
		show_meter = true
	elif not blocked_reason.is_empty():
		status_label.text = blocked_reason
		status_color = Color("ef9b88")
		unavailable = true
	elif _selected.is_transformation():
		if _special.is_transformation_active(
			_selected.transformation_id
		):
			status_label.text = "ATIVA - O REVERTER"
		else:
			status_label.text = "O TRANSFORMAR"
	elif _selected.is_continuous():
		status_label.text = "SEGURE O PARA CANALIZAR"
	elif _selected.is_charge_attack():
		status_label.text = "SEGURE O / SOLTE PARA USAR"
	else:
		status_label.text = "O USAR"
	status_label.add_theme_color_override("font_color", status_color)
	$Panel/Icon.modulate = Color(0.55, 0.55, 0.55) if unavailable else Color.WHITE

	meter_back.visible = show_meter
	if show_meter:
		var max_width: float = meter_back.size.x
		meter_fill.size = Vector2(
			floorf(max_width * meter_ratio),
			2.0
		)
