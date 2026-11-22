extends SceneTree

# Visual audit: records a filmstrip of every special in four directions.
# One PNG per skill: rows = right/left/up/down, columns = sampled frames.
# Must run WITH a window (not --headless):
#   Godot --path . --script res://tools/capture_special_filmstrip.gd -- --out=<dir> [--only=id,id]

const ENEMY_SCENE := preload("res://actors/enemies/debug_goku_enemy.tscn")
var CROP := Vector2i(200, 120)
var ZOOM := 1
var COLUMNS := 10
var FRAME_STEP := 6
var START_FRAME := 0
const HOLD_FRAMES := 50

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var out_dir := "user://special_filmstrips"
	var only: PackedStringArray = []
	var dir_filter: PackedStringArray = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
		elif arg.begins_with("--only="):
			only = arg.substr(7).split(",")
		elif arg.begins_with("--crop="):
			var parts := arg.substr(7).split("x")
			CROP = Vector2i(int(parts[0]), int(parts[1]))
		elif arg.begins_with("--zoom="):
			ZOOM = int(arg.substr(7))
		elif arg.begins_with("--columns="):
			COLUMNS = int(arg.substr(10))
		elif arg.begins_with("--step="):
			FRAME_STEP = int(arg.substr(7))
		elif arg.begins_with("--start="):
			START_FRAME = int(arg.substr(8))
		elif arg.begins_with("--dirs="):
			dir_filter = arg.substr(7).split(",")
	DirAccess.make_dir_recursive_absolute(out_dir)

	var game := load("res://scenes/bootstrap/bootstrap.tscn").instantiate() as Node2D
	var saves := game.get_node("SaveManager") as SaveManager
	saves.save_path = "res://audit-special-filmstrip-save.json"
	root.add_child(game)
	current_scene = game
	game.get_node("GameSession").autosave_on_quest_complete = false
	await create_timer(0.3).timeout
	var player := get_first_node_in_group("player") as Player
	player.set_physics_process(false)
	for enemy in get_nodes_in_group("enemy"):
		enemy.queue_free()
	for ui in game.get_node("UIContainer").get_children():
		if ui is CanvasItem:
			ui.visible = false
	await physics_frame
	var special := player.special_attack_component
	var forms := special.transformation_component
	var all_directions := {&"right": Vector2.RIGHT, &"left": Vector2.LEFT, &"up": Vector2.UP, &"down": Vector2.DOWN}
	var directions := {}
	for key in all_directions:
		if dir_filter.is_empty() or dir_filter.has(String(key)):
			directions[key] = all_directions[key]
	var cell := CROP * ZOOM

	for index in special.abilities.size():
		var data := special.abilities[index]
		if not only.is_empty() and not only.has(String(data.ability_id)):
			continue
		var sheet := Image.create(cell.x * COLUMNS, cell.y * directions.size(), false, Image.FORMAT_RGBA8)
		var row := 0
		for facing in directions:
			var dir: Vector2 = directions[facing]
			player.global_position = Vector2(480, 360)
			forms.end_transformation()
			special.loadout_component._cooldowns.clear()
			special.ki_component.restore_full()
			var target := ENEMY_SCENE.instantiate() as DebugGokuEnemy
			game.add_child(target)
			target.set_physics_process(false)
			target.health_component.max_health = 100000
			target.health_component.restore_full()
			target.global_position = player.global_position + dir * 70.0
			await physics_frame
			special._selected_index = index
			special.start_cast(facing, dir)
			var column := 0
			for frame in START_FRAME + COLUMNS * FRAME_STEP:
				if special.is_casting():
					special.tick_cast(player, 1.0 / 60.0, frame < HOLD_FRAMES)
					player.animation_controller.update_visual(special.get_cast_state(), special.get_cast_facing(), 1.0 / 60.0)
				else:
					player.animation_controller.update_visual(&"idle", facing, 1.0 / 60.0)
				await physics_frame
				if frame >= START_FRAME and (frame - START_FRAME) % FRAME_STEP == FRAME_STEP - 1 and column < COLUMNS:
					await RenderingServer.frame_post_draw
					var shot := root.get_texture().get_image()
					var scale_x := float(shot.get_width()) / 480.0
					var center := player.get_global_transform_with_canvas().origin * scale_x
					var crop_px := Vector2i(CROP * scale_x)
					var rect := Rect2i(Vector2i(center) - crop_px / 2, crop_px)
					var piece := shot.get_region(rect.intersection(Rect2i(Vector2i.ZERO, shot.get_size())))
					piece.resize(cell.x, cell.y, Image.INTERPOLATE_NEAREST)
					sheet.blit_rect(piece, Rect2i(Vector2i.ZERO, piece.get_size()), Vector2i(column * cell.x, row * cell.y))
					column += 1
			if special.is_casting():
				special.cancel_cast()
			target.queue_free()
			for node in get_nodes_in_group("combat_projectile"):
				node.queue_free()
			await physics_frame
			row += 1
		var path := out_dir.path_join("%02d_%s.png" % [index, data.ability_id])
		sheet.save_png(path)
		print("FILMSTRIP ", path)
	forms.end_transformation()
	saves.delete_save()
	quit(0)
