class_name PowerAuraComponent
extends Node2D

# Toggleable ki aura (HU2 Effects.dmi). On the ground it is the round
# <Color>Energy flame; while flying it switches to the stretched
# <Color>EnergyFly for the travel direction, and fast flight leaves the
# <Color>EnergyTrail streaks behind the character.
# Colours without a dedicated HU2 sheet tint the white one.

signal aura_changed(enabled: bool, color_id: StringName)

const EFFECT_DMI_PATH := "res://assets/sprites/effects/hu2/Effects.dmi"
# Tiles are 32px; stamping every 16px overlaps them on the same streak lines
# so no gap opens behind the flyer between two stamps.
const TRAIL_STEP := 16.0
const DEFAULT_COLOR: StringName = &"white"
const HIDDEN_PREFIXES: Array[String] = ["koed", "transform"]
const COLORS: Array[Dictionary] = [
	{"id": &"white", "name": "White", "sheet": "White", "tint": Color(1, 1, 1)},
	{"id": &"blue", "name": "Blue", "sheet": "Blue", "tint": Color(1, 1, 1)},
	{"id": &"yellow", "name": "Yellow", "sheet": "Yellow", "tint": Color(1, 1, 1)},
	{"id": &"red", "name": "Red", "sheet": "Red", "tint": Color(1, 1, 1)},
	{"id": &"green", "name": "Green", "sheet": "Green", "tint": Color(1, 1, 1)},
	{"id": &"purple", "name": "Purple", "sheet": "White", "tint": Color(0.78, 0.48, 1.0)},
	{"id": &"pink", "name": "Pink", "sheet": "White", "tint": Color(1.0, 0.56, 0.86)},
	{"id": &"black", "name": "Black", "sheet": "Black", "tint": Color(1, 1, 1)},
]

@export var aura_alpha: float = 0.92
@export var trail_alpha: float = 0.6
@export var trail_lifetime: float = 0.38
@export var player_path: NodePath = ^"../.."

var enabled: bool = false
var color_id: StringName = DEFAULT_COLOR

var _player: Player
var _flame: DmiEffectSprite2D
var _trail_active: bool = false
var _trail_anchor: Vector2 = Vector2.ZERO
var _trail_facing: StringName = &""
var _trail_index: int = 0

static func get_color_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for entry in COLORS:
		ids.append(entry["id"])
	return ids

static func get_color_entry(id: StringName) -> Dictionary:
	for entry in COLORS:
		if entry["id"] == id:
			return entry
	return COLORS[0]

static func get_color_name(id: StringName) -> String:
	return String(get_color_entry(id)["name"])

# Representative colour for UI swatches.
static func get_swatch_color(id: StringName) -> Color:
	match String(get_color_entry(id)["sheet"]):
		"Blue":
			return Color(0.2, 0.75, 1.0)
		"Yellow":
			return Color(1.0, 0.88, 0.25)
		"Red":
			return Color(1.0, 0.3, 0.25)
		"Green":
			return Color(0.35, 1.0, 0.4)
		"Black":
			return Color(0.16, 0.12, 0.22)
	return get_color_entry(id)["tint"]

func _ready() -> void:
	_player = get_node_or_null(player_path) as Player
	_flame = DmiEffectSprite2D.new()
	_flame.name = "Flame"
	_flame.visible = false
	add_child(_flame)
	_apply_color_to_charge_aura()

func set_enabled(value: bool) -> void:
	if enabled == value:
		return
	enabled = value
	if not enabled:
		_trail_active = false
	_refresh()
	aura_changed.emit(enabled, color_id)

func toggle() -> bool:
	set_enabled(not enabled)
	return enabled

func set_color(id: StringName) -> void:
	var entry := get_color_entry(id)
	if color_id == entry["id"]:
		return
	color_id = entry["id"]
	_apply_color_to_charge_aura()
	_refresh()
	aura_changed.emit(enabled, color_id)

func cycle_color(step: int = 1) -> StringName:
	var ids := get_color_ids()
	var index := maxi(ids.find(color_id), 0)
	set_color(ids[wrapi(index + step, 0, ids.size())])
	return color_id

func get_sheet_state(kind: String = "") -> StringName:
	return StringName("%sEnergy%s" % [get_color_entry(color_id)["sheet"], kind])

func get_shown_state() -> StringName:
	return _flame.dmi_state if _flame != null and _flame.visible else &""

func serialize_state() -> Dictionary:
	return {"enabled": enabled, "color": String(color_id)}

func load_state(data: Dictionary) -> void:
	set_color(StringName(str(data.get("color", String(DEFAULT_COLOR)))))
	set_enabled(bool(data.get("enabled", false)))

