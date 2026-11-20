extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var editor = load("res://tools/sprite_generator/sprite_generator.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	assert(editor.generated == null)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://audit-sprite-chooser.png")
	editor.origin_filter.select(1)
	editor.search.text = "Roshi"
	editor._filter_sources()
	assert(editor.sources.item_count > 0)
	for i in editor.sources.item_count:
		var actual: int = editor.sources.get_item_metadata(i)
		assert(editor.paths[actual].ends_with(".json"))
		assert("roshi" in editor.source_labels[actual].to_lower())
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(editor.GBA_CHARACTERS))
	var pose_count := 0
	for record in manifest.characters:
		if record.poses.is_empty():
			continue
		var path: String = "res://generated/sprites/characters/" + String(record.image).get_basename() + ".json"
		var index: int = editor.paths.find(path)
		assert(index >= 0)
		editor._load_source(index)
		assert(editor.provenance.mapping_status == "reviewed_poses_timing_unmeasured")
		var source := Image.load_from_file(path.get_basename() + ".png")
		for pose in record.poses:
			pose_count += 1
			for frame in pose.frames:
				var name := StringName("%s_%s" % [pose.name, frame.direction])
				assert(editor.generated.has_animation(name))
				var r: Array = frame.rect
				var rect := Rect2i(r[0], r[1], r[2], r[3])
				assert(editor.generated.get_frame_texture(name, int(frame.frame)).get_image().get_data() == source.get_region(rect).get_data())
		if record.label == "Master Roshi":
			assert(editor.generated.has_animation(&"walk_left"))
			assert(editor.generated.get_frame_count(&"walk_left") == 4)
			if DisplayServer.get_name() != "headless":
				editor.animations.select(1)
				editor._update_directions()
				editor._play()
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://audit-sprite-roshi.png")
			editor.replacement.color = Color.MAGENTA
			editor._apply_color()
			editor._export()
			assert(editor.status.text.begins_with("Exportado:"))
			var folder: String = "res://" + editor.status.text.trim_prefix("Exportado: ")
			var exported: SpriteFrames = load(folder.path_join("animations.tres"))
			assert(exported.has_animation(&"walk_up"))
			var atlas := Image.load_from_file(folder.path_join("spritesheet.png"))
			var recipe: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("recipe.json")))
			for f in recipe.frames:
				var r: Array = f.rect
				assert(atlas.get_region(Rect2i(r[0],r[1],r[2],r[3])).get_data() == exported.get_frame_texture(f.animation,int(f.frame)).get_image().get_data())
	assert(pose_count == int(manifest.mapped_poses))
	var gba_goku := -1
	for i in editor.paths.size():
		if editor.source_labels[i] == "GBA — Goku [dbzbuusfury]":
			gba_goku = i
	assert(gba_goku >= 0)
	editor._load_source(gba_goku)
	assert(editor.generated.has_animation(&"run_down"))
	editor.gba_view.select(1)
	editor._load_gba_character(editor.paths[gba_goku])
	assert(editor.provenance.mapping_status == "unreviewed_regions_not_animations")
	assert(editor.animations.item_count > 0)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://audit-sprite-pending.png")
	assert(editor.generated.get_frame_count(editor.generated.get_animation_names()[0]) == 1)
	editor._export()
	assert(editor.status.text.begins_with("Exportado:"))
	var pending_folder: String = "res://" + editor.status.text.trim_prefix("Exportado: ")
	var pending_recipe: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(pending_folder.path_join("recipe.json")))
	assert(pending_recipe.frames.size() == 1)
	assert(pending_recipe.sources.mapping_status == "unreviewed_regions_not_animations")
	editor.gba_view.select(2)
	editor._load_gba_character(editor.paths[gba_goku])
	assert(editor.generated.has_animation(&"bloco_01"))
	assert(editor.direction.disabled)
	editor.search.text = "zzzz sem resultado"
	editor._filter_sources()
	assert(editor.sources.item_count == 0)
	print("GBA poses: PASS — startup chooser, search, all %d mapped poses, exact pixels, recolor/export" % pose_count)
	quit()
