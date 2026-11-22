extends SceneTree

# Behavioral regression for every special except Kamehameha / Spirit Bomb
# (those have dedicated tests). Each case checks the rule the technique was
# designed around, not merely "some damage happened".
#
#   Godot --headless --path . --script res://tools/test_special_behaviors.gd

const ENEMY_SCENE := preload("res://actors/enemies/debug_goku_enemy.tscn")
const STEP := 1.0 / 60.0

var failures := 0
var game: Node2D
var player: Player
var special: SpecialAttackComponent
var _targets: Array[DebugGokuEnemy] = []
var _walls: Array[Node] = []
var _hits: Dictionary = {}

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	game = load("res://scenes/bootstrap/bootstrap.tscn").instantiate() as Node2D
	var saves := game.get_node("SaveManager") as SaveManager
	saves.save_path = "res://audit-special-behaviors-save.json"
	root.add_child(game)
	current_scene = game
	game.get_node("GameSession").autosave_on_quest_complete = false
	await create_timer(0.2).timeout
	player = get_first_node_in_group("player") as Player
	# Sword techniques (Cross Slash, Sword Blast) need the sword equipped.
	player.inventory_component.add_item(&"sword", 1)
	player.equipment_component.equip(&"sword")
	player._equip_pose_left = 0.0
	player.set_physics_process(false)
	special = player.special_attack_component
	for enemy in get_nodes_in_group("enemy"):
		enemy.queue_free()
	await physics_frame

	await _case_burning()
	await _case_big_bang()
	await _case_scatter()
	await _case_masenko()
	await _case_sword_blast()
	await _case_energy_punch()
	await _case_charged_lunges()
	await _case_whirlspin()
	await _case_flurry()
	await _case_peace_sign()
	await _case_beam_cannon()
	await _case_point_blank_and_walls()
	await _case_super_namek()

	print("Special behaviors: ", failures, " failures")
	saves.delete_save()
	quit(0 if failures == 0 else 1)

# ---------------------------------------------------------------- cases

func _case_burning() -> void:
	await _reset()
	var t := await _spawn(Vector2(80, 0))
	var r := await _cast(&"burning_attack", 0)
	_expect("burning: one direct hit of 18", _hits_on(t) == [18], str(_hits_on(t)))
	_expect("burning: stuns target", r.stunned.get(t, false), "")
	_expect("burning: costs 18 Ki", is_equal_approx(r.ki_spent, 18.0), str(r.ki_spent))
	_expect("burning: starts cooldown", r.cooldown > 0.0, "")

func _case_big_bang() -> void:
	await _reset()
	var a := await _spawn(Vector2(90, 0))
	var b := await _spawn(Vector2(105, 18))
	var r := await _cast(&"big_bang_attack", 120)
	_expect("big bang: explosion hits the target", _hits_on(a).size() == 1, str(_hits_on(a)))
	_expect("big bang: explosion splashes a neighbour", _hits_on(b).size() == 1, str(_hits_on(b)))
	_expect("big bang: full charge more than doubles damage", _sum(a) >= 60, str(_hits_on(a)))
	_expect("big bang: full charge spends base + charge Ki", is_equal_approx(r.ki_spent, 56.0), str(r.ki_spent))

func _case_scatter() -> void:
	await _reset()
	var data := _data(&"scatter_shot")
	var half := deg_to_rad(data.spread_degrees * 0.5)
	var center := await _spawn(Vector2(120, 0))
	var up := await _spawn(Vector2.RIGHT.rotated(-half) * 120.0)
	var down := await _spawn(Vector2.RIGHT.rotated(half) * 120.0)
	var r := await _cast(&"scatter_shot", 0)
	for pair in [["center", center], ["upper", up], ["lower", down]]:
		_expect("scatter: %s fan shot hits its target" % pair[0], _hits_on(pair[1]).size() == 1, str(_hits_on(pair[1])))
	await _reset()
	r = await _cast(&"scatter_shot", 0)
	_expect("scatter: fan covers the full spread", r.max_projectiles == 3, str(r.max_projectiles))
	_expect("scatter: three projectiles", r.max_projectiles == 3, str(r.max_projectiles))

