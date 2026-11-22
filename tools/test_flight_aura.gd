extends SceneTree

# Flight + aura regression.
#   Godot --headless --path . --script res://tools/test_flight_aura.gd

const STEP := 1.0 / 60.0
const FACINGS: Array[StringName] = [&"down", &"left", &"right", &"up"]

var failures := 0
var game: Node2D
var player: Player
var flight: FlightComponent
var aura: PowerAuraComponent
var saves: SaveManager

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	game = load("res://scenes/bootstrap/bootstrap.tscn").instantiate() as Node2D
	saves = game.get_node("SaveManager") as SaveManager
	saves.save_path = "res://audit-flight-aura-save.json"
	root.add_child(game)
	current_scene = game
	game.get_node("GameSession").autosave_on_quest_complete = false
	await create_timer(0.2).timeout
	player = get_first_node_in_group("player") as Player
	player.set_physics_process(false)
	flight = player.flight_component
	aura = player.power_aura
	for enemy in get_nodes_in_group("enemy"):
		enemy.queue_free()
	# Measurements run in open space: ignore the map's walls.
	player.collision_mask = 0
	await physics_frame

	_case_animations()
	await _case_take_off_and_land()
	await _case_flight_speeds()
	await _case_aura_ground_and_air()
	await _case_aura_colors()
	await _case_trail()
	await _case_transformation_flame()
	await _case_save_roundtrip()
	await _case_pause_menu()
	await _case_sword_in_flight()
	await _case_respawn_lands()

	print("Flight aura: ", failures, " failures")
	saves.delete_save()
	quit(0 if failures == 0 else 1)

func _case_animations() -> void:
	var frames := player.animation_controller.sprite.sprite_frames
	for kind in ["fly", "fly_fast", "fly_hover"]:
		for facing in FACINGS:
			var name := StringName("%s_%s" % [kind, facing])
			_expect("anim: %s built" % name, frames.has_animation(name), "")
	_expect("anim: cruise ping-pongs 0-1-2-1", frames.get_frame_count(&"fly_right") == 4, str(frames.get_frame_count(&"fly_right")))
	_expect("anim: fast flight plays faster", frames.get_animation_speed(&"fly_fast_right") > frames.get_animation_speed(&"fly_right"), "")
	_expect("anim: hover holds one frame", frames.get_frame_count(&"fly_hover_down") == 1, "")
	_expect("anim: flying is not the run pose", frames.get_frame_texture(&"fly_right", 0) != frames.get_frame_texture(&"run_right", 0), "")

func _case_take_off_and_land() -> void:
	var sprite := player.animation_controller.sprite
	_expect("ground: not flying", not player.is_flying() and flight.get_lift() == 0.0, "")
	_expect("ground: no flight shadow", flight.get_shadow() == null or not flight.get_shadow().visible, "")
	_expect("toggle: takes off", player.toggle_flight(), "")
	await _drive(Vector2.ZERO, 40)
	_expect("air: hover state", player.get_current_state() == Player.STATE_FLY_HOVER, String(player.get_current_state()))
	_expect("air: hover animation", sprite.animation == &"fly_hover_down", String(sprite.animation))
	var ground_frames := BakedShadowStripper.ground_set(sprite.sprite_frames)
	_expect("air: hover stays upright", (ground_frames.get_frame_texture(&"fly_hover_right", 0) as AtlasTexture).region == (ground_frames.get_frame_texture(&"idle_right", 0) as AtlasTexture).region, "")
	_expect("air: body uses the shadowless frames", BakedShadowStripper.is_airborne_set(sprite.sprite_frames), "")
	var air_image := sprite.sprite_frames.get_frame_texture(&"fly_hover_down", 0).get_image()
	var ground_image := ground_frames.get_frame_texture(&"fly_hover_down", 0).get_image()
	_expect("air: baked feet shadow removed", _count_black(air_image) < _count_black(ground_image) and _count_black(air_image, 28) == 0, "%d -> %d" % [_count_black(ground_image), _count_black(air_image)])
	_expect("air: hair and outline kept", _count_black(air_image) > 0 or _opaque(air_image) > _opaque(ground_image) - _count_black(ground_image, 24) - 1, "")
	_expect("air: body lifted", sprite.position.y <= -9.0, str(sprite.position.y))
	var shadow := flight.get_shadow() as Node2D
	_expect("air: flight shadow on the ground", shadow != null and shadow.visible and shadow.position.y > 10.0, "")
	_expect("air: collision unchanged", is_equal_approx(player.get_node("CollisionShape2D").position.y, 8.0), "")
	_expect("toggle: lands", not player.toggle_flight(), "")
	await _drive(Vector2.ZERO, 40)
	_expect("ground: idle again", player.get_current_state() == Player.STATE_IDLE, String(player.get_current_state()))
	_expect("ground: body back on the ground", is_equal_approx(sprite.position.y, 0.0), str(sprite.position.y))
	_expect("ground: flight shadow gone", not flight.get_shadow().visible, "")
	_expect("ground: baked shadow back on landing", not BakedShadowStripper.is_airborne_set(sprite.sprite_frames), "")

