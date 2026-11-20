extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var editor = load("res://tools/sprite_generator/sprite_generator.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	assert(editor.generated == null and editor.sources.selected == -1)
	var initial_goku: int = editor.paths.find(editor.SOURCE_DIR.path_join("Goku.dmi"))
	editor._load_source(initial_goku)
	assert(editor.generated.has_animation(&"spirit_charge_right"))
	assert(editor.generated.has_animation(&"idle_down") or editor.generated.has_animation(&"idle#0_down"))
	if FileAccess.file_exists("res://generated/sprites/catalog/catalog.json"):
		assert(editor.generated.has_animation(&"fly#0_down"))
		assert(editor.generated.has_animation(&"fly#1_down"))
	var before: Color = editor.colors[0]
	editor.replacement.color = Color.MAGENTA
	editor._apply_color()
	assert(editor.mappings[before.to_html()] == Color.MAGENTA.to_html())
	editor._export()
	assert(editor.status.text.begins_with("Exportado:"))
	var folder: String = "res://" + editor.status.text.trim_prefix("Exportado: ")
	var restored := load(folder.path_join("animations.tres")) as SpriteFrames
	assert(restored != null and restored.has_animation(&"spirit_charge_up"))
	var atlas := Image.load_from_file(folder.path_join("spritesheet.png"))
	var recipe: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("recipe.json")))
	for entry in recipe.frames:
		var texture := restored.get_frame_texture(entry.animation, int(entry.frame)).get_image()
		var rect := Rect2i(int(entry.rect[0]), int(entry.rect[1]), int(entry.rect[2]), int(entry.rect[3]))
		assert(atlas.get_region(rect).get_data() == texture.get_data())
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://audit-sprite-generator.png")
	var gba_count := 0
	for index in editor.paths.size():
		if not editor.paths[index].ends_with(".json"):
			continue
		gba_count += 1
		var label: String = editor.sources.get_item_text(index)
		if not ("Master Roshi" in label or "King Yemma" in label):
			continue
		editor.sources.select(index)
		editor._load_source(index)
		if editor.provenance.mapping_status == "reviewed_poses_timing_unmeasured":
			assert(not editor.direction.disabled)
			continue
		editor.gba_view.select(2)
		editor._load_gba_character(editor.paths[index])
		assert(editor.direction.disabled)
		assert(editor.provenance.kind == "gba_character")
		assert(editor.generated.has_animation(&"bloco_01"))
		var raw := Image.load_from_file(editor.paths[index].get_basename() + ".png")
		var block_index := 0
		for name in editor.original.get_animation_names():
			var block: Dictionary = editor.provenance.blocks[block_index]
			var r: Array = block.atlas_rect
			var cell := raw.get_region(Rect2i(r[0], r[1], r[2], r[3]))
			assert(editor.original.get_frame_texture(name, 0).get_image().get_data() == cell.get_data())
			block_index += 1
		editor.replacement.color = Color.MAGENTA
		editor._apply_color()
		editor._export()
		assert(editor.status.text.begins_with("Exportado:"))
		folder = "res://" + editor.status.text.trim_prefix("Exportado: ")
		restored = load(folder.path_join("animations.tres")) as SpriteFrames
		atlas = Image.load_from_file(folder.path_join("spritesheet.png"))
		recipe = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("recipe.json")))
		for entry in recipe.frames:
			var rect := Rect2i(entry.rect[0], entry.rect[1], entry.rect[2], entry.rect[3])
			assert(atlas.get_region(rect).get_data() == restored.get_frame_texture(entry.animation, int(entry.frame)).get_image().get_data())
	var character_manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(editor.GBA_CHARACTERS))
	assert(gba_count == character_manifest.characters.size() and gba_count > 0)
	var goku_index: int = editor.paths.find(editor.SOURCE_DIR.path_join("Goku.dmi"))
	editor._load_source(goku_index)
	assert(not editor.direction.disabled)
	assert(editor.generated.has_animation(&"spirit_charge_right"))
	print("Sprite generator: PASS — HU2/GBA selection, palette, character blocks, export and atlas roundtrip")
	quit()
