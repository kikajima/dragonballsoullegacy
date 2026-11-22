class_name SwordSheathVisual
extends Node2D

# Scabbard worn on the character's back while a sword is equipped, as Future
# Trunks carries it in Legacy of Goku II. The back layer sits behind the body
# sprite and the front layer (hilt over the shoulder / strap) in front of it.
# While a sword animation plays, the scabbard is shown empty because the
# blade is in the character's hand.

const HIDDEN_PREFIXES: Array[String] = [
	"koed", "transform", "knockback", "special_spirit_charge",
]

@export var sprite_path: NodePath = ^"../AnimatedSprite2D"

var equipped: bool = false:
	set(value):
		equipped = value
		_refresh(true)

var _sprite: AnimatedSprite2D
var _back: Sprite2D
var _front: Sprite2D
var _shown_key: String = ""
var _textures: Dictionary = {}

func _ready() -> void:
	_sprite = get_node_or_null(sprite_path) as AnimatedSprite2D
	_back = Sprite2D.new()
	_back.name = "SheathBack"
	_front = Sprite2D.new()
	_front.name = "SheathFront"
	# The back layer must render before the body sprite and the front layer
	# after it, so they are inserted around it as siblings.
	var parent := get_parent()
	parent.add_child.call_deferred(_back)
	parent.add_child.call_deferred(_front)
	_place_layers.call_deferred()
	_refresh(true)

func _place_layers() -> void:
	if _sprite == null:
		return
	var parent := get_parent()
	parent.move_child(_back, _sprite.get_index())
	parent.move_child(_front, _sprite.get_index() + 1)
	_refresh(true)

func _process(_delta: float) -> void:
	_refresh(false)

func get_shown_key() -> String:
	return _shown_key

func _refresh(force: bool) -> void:
	if _back == null or _front == null:
		return
	var key := _compute_key()
	if key == _shown_key and not force:
		return
	_shown_key = key
	if key.is_empty():
		_back.visible = false
		_front.visible = false
		return
	var parts := key.rsplit(":", true, 1)
	var layers := _get_textures(StringName(parts[0]), parts[1] == "full")
	_back.texture = layers[0]
	_front.texture = layers[1]
	_back.visible = layers[0] != null
	_front.visible = layers[1] != null and _sprite.visible

func _compute_key() -> String:
	if not equipped or _sprite == null or not _sprite.visible:
		return ""
	var animation := String(_sprite.animation)
	for prefix in HIDDEN_PREFIXES:
		if animation.begins_with(prefix):
			return ""
	var facing := animation.get_slice("_", animation.get_slice_count("_") - 1)
	if not facing in ["down", "left", "right", "up"]:
		facing = "down"
	var drawn := animation.begins_with("sword_")
	# Horizontal flight pose: the scabbard lies along the back.
	if (
		animation.begins_with("fly_")
		and not animation.begins_with("fly_hover")
		and (facing == "left" or facing == "right")
	):
		facing = "fly_" + facing
	return "%s:%s" % [facing, "empty" if drawn else "full"]

func _get_textures(facing: StringName, with_sword: bool) -> Array[Texture2D]:
	var key := "%s:%s" % [facing, with_sword]
	if not _textures.has(key):
		_textures[key] = SwordAnimationLibrary.get_sheath_textures(facing, with_sword)
	return _textures[key]