func _case_flight_speeds() -> void:
	var walk := await _distance(Vector2.RIGHT, false, false)
	var run := await _distance(Vector2.RIGHT, true, false)
	var fly := await _distance(Vector2.RIGHT, false, true)
	var fast := await _distance(Vector2.RIGHT, true, true)
	_expect("speed: flying is a bit faster than walking", fly > walk * 1.1, "%f vs %f" % [fly, walk])
	_expect("speed: fast flight is faster than running", fast > run * 1.4, "%f vs %f" % [fast, run])
	_expect("speed: fast flight is faster than flying", fast > fly * 1.6, "%f vs %f" % [fast, fly])
	player.toggle_flight()
	await _drive(Vector2.RIGHT, 2)
	_expect("air: cruise animation", player.animation_controller.sprite.animation == &"fly_right", String(player.animation_controller.sprite.animation))
	Input.action_press(&"dash")
	await _drive(Vector2.RIGHT, 2)
	_expect("air: fast state with run button", player.get_current_state() == Player.STATE_FLY_FAST, String(player.get_current_state()))
	_expect("air: fast animation", player.animation_controller.sprite.animation == &"fly_fast_right", String(player.animation_controller.sprite.animation))
	Input.action_release(&"dash")
	flight.land_immediately()
	await _drive(Vector2.ZERO, 2)

func _case_aura_ground_and_air() -> void:
	aura.set_color(&"white")
	aura.set_enabled(false)
	await _drive(Vector2.ZERO, 2)
	_expect("aura: off by default", aura.get_shown_state() == &"", String(aura.get_shown_state()))
	aura.toggle()
	await _drive(Vector2.ZERO, 2)
	_expect("aura: ground flame", aura.get_shown_state() == &"WhiteEnergy", String(aura.get_shown_state()))
	player.toggle_flight()
	await _drive(Vector2.ZERO, 20)
	_expect("aura: hovering keeps the round flame", aura.get_shown_state() == &"WhiteEnergy", String(aura.get_shown_state()))
	_expect("aura: lifted with the body", aura.position.y <= -9.0, str(aura.position.y))
	await _drive(Vector2.UP, 3)
	_expect("aura: flight flame while moving", aura.get_shown_state() == &"WhiteEnergyFly", String(aura.get_shown_state()))
	aura.toggle()
	await _drive(Vector2.UP, 2)
	_expect("aura: can be turned off in flight", aura.get_shown_state() == &"", String(aura.get_shown_state()))
	aura.toggle()
	await _drive(Vector2.UP, 2)
	_expect("aura: can be turned on in flight", aura.get_shown_state() == &"WhiteEnergyFly", String(aura.get_shown_state()))
	flight.land_immediately()
	await _drive(Vector2.ZERO, 2)

func _case_aura_colors() -> void:
	var dmi := DmiSpriteSheet.load_file(PowerAuraComponent.EFFECT_DMI_PATH)
	for id in PowerAuraComponent.get_color_ids():
		aura.set_color(id)
		for kind in ["", "Fly", "Trail"]:
			_expect("color %s: %s sheet exists" % [id, kind], dmi.has_state(aura.get_sheet_state(kind)), String(aura.get_sheet_state(kind)))
	aura.set_color(&"red")
	await _drive(Vector2.ZERO, 2)
	_expect("color: red flame", aura.get_shown_state() == &"RedEnergy", String(aura.get_shown_state()))
	aura.set_color(&"purple")
	await _drive(Vector2.ZERO, 2)
	var flame := aura.get_node("Flame") as CanvasItem
	_expect("color: purple tints white", aura.get_shown_state() == &"WhiteEnergy" and flame.modulate.b > flame.modulate.g, str(flame.modulate))
	aura.cycle_color(1)
	_expect("color: cycles", aura.color_id == &"pink", String(aura.color_id))
	_expect("color: charge aura follows", (player.charge_aura as DmiEffectSprite2D).dmi_state == &"WhiteEnergy", String((player.charge_aura as DmiEffectSprite2D).dmi_state))
	aura.set_color(&"blue")
	_expect("color: charge aura blue", (player.charge_aura as DmiEffectSprite2D).dmi_state == &"BlueEnergy", "")