func _case_masenko() -> void:
	await _reset()
	var data := _data(&"masenko_ha")
	var landing := special.spawn_distance + data.projectile_range
	var under := await _spawn(Vector2(55, 0))
	var at_landing := await _spawn(Vector2(landing, 0))
	var r := await _cast(&"masenko_ha", 0)
	_expect("masenko: flies over targets in the arc", _hits_on(under).is_empty(), str(_hits_on(under)))
	_expect("masenko: detonates at landing point", _hits_on(at_landing) == [data.damage], str(_hits_on(at_landing)))
	_expect("masenko: arc rises on screen when thrown right", r.arc_min_y < -8.0, str(r.arc_min_y))
	await _reset()
	var below := await _spawn(Vector2(0, landing))
	r = await _cast(&"masenko_ha", 0, &"down")
	_expect("masenko: lands when thrown down", _hits_on(below) == [data.damage], str(_hits_on(below)))
	_expect("masenko: arc rises on screen when thrown down", r.arc_min_y < -8.0, str(r.arc_min_y))

func _case_sword_blast() -> void:
	await _reset()
	var close := await _spawn(Vector2(24, 0))
	await _cast(&"sword_blast", 0)
	_expect("sword blast: slash and wave both confirm on a close target", _hits_on(close).size() == 2, str(_hits_on(close)))
	await _reset()
	var far := await _spawn(Vector2(120, 0))
	await _cast(&"sword_blast", 0)
	_expect("sword blast: wave alone reaches a distant target", _hits_on(far) == [24], str(_hits_on(far)))

func _case_energy_punch() -> void:
	await _reset()
	var t := await _spawn(Vector2(26, 0))
	await _cast(&"energy_punch", 0)
	_expect("energy punch: single hit of 18", _hits_on(t) == [18], str(_hits_on(t)))
	await _reset()
	var r := await _cast(&"energy_punch", 0)
	_expect("energy punch: short forward step", is_equal_approx(r.moved.x, _data(&"energy_punch").dash_distance), str(r.moved))

func _case_charged_lunges() -> void:
	for id in [&"super_kick", &"two_handed_smash", &"cross_slash"]:
		var data := _data(id)
		await _reset()
		var t := await _spawn(Vector2(48, 0))
		var r := await _cast(id, 90)
		var full := roundi(data.damage * data.charge_damage_multiplier)
		_expect("%s: full-charge lunge reaches a target 48px away" % id, _hits_on(t) == [full], str(_hits_on(t)))
		_expect("%s: caster lunges into contact" % id, r.moved.x > 4.0, str(r.moved))
		_expect("%s: lunge is not a one-frame teleport" % id, r.max_step < data.dash_distance * 0.6, str(r.max_step))
		await _reset()
		var t2 := await _spawn(Vector2(26, 0))
		await _cast(id, 0)
		_expect("%s: tapped strike deals base damage" % id, _hits_on(t2) == [data.damage], str(_hits_on(t2)))

func _case_whirlspin() -> void:
	await _reset()
	var front := await _spawn(Vector2(18, 0))
	var back := await _spawn(Vector2(-18, 0))
	await _cast(&"spin_punch", 0)
	_expect("whirlspin: hits in front", _hits_on(front) == [20], str(_hits_on(front)))
	_expect("whirlspin: hits behind", _hits_on(back) == [20], str(_hits_on(back)))

func _case_flurry() -> void:
	await _reset()
	var data := _data(&"flurry_punch")
	var t := await _spawn(Vector2(26, 0))
	await _cast(&"flurry_punch", 0)
	var hits := _hits_on(t)
	_expect("flurry: lands every hit of the sequence", hits.size() == data.flurry_hit_count, str(hits))
	_expect("flurry: final hit is the strongest", not hits.is_empty() and hits.back() > hits.front(), str(hits))
	await _reset()
	var t2 := await _spawn(Vector2(26, 0))
	await _cast(&"flurry_punch", 0, &"right", true)
	_expect("flurry: attack presses add bonus hits", _hits_on(t2).size() == data.flurry_hit_count + data.flurry_bonus_hit_limit, str(_hits_on(t2)))

