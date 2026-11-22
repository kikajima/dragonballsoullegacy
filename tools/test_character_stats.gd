extends SceneTree

# Character stats: Strength, Agility, Vigor, Wisdom, Intelligence.
#   Godot --headless --path . --script res://tools/test_character_stats.gd

const ENEMY_SCENE := preload("res://actors/enemies/debug_goku_enemy.tscn")
const KI_BLAST_SCENE := preload("res://combat/projectiles/ki_blast_projectile.tscn")
const STEP := 1.0 / 60.0

var failures := 0
var game: Node2D
var player: Player
var stats: CharacterStatsComponent
var saves: SaveManager

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	game = load("res://scenes/bootstrap/bootstrap.tscn").instantiate() as Node2D
	saves = game.get_node("SaveManager") as SaveManager
	saves.save_path = "res://audit-character-stats-save.json"
	root.add_child(game)
	current_scene = game
	game.get_node("GameSession").autosave_on_quest_complete = false
	await create_timer(0.3).timeout
	player = get_first_node_in_group("player") as Player
	player.set_physics_process(false)
	stats = player.character_stats
	for enemy in get_nodes_in_group("enemy"):
		enemy.queue_free()
	await physics_frame

	_case_basics()
	await _case_strength()
	await _case_agility()
	await _case_dash()
	await _case_vigor()
	await _case_wisdom()
	await _case_meditation_and_sense()
	await _case_intelligence()
	await _case_study()
	await _case_save()
	await _case_status_menu()

	print("Character stats: ", failures, " failures")
	saves.delete_save()
	quit(0 if failures == 0 else 1)

func _reset_stats() -> void:
	for stat in CharacterStatsComponent.STATS:
		stats.set_level(stat, 1)

func _spawn_enemy(at: Vector2) -> DebugGokuEnemy:
	var enemy := ENEMY_SCENE.instantiate() as DebugGokuEnemy
	game.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.global_position = at
	return enemy

func _case_basics() -> void:
	_expect("basics: five stats at level 1", CharacterStatsComponent.STATS.size() == 5 and CharacterStatsComponent.STATS.all(func(s): return stats.get_level(s) == 1), "")
	_expect("basics: Lv1 needs 25 XP", is_equal_approx(stats.xp_to_next(1), 25.0), str(stats.xp_to_next(1)))
	var gained := stats.add_xp(CharacterStatsComponent.STRENGTH, 25.0 + 71.0)
	_expect("basics: XP levels up (25 + 71 -> Lv 3)", gained == 2 and stats.get_level(CharacterStatsComponent.STRENGTH) == 3, "Lv %d" % stats.get_level(CharacterStatsComponent.STRENGTH))
	stats.set_level(CharacterStatsComponent.STRENGTH, 99)
	stats.add_xp(CharacterStatsComponent.STRENGTH, 1.0e9)
	_expect("basics: capped at 100", stats.get_level(CharacterStatsComponent.STRENGTH) == 100, "")
	_reset_stats()

func _case_strength() -> void:
	var base := player.melee_combat_component._damage_multiplier
	stats.set_level(CharacterStatsComponent.STRENGTH, 51)
	_expect("strength: melee damage x2 at Lv 51", is_equal_approx(player.melee_combat_component._damage_multiplier, base * 2.0), str(player.melee_combat_component._damage_multiplier))
	_expect("strength: +5 bag spaces at Lv 51", player.inventory_component.get_capacity() == 10, str(player.inventory_component.get_capacity()))
	_reset_stats()
	_expect("strength: back to 5 spaces", player.inventory_component.get_capacity() == 5, "")
	var before := stats.get_xp(CharacterStatsComponent.STRENGTH)
	var enemy := _spawn_enemy(player.global_position + Vector2(18, 0))
	await physics_frame
	player.melee_combat_component.attack_hitbox.hit_confirmed.emit(enemy, 10)
	_expect("strength: a landed hit trains Strength", stats.get_xp(CharacterStatsComponent.STRENGTH) > before, "")
	enemy.queue_free()
	await physics_frame

