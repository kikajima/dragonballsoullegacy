extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3:
		push_error("Usage: -- source.png first_column count")
		quit(1)
		return
	var source := Image.load_from_file(args[0])
	var first := int(args[1])
	var count := int(args[2])
	root.size = Vector2i(count * 56, 310)
	root.content_scale_size = root.size
	for row in range(4):
		for index in range(count):
			var column := first + index
			var sprite := Sprite2D.new()
			sprite.texture = ImageTexture.create_from_image(source.get_region(Rect2i(column * 32, 32 + row * 32, 32, 32)))
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.scale = Vector2(1.5, 1.5)
			sprite.position = Vector2(28 + index * 56, 40 + row * 74)
			root.add_child(sprite)
			var label := Label.new()
			label.position = Vector2(6 + index * 56, 2 + row * 74)
			label.add_theme_font_size_override("font_size", 11)
			label.text = "%d / %s" % [column, ["D", "L", "R", "U"][row]]
			root.add_child(label)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://audit-gba-columns.png")
	quit()