func _case_trail() -> void:
	aura.set_color(&"yellow")
	aura.set_enabled(true)
	player.global_position = Vector2(300, 360)
	player.toggle_flight()
	await _drive(Vector2.ZERO, 20)
	await _drive(Vector2.RIGHT, 30)
	_expect("trail: none in normal flight", _trails().is_empty(), str(_trails().size()))
	Input.action_press(&"dash")
	var spawned_before := aura._trail_index
	var from_x := player.global_position.x
	await _drive(Vector2.RIGHT, 60)
	var trails := _trails()
	var spawned := aura._trail_index - spawned_before
	var flown := player.global_position.x - from_x
	_expect("trail: fast flight leaves a trail (one tile per 16px)", spawned >= floori(flown / 16.0) - 1 and spawned >= 3, "%d tiles over %.0fpx" % [spawned, flown])
	if not trails.is_empty():
		var tile := trails[-1] as Sprite2D
		_expect("trail: aura colour", tile.texture != null, "")
		_expect("trail: behind the flyer", tile.global_position.x < player.global_position.x, "%s vs %s" % [tile.global_position, player.global_position])
		_expect("trail: at body height", absf(tile.global_position.y - (player.global_position.y + aura.position.y)) <= 3.0, "%s" % tile.global_position)
		var xs: Array = []
		for t in trails:
			xs.append(roundi((t as Node2D).global_position.x))
		xs.sort()
		var seamless := true
		for i in range(1, xs.size()):
			seamless = seamless and xs[i] - xs[i - 1] == 16
		_expect("trail: tiles join seamlessly", seamless, str(xs))
	Input.action_release(&"dash")
	aura.set_enabled(false)
	var before := _trails().size()
	Input.action_press(&"dash")
	await _drive(Vector2.RIGHT, 20)
	Input.action_release(&"dash")
	_expect("trail: none with aura off", _trails().size() <= before, "")
	await create_timer(0.5).timeout
	_expect("trail: fades away", _trails().is_empty(), str(_trails().size()))
	flight.land_immediately()
	await _drive(Vector2.ZERO, 2)

func _case_transformation_flame() -> void:
	var transform := player.transformation_component
	var ids: Array = transform.get_available_transformations() if transform.has_method("get_available_transformations") else []
	var visual := get_first_node_in_group("transformation_visual_system")
	if visual == null:
		for node in game.find_children("*", "TransformationVisualSystem", true, false):
			visual = node
	if visual == null:
		print("SKIP transformation flame (no visual system)")
		return
	transform.active_transformation = &"super_saiyan"
	visual._on_transformation_started(&"super_saiyan")
	aura.set_enabled(true)
	await process_frame
	await process_frame
	var fx := player.get_node_or_null("Visuals/TransformationAuraFX") as CanvasItem
	_expect("transform: own aura hides the transformation flame", fx == null or not fx.visible, "")
	aura.set_enabled(false)
	await process_frame
	await process_frame
	_expect("transform: flame back with aura off", fx == null or fx.visible, "")
	transform.active_transformation = &""
	visual._on_transformation_ended(&"super_saiyan")

func _case_save_roundtrip() -> void:
	aura.set_color(&"green")
	aura.set_enabled(true)
	player.toggle_flight()
	_expect("save: writes", saves.save_game(), "")
	aura.set_color(&"white")
	aura.set_enabled(false)
	_expect("save: loads", saves.load_game(), "")
	await physics_frame
	_expect("save: aura colour restored", aura.color_id == &"green", String(aura.color_id))
	_expect("save: aura state restored", aura.enabled, "")
	_expect("save: load lands the player", not player.is_flying(), "")

