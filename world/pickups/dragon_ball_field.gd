class_name DragonBallField
extends Node2D

# Shows the Dragon Balls lying on Earth (child of OpenWorld) and lets the
# player pick them up by walking over them. After a wish they are stone:
# visible, but they cannot be taken.

const DMI_PATH := "res://assets/vendor/hu2/Icons/Items/DragonBalls.dmi"
# HU2 states: "DB1".."DB7" shining, "15".."21" stone.
const STONE_STATE_OFFSET := 14

var _manager: DragonBallManager
var _balls: Dictionary = {} # index -> Area2D
var _time: float = 0.0

func _ready() -> void:
	call_deferred("_bind")

func _bind() -> void:
	_manager = get_tree().get_first_node_in_group("dragon_ball_manager") as DragonBallManager
	if _manager == null:
		return
	_manager.balls_changed.connect(_rebuild, CONNECT_DEFERRED)
	_manager.ensure_placed(get_parent() as OpenWorld)
	_rebuild()

func _process(delta: float) -> void:
	_time += delta
	for index in _balls:
		var ball := _balls[index] as Area2D
		var sprite := ball.get_node("Sprite") as Sprite2D
		sprite.position.y = -6.0 + sin(_time * 3.0 + index) * 1.5
		var glow := ball.get_node("Glow") as Polygon2D
		glow.visible = not _manager.is_stone()
		glow.modulate.a = 0.35 + sin(_time * 4.0 + index) * 0.2

func _rebuild() -> void:
	for index in _balls:
		(_balls[index] as Node).queue_free()
	_balls.clear()
	if _manager == null:
		return
	var ground := _manager.get_ground_balls()
	for index in ground:
		_balls[index] = _make_ball(index, (Vector2(ground[index]) + Vector2(0.5, 0.5)) * OpenWorld.TILE)

func _make_ball(index: int, point: Vector2) -> Area2D:
	var ball := Area2D.new()
	ball.name = "DragonBall%d" % (index + 1)
	ball.collision_layer = 0
	ball.collision_mask = 2
	ball.add_to_group("dragon_ball")
	ball.set_meta("ball_index", index)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 9.0
	shape.shape = circle
	ball.add_child(shape)

	var glow := Polygon2D.new()
	glow.name = "Glow"
	var points := PackedVector2Array()
	for step in 12:
		points.append(Vector2.from_angle(TAU * step / 12.0) * Vector2(11, 6) + Vector2(0, 2))
	glow.polygon = points
	glow.color = Color(1.0, 0.75, 0.2, 1.0)
	ball.add_child(glow)

	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = _ball_texture(index, _manager.is_stone())
	sprite.position = Vector2(0, -6)
	ball.add_child(sprite)
	add_child(ball)
	ball.global_position = point
	WorldDepth.place(ball, point.y)
	ball.body_entered.connect(_on_body_entered.bind(index))
	return ball

func _on_body_entered(body: Node2D, index: int) -> void:
	if body == null or not body.is_in_group("player") or _manager == null:
		return
	if _manager.is_stone():
		var feed := get_tree().get_first_node_in_group("notification_feed")
		if feed != null:
			feed.push_message("This Dragon Ball has turned to stone")
		return
	_manager.collect(index)

static func _ball_texture(index: int, stone: bool) -> Texture2D:
	var dmi := DmiSpriteSheet.load_file(DMI_PATH)
	if dmi == null:
		return null
	var state := str(index + 1 + STONE_STATE_OFFSET) if stone else "DB%d" % (index + 1)
	return dmi.get_frame_texture(StringName(state), &"down", 0)

static func ball_icon(index: int, stone: bool = false) -> Texture2D:
	return _ball_texture(index, stone)
