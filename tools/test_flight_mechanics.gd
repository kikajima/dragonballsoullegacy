extends SceneTree

# Flight mechanics: passing over walls and fighters, bounds, landing rules,
# fast-flight ki cost, melee by height, airborne shots and flying enemies.
#   Godot --headless --path . --script res://tools/test_flight_mechanics.gd

const ENEMY_SCENE := preload("res://actors/enemies/debug_goku_enemy.tscn")
const KI_BLAST_SCENE := preload("res://combat/projectiles/ki_blast_projectile.tscn")
const STEP := 1.0 / 60.0
var OPEN := Vector2(480, 300)

var failures := 0
var game: Node2D
var player: Player
var flight: FlightComponent
var saves: SaveManager
var world: Node

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	game = load("res://scenes/bootstrap/bootstrap.tscn").instantiate() as Node2D
	saves = game.get_node("SaveManager") as SaveManager
	saves.save_path = "res://audit-flight-mechanics-save.json"
	root.add_child(game)
	current_scene = game
	game.get_node("GameSession").autosave_on_quest_complete = false
	await create_timer(0.2).timeout
	player = get_first_node_in_group("player") as Player
	player.set_physics_process(false)
	flight = player.flight_component
	for enemy in get_nodes_in_group("enemy"):
		enemy.queue_free()
	world = get_first_node_in_group("world_bounds").get_parent()
	await physics_frame
	OPEN = _find_open_area()
	print("open area ", OPEN)

	await _case_collision_layers()
	await _case_walls()
	await _case_over_enemies()
	await _case_landing_rules()
	await _case_bounds()
	await _case_fast_flight_ki()
	await _case_melee_by_height()
	await _case_airborne_shots()
	await _case_enemy_flight()

	print("Flight mechanics: ", failures, " failures")
	saves.delete_save()
	quit(0 if failures == 0 else 1)

func _case_collision_layers() -> void:
	var layer := player.collision_layer
	var mask := player.collision_mask
	player.toggle_flight()
	_expect("layers: flying body on the Flying layer", player.collision_layer == FlightComponent.FLYING_LAYER, str(player.collision_layer))
	_expect("layers: flying body collides with nothing", player.collision_mask == 0, str(player.collision_mask))
	player.global_position = OPEN
	await physics_frame
	player.toggle_flight()
	_expect("layers: landing restores the body layer", player.collision_layer == layer and player.collision_mask == mask, "%d/%d" % [player.collision_layer, player.collision_mask])

func _case_walls() -> void:
	var wall := _make_wall(OPEN + Vector2(40, 0), Vector2(16, 120))
	await physics_frame
	player.global_position = OPEN
	var ground_x := await _travel(Vector2.RIGHT, 50)
	_expect("wall: blocks on the ground", ground_x < OPEN.x + 40.0, str(ground_x))
	player.global_position = OPEN
	player.toggle_flight()
	var air_x := await _travel(Vector2.RIGHT, 50)
	_expect("wall: flown over in the air", air_x > OPEN.x + 60.0, str(air_x))
	flight.land_immediately()
	wall.queue_free()
	await physics_frame

func _case_over_enemies() -> void:
	var enemy := _spawn_enemy(OPEN + Vector2(30, 0))
	enemy.set_physics_process(false)
	await physics_frame
	player.global_position = OPEN
	var ground_x := await _travel(Vector2.RIGHT, 50)
	_expect("enemy: body blocks on the ground", ground_x < OPEN.x + 30.0, str(ground_x))
	player.global_position = OPEN
	player.toggle_flight()
	var air_x := await _travel(Vector2.RIGHT, 50)
	_expect("enemy: flown over", air_x > OPEN.x + 50.0, str(air_x))
	flight.land_immediately()
	enemy.queue_free()
	await physics_frame

func _case_landing_rules() -> void:
	var wall := _make_wall(OPEN, Vector2(80, 80))
	await physics_frame
	player.global_position = OPEN + Vector2(-100, 0)
	player.toggle_flight()
	await physics_frame
	player.global_position = OPEN
	await physics_frame
	_expect("land: blocked over a building", not flight.can_land_at(OPEN), "")
	_expect("land: refused over a building", not flight.land() and player.is_flying(), "")
	flight.land_immediately()
	_expect("land: forced landing moves to free ground", flight.can_land_at(player.global_position) and player.global_position.distance_to(OPEN) > 40.0, str(player.global_position))
	wall.queue_free()
	await physics_frame
	if world.has_method("is_landable_point"):
		_expect("land: island ground is landable", world.is_landable_point(OPEN), "")
		_expect("land: open sea is not landable", not world.is_landable_point(Vector2(20, 20)), "")
		player.toggle_flight()
		player.global_position = Vector2(24, 24)
		await physics_frame
		_expect("land: refused over the sea", not flight.land(), "")
		flight.land_immediately()
		_expect("land: forced landing reaches the island", world.is_landable_point(player.global_position), str(player.global_position))
	else:
		print("SKIP sea landing (world has no coast)")
	player.global_position = OPEN
	await physics_frame

