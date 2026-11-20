extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var source := Image.load_from_file("res://assets/sprites/characters/goku/source/goku_buus_fury_source.png")
	for row in range(2):
		for column in range(32, 48):
			var sprite := Sprite2D.new()
			sprite.texture = ImageTexture.create_from_image(source.get_region(Rect2i(column * 32, 32 + row * 32, 32, 32)))
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.scale = Vector2(1.5, 1.5)
			sprite.position = Vector2(30 + ((column - 32) % 8) * 58, 30 + (row * 2 + (column - 32) / 8) * 60)
			root.add_child(sprite)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://audit-spirit-poses.png")
	quit()
