class_name ShenronWishMenu
extends GameMenu

# Shenron appears and grants one wish (DragonBallManager.WISHES). The sky
# darkens, the dragon rises, the player picks a wish; afterwards the balls
# scatter and turn to stone.

const SHENRON_PATH := "res://assets/vendor/hu2/Icons/Images/Shenron2x.png"

var _manager: DragonBallManager
var _cursor := 0
var _granted: StringName = &""
var _time := 0.0
var _sky: ColorRect
var _dragon: TextureRect
var _list: Control
var _speech: Label

func _ready() -> void:
	super._ready()
	add_to_group("shenron_menu")

func summon() -> bool:
	_manager = get_tree().get_first_node_in_group("dragon_ball_manager") as DragonBallManager
	if _manager == null or not _manager.can_summon():
		return false
	_cursor = 0
	_granted = &""
	_time = 0.0
	return open()

func _build_content() -> void:
	# The game's own panel is replaced by a dark sky with the dragon.
	_panel.color = Color(0, 0, 0, 0)
	_sky = ColorRect.new()
	_sky.color = Color(0.02, 0.05, 0.03, 0.0)
	_sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sky)
	move_child(_sky, 1)

	_dragon = TextureRect.new()
	_dragon.texture = load(SHENRON_PATH) as Texture2D
	_dragon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_dragon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_dragon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_dragon.position = Vector2(-8, 0)
	_dragon.size = Vector2(150, 250)
	_panel.add_child(_dragon)

	var box := ColorRect.new()
	box.color = Color(0.02, 0.06, 0.04, 0.9)
	box.position = Vector2(148, 30)
	box.size = Vector2(276, 170)
	_panel.add_child(box)

	_speech = make_label("", COLOR_TEXT)
	_speech.position = Vector2(156, 36)
	_speech.size = Vector2(262, 50)
	_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_speech)

	_list = make_canvas(Rect2(156, 92, 262, 100), _draw_wishes)
	_title.add_theme_color_override("font_color", Color(0.6, 1.0, 0.55))

func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	# The sky darkens and the dragon rises during the first second.
	var appear := clampf(_time / 1.0, 0.0, 1.0)
	_sky.color.a = 0.97 * appear
	_dragon.modulate = Color(1, 1, 1, appear)
	_dragon.position.y = 30.0 * (1.0 - appear) + sin(_time * 1.6) * 2.0

func refresh() -> void:
	_title.text = "SHENRON"
	if _granted == &"":
		_speech.text = "I am the eternal dragon. I shall grant you one wish. Speak!"
		_hint.text = "Up/Down: Choose    J/E: Make the wish"
	else:
		var result := ""
		for wish: Dictionary in DragonBallManager.WISHES:
			if wish["id"] == _granted:
				result = wish["result"]
		_speech.text = "Your wish has been granted. %s Farewell!" % result
		_hint.text = "J/E: Continue"
	_list.queue_redraw()

func _draw_wishes() -> void:
	if _granted != &"":
		return
	var rows := []
	for wish: Dictionary in DragonBallManager.WISHES:
		rows.append({"text": wish["text"], "color": COLOR_TEXT})
	draw_list(_list, rows, _cursor)
	var font := get_theme_default_font()
	var wish: Dictionary = DragonBallManager.WISHES[_cursor]
	_list.draw_string(font, Vector2(0, 92), wish["result"], HORIZONTAL_ALIGNMENT_LEFT, 262, SMALL_FONT + 1, COLOR_DIM)

func _on_move(direction: Vector2i) -> void:
	if _granted == &"" and direction.y != 0:
		_cursor = wrapi(_cursor + direction.y, 0, DragonBallManager.WISHES.size())
		refresh()

func _on_accept() -> void:
	if _time < 0.6:
		return
	if _granted != &"":
		close()
		return
	make_wish(DragonBallManager.WISHES[_cursor]["id"])

func make_wish(wish_id: StringName) -> bool:
	if _manager == null or not _manager.grant_wish(wish_id):
		set_status("The dragon does not answer...")
		return false
	_granted = wish_id
	refresh()
	return true

# Esc only closes once the wish is made.
func _unhandled_input(event: InputEvent) -> void:
	if visible and _granted == &"" and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)