func _case_bounds() -> void:
	var bounds := flight.get_world_bounds()
	_expect("bounds: world bounds found", bounds.size != Vector2.ZERO, str(bounds))
	player.global_position = OPEN
	player.toggle_flight()
	await _travel(Vector2.LEFT, 400, 4.0)
	_expect("bounds: flight stops at the map edge", player.global_position.x >= bounds.position.x + FlightComponent.BOUNDS_MARGIN - 0.5, str(player.global_position))
	await _travel(Vector2.UP, 400, 4.0)
	_expect("bounds: top edge too", player.global_position.y >= bounds.position.y + FlightComponent.BOUNDS_MARGIN - 0.5, str(player.global_position))
	flight.land_immediately()
	player.global_position = OPEN
	await physics_frame

func _case_fast_flight_ki() -> void:
	var ki := player.ki_component
	ki.restore_full()
	player.global_position = OPEN
	player.toggle_flight()
	Input.action_press(&"dash")
	for i in 60:
		_player_step(Vector2.ZERO)
		await physics_frame
	_expect("ki: hovering with run held is free", is_equal_approx(ki.current_ki, ki.max_ki), str(ki.current_ki))
	for i in 60:
		_player_step(Vector2.RIGHT if i % 2 == 0 else Vector2.LEFT)
		await physics_frame
	var spent := ki.max_ki - ki.current_ki
	_expect("ki: fast flight drains ki (~9/s)", spent > 6.0 and spent < 12.0, str(spent))
	ki.consume_up_to(ki.current_ki)
	for i in 4:
		_player_step(Vector2.RIGHT)
		await physics_frame
	_expect("ki: empty tank falls back to normal flight", player.get_current_state() == Player.STATE_FLY, String(player.get_current_state()))
	Input.action_release(&"dash")
	ki.restore_full()
	_player_step(Vector2.RIGHT)
	_expect("ki: cruising is free", player.get_current_state() == Player.STATE_FLY, "")
	flight.land_immediately()
	await physics_frame

func _case_melee_by_height() -> void:
	var enemy := _spawn_enemy(OPEN + Vector2(14, 0))
	enemy.set_physics_process(false)
	enemy.health_component.max_health = 10000
	enemy.health_component.restore_full()
	await physics_frame
	player.global_position = OPEN
	await physics_frame
	_expect("melee: ground punch hits a grounded enemy", await _punch_hits(enemy), "")
	player.toggle_flight()
	await physics_frame
	_expect("melee: flying punch passes over a grounded enemy", not await _punch_hits(enemy), "")
	enemy.flight_component.take_off()
	await physics_frame
	_expect("melee: flying punch hits a flying enemy", await _punch_hits(enemy), "")
	flight.land_immediately()
	await physics_frame
	_expect("melee: ground punch passes under a flying enemy", not await _punch_hits(enemy), "")
	enemy.queue_free()
	await physics_frame

func _case_airborne_shots() -> void:
	var wall := _make_wall(OPEN + Vector2(40, 0), Vector2(16, 120))
	await physics_frame
	player.global_position = OPEN
	var ground_shot := _fire(Vector2.RIGHT)
	for i in 40:
		await physics_frame
	_expect("shot: ground ki blast stops at the wall", not is_instance_valid(ground_shot) or ground_shot.global_position.x < OPEN.x + 50.0, "")
	player.toggle_flight()
	var air_shot := _fire(Vector2.RIGHT)
	for i in 20:
		await physics_frame
	_expect("shot: airborne ki blast flies over the wall", is_instance_valid(air_shot) and air_shot.global_position.x > OPEN.x + 60.0, str(air_shot.global_position if is_instance_valid(air_shot) else "freed"))
	flight.land_immediately()
	wall.queue_free()
	if is_instance_valid(air_shot):
		air_shot.queue_free()
	await physics_frame

