class_name JournalMenu
extends GameMenu

# Journal (N): QUESTS (active and finished; J/E tracks one in the HUD),
# SAGAS (the story so far) and DRAGON BALLS (found balls, radar, summoning
# Shenron).

const TABS := ["QUESTS", "SAGAS", "DRAGON BALLS"]
const NPC_NAMES := {
	"roshi": "Master Roshi", "bulma": "Bulma", "piccolo": "Piccolo",
	"turtle": "Turtle", "krillin": "Krillin",
}

var _tab := 0
var _cursor := 0
var _tabs: Control
var _list: Control
var _detail: Control
var _quests: QuestManager
var _balls: DragonBallManager
var _quest_rows: Array[Dictionary] = []

func _ready() -> void:
	super._ready()
	toggle_action = &"journal"
	add_to_group("journal_menu")

func open_tab(tab: int) -> bool:
	_tab = clampi(tab, 0, TABS.size() - 1)
	_cursor = 0
	return open()

func _on_opened() -> void:
	_quests = get_tree().get_first_node_in_group("quest_manager") as QuestManager
	_balls = get_tree().get_first_node_in_group("dragon_ball_manager") as DragonBallManager

func _build_content() -> void:
	_title.text = "JOURNAL"
	_tabs = make_canvas(Rect2(80, 4, 300, 14), func() -> void: draw_tabs(_tabs, TABS, _tab))
	_list = make_canvas(Rect2(8, 22, 176, 176), _draw_list)
	_detail = make_canvas(Rect2(192, 22, 232, 178), _draw_detail)

func refresh() -> void:
	if _quests == null:
		_quests = get_tree().get_first_node_in_group("quest_manager") as QuestManager
	if _balls == null:
		_balls = get_tree().get_first_node_in_group("dragon_ball_manager") as DragonBallManager
	_quest_rows.clear()
	if _quests != null:
		_quest_rows.append_array(_quests.get_active_quests())
		var done := _quests.get_completed_quests()
		done.reverse()
		_quest_rows.append_array(done)
	_cursor = clampi(_cursor, 0, maxi(_row_count() - 1, 0))
	match _tab:
		0:
			_hint.text = "J/E: Track in HUD    Up/Down: Choose    Left/Right: Tabs    N/Esc: Close"
		1:
			_hint.text = "Up/Down: Choose saga    Left/Right: Tabs    N/Esc: Close"
		2:
			var summon := _balls != null and _balls.can_summon()
			_hint.text = ("J/E: Summon Shenron    " if summon else "") + "Left/Right: Tabs    N/Esc: Close"
	_tabs.queue_redraw()
	_list.queue_redraw()
	_detail.queue_redraw()

func _row_count() -> int:
	match _tab:
		0:
			return _quest_rows.size()
		1:
			return QuestCatalog.SAGAS.size()
	return 0

func _on_move(direction: Vector2i) -> void:
	if direction.x != 0:
		_tab = wrapi(_tab + direction.x, 0, TABS.size())
		_cursor = 0
		set_status("")
	else:
		_cursor = clampi(_cursor + direction.y, 0, maxi(_row_count() - 1, 0))
	refresh()

func _on_accept() -> void:
	match _tab:
		0:
			if _cursor < _quest_rows.size() and _quests != null:
				var state := _quest_rows[_cursor]
				if _quests.is_active(StringName(str(state["quest_id"]))):
					_quests.set_tracked(StringName(str(state["quest_id"])))
					set_status("Tracking: %s" % state.get("title", ""), COLOR_GOOD)
		2:
			summon_shenron()
	refresh()

func summon_shenron() -> bool:
	if _balls == null or not _balls.can_summon():
		set_status("You need all seven Dragon Balls" if _balls == null or not _balls.is_stone() else "The Dragon Balls are stone")
		return false
	var world := get_tree().get_first_node_in_group("open_world") as OpenWorld
	if world == null:
		set_status("Go outside to summon the dragon")
		return false
	var menu := get_tree().get_first_node_in_group("shenron_menu") as ShenronWishMenu
	if menu == null:
		return false
	close()
	return menu.summon()

# --- Drawing -----------------------------------------------------------------