func _case_peace_sign() -> void:
	await _reset()
	var data := _data(&"peace_sign_pose")
	var near := await _spawn(Vector2(-data.area_radius * 0.8, 0))
	var outside := await _spawn(Vector2(0, data.area_radius + 20.0))
	var r := await _cast(&"peace_sign_pose", 0)
	_expect("peace sign: stuns nearby enemies on any side", r.stunned.get(near, false), "")
	_expect("peace sign: ignores enemies out of range", not r.stunned.get(outside, false), "")
	_expect("peace sign: deals no damage", _hits_on(near).is_empty(), str(_hits_on(near)))

func _case_beam_cannon() -> void:
	await _reset()
	var a := await _spawn(Vector2(60, 0))
	var b := await _spawn(Vector2(110, 0))
	var r := await _cast(&"special_beam_cannon", 60)
	_expect("beam cannon: pierces the first target", not _hits_on(a).is_empty(), str(_hits_on(a)))
	_expect("beam cannon: reaches the second target", not _hits_on(b).is_empty(), str(_hits_on(b)))
	_expect("beam cannon: drains Ki while held", r.ki_spent > 20.0, str(r.ki_spent))
	await _reset()
	var tapped := await _spawn(Vector2(60, 0))
	r = await _cast(&"special_beam_cannon", 1)
	_expect("beam cannon: a tap still fires a short beam", not _hits_on(tapped).is_empty(), str(_hits_on(tapped)))
	_expect("beam cannon: tap does not linger", r.frames < 50, str(r.frames))
	await _reset()
	_wall(Vector2(40, 0))
	var hidden := await _spawn(Vector2(80, 0))
	await _cast(&"special_beam_cannon", 40)
	_expect("beam cannon: stops at scenery", _hits_on(hidden).is_empty(), str(_hits_on(hidden)))

func _case_point_blank_and_walls() -> void:
	for id in [&"burning_attack", &"big_bang_attack", &"scatter_shot"]:
		await _reset()
		var t := await _spawn(Vector2(9, 0))
		await _cast(id, 0)
		_expect("%s: hits a point-blank target" % id, not _hits_on(t).is_empty(), str(_hits_on(t)))
		await _reset()
		_wall(Vector2(12, 0))
		var hidden := await _spawn(Vector2(60, 0))
		await _cast(id, 0)
		_expect("%s: does not pass through a wall at the muzzle" % id, _hits_on(hidden).is_empty(), str(_hits_on(hidden)))
	for id in [&"energy_punch", &"spin_punch", &"peace_sign_pose"]:
		await _reset()
		_wall(Vector2(14, 0))
		var hidden := await _spawn(Vector2(26, 0))
		var r := await _cast(id, 0)
		_expect("%s: does not reach through a wall" % id, _hits_on(hidden).is_empty() and not r.stunned.get(hidden, false), str(_hits_on(hidden)))

func _case_super_namek() -> void:
	await _reset()
	var health := player.get_node("Components/HealthComponent") as HealthComponent
	health.current_health = maxi(health.max_health / 2, 1)
	var before := health.current_health
	var forms := player.get_node("Components/TransformationComponent") as TransformationComponent
	await _cast(&"super_namek", 0)
	_expect("super namek: form becomes active", forms.active_transformation == &"super_namek", String(forms.active_transformation))
	for i in 180:
		await physics_frame
	_expect("super namek: regenerates health while active", health.current_health > before, "%d -> %d" % [before, health.current_health])
	await _cast(&"super_namek", 0)
	_expect("super namek: second cast reverts", forms.active_transformation == &"", String(forms.active_transformation))
	health.restore_full()