func _case_enemy_flight() -> void:
	player.global_position = OPEN
	var enemy := _spawn_enemy(OPEN + Vector2(90, 0))
	enemy.health_component.max_health = 10000
	enemy.health_component.restore_full()
	enemy.attack_cooldown = 99.0
	await create_timer(0.3).timeout
	_expect("enemy: starts on the ground", not enemy.is_flying(), "")
	player.toggle_flight()
	await create_timer(0.8).timeout
	_expect("enemy: takes off after the player", enemy.is_flying(), "")
	_expect("enemy: flying body layer", enemy.collision_layer == FlightComponent.FLYING_LAYER, str(enemy.collision_layer))
	var anim := String(enemy.sprite.animation)
	_expect("enemy: flight animations built", enemy.sprite.sprite_frames.has_animation(&"fly_left") and enemy.sprite.sprite_frames.has_animation(&"fly_hover_down"), "")
	_expect("enemy: airborne animation (flying or striking)", anim.begins_with("fly") or anim.begins_with("attack") or anim.begins_with("ki_blast"), anim)
	flight.land_immediately()
	await create_timer(0.9).timeout
	_expect("enemy: lands after the player", not enemy.is_flying(), "")
	_expect("enemy: ground layer restored", enemy.collision_layer == 4, str(enemy.collision_layer))
	player.toggle_flight()
	await create_timer(0.8).timeout
	enemy.health_component.take_damage(99999) if enemy.health_component.has_method("take_damage") else enemy.health_component.apply_damage(99999)
	await physics_frame
	_expect("enemy: defeated flyer drops to the ground", not enemy.is_flying(), "")
	flight.land_immediately()
	enemy.queue_free()
	await physics_frame

# --- helpers ----------------------------------------------------------------

# A spot with free walkable ground from -120 to +140 px horizontally.
func _find_open_area() -> Vector2:
	# The search area is Kame Island; in the open world it sits at an offset.
	var island := world.get_node_or_null("KameIsland") as Node2D
	var offset := island.position if island != null else Vector2.ZERO
	for y in range(160, 460, 20):
		for x in range(200, 760, 20):
			var p := offset + Vector2(x, y)
			var ok := true
			for dx in range(-120, 150, 10):
				for dy in [-24, 0, 24]:
					if not flight.can_land_at(p + Vector2(dx, dy)):
						ok = false
						break
				if not ok:
					break
			if ok:
				return p
	return offset + Vector2(480, 300)

func _make_wall(at: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	game.add_child(body)
	body.global_position = at
	return body

func _spawn_enemy(at: Vector2) -> DebugGokuEnemy:
	var enemy := ENEMY_SCENE.instantiate() as DebugGokuEnemy
	enemy.respawn_for_debug = false
	game.add_child(enemy)
	enemy.global_position = at
	return enemy

func _player_step(direction: Vector2) -> void:
	player.facing_component.update_from_direction(direction)
	player._update_movement_state(direction)
	player.movement_component.move(player, direction, player._get_locomotion_speed_scale())
	if player.state_machine.is_state(Player.STATE_FLY_FAST):
		player._drain_fast_flight_ki(STEP)

func _travel(direction: Vector2, frames: int, speed_scale: float = 1.0) -> float:
	for i in frames:
		player.movement_component.move(player, direction, speed_scale)
		flight._physics_process(STEP)
		await physics_frame
	return player.global_position.x

func _punch_hits(enemy: DebugGokuEnemy) -> bool:
	var hits: Array = []
	var hurtbox := enemy.get_node("Hurtbox") as HurtboxComponent
	var on_hit := func(d: int, _f: Vector2): hits.append(d)
	hurtbox.hit_received.connect(on_hit)
	hurtbox.grant_invulnerability(0.0) if hurtbox.has_method("grant_invulnerability") else null
	var melee := player.melee_combat_component
	melee.cancel_attack()
	melee.start_attack(&"right", MeleeCombatComponent.ATTACK_PUNCH)
	var guard := 0
	while melee.is_attacking() and guard < 120:
		melee.tick_attack(STEP)
		await physics_frame
		guard += 1
	hurtbox.hit_received.disconnect(on_hit)
	await create_timer(0.3).timeout
	return not hits.is_empty()

func _fire(direction: Vector2) -> Node2D:
	var shot := KI_BLAST_SCENE.instantiate() as Node2D
	game.add_child(shot)
	shot.global_position = player.global_position + direction * 10.0
	shot.setup(direction, 1, player)
	return shot

func _expect(label: String, ok: bool, detail: String) -> void:
	if not ok:
		failures += 1
	print("%s  %s%s" % ["PASS" if ok else "FAIL", label, "" if detail.is_empty() else "  [" + detail + "]"])
