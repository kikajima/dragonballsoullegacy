extends SceneTree

# Elevation levels (underground / ground / air): every skill acts and is
# drawn on its user's level.
#   Godot --headless --path . --script res://tools/test_elevation_levels.gd

const ENEMY_SCENE := preload("res://actors/enemies/debug_goku_enemy.tscn")
const KI_BLAST_SCENE := preload("res://combat/projectiles/ki_blast_projectile.tscn")
const STEP := 1.0 / 60.0
const AT := Vector2(420, 360)

var failures := 0
var game: Node2D
var player: Player
var saves: SaveManager

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	game = load("res://scenes/bootstrap/bootstrap.tscn").instantiate() as Node2D
	saves = game.get_node("SaveManager") as SaveManager
	saves.save_path = "res://audit-elevation-save.json"
	root.add_child(game)
	current_scene = game
	game.get_node("GameSession").autosave_on_quest_complete = false
	await create_timer(0.2).timeout
	player = get_first_node_in_group("player") as Player
	player.inventory_component.add_item(&"sword", 1)
	player.equipment_component.equip(&"sword")
	player._equip_pose_left = 0.0
	player.set_physics_process(false)
	for enemy in get_nodes_in_group("enemy"):
		enemy.queue_free()
	await physics_frame

	_case_actor_levels()
	await _case_ki_blasts()
	await _case_punches()
	await _case_skill_visuals()
	await _case_every_special()
	await _case_underground_tag()

	print("Elevation levels: ", failures, " failures")
	saves.delete_save()
	quit(0 if failures == 0 else 1)

func _case_actor_levels() -> void:
	_expect("level: walking is ground", ElevationLevel.of(player) == ElevationLevel.GROUND, "")
	_expect("level: hurtbox inherits its actor", ElevationLevel.of(player.hurtbox) == ElevationLevel.GROUND, "")
	player.flight_component.take_off()
	_expect("level: flying is air", ElevationLevel.of(player) == ElevationLevel.AIR, "")
	_expect("level: air hurtbox", ElevationLevel.of(player.hurtbox) == ElevationLevel.AIR, "")
	player.flight_component.land_immediately()
	player.set_meta(ElevationLevel.META, ElevationLevel.UNDERGROUND)
	_expect("level: underground by metadata", ElevationLevel.of(player) == ElevationLevel.UNDERGROUND, "")
	player.flight_component.take_off()
	_expect("level: flying overrides the floor below", ElevationLevel.of(player) == ElevationLevel.AIR, "")
	player.flight_component.land_immediately()
	player.remove_meta(ElevationLevel.META)

func _case_ki_blasts() -> void:
	for shooter_air in [false, true]:
		for target_air in [false, true]:
			var target := await _target(AT + Vector2(60, 0), target_air)
			_set_player_air(shooter_air)
			player.global_position = AT
			var shot := KI_BLAST_SCENE.instantiate() as Node2D
			game.add_child(shot)
			shot.global_position = AT + Vector2(10, 0)
			shot.setup(Vector2.RIGHT, 5, player)
			for i in 40:
				await physics_frame
			var hit := target.health_component.current_health < 10000
			var label := "ki blast %s -> %s" % [_n(shooter_air), _n(target_air)]
			_expect(label + (" hits" if shooter_air == target_air else " passes by"), hit == (shooter_air == target_air), str(10000 - target.health_component.current_health))
			if is_instance_valid(shot):
				shot.queue_free()
			target.queue_free()
			await physics_frame
	_set_player_air(false)

func _case_punches() -> void:
	for attacker_air in [false, true]:
		for target_air in [false, true]:
			var target := await _target(AT + Vector2(14, 0), target_air)
			_set_player_air(attacker_air)
			player.global_position = AT
			var melee := player.melee_combat_component
			melee.cancel_attack()
			melee.start_attack(&"right", MeleeCombatComponent.ATTACK_PUNCH)
			while melee.is_attacking():
				melee.tick_attack(STEP)
				await physics_frame
			var hit := target.health_component.current_health < 10000
			_expect("punch %s -> %s" % [_n(attacker_air), _n(target_air)], hit == (attacker_air == target_air), "")
			target.queue_free()
			await physics_frame
	_set_player_air(false)

func _case_skill_visuals() -> void:
	_set_player_air(true)
	player.global_position = AT
	var shot := KI_BLAST_SCENE.instantiate() as Area2D
	game.add_child(shot)
	shot.global_position = AT + Vector2(10, 0)
	shot.setup(Vector2.UP, 1, player)
	var sprite := shot.get_node("AnimatedSprite2D") as Node2D
	_expect("visual: air ki blast drawn 12px up (any heading)", is_equal_approx(sprite.global_position.y - shot.global_position.y, -ElevationLevel.AIR_HEIGHT) and absf(sprite.global_position.x - shot.global_position.x) < 0.01, str(sprite.global_position - shot.global_position))
	_expect("visual: air ki blast above scenery", shot.z_index == ElevationLevel.AIR_DRAW_Z and not shot.z_as_relative, str(shot.z_index))
	_expect("visual: hit shape stays on the ground plane", (shot.get_node("CollisionShape2D") as Node2D).position == Vector2.ZERO, "")
	shot.queue_free()

	var special := player.special_attack_component
	var seen_projectile := false
	var seen_beam := false
	for index in special.abilities.size():
		var data := special.abilities[index]
		if seen_projectile and seen_beam:
			break
		special._selected_index = index
		special.loadout_component._cooldowns.clear()
		special.ki_component.restore_full()
		if not special.start_cast(&"right", Vector2.RIGHT):
			continue
		for frame in 70:
			special.tick_cast(player, STEP, frame < 40)
			await physics_frame
			for node in get_nodes_in_group("combat_projectile"):
				if node is SpecialAttackProjectile and not seen_projectile:
					var p := node as SpecialAttackProjectile
					seen_projectile = true
					var lifted := (p.sprite.global_position - p.global_position).y
					_expect("visual: special projectile drawn at air height (%s)" % data.ability_id, lifted <= -ElevationLevel.AIR_HEIGHT + 0.5, str(lifted))
					_expect("visual: special projectile above scenery", p.z_index == ElevationLevel.AIR_DRAW_Z, str(p.z_index))
			for node in get_nodes_in_group("active_special_beam"):
				if not seen_beam:
					var b := node as SpecialAttackBeam
					seen_beam = true
					var line := b.get_node("BeamLine") as Node2D
					_expect("visual: beam drawn at air height (%s)" % data.ability_id, is_equal_approx(line.global_position.y - b.global_position.y, -ElevationLevel.AIR_HEIGHT), str(line.global_position - b.global_position))
					_expect("visual: beam above scenery", b.z_index == ElevationLevel.AIR_DRAW_Z, str(b.z_index))
		special.cancel_cast()
		_clear_skills()
		await physics_frame
	_expect("visual: a special projectile was checked", seen_projectile, "")
	_expect("visual: a beam was checked", seen_beam, "")
	_set_player_air(false)