func _case_agility() -> void:
	player.state_machine.change_state(Player.STATE_WALK)
	var slow := player._get_locomotion_speed_scale()
	stats.set_level(CharacterStatsComponent.AGILITY, 100)
	var fast := player._get_locomotion_speed_scale()
	_expect("agility: faster walk at Lv 100 (x1.59)", is_equal_approx(fast / slow, 1.594), "%.3f" % (fast / slow))
	_expect("agility: 40% dodge at Lv 100", is_equal_approx(stats.dodge_chance(), 0.40), str(stats.dodge_chance()))
	seed(7)
	var dodged := 0
	var hp := player.health_component.current_health
	for i in 200:
		if player.modify_incoming_damage(5, player.global_position + Vector2(10, 0)) == 0:
			dodged += 1
	_expect("agility: dodges ~40% of hits", dodged > 50 and dodged < 110, "%d / 200" % dodged)
	_expect("agility: a dodge costs no HP", player.health_component.current_health == hp, "")
	_expect("agility: dodging blinks the body out", player._blink_tween != null, "")
	await create_timer(0.3).timeout
	_expect("agility: body back after the blink", is_equal_approx(_visuals_of(player).modulate.a, 1.0), "")
	_reset_stats()
	var before := stats.get_xp(CharacterStatsComponent.AGILITY)
	player.state_machine.change_state(Player.STATE_RUN)
	player.velocity = Vector2(100, 0)
	player._train_movement(1.0)
	player.velocity = Vector2.ZERO
	_expect("agility: running trains Agility", stats.get_xp(CharacterStatsComponent.AGILITY) >= before + 1.4, "")
	player.state_machine.change_state(Player.STATE_IDLE)

func _case_dash() -> void:
	_reset_stats()
	player.set_physics_process(true)
	player.ki_component.restore_full()
	var dash := get_first_node_in_group("player_dash_system") as PlayerDashSystem
	var before := stats.get_xp(CharacterStatsComponent.AGILITY)
	Input.action_press("move_right")
	await _tap("dash")
	_expect("dash: a dash trains Agility", stats.get_xp(CharacterStatsComponent.AGILITY) >= before + stats.xp_dash, "%.1f" % stats.get_xp(CharacterStatsComponent.AGILITY))
	var enemy := _spawn_enemy(player.global_position + Vector2(200, 0))
	var shot := KI_BLAST_SCENE.instantiate() as Node2D
	game.add_child(shot)
	shot.global_position = player.global_position + Vector2(8, 0)
	shot.setup(Vector2.LEFT, 1, enemy)
	before = _total_xp(CharacterStatsComponent.AGILITY)
	var dodged := dash._check_dash_dodges()
	_expect("dash: dashing through an enemy shot is a dodge", dodged == 1 and _total_xp(CharacterStatsComponent.AGILITY) >= before + stats.xp_dash_dodge - 0.01, "")
	_expect("dash: the same shot counts once", dash._check_dash_dodges() == 0, "")
	Input.action_release("move_right")
	player.set_physics_process(false)
	shot.queue_free()
	enemy.queue_free()
	await create_timer(0.3).timeout