func _case_pause_menu() -> void:
	var pause := game.find_children("*", "PauseMenu", true, false)
	if pause.is_empty():
		_expect("pause: exists", false, "")
		return
	var menu := pause[0] as PauseMenu
	aura.set_enabled(false)
	aura.set_color(&"white")
	menu._pause()
	_expect("pause: aura button", menu.aura_toggle_button.text == "Aura: OFF", menu.aura_toggle_button.text)
	menu.aura_toggle_button.pressed.emit()
	_expect("pause: turns aura on", aura.enabled and menu.aura_toggle_button.text == "Aura: ON", menu.aura_toggle_button.text)
	menu.aura_color_button.pressed.emit()
	_expect("pause: picks next colour", aura.color_id == &"blue" and menu.aura_color_button.text.contains("Blue"), menu.aura_color_button.text)
	menu.cycle_aura_color(-2)
	_expect("pause: picks previous colour", aura.color_id == &"black", String(aura.color_id))
	var panel := menu.get_node("Panel") as Control
	var inside := Rect2(Vector2.ZERO, panel.size).encloses(Rect2(menu.aura_color_button.position, menu.aura_color_button.size))
	_expect("pause: aura row inside the panel", inside, str(panel.size))
	menu._resume()
	_expect("pause: resumes", not paused, "")

func _case_sword_in_flight() -> void:
	player.inventory_component.add_item(&"sword", 1)
	player.equipment_component.equip(&"sword")
	player._equip_pose_left = 0.0
	player.toggle_flight()
	await _drive(Vector2.ZERO, 20)
	_expect("sword: upright scabbard while hovering", player.sword_sheath.get_shown_key() == "%s:full" % player.get_facing(), player.sword_sheath.get_shown_key())
	await _drive(Vector2.RIGHT, 3)
	_expect("sword: scabbard along the back flying right", player.sword_sheath.get_shown_key() == "fly_right:full", player.sword_sheath.get_shown_key())
	await _drive(Vector2.LEFT, 3)
	_expect("sword: scabbard along the back flying left", player.sword_sheath.get_shown_key() == "fly_left:full", player.sword_sheath.get_shown_key())
	await _drive(Vector2.UP, 3)
	_expect("sword: upright scabbard flying up", player.sword_sheath.get_shown_key() == "up:full", player.sword_sheath.get_shown_key())
	_expect("sword: fly scabbard textures exist", SwordAnimationLibrary.get_sheath_textures(&"fly_right", true)[0] != null, "")
	player.equipment_component.unequip(&"weapon")
	flight.land_immediately()

func _case_respawn_lands() -> void:
	player.toggle_flight()
	await _drive(Vector2.ZERO, 10)
	player.reset_runtime_after_load()
	_expect("reset: lands immediately", not player.is_flying() and flight.get_lift() == 0.0, str(flight.get_lift()))

func _distance(direction: Vector2, fast: bool, flying: bool) -> float:
	flight.land_immediately()
	if flying:
		player.toggle_flight()
	player.global_position = Vector2(300, 360)
	await _drive(Vector2.ZERO, 2)
	if fast:
		Input.action_press(&"dash")
	var start := player.global_position
	# Run the real movement code path (state + speed scale).
	for i in 30:
		player._update_movement_state(direction)
		player.movement_component.move(player, direction, player._get_locomotion_speed_scale())
		player.animation_controller.update_visual(player.get_current_state(), &"right", STEP)
		await physics_frame
	if fast:
		Input.action_release(&"dash")
	var travelled := player.global_position.distance_to(start)
	flight.land_immediately()
	return travelled

func _drive(direction: Vector2, frames: int) -> void:
	for i in frames:
		player.facing_component.update_from_direction(direction)
		player._update_movement_state(direction)
		player.movement_component.move(player, direction, player._get_locomotion_speed_scale())
		player.animation_controller.update_visual(player.get_current_state(), player.get_facing(), STEP)
		await physics_frame
		await process_frame

func _trails() -> Array:
	var result: Array = []
	for node in get_nodes_in_group("aura_trail"):
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			result.append(node)
	return result

func _count_black(image: Image, from_row: int = 0) -> int:
	var count := 0
	for y in range(from_row, image.get_height()):
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			if c.a > 0.99 and c.r8 == 0 and c.g8 == 0 and c.b8 == 0:
				count += 1
	return count

func _opaque(image: Image) -> int:
	var count := 0
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.01:
				count += 1
	return count

func _expect(label: String, ok: bool, detail: String) -> void:
	if not ok:
		failures += 1
	print("%s  %s%s" % ["PASS" if ok else "FAIL", label, "" if detail.is_empty() else "  [" + detail + "]"])