func _case_every_special() -> void:
	var special := player.special_attack_component
	var checked := 0
	for index in special.abilities.size():
		var data := special.abilities[index]
		if data.is_transformation():
			continue
		for scenario in [[true, false], [true, true], [false, true]]:
			var caster_air: bool = scenario[0]
			var target_air: bool = scenario[1]
			var distance := 28.0
			if data.attack_type == SpecialAttackData.AttackType.ARC_GRENADE:
				distance = 210.0
			elif data.projectile_speed > 0.0 and data.attack_type in [0, 1, 2, 4]:
				distance = 80.0
			var target := await _target(AT + Vector2(distance, 0), target_air)
			_set_player_air(caster_air)
			player.global_position = AT
			await physics_frame
			special._selected_index = index
			special.loadout_component._cooldowns.clear()
			special.ki_component.restore_full()
			special.start_cast(&"right", Vector2.RIGHT)
			var stunned := false
			for frame in 130:
				special.tick_cast(player, STEP, frame < 50)
				await physics_frame
				stunned = stunned or target.get_node("Components/StatusEffectComponent").has_status(&"stun")
			special.cancel_cast()
			var damage := 10000 - target.health_component.current_health
			var touched: bool = stunned if data.attack_type == SpecialAttackData.AttackType.AREA_STATUS else damage > 0
			var should := caster_air == target_air
			_expect("special %s: %s -> %s %s" % [data.ability_id, _n(caster_air), _n(target_air), "hits" if should else "passes by"], touched == should, "damage=%d stun=%s" % [damage, stunned])
			target.queue_free()
			_clear_skills()
			await physics_frame
			checked += 1
	_set_player_air(false)
	_expect("specials: all cross-level scenarios checked", checked >= 30, str(checked))

func _case_underground_tag() -> void:
	# The underground is not built yet; its rule already applies.
	player.set_meta(ElevationLevel.META, ElevationLevel.UNDERGROUND)
	var target := await _target(AT + Vector2(60, 0), false)
	player.global_position = AT
	var shot := KI_BLAST_SCENE.instantiate() as Node2D
	game.add_child(shot)
	shot.global_position = AT + Vector2(10, 0)
	shot.setup(Vector2.RIGHT, 5, player)
	_expect("underground: shot tagged underground", ElevationLevel.of(shot) == ElevationLevel.UNDERGROUND, "")
	for i in 40:
		await physics_frame
	_expect("underground: does not reach the ground level", target.health_component.current_health == 10000, "")
	target.set_meta(ElevationLevel.META, ElevationLevel.UNDERGROUND)
	var shot2 := KI_BLAST_SCENE.instantiate() as Node2D
	game.add_child(shot2)
	shot2.global_position = AT + Vector2(10, 0)
	shot2.setup(Vector2.RIGHT, 5, player)
	for i in 40:
		await physics_frame
	_expect("underground: hits on the same level", target.health_component.current_health < 10000, "")
	player.remove_meta(ElevationLevel.META)
	target.queue_free()
	for s in [shot, shot2]:
		if is_instance_valid(s):
			s.queue_free()
	await physics_frame

# --- helpers ----------------------------------------------------------------

func _target(at: Vector2, air: bool) -> DebugGokuEnemy:
	var target := ENEMY_SCENE.instantiate() as DebugGokuEnemy
	target.respawn_for_debug = false
	game.add_child(target)
	target.set_physics_process(false)
	target.health_component.max_health = 10000
	target.health_component.restore_full()
	target.global_position = at
	if air:
		target.flight_component.take_off()
	await physics_frame
	return target

func _set_player_air(air: bool) -> void:
	if air and not player.flight_component.is_flying:
		player.flight_component.take_off()
	elif not air and player.flight_component.is_flying:
		player.flight_component.land_immediately()

func _clear_skills() -> void:
	for group in [&"combat_projectile", &"active_special_beam"]:
		for node in get_nodes_in_group(group):
			node.queue_free()

func _n(air: bool) -> String:
	return "air" if air else "ground"

func _expect(label: String, ok: bool, detail: String) -> void:
	if not ok:
		failures += 1
	print("%s  %s%s" % ["PASS" if ok else "FAIL", label, "" if detail.is_empty() else "  [" + detail + "]"])