func _process(_delta: float) -> void:
	_refresh()

func _refresh() -> void:
	if _flame == null:
		return
	if not _should_show():
		_flame.visible = false
		_trail_active = false
		return

	var facing := _player.get_facing() if _player != null else &"down"
	var state := _player.get_current_state() if _player != null else &"idle"
	var moving_in_air := state == Player.STATE_FLY or state == Player.STATE_FLY_FAST
	var sheet_state := get_sheet_state("Fly" if moving_in_air else "")
	_flame.configure(EFFECT_DMI_PATH, sheet_state, String(facing), true, true)
	_flame.modulate = get_color_entry(color_id)["tint"]
	_flame.modulate.a = aura_alpha
	_flame.visible = true

	if state == Player.STATE_FLY_FAST:
		_update_trail(facing)
	else:
		_trail_active = false

func _should_show() -> bool:
	if not enabled or _player == null:
		return false
	var sprite := _player.animation_controller.sprite
	if sprite == null or not sprite.visible:
		return false
	var animation := String(sprite.animation)
	for prefix in HIDDEN_PREFIXES:
		if animation.begins_with(prefix):
			return false
	# The ki charge already wraps the body in an aura of this colour.
	if _player.charge_aura.visible:
		return false
	return true

# Streak tiles are stamped on a fixed grid along the travel axis so they line
# up into one continuous trail, each one fading out on its own.
func _update_trail(facing: StringName) -> void:
	var axis := _facing_axis(facing)
	var body := global_position
	if not _trail_active or facing != _trail_facing:
		_trail_active = true
		_trail_facing = facing
		_trail_anchor = body
		return
	# Follow sideways drift so the trail stays centred on the body.
	var across := Vector2(absf(axis.y), absf(axis.x))
	_trail_anchor = _trail_anchor * (Vector2.ONE - across) + body * across
	var travelled := (body - _trail_anchor).dot(axis)
	if travelled < 0.0:
		_trail_anchor = body
		return
	while travelled >= TRAIL_STEP:
		# Centre one tile-half behind the body: its front edge meets the body.
		_spawn_trail_tile(_trail_anchor, facing)
		_trail_anchor += axis * TRAIL_STEP
		travelled -= TRAIL_STEP

func _spawn_trail_tile(at: Vector2, facing: StringName) -> void:
	var dmi = DmiSpriteSheet.load_file(EFFECT_DMI_PATH)
	if dmi == null:
		return
	var state := get_sheet_state("Trail")
	if not dmi.has_state(state):
		return
	var frame := _trail_index % maxi(dmi.get_frame_count(state), 1)
	_trail_index += 1
	var tile := Sprite2D.new()
	tile.name = "AuraTrail"
	tile.top_level = true
	tile.texture = dmi.get_frame_texture(state, facing, frame)
	tile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tile.global_position = at
	# top_level also drops the parent's draw order, so a relative z would put
	# the trail under the floor of maps whose ground is drawn at z >= 0. Pin
	# it just behind the flyer instead (flyers sit above all scenery).
	tile.z_as_relative = false
	tile.z_index = _trail_z()
	tile.modulate = get_color_entry(color_id)["tint"]
	tile.modulate.a = trail_alpha
	tile.add_to_group("aura_trail")
	add_child(tile)
	var tween := tile.create_tween()
	tween.tween_property(tile, "modulate:a", 0.0, trail_lifetime)
	tween.tween_callback(tile.queue_free)

func _trail_z() -> int:
	var z := 0
	var node: Node = self
	while node is CanvasItem:
		var item := node as CanvasItem
		z += item.z_index
		if not item.z_as_relative:
			break
		node = node.get_parent()
	# Behind the body (PowerAura itself sits at -2 under the sprite).
	return clampi(z - 1, RenderingServer.CANVAS_ITEM_Z_MIN, RenderingServer.CANVAS_ITEM_Z_MAX)

func _apply_color_to_charge_aura() -> void:
	if _player == null:
		return
	var charge := _player.get_node_or_null("Visuals/ChargeAura") as DmiEffectSprite2D
	if charge == null:
		return
	charge.configure(EFFECT_DMI_PATH, get_sheet_state(), "down", true, charge.visible)
	var tint: Color = get_color_entry(color_id)["tint"]
	charge.modulate = Color(tint.r, tint.g, tint.b, charge.modulate.a)

static func _facing_axis(facing: StringName) -> Vector2:
	match facing:
		&"up":
			return Vector2.UP
		&"left":
			return Vector2.LEFT
		&"right":
			return Vector2.RIGHT
	return Vector2.DOWN
