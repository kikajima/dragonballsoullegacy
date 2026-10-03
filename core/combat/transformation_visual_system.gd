class_name TransformationVisualSystem
extends Node

const DMI_SPRITE_SHEET_SCRIPT = preload(
	"res://core/assets/dmi_sprite_sheet.gd"
)
const EFFECT_DMI_PATH := (
	"res://assets/sprites/effects/hu2/Effects.dmi"
)

var _player: Player
var _transform: TransformationComponent
var _legacy_aura: Polygon2D
var _aura_fx: DmiEffectSprite2D
var _time: float = 0.0

func _ready() -> void:
	call_deferred("_bind_player")

func _process(delta: float) -> void:
	_time += delta

	if _player == null or not is_instance_valid(_player):
		_bind_player()
		return

	if _transform == null:
		return

	if _transform.active_transformation == &"":
		if _aura_fx != null:
			_aura_fx.visible = false
		return

	if _legacy_aura != null:
		_legacy_aura.visible = false

	if _aura_fx != null:
		_aura_fx.visible = true
		var pulse: float = 1.0 + sin(_time * 7.0) * 0.035
		_aura_fx.scale = Vector2(pulse, pulse)

func _bind_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player
	if _player == null:
		return

	_transform = _player.get_node_or_null(
		"Components/TransformationComponent"
	) as TransformationComponent
	_legacy_aura = _player.get_node_or_null(
		"Visuals/TransformationAura"
	) as Polygon2D

	if _transform == null:
		return

	if not _transform.transformation_started.is_connected(
		_on_transformation_started
	):
		_transform.transformation_started.connect(
			_on_transformation_started
		)
	if not _transform.transformation_ended.is_connected(
		_on_transformation_ended
	):
		_transform.transformation_ended.connect(
			_on_transformation_ended
		)

	_ensure_aura_fx()
	if _transform.active_transformation != &"":
		_on_transformation_started(
			_transform.active_transformation
		)

func _ensure_aura_fx() -> void:
	if _player == null:
		return

	var visuals: Node = _player.get_node_or_null("Visuals")
	if visuals == null:
		return

	_aura_fx = visuals.get_node_or_null(
		"TransformationAuraFX"
	) as DmiEffectSprite2D
	if _aura_fx != null:
		return

	_aura_fx = DmiEffectSprite2D.new()
	_aura_fx.name = "TransformationAuraFX"
	_aura_fx.z_index = -3
	_aura_fx.visible = false
	visuals.add_child(_aura_fx)

func _on_transformation_started(
	transformation_id: StringName
) -> void:
	_ensure_aura_fx()
	if _aura_fx == null:
		return

	var state: StringName = _pick_aura_state(
		transformation_id
	)
	_aura_fx.configure(
		EFFECT_DMI_PATH,
		state,
		"down",
		true,
		true
	)
	_aura_fx.visible = true

	if _legacy_aura != null:
		_legacy_aura.visible = false

func _on_transformation_ended(
	_transformation_id: StringName
) -> void:
	if _aura_fx != null:
		_aura_fx.visible = false
	if _legacy_aura != null:
		_legacy_aura.visible = false

func _pick_aura_state(
	transformation_id: StringName
) -> StringName:
	var dmi = DMI_SPRITE_SHEET_SCRIPT.load_file(
		EFFECT_DMI_PATH
	)
	if dmi == null:
		return &"BlueEnergy"

	var candidates: Array[StringName] = []
	match transformation_id:
		&"super_saiyan":
			candidates = [
				&"YellowEnergy",
				&"GoldEnergy",
				&"SSJEnergy",
				&"BlueEnergy",
			]
		&"super_namek":
			candidates = [
				&"GreenEnergy",
				&"NamekEnergy",
				&"BlueEnergy",
			]
		_:
			candidates = [&"BlueEnergy"]

	for state in candidates:
		if dmi.has_state(state):
			return state

	return &"BlueEnergy"