func _case_vigor() -> void:
	_reset_stats()
	var max_hp := player.health_component.max_health
	stats.set_level(CharacterStatsComponent.VIGOR, 11)
	_expect("vigor: +60 max HP at Lv 11", player.health_component.max_health == max_hp + 60, "%d -> %d" % [max_hp, player.health_component.max_health])
	stats.set_level(CharacterStatsComponent.VIGOR, 1)
	_expect("vigor: bonus removed again", player.health_component.max_health == max_hp, "")
	_expect("vigor: supports 2x at Lv 1", is_equal_approx(stats.gravity_tolerance(), 2.0), "")
	stats.set_level(CharacterStatsComponent.VIGOR, 100)
	_expect("vigor: supports 10,000x at Lv 100", is_equal_approx(stats.gravity_tolerance(), 10000.0), str(stats.gravity_tolerance()))
	stats.set_level(CharacterStatsComponent.VIGOR, 1)
	var training := get_first_node_in_group("training_manager") as TrainingManager
	_expect("vigor: gravity goes up to 10,000x", TrainingManager.GRAVITY_LEVELS.max() == 10000.0, "")
	_expect("vigor: 10,000x label", TrainingManager.format_gravity(10000.0) == "10,000x", TrainingManager.format_gravity(10000.0))
	training.set_gravity(2.0)
	_expect("vigor: at the limit the body is slowed (x0.55)", is_equal_approx(training.get_movement_multiplier(), 0.55), str(training.get_movement_multiplier()))
	stats.set_level(CharacterStatsComponent.VIGOR, 60)
	_expect("vigor: a trained body barely feels 2x", training.get_movement_multiplier() > 0.9, str(training.get_movement_multiplier()))
	stats.set_level(CharacterStatsComponent.VIGOR, 1)
	var xp_before := stats.get_xp(CharacterStatsComponent.VIGOR)
	await create_timer(0.5).timeout
	_expect("vigor: time under gravity trains Vigor", stats.get_xp(CharacterStatsComponent.VIGOR) > xp_before, "")
	player.health_component.restore_full()
	training.set_gravity(100.0)
	var hp := player.health_component.current_health
	await create_timer(0.6).timeout
	_expect("vigor: past the limit the body is crushed (HP drains)", training.is_overloaded() and player.health_component.current_health < hp, "%d -> %d" % [hp, player.health_component.current_health])
	_expect("vigor: overloaded movement is very slow", training.get_movement_multiplier() <= 0.15, str(training.get_movement_multiplier()))
	training.set_gravity(1.0)
	await process_frame
	await process_frame
	_expect("vigor: normal gravity, no overload", not training.is_overloaded() and is_equal_approx(training.get_movement_multiplier(), 1.0), "")
	player.health_component.restore_full()

func _case_wisdom() -> void:
	_reset_stats()
	var special := player.special_attack_component
	var base := special._damage_multiplier
	stats.set_level(CharacterStatsComponent.WISDOM, 100)
	_expect("wisdom: ki technique damage x2.49 at Lv 100", is_equal_approx(special._damage_multiplier / base, 2.485), "%.3f" % (special._damage_multiplier / base))
	_expect("wisdom: ki blast damage follows", is_equal_approx(player.ki_blast_component._damage_multiplier, special._damage_multiplier), "")
	_expect("wisdom: cooldowns x0.6 at Lv 100", is_equal_approx(special.cooldown_multiplier, 0.6), str(special.cooldown_multiplier))
	var data := special.get_selected()
	special.loadout_component._cooldowns.clear()
	player.ki_component.restore_full()
	var xp_before := stats.get_xp(CharacterStatsComponent.WISDOM)
	_reset_stats()
	stats.set_level(CharacterStatsComponent.WISDOM, 100)
	xp_before = stats.get_xp(CharacterStatsComponent.WISDOM)
	special._active_data = data
	special._finish_cast(true)
	var left := special.loadout_component.get_cooldown_left(data.ability_id)
	_expect("wisdom: cast cooldown shortened", is_equal_approx(left, data.cooldown * 0.6), "%.2f vs %.2f" % [left, data.cooldown])
	special.loadout_component._cooldowns.clear()
	_reset_stats()
	xp_before = stats.get_xp(CharacterStatsComponent.WISDOM)
	special.cast_started.emit(data.ability_id)
	_expect("wisdom: using a technique trains Wisdom", stats.get_xp(CharacterStatsComponent.WISDOM) > xp_before, "")
	xp_before = stats.get_xp(CharacterStatsComponent.WISDOM)
	player.ki_blast_component.projectile_fired.emit(&"right", 0)
	_expect("wisdom: ki blasts train Wisdom", stats.get_xp(CharacterStatsComponent.WISDOM) > xp_before, "")