# ---------------------------------------------------------------- harness

func _cast(id: StringName, held_frames: int, facing: StringName = &"right", spam_attack: bool = false) -> Dictionary:
	var index := -1
	for i in special.abilities.size():
		if special.abilities[i].ability_id == id:
			index = i
	special._selected_index = index
	special.loadout_component._cooldowns.clear()
	special.ki_component.restore_full()
	var ki_before := special.ki_component.current_ki
	var start := player.global_position
	var dir := special._facing_vector(facing)
	var result := {"stunned": {}, "max_projectiles": 0, "arc_min_y": 0.0, "max_step": 0.0, "frames": 0, "cooldown": 0.0}
	if not special.start_cast(facing, dir):
		_expect("%s: cast starts" % id, false, special.get_cast_block_reason(special.get_selected()))
		return result
	var last := player.global_position
	var frame := 0
	var tail := 0
	while tail < 70 and frame < 600:
		if special.is_casting():
			if spam_attack and frame % 4 == 0:
				special.add_flurry_bonus_hit()
			special.tick_cast(player, STEP, frame < held_frames)
			result.frames = frame + 1
			if not special.is_casting():
				result.cooldown = special.loadout_component.get_cooldown_left(id)
		else:
			tail += 1
		await physics_frame
		frame += 1
		result.max_step = maxf(result.max_step, player.global_position.distance_to(last))
		last = player.global_position
		var projectiles := get_nodes_in_group("combat_projectile").filter(
			func(node): return node is SpecialAttackProjectile and node.is_active_projectile())
		result.max_projectiles = maxi(result.max_projectiles, projectiles.size())
		for node in projectiles:
			var screen_offset: Vector2 = node.sprite.global_position - node.global_position
			result.arc_min_y = minf(result.arc_min_y, screen_offset.y)
		for t in _targets:
			if is_instance_valid(t) and t.status_effect_component.has_status(&"stun"):
				result.stunned[t] = true
	result.ki_spent = ki_before - special.ki_component.current_ki
	result.moved = (player.global_position - start).rotated(-dir.angle())
	return result

func _reset() -> void:
	for t in _targets:
		if is_instance_valid(t):
			t.queue_free()
	for w in _walls:
		w.queue_free()
	_targets.clear()
	_walls.clear()
	_hits.clear()
	for node in get_nodes_in_group("combat_projectile"):
		node.queue_free()
	var forms := player.get_node("Components/TransformationComponent") as TransformationComponent
	if forms.active_transformation != &"":
		forms.end_transformation()
	special.set_damage_multiplier(1.0)
	player.global_position = Vector2(420, 360)
	await physics_frame
	await physics_frame

func _spawn(offset: Vector2) -> DebugGokuEnemy:
	var target := ENEMY_SCENE.instantiate() as DebugGokuEnemy
	game.add_child(target)
	target.set_physics_process(false)
	target.health_component.max_health = 10000
	target.health_component.restore_full()
	target.global_position = player.global_position + offset
	_targets.append(target)
	_hits[target] = []
	var hurtbox := target.get_node("Hurtbox") as HurtboxComponent
	hurtbox.hit_received.connect(func(damage: int, _from: Vector2): _hits[target].append(damage))
	await physics_frame
	return target

func _wall(offset: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4, 80)
	shape.shape = rect
	wall.add_child(shape)
	game.add_child(wall)
	wall.global_position = player.global_position + offset
	_walls.append(wall)

func _data(id: StringName) -> SpecialAttackData:
	for data in special.abilities:
		if data.ability_id == id:
			return data
	return null

func _hits_on(target: Node) -> Array:
	return _hits.get(target, [])

func _sum(target: Node) -> int:
	var total := 0
	for value in _hits_on(target):
		total += value
	return total

func _expect(label: String, ok: bool, detail: String) -> void:
	if not ok:
		failures += 1
	print("%s  %s%s" % ["PASS" if ok else "FAIL", label, "" if detail.is_empty() else "  [" + detail + "]"])
