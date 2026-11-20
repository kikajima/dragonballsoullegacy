extends SceneTree

func _initialize() -> void:
	_preview.call_deferred()

func _preview() -> void:
	root.size = Vector2i(960, 544)
	var island := load("res://scenes/world/kame_island.tscn").instantiate() as Node2D
	root.add_child(island)
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://audit-kame-sand.png")
	quit()