func _case_meditation_and_sense() -> void:
	_reset_stats()
	player.set_physics_process(true)
	await _tap("meditate")
	_expect("meditate: M starts meditating", player.is_meditating() and player.get_current_state() == Player.STATE_MEDITATE, str(player.get_current_state()))
	_expect("meditate: kneeling pose", String(player.animation_controller.sprite.animation) == "land_down", String(player.animation_controller.sprite.animation))
	var xp_before := stats.get_xp(CharacterStatsComponent.WISDOM)
	await create_timer(0.5).timeout
	_expect("meditate: trains Wisdom over time", stats.get_xp(CharacterStatsComponent.WISDOM) >= xp_before + 1.5, "%.2f" % (stats.get_xp(CharacterStatsComponent.WISDOM) - xp_before))
	_expect("meditate: doubles the ki sense radius", is_equal_approx(stats.ki_sense_radius(true), stats.ki_sense_radius() * 2.0), "")
	var overlay := get_first_node_in_group("ki_sense_overlay") as KiSenseOverlay
	var far := _spawn_enemy(player.global_position + Vector2(0, 250))
	var near := _spawn_enemy(player.global_position + Vector2(60, 0))
	await process_frame
	var markers := overlay.compute_markers()
	_expect("sense: meditating feels an off-screen enemy (250px)", markers.any(func(m): return m["being"] == far and not m["on_screen"]), str(markers.size()))
	_expect("sense: meditating also marks enemies on screen", markers.any(func(m): return m["being"] == near and m["on_screen"]), "")
	Input.action_press("move_left")
	await physics_frame
	await physics_frame
	Input.action_release("move_left")
	_expect("meditate: moving stops it", not player.is_meditating(), "")
	markers = overlay.compute_markers()
	_expect("sense: Wisdom 1 does not reach 250px", not markers.any(func(m): return m["being"] == far), "")
	_expect("sense: on-screen beings need no marker", not markers.any(func(m): return m["being"] == near), "")
	stats.set_level(CharacterStatsComponent.WISDOM, 30)
	markers = overlay.compute_markers()
	var marker: Variant = null
	for m in markers:
		if m["being"] == far:
			marker = m
	_expect("sense: higher Wisdom feels it without meditating", marker != null, "radius %.0f" % stats.ki_sense_radius())
	if marker != null:
		var screen := Rect2(Vector2.ZERO, overlay.get_viewport_rect().size)
		_expect("sense: marker sits on the screen edge", screen.has_point(marker["position"]) and (marker["position"] as Vector2).y > screen.size.y - 20.0, str(marker["position"]))
	player.set_physics_process(false)
	far.queue_free()
	near.queue_free()
	await physics_frame

func _case_intelligence() -> void:
	_reset_stats()
	var enemy := _spawn_enemy(player.global_position + Vector2(40, 0))
	await physics_frame
	var bar_text := EnemyTargetBar.health_text_for(enemy, enemy.health_component)
	_expect("analyze: HP unknown before analyzing", bar_text == "?? / ??", bar_text)
	var panel := get_first_node_in_group("analyze_panel") as AnalyzePanel
	_expect("analyze: finds the nearby enemy", player.analyze_nearest() == enemy and panel.is_showing(), "")
	var lines := panel.get_lines()
	_expect("analyze: Lv 1 reads only the condition", "HP: Healthy" in lines and "Power: ???" in lines, str(lines))
	_expect("analyze: target bar now shows the condition", EnemyTargetBar.health_text_for(enemy, enemy.health_component) == "Healthy", "")
	stats.set_level(CharacterStatsComponent.INTELLIGENCE, 10)
	player.analyze_nearest()
	lines = panel.get_lines()
	_expect("analyze: Lv 10 reads HP to 10%", "HP: ~100%" in lines, str(lines))
	stats.set_level(CharacterStatsComponent.INTELLIGENCE, 25)
	enemy.health_component.take_damage(7)
	player.analyze_nearest()
	lines = panel.get_lines()
	var exact := "HP: %d / %d" % [enemy.health_component.current_health, enemy.health_component.max_health]
	_expect("analyze: Lv 25 reads exact HP and power", exact in lines and Array(lines).any(func(l): return l.begins_with("Power level:")), str(lines))
	_expect("analyze: target bar exact after it", EnemyTargetBar.health_text_for(enemy, enemy.health_component) == exact.trim_prefix("HP: "), "")
	stats.set_level(CharacterStatsComponent.INTELLIGENCE, 50)
	player.analyze_nearest()
	_expect("analyze: Lv 50 also reads its damage", Array(panel.get_lines()).any(func(l): return l.begins_with("Hits ~")), str(panel.get_lines()))
	stats.set_level(CharacterStatsComponent.INTELLIGENCE, 100)
	_expect("read: 75% attack read at Lv 100", is_equal_approx(stats.attack_read_chance(), 0.75), "")
	var texts := [0]
	var counter := func(node: Node) -> void:
		if node is FloatingCombatText:
			texts[0] += 1
	node_added.connect(counter)
	seed(3)
	for i in 40:
		player.on_enemy_attack_started(enemy, &"melee")
	node_added.disconnect(counter)
	_expect("read: enemy attacks are read (\"!\")", texts[0] > 15 and texts[0] < 40, "%d / 40" % texts[0])
	enemy.queue_free()
	_reset_stats()
	await physics_frame