func _draw_list() -> void:
	match _tab:
		0:
			var rows := []
			for state in _quest_rows:
				var status := str(state.get("status", ""))
				var tracked := _quests != null and str(_quests.get_tracked_quest().get("quest_id", "")) == str(state["quest_id"])
				rows.append({
					"text": ("> " if tracked else "") + str(state.get("title", "")),
					"color": COLOR_DIM if status == QuestManager.STATUS_COMPLETED else COLOR_TEXT,
					"right": {"ready": "REPORT", "completed": "DONE"}.get(status, ""),
					"right_color": COLOR_GOOD if status == QuestManager.STATUS_READY else COLOR_DIM,
				})
			if rows.is_empty():
				rows.append({"text": "No quests yet", "color": COLOR_DIM})
			draw_list(_list, rows, _cursor)
		1:
			var rows := []
			for saga: Dictionary in QuestCatalog.SAGAS:
				var progress := _saga_progress(saga["id"])
				var right := "LOCKED"
				if progress.get("completed", false):
					right = "DONE"
				elif progress.get("started", false):
					right = "%d/%d" % [progress["done"], progress["total"]]
				rows.append({
					"text": saga["title"] if progress.get("started", false) else "???",
					"color": COLOR_TEXT if progress.get("started", false) else COLOR_DIM,
					"right": right,
					"right_color": COLOR_GOOD if right == "DONE" else COLOR_GOLD,
				})
			draw_list(_list, rows, _cursor)
		2:
			_draw_balls(_list)

func _draw_detail() -> void:
	var font := get_theme_default_font()
	match _tab:
		0:
			if _cursor >= _quest_rows.size():
				return
			var state := _quest_rows[_cursor]
			var y := 10.0
			_detail.draw_string(font, Vector2(0, y), str(state.get("title", "")), HORIZONTAL_ALIGNMENT_LEFT, 232, FONT_SIZE, COLOR_GOLD)
			y += 4
			var saga := QuestCatalog.get_saga(StringName(str(state.get("saga_id", ""))))
			if not saga.is_empty():
				y += 10
				_detail.draw_string(font, Vector2(0, y), saga["title"], HORIZONTAL_ALIGNMENT_LEFT, 232, SMALL_FONT, COLOR_DIM)
			y += 4
			for line in _wrap(str(state.get("description", "")), 228, font):
				y += 10
				_detail.draw_string(font, Vector2(0, y), line, HORIZONTAL_ALIGNMENT_LEFT, 232, SMALL_FONT + 1, COLOR_DIM)
			y += 16
			for objective: Dictionary in state.get("objectives", []):
				var progress := int(objective.get("progress", 0))
				var target := int(objective.get("target", 1))
				var done := progress >= target
				_detail.draw_string(font, Vector2(0, y), ("[x] " if done else "[ ] ") + str(objective.get("text", "")),
					HORIZONTAL_ALIGNMENT_LEFT, 190, SMALL_FONT + 1, COLOR_GOOD if done else COLOR_TEXT)
				if target > 1:
					_detail.draw_string(font, Vector2(0, y), "%d/%d" % [progress, target],
						HORIZONTAL_ALIGNMENT_RIGHT, 230, SMALL_FONT + 1, COLOR_GOOD if done else COLOR_GOLD)
				y += 12
			var turn_in := str(state.get("turn_in", ""))
			if not turn_in.is_empty() and str(state.get("status", "")) != QuestManager.STATUS_COMPLETED:
				y += 2
				_detail.draw_string(font, Vector2(0, y), "Report to %s" % NPC_NAMES.get(turn_in, turn_in.capitalize()),
					HORIZONTAL_ALIGNMENT_LEFT, 232, SMALL_FONT + 1,
					COLOR_GOOD if str(state.get("status", "")) == QuestManager.STATUS_READY else COLOR_DIM)
				y += 12
			var rewards := _reward_text(state)
			if not rewards.is_empty():
				y += 4
				for line in _wrap("Reward: " + rewards, 228, font):
					_detail.draw_string(font, Vector2(0, y), line, HORIZONTAL_ALIGNMENT_LEFT, 232, SMALL_FONT, COLOR_GOLD)
					y += 9
		1:
			var saga: Dictionary = QuestCatalog.SAGAS[_cursor]
			var progress := _saga_progress(saga["id"])
			var started: bool = progress.get("started", false)
			var y := 10.0
			_detail.draw_string(font, Vector2(0, y), saga["title"] if started else "???", HORIZONTAL_ALIGNMENT_LEFT, 232, FONT_SIZE, COLOR_GOLD)
			y += 4
			var summary: String = saga["summary"] if started else "Finish the previous saga to unlock it."
			for line in _wrap(summary, 228, font):
				y += 10
				_detail.draw_string(font, Vector2(0, y), line, HORIZONTAL_ALIGNMENT_LEFT, 232, SMALL_FONT + 1, COLOR_DIM)
			y += 16
			if not started:
				return
			var number := 1
			for quest_id: StringName in saga["quests"]:
				var known := _quests != null and _quests.is_started(quest_id)
				var done := _quests != null and _quests.is_completed(quest_id)
				var definition := QuestCatalog.get_definition(quest_id)
				var text := "%d. %s" % [number, definition.title if known else "???"]
				_detail.draw_string(font, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_LEFT, 196, SMALL_FONT + 1,
					COLOR_GOOD if done else (COLOR_GOLD if known else COLOR_DIM))
				if done:
					_detail.draw_string(font, Vector2(0, y), "DONE", HORIZONTAL_ALIGNMENT_RIGHT, 230, SMALL_FONT, COLOR_GOOD)
				elif known:
					_detail.draw_string(font, Vector2(0, y), "NOW", HORIZONTAL_ALIGNMENT_RIGHT, 230, SMALL_FONT, COLOR_GOLD)
				y += 12
				number += 1
		2:
			_draw_ball_detail()

