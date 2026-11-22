class_name StudySpot
extends Area2D

# A place to study (library shelf, university board, Capsule Corp lab
# terminal). Interacting (E) starts a study session: the player stays still
# and trains Intelligence until they move or press E again.

@export var place_name: String = "West City Library"
@export var action_label: String = "Read"
@export_enum("books", "board", "lab") var kind: String = "books"
# Intelligence XP per second relative to CharacterStatsComponent.xp_study_per_second.
@export var xp_multiplier: float = 1.0
# Solid footprint (scenery blocks the player like every other prop).
@export var footprint: Vector2 = Vector2(26, 10)

var _time: float = 0.0

func _ready() -> void:
	add_to_group("study_spot")
	collision_layer = 64
	collision_mask = 0
	monitoring = false
	monitorable = true
	if get_node_or_null("CollisionShape2D") == null:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(40, 34)
		shape.shape = rect
		shape.position = Vector2(0, 10)
		add_child(shape)
	var body := StaticBody2D.new()
	body.name = "Footprint"
	body.collision_layer = 1
	body.collision_mask = 0
	var solid := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = footprint
	solid.shape = box
	solid.position = Vector2(0, -footprint.y * 0.5)
	body.add_child(solid)
	add_child(body)
	z_as_relative = false
	z_index = 1000 + roundi(global_position.y)

func get_interaction_label() -> String:
	return "%s: %s" % [action_label, place_name]

func interact(actor: Node) -> void:
	if actor == null or not actor.has_method("start_study"):
		return
	if actor.has_method("is_studying") and actor.is_studying():
		actor.stop_focus()
		return
	if actor.start_study(self):
		if actor.has_method("_notify"):
			actor._notify("Studying at %s (move or E to stop)" % place_name)

func _process(delta: float) -> void:
	_time += delta
	if kind == "lab":
		queue_redraw()

func _draw() -> void:
	match kind:
		"books":
			_draw_bookshelf()
		"board":
			_draw_board()
		"lab":
			_draw_lab()

func _draw_bookshelf() -> void:
	var wood := Color(0.42, 0.25, 0.12)
	var dark := Color(0.22, 0.12, 0.06)
	draw_rect(Rect2(-14, -30, 28, 30), dark)
	draw_rect(Rect2(-13, -29, 26, 28), wood)
	var colors := [Color(0.75, 0.2, 0.2), Color(0.2, 0.45, 0.8), Color(0.85, 0.7, 0.2), Color(0.25, 0.6, 0.3), Color(0.6, 0.3, 0.7)]
	for shelf in 3:
		var y := -28 + shelf * 9
		draw_rect(Rect2(-13, y + 7, 26, 2), dark)
		for book in 6:
			var height := 6 - (book + shelf) % 2
			draw_rect(Rect2(-12 + book * 4, y + 7 - height, 3, height), colors[(book + shelf * 2) % colors.size()])

func _draw_board() -> void:
	var post := Color(0.35, 0.3, 0.28)
	draw_rect(Rect2(-12, -12, 2, 12), post)
	draw_rect(Rect2(10, -12, 2, 12), post)
	draw_rect(Rect2(-16, -32, 32, 21), Color(0.2, 0.16, 0.12))
	draw_rect(Rect2(-15, -31, 30, 19), Color(0.13, 0.32, 0.22))
	var chalk := Color(0.9, 0.92, 0.88)
	draw_line(Vector2(-12, -27), Vector2(-2, -27), chalk, 1.0)
	draw_line(Vector2(-12, -23), Vector2(6, -23), chalk, 1.0)
	draw_line(Vector2(-12, -19), Vector2(2, -19), chalk, 1.0)
	draw_circle(Vector2(9, -24), 3.0, Color(chalk, 0.0))
	draw_arc(Vector2(9, -24), 3.0, 0.0, TAU, 10, chalk, 1.0)

func _draw_lab() -> void:
	draw_rect(Rect2(-14, -12, 28, 12), Color(0.55, 0.58, 0.64))
	draw_rect(Rect2(-14, -12, 28, 2), Color(0.78, 0.8, 0.86))
	draw_rect(Rect2(-11, -30, 22, 17), Color(0.2, 0.22, 0.28))
	var glow := 0.75 + 0.25 * sin(_time * 3.0)
	draw_rect(Rect2(-9, -28, 18, 13), Color(0.2, 0.75 * glow, 0.55 * glow))
	for i in 3:
		var y := -26 + i * 4
		draw_line(Vector2(-7, y), Vector2(-7 + 4 + (i * 5 + int(_time * 4.0)) % 10, y), Color(0.75, 1.0, 0.85), 1.0)
	draw_rect(Rect2(-10, -8, 4, 3), Color(0.9, 0.3, 0.25))
	draw_rect(Rect2(-4, -8, 4, 3), Color(0.95, 0.8, 0.25))
	draw_rect(Rect2(2, -8, 4, 3), Color(0.3, 0.7, 0.95))