func _case_study() -> void:
	_reset_stats()
	var spot := StudySpot.new()
	spot.place_name = "Test Library"
	game.add_child(spot)
	spot.global_position = player.global_position + Vector2(0, -20)
	await process_frame
	player.set_physics_process(true)
	spot.interact(player)
	_expect("study: starts a study session", player.is_studying(), "")
	var before := stats.get_xp(CharacterStatsComponent.INTELLIGENCE)
	await create_timer(0.5).timeout
	_expect("study: trains Intelligence over time", stats.get_xp(CharacterStatsComponent.INTELLIGENCE) >= before + 2.0, "%.2f" % (stats.get_xp(CharacterStatsComponent.INTELLIGENCE) - before))
	Input.action_press("move_down")
	await physics_frame
	await physics_frame
	Input.action_release("move_down")
	_expect("study: moving stops it", not player.is_studying(), "")
	player.set_physics_process(false)
	spot.queue_free()
	for path in ["res://scenes/world/west_city_outskirts.tscn", "res://scenes/world/capsule_training_chamber.tscn"]:
		var scene := (load(path) as PackedScene).instantiate()
		var found := scene.find_children("*", "", true, false).filter(func(n): return n.get_script() == StudySpot)
		_expect("study: spots placed in %s" % path.get_file(), found.size() >= 1, str(found.size()))
		scene.free()

func _case_save() -> void:
	_reset_stats()
	var base_hp := player.health_component.max_health
	stats.set_level(CharacterStatsComponent.VIGOR, 21)
	stats.set_level(CharacterStatsComponent.STRENGTH, 30)
	stats.add_xp(CharacterStatsComponent.AGILITY, 10.0)
	var hp_with_bonus := player.health_component.max_health
	_expect("save: writes", saves.save_game(), "")
	_reset_stats()
	_expect("save: loads", saves.load_game(), "")
	await physics_frame
	_expect("save: levels restored", stats.get_level(CharacterStatsComponent.VIGOR) == 21 and stats.get_level(CharacterStatsComponent.STRENGTH) == 30, "")
	_expect("save: XP restored", is_equal_approx(stats.get_xp(CharacterStatsComponent.AGILITY), 10.0), str(stats.get_xp(CharacterStatsComponent.AGILITY)))
	_expect("save: Vigor HP bonus not applied twice", player.health_component.max_health == hp_with_bonus and hp_with_bonus == base_hp + 120, "%d vs %d" % [player.health_component.max_health, hp_with_bonus])
	_expect("save: Strength bag spaces restored", player.inventory_component.get_bonus_capacity() == 3, "")
	_reset_stats()

func _case_status_menu() -> void:
	var menu := get_first_node_in_group("status_menu") as StatusMenu
	_expect("status: menu exists", menu != null, "")
	if menu == null:
		return
	menu.open()
	_expect("status: opens and pauses", menu.is_open() and paused, "")
	for stat in CharacterStatsComponent.STATS:
		_expect("status: %s effects" % stat, not StatusMenu.effects_text(stats, stat).is_empty(), "")
	menu.close()
	_expect("status: closes", not menu.is_open() and not paused, "")

# XP earned since level 1 (level-ups reset the bar).
func _total_xp(stat: StringName) -> float:
	var total := stats.get_xp(stat)
	for level in range(1, stats.get_level(stat)):
		total += stats.xp_to_next(level)
	return total

# A real key tap: just-pressed for one frame, then released.
func _tap(action: String) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	for i in 3:
		await physics_frame
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
	await physics_frame

func _visuals_of(p: Node) -> CanvasItem:
	return p.get_node("Visuals") as CanvasItem

func _expect(label: String, ok: bool, detail: String) -> void:
	if not ok:
		failures += 1
	print("%s  %s%s" % ["PASS" if ok else "FAIL", label, "" if detail.is_empty() else "  [" + detail + "]"])