func _draw_balls(canvas: Control) -> void:
	if _balls == null:
		return
	for index in DragonBallManager.COUNT:
		var held := _balls.is_held(index)
		var icon := DragonBallField.ball_icon(index, not held)
		var at := Vector2(8 + (index % 4) * 40, 16 + (index / 4) * 44)
		canvas.draw_rect(Rect2(at - Vector2(4, 4), Vector2(40, 40)), COLOR_CELL)
		canvas.draw_rect(Rect2(at - Vector2(4, 4), Vector2(40, 40)).grow(-0.5), COLOR_GOLD if held else COLOR_CELL_EDGE, false, 1.0)
		if icon != null:
			canvas.draw_texture(icon, at, Color.WHITE if held else Color(1, 1, 1, 0.35))
	var font := get_theme_default_font()
	canvas.draw_string(font, Vector2(8, 120), "Found: %d / %d" % [_balls.held_count(), DragonBallManager.COUNT],
		HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, COLOR_GOLD)

func _draw_ball_detail() -> void:
	if _balls == null:
		return
	var font := get_theme_default_font()
	var lines: Array = []
	lines.append(["THE DRAGON BALLS", COLOR_GOLD, FONT_SIZE])
	lines.append(["Seven balls lie scattered across the Earth. Gather all seven to summon Shenron, who grants one wish.", COLOR_DIM, SMALL_FONT + 1])
	var radar := inventory != null and inventory.get_bag_quantity(&"dragon_radar") > 0
	lines.append(["Dragon Radar: %s" % ("in your bag" if radar else "not carried (Bulma, shops, workbench)"),
		COLOR_GOOD if radar else COLOR_WARN, SMALL_FONT + 1])
	if _balls.is_stone():
		lines.append(["The balls are stone for %d more minutes." % ceili(_balls.stone_seconds_left() / 60.0), COLOR_WARN, SMALL_FONT + 1])
	elif _balls.can_summon():
		lines.append(["All seven gathered! Press J or E to summon Shenron.", COLOR_GOOD, SMALL_FONT + 1])
	else:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if radar and player != null and get_tree().get_first_node_in_group("open_world") != null:
			var nearest := _balls.nearest_ball(player.global_position)
			if not nearest.is_empty():
				lines.append(["Nearest ball: %s, %d m" % [DragonRadarHUD.compass(nearest["point"] - player.global_position),
					roundi(float(nearest["distance"]) / 32.0 * 10.0)], COLOR_TEXT, SMALL_FONT + 1])
	lines.append(["Wishes made: %d" % _balls.wishes_made(), COLOR_DIM, SMALL_FONT + 1])
	var y := 10.0
	for entry in lines:
		for line in _wrap(entry[0], 228, font, entry[2]):
			_detail.draw_string(font, Vector2(0, y), line, HORIZONTAL_ALIGNMENT_LEFT, 232, entry[2], entry[1])
			y += 11
		y += 5

func _saga_progress(saga_id: StringName) -> Dictionary:
	return _quests.get_saga_progress(saga_id) if _quests != null else {}

func _reward_text(state: Dictionary) -> String:
	var parts: Array[String] = []
	if int(state.get("reward_experience", 0)) > 0:
		parts.append("%d XP" % int(state["reward_experience"]))
	if int(state.get("reward_currency", 0)) > 0:
		parts.append("%d Zeni" % int(state["reward_currency"]))
	var items: Dictionary = state.get("reward_items", {}) if state.get("reward_items") is Dictionary else {}
	if not str(state.get("reward_item_id", "")).is_empty() and int(state.get("reward_item_amount", 0)) > 0:
		items = items.duplicate()
		items[str(state["reward_item_id"])] = int(items.get(str(state["reward_item_id"]), 0)) + int(state["reward_item_amount"])
	for item_id in items:
		parts.append("%s x%d" % [ItemCatalog.get_display_name(StringName(str(item_id))), int(items[item_id])])
	return ", ".join(parts)

func _wrap(text: String, width: float, font: Font, size: int = SMALL_FONT + 1) -> Array[String]:
	var lines: Array[String] = []
	var line := ""
	for word in text.split(" "):
		var candidate := word if line.is_empty() else line + " " + word
		if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and not line.is_empty():
			lines.append(line)
			line = word
		else:
			line = candidate
	if not line.is_empty():
		lines.append(line)
	return lines
