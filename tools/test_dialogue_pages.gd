extends SceneTree

var failures: int = 0
var page_events: int = 0
var finish_events: int = 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var box := load("res://ui/dialogue/dialogue_box.tscn").instantiate() as DialogueBox
	root.add_child(box)
	box.set_process(false)
	box.line_changed.connect(func(_index: int, _text: String) -> void: page_events += 1)
	box.dialogue_finished.connect(func() -> void: finish_events += 1)
	# Read the real tips without entering either map or triggering its saves.
	for source in [
		["res://scenes/world/kame_house_interior.tscn", "TV"],
		["res://scenes/world/kame_island.tscn", "BeachGuide"],
	]:
		var map := load(source[0]).instantiate() as Node
		var tips: String = map.get_node(source[1]).get("text")
		var lines: Array[String] = []
		lines.assign(tips.split("|", false))
		map.free()
		check_dialogue(box, lines, source[1])

	check_dialogue(box, ["one\ntwo\nthree\nfour", "five\n\nsix\nseven\neight"], "Explicit newlines")
	check_dialogue(box, ["ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"], "Long word")
	check_dialogue(box, ["Água, técnica e coração! ".repeat(12)], "Accented text")
	check_dialogue(box, [""], "Empty page")
	check_dialogue(box, ["First\n\n\n\n\nLast\n"], "Blank lines")
	check_dialogue(box, ["One two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen."], "Narrow text area", Vector2(98, 37))

	for was_paused in [false, true]:
		for replace_while_closing in [false, true]:
			paused = was_paused
			box.show_dialogue(["First dialogue"])
			if replace_while_closing:
				box.close_dialogue()
			box.show_dialogue(["Replacement dialogue"])
			box.close_dialogue()
			box.advance()
			check(paused == was_paused, "Replacing dialogue must restore the original pause state")
	paused = false
	box.show_dialogue([])
	check(not box.is_open() and not paused, "An empty dialogue must stay closed")
	if "--screenshots" in OS.get_cmdline_user_args():
		await capture_guide_pages(box)
	box.queue_free()
	await process_frame
	print("Dialogue pages: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(failures)

func check_dialogue(
	box: DialogueBox,
	lines: Array[String],
	label: String,
	text_size: Vector2 = Vector2(146, 52)
) -> void:
	var renderer := box.text_renderer
	renderer.size = text_size
	var start_page_events: int = page_events
	var start_finish_events: int = finish_events
	box.show_dialogue(lines)
	check(paused, label + ": dialogue must pause the game")
	var expected_pages: int = box._pages.size()
	var seen_pages: int = 0
	var rendered_text: String = ""
	box.advance()
	while box._state == DialogueBox.DialogueState.TYPING:
		check(renderer._visible_characters == 0, label + ": each page starts hidden")
		box.advance()
		check(renderer._visible_characters == renderer.get_character_count(), label + ": advance reveals the whole page")
		var wrapped_lines := renderer._wrapped_text.split("\n", true)
		for row in range(wrapped_lines.size()):
			if wrapped_lines[row].is_empty():
				continue
			var bottom: float = row * renderer.line_height + renderer.glyph_draw_offset.y + renderer.glyph_size.y
			var right: float = (wrapped_lines[row].length() - 1) * renderer.character_advance + renderer.glyph_draw_offset.x + renderer.glyph_size.x
			check(bottom <= renderer.size.y, "%s: page %d row %d is clipped vertically" % [label, seen_pages + 1, row + 1])
			check(right <= renderer.size.x, "%s: page %d has a clipped word" % [label, seen_pages + 1])
		rendered_text += renderer._wrapped_text + "\n"
		seen_pages += 1
		check(seen_pages <= expected_pages, label + ": pagination must terminate")
		if seen_pages > expected_pages:
			break
		box.advance()
	check(seen_pages == expected_pages, label + ": every page must be reachable")
	check(page_events - start_page_events == expected_pages, label + ": each page emits line_changed")
	check(without_whitespace(rendered_text) == without_whitespace("".join(lines)), label + ": pagination must preserve every character")
	if label != "Long word":
		check(words(rendered_text) == words("\n".join(lines)), label + ": ordinary words must stay intact")
	box.advance()
	check(not box.is_open() and not paused, label + ": finishing must resume the game")
	check(finish_events - start_finish_events == 1, label + ": finishing emits one signal")
	print("  ", label, ": ", lines.size(), " source entries -> ", seen_pages, " pages")

func without_whitespace(value: String) -> String:
	return value.replace(" ", "").replace("\n", "")

func words(value: String) -> PackedStringArray:
	return value.replace("\n", " ").split(" ", false)

func capture_guide_pages(box: DialogueBox) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var map := load("res://scenes/world/kame_island.tscn").instantiate() as Node
	var tips: String = map.get_node("BeachGuide").get("text")
	map.free()
	box.text_renderer.size = Vector2(146, 52)
	box.show_dialogue([tips.split("|")[-1]])
	box.advance()
	for page in range(box._pages.size()):
		box.advance()
		await process_frame
		await RenderingServer.frame_post_draw
		var path := OS.get_environment("TEMP").path_join("dbsl-dialogue-page-%d.png" % (page + 1))
		check(root.get_texture().get_image().save_png(path) == OK, "Save dialogue screenshot")
		print("Screenshot: ", path)
		box.advance()
	box.advance()
