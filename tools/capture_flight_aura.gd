extends SceneTree

# Visual audit of flight + aura (must run WITH a window):
#   Godot --path . --script res://tools/capture_flight_aura.gd -- --out=<dir>
# Writes poses.png (rows: ground / hover / cruise, each without and with the
# aura, columns = facings), colors.png (every aura colour, ground + flight),
# trail.png (fast flight with the trail, right and down), sword.png
# (flying with the sword equipped), pause.png (aura options) and
# mechanics.png (over the Kame House roof, then a flying enemy chase).

const CROP := Vector2i(80, 72)
const ZOOM := 2
const FACINGS: Array[StringName] = [&"down", &"left", &"right", &"up"]
const DIRS := {&"right": Vector2.RIGHT, &"left": Vector2.LEFT, &"up": Vector2.UP, &"down": Vector2.DOWN}

var game: Node2D
var player: Player
var out_dir := "user://flight_aura_filmstrips"

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	game = load("res://scenes/bootstrap/bootstrap.tscn").instantiate() as Node2D
	var saves := game.get_node("SaveManager") as SaveManager
	saves.save_path = "res://audit-flight-aura-capture-save.json"
	root.add_child(game)
	current_scene = game
	game.get_node("GameSession").autosave_on_quest_complete = false
	await create_timer(0.3).timeout
	player = get_first_node_in_group("player") as Player
	player.set_physics_process(false)
	player.collision_mask = 0
	for enemy in get_nodes_in_group("enemy"):
		enemy.queue_free()
	var pause: PauseMenu = null
	for ui in game.get_node("UIContainer").get_children():
		if ui is PauseMenu:
			pause = ui
		elif ui is CanvasItem:
			ui.visible = false
	var aura := player.power_aura
	var flight := player.flight_component

	# Poses: 6 rows x 4 facings.
	var sheet := Image.create(CROP.x * ZOOM * 4, CROP.y * ZOOM * 6, false, Image.FORMAT_RGBA8)
	var row := 0
	for mode in ["ground", "hover", "cruise"]:
		for with_aura in [false, true]:
			aura.set_color(&"white")
			aura.set_enabled(with_aura)
			for i in FACINGS.size():
				var facing := FACINGS[i]
				_place()
				flight.land_immediately()
				if mode != "ground":
					flight.take_off()
				await _drive(Vector2.ZERO, facing, 30)
				if mode == "cruise":
					await _drive(DIRS[facing], facing, 5)
				_blit(sheet, await _shot(CROP), i, row)
			row += 1
	sheet.save_png(out_dir.path_join("poses.png"))

	# Colours: ground (row 0) and cruising right (row 1).
	var ids := PowerAuraComponent.get_color_ids()
	var colors := Image.create(CROP.x * ZOOM * ids.size(), CROP.y * ZOOM * 2, false, Image.FORMAT_RGBA8)
	aura.set_enabled(true)
	for i in ids.size():
		aura.set_color(ids[i])
		_place()
		flight.land_immediately()
		await _drive(Vector2.ZERO, &"down", 4)
		_blit(colors, await _shot(CROP), i, 0)
		flight.take_off()
		await _drive(Vector2.ZERO, &"right", 30)
		await _drive(Vector2.RIGHT, &"right", 5)
		_blit(colors, await _shot(CROP), i, 1)
	colors.save_png(out_dir.path_join("colors.png"))

	# Trail while flying fast.
	var wide := Vector2i(220, 120)
	var trail := Image.create(wide.x * ZOOM, wide.y * ZOOM * 3, false, Image.FORMAT_RGBA8)
	var trail_cases := [[&"yellow", &"right"], [&"blue", &"down"], [&"red", &"left"]]
	for i in trail_cases.size():
		aura.set_color(trail_cases[i][0])
		var facing: StringName = trail_cases[i][1]
		_place()
		flight.land_immediately()
		flight.take_off()
		await _drive(Vector2.ZERO, facing, 30)
		Input.action_press(&"dash")
		await _drive(DIRS[facing], facing, 34)
		var shot := await _shot(wide, -DIRS[facing] * 50.0)
		Input.action_release(&"dash")
		_blit_size(trail, shot, wide, 0, i)
	trail.save_png(out_dir.path_join("trail.png"))

	# Flying with the sword equipped.
	player.inventory_component.add_item(&"sword", 1)
	player.equipment_component.equip(&"sword")
	player._equip_pose_left = 0.0
	aura.set_enabled(false)
	var sword := Image.create(CROP.x * ZOOM * 4, CROP.y * ZOOM * 2, false, Image.FORMAT_RGBA8)
	for i in FACINGS.size():
		_place()
		flight.land_immediately()
		flight.take_off()
		await _drive(Vector2.ZERO, FACINGS[i], 30)
		_blit(sword, await _shot(CROP), i, 0)
		await _drive(DIRS[FACINGS[i]], FACINGS[i], 5)
		_blit(sword, await _shot(CROP), i, 1)
	sword.save_png(out_dir.path_join("sword.png"))
	flight.land_immediately()

	# Mechanics: crossing the Kame House roof, then a flying enemy.
	var mech_crop := Vector2i(200, 150)
	var mech := Image.create(mech_crop.x * ZOOM * 3, mech_crop.y * ZOOM, false, Image.FORMAT_RGBA8)
	player.equipment_component.unequip(&"weapon")
	aura.set_color(&"white")
	aura.set_enabled(true)
	player.collision_mask = 5
	var house := game.find_child("KameHouse", true, false) as Node2D
	var roof := house.global_position if house != null else Vector2(480, 250)
	flight.land_immediately()
	player.global_position = roof + Vector2(0, 70)
	await _drive(Vector2.ZERO, &"up", 4)
	await _drive(Vector2.UP, &"up", 50)
	_blit_size(mech, await _shot(mech_crop, Vector2(0, -30)), mech_crop, 0, 0)
	player.global_position = roof + Vector2(0, 70)
	flight.take_off()
	await _drive(Vector2.ZERO, &"up", 30)
	await _drive(Vector2.UP, &"up", 45)
	_blit_size(mech, await _shot(mech_crop, Vector2(0, 10)), mech_crop, 1, 0)
	var enemy := (load("res://actors/enemies/debug_goku_enemy.tscn") as PackedScene).instantiate() as DebugGokuEnemy
	enemy.respawn_for_debug = false
	game.add_child(enemy)
	enemy.health_component.max_health = 100000
	enemy.health_component.restore_full()
	enemy.attack_cooldown = 99.0
	enemy.global_position = roof + Vector2(70, -60)
	player.global_position = roof + Vector2(-40, -60)
	for i in 50:
		await physics_frame
	_blit_size(mech, await _shot(mech_crop, Vector2(30, 0)), mech_crop, 2, 0)
	enemy.queue_free()
	flight.land_immediately()
	mech.save_png(out_dir.path_join("mechanics.png"))

	if pause != null:
		aura.set_color(&"purple")
		aura.set_enabled(true)
		pause._pause()
		for i in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out_dir.path_join("pause.png"))
		pause._resume()

	saves.delete_save()
	print("FLIGHT AURA FILMSTRIPS ", out_dir)
	quit(0)

