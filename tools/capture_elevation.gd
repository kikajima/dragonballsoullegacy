extends SceneTree

# Visual audit of skills on the air level (must run WITH a window):
#   Godot --path . --script res://tools/capture_elevation.gd -- --out=<dir>
# Writes elevation.png: columns = ki blast, Kamehameha, Spirit Bomb, a
# grounded Kamehameha for comparison; all aimed across the Kame House.

const CROP := Vector2i(220, 130)
const ZOOM := 2

var game: Node2D
var player: Player
var out_dir := "user://elevation_filmstrips"

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	game = load("res://scenes/bootstrap/bootstrap.tscn").instantiate() as Node2D
	var saves := game.get_node("SaveManager") as SaveManager
	saves.save_path = "res://audit-elevation-capture-save.json"
	root.add_child(game)
	current_scene = game
	game.get_node("GameSession").autosave_on_quest_complete = false
	await create_timer(0.3).timeout
	player = get_first_node_in_group("player") as Player
	player.set_physics_process(false)
	for enemy in get_nodes_in_group("enemy"):
		enemy.queue_free()
	for ui in game.get_node("UIContainer").get_children():
		if ui is CanvasItem:
			ui.visible = false
	var house := game.find_child("KameHouse", true, false) as Node2D
	var roof := house.global_position if house != null else Vector2(480, 250)
	var sheet := Image.create(CROP.x * ZOOM * 4, CROP.y * ZOOM, false, Image.FORMAT_RGBA8)
	var special := player.special_attack_component

	var cases := [[&"ki", true], [&"kamehameha", true], [&"spirit_bomb", true], [&"kamehameha", false]]
	for column in cases.size():
		var id: StringName = cases[column][0]
		var air: bool = cases[column][1]
		player.flight_component.land_immediately()
		player.global_position = roof + Vector2(-70, 40 if not air else 0)
		if air:
			player.flight_component.take_off()
		for i in 30:
			player.animation_controller.update_visual(&"fly_hover" if air else &"idle", &"right", 1.0 / 60.0)
			await physics_frame
		if id == &"ki":
			var shot := (load("res://combat/projectiles/ki_blast_projectile.tscn") as PackedScene).instantiate() as Node2D
			game.add_child(shot)
			shot.global_position = player.global_position + Vector2(12, 0)
			shot.setup(Vector2.RIGHT, 1, player)
			for i in 12:
				await physics_frame
		else:
			for index in special.abilities.size():
				if special.abilities[index].ability_id == id:
					special._selected_index = index
			special.loadout_component._cooldowns.clear()
			special.ki_component.restore_full()
			special.start_cast(&"right", Vector2.RIGHT)
			var beam_frames := 0
			for frame in (120 if id == &"kamehameha" else 46):
				special.tick_cast(player, 1.0 / 60.0, true)
				player.animation_controller.update_visual(special.get_cast_state(), &"right", 1.0 / 60.0)
				await physics_frame
				if not get_nodes_in_group("active_special_beam").is_empty():
					beam_frames += 1
					if beam_frames >= 8:
						break
		_blit(sheet, await _shot(Vector2(70, 0)), column)
		special.cancel_cast()
		for group in [&"combat_projectile", &"active_special_beam"]:
			for node in get_nodes_in_group(group):
				node.queue_free()
		await physics_frame
	sheet.save_png(out_dir.path_join("elevation.png"))
	saves.delete_save()
	print("ELEVATION FILMSTRIPS ", out_dir)
	quit(0)

func _shot(shift: Vector2) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var shot := root.get_texture().get_image()
	var scale_x := float(shot.get_width()) / 480.0
	var center := (player.get_global_transform_with_canvas().origin + shift) * scale_x
	var crop_px := Vector2i(Vector2(CROP) * scale_x)
	var rect := Rect2i(Vector2i(center) - crop_px / 2, crop_px)
	var piece := shot.get_region(rect.intersection(Rect2i(Vector2i.ZERO, shot.get_size())))
	piece.resize(CROP.x * ZOOM, CROP.y * ZOOM, Image.INTERPOLATE_NEAREST)
	return piece

func _blit(sheet: Image, piece: Image, column: int) -> void:
	sheet.blit_rect(piece, Rect2i(Vector2i.ZERO, piece.get_size()), Vector2i(column * CROP.x * ZOOM, 0))
