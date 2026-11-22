extends SceneTree

# Visual audit of the sword (must run WITH a window):
#   Godot --path . --script res://tools/capture_sword_filmstrip.gd -- --out=<dir>
# Writes sheath.png (idle/walk with the scabbard, 4 facings), combo.png (the
# 3-hit sword string, rows = facings), punch.png (same string unequipped)
# and inventory.png (the Tab menu).

const ENEMY_SCENE := preload("res://actors/enemies/debug_goku_enemy.tscn")
const CROP := Vector2i(96, 80)
const ZOOM := 2
const FACINGS: Array[StringName] = [&"right", &"left", &"up", &"down"]
const DIRS := {&"right": Vector2.RIGHT, &"left": Vector2.LEFT, &"up": Vector2.UP, &"down": Vector2.DOWN}

var game: Node2D
var player: Player
var out_dir := "user://sword_filmstrips"

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	game = load("res://scenes/bootstrap/bootstrap.tscn").instantiate() as Node2D
	var saves := game.get_node("SaveManager") as SaveManager
	saves.save_path = "res://audit-sword-filmstrip-save.json"
	root.add_child(game)
	current_scene = game
	game.get_node("GameSession").autosave_on_quest_complete = false
	await create_timer(0.3).timeout
	player = get_first_node_in_group("player") as Player
	player.set_physics_process(false)
	for enemy in get_nodes_in_group("enemy"):
		enemy.queue_free()
	var menu: Node = null
	for ui in game.get_node("UIContainer").get_children():
		if ui is InventoryMenu:
			menu = ui
		elif ui is CanvasItem:
			ui.visible = false
	player.global_position = Vector2(480, 360)
	player.inventory_component.add_item(&"sword", 1)
	await physics_frame

	# Sheath: unequipped idle, then equipped idle/walk per facing.
	var sheet := Image.create(CROP.x * ZOOM * 5, CROP.y * ZOOM * 2, false, Image.FORMAT_RGBA8)
	await _pose(&"idle", &"down")
	_blit(sheet, await _shot(), 0, 0)
	player.equipment_component.equip(&"sword")
	player._equip_pose_left = 0.0
	for i in FACINGS.size():
		await _pose(&"idle", FACINGS[i])
		_blit(sheet, await _shot(), i + 1, 0)
		await _pose(&"walk", FACINGS[i], 3)
		_blit(sheet, await _shot(), i + 1, 1)
	await _pose(&"sword_equip", &"down", 3)
	_blit(sheet, await _shot(), 0, 1)
	sheet.save_png(out_dir.path_join("sheath.png"))

	await _combo(MeleeCombatComponent.ATTACK_SWORD, "combo.png")
	player.equipment_component.unequip(&"weapon")
	await _combo(MeleeCombatComponent.ATTACK_PUNCH, "punch.png")

	if menu != null:
		player.equipment_component.equip(&"sword")
		player._equip_pose_left = 0.0
		menu.open()
		menu.select_item(&"sword")
		for i in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out_dir.path_join("inventory.png"))
		menu.close()

	saves.delete_save()
	print("SWORD FILMSTRIPS ", out_dir)
	quit(0)

func _combo(kind: StringName, file: String) -> void:
	const COLUMNS := 14
	const STEP_FRAMES := 4
	var sheet := Image.create(CROP.x * ZOOM * COLUMNS, CROP.y * ZOOM * FACINGS.size(), false, Image.FORMAT_RGBA8)
	for row in FACINGS.size():
		var facing := FACINGS[row]
		player.global_position = Vector2(480, 360)
		var target := ENEMY_SCENE.instantiate() as DebugGokuEnemy
		game.add_child(target)
		target.set_physics_process(false)
		target.health_component.max_health = 100000
		target.health_component.restore_full()
		target.global_position = player.global_position + DIRS[facing] * 30.0
		await physics_frame
		var melee := player.melee_combat_component
		melee.cancel_attack()
		melee.start_attack(facing, kind)
		var column := 0
		for frame in COLUMNS * STEP_FRAMES:
			if frame % 5 == 0 and frame < 70:
				melee.buffer_attack(facing, kind)
			melee.tick_attack(1.0 / 60.0)
			var state: StringName = melee.get_attack_state() if melee.is_attacking() else &"idle"
			player.animation_controller.update_visual(state, facing, 1.0 / 60.0)
			await physics_frame
			if frame % STEP_FRAMES == STEP_FRAMES - 1 and column < COLUMNS:
				_blit(sheet, await _shot(), column, row)
				column += 1
		melee.cancel_attack()
		target.queue_free()
		await physics_frame
	sheet.save_png(out_dir.path_join(file))

func _pose(state: StringName, facing: StringName, frames: int = 2) -> void:
	for i in frames:
		player.animation_controller.update_visual(state, facing, 1.0 / 60.0)
		await physics_frame

func _shot() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var shot := root.get_texture().get_image()
	var scale_x := float(shot.get_width()) / 480.0
	var center := player.get_global_transform_with_canvas().origin * scale_x
	var crop_px := Vector2i(Vector2(CROP) * scale_x)
	var rect := Rect2i(Vector2i(center) - crop_px / 2, crop_px)
	var piece := shot.get_region(rect.intersection(Rect2i(Vector2i.ZERO, shot.get_size())))
	piece.resize(CROP.x * ZOOM, CROP.y * ZOOM, Image.INTERPOLATE_NEAREST)
	return piece

func _blit(sheet: Image, piece: Image, column: int, row: int) -> void:
	var cell := CROP * ZOOM
	sheet.blit_rect(piece, Rect2i(Vector2i.ZERO, piece.get_size()), Vector2i(column * cell.x, row * cell.y))