func _place() -> void:
	player.global_position = Vector2(480, 360)

func _drive(direction: Vector2, facing: StringName, frames: int) -> void:
	for i in frames:
		player.facing_component.update_from_direction(direction if direction != Vector2.ZERO else DIRS[facing] * 0.01)
		player._update_movement_state(direction)
		player.movement_component.move(player, direction, player._get_locomotion_speed_scale())
		player.animation_controller.update_visual(player.get_current_state(), facing, 1.0 / 60.0)
		await physics_frame

func _shot(crop: Vector2i, shift: Vector2 = Vector2.ZERO) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var shot := root.get_texture().get_image()
	var scale_x := float(shot.get_width()) / 480.0
	var center := (player.get_global_transform_with_canvas().origin + shift) * scale_x
	var crop_px := Vector2i(Vector2(crop) * scale_x)
	var rect := Rect2i(Vector2i(center) - crop_px / 2, crop_px)
	var piece := shot.get_region(rect.intersection(Rect2i(Vector2i.ZERO, shot.get_size())))
	piece.resize(crop.x * ZOOM, crop.y * ZOOM, Image.INTERPOLATE_NEAREST)
	return piece

func _blit(sheet: Image, piece: Image, column: int, row: int) -> void:
	_blit_size(sheet, piece, CROP, column, row)

func _blit_size(sheet: Image, piece: Image, crop: Vector2i, column: int, row: int) -> void:
	var cell := crop * ZOOM
	sheet.blit_rect(piece, Rect2i(Vector2i.ZERO, piece.get_size()), Vector2i(column * cell.x, row * cell.y))
