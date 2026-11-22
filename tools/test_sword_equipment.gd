extends SceneTree

# Inventory / equipment / sword regression.
#   Godot --headless --path . --script res://tools/test_sword_equipment.gd

const ENEMY_SCENE := preload("res://actors/enemies/debug_goku_enemy.tscn")
const STEP := 1.0 / 60.0
const FACINGS: Array[StringName] = [&"down", &"left", &"right", &"up"]

var failures := 0
var game: Node2D
var player: Player
var inventory: InventoryComponent
var equipment: EquipmentComponent
var melee: MeleeCombatComponent
var special: SpecialAttackComponent
var saves: SaveManager

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	game = load("res://scenes/bootstrap/bootstrap.tscn").instantiate() as Node2D
	saves = game.get_node("SaveManager") as SaveManager
	saves.save_path = "res://audit-sword-equipment-save.json"
	root.add_child(game)
	current_scene = game
	game.get_node("GameSession").autosave_on_quest_complete = false
	await create_timer(0.2).timeout
	player = get_first_node_in_group("player") as Player
	player.set_physics_process(false)
	inventory = player.inventory_component
	equipment = player.equipment_component
	melee = player.melee_combat_component
	special = player.special_attack_component
	for enemy in get_nodes_in_group("enemy"):
		enemy.queue_free()
	await physics_frame

	_case_catalog()
	_case_animations_built()
	await _case_equip_rules()
	await _case_sheath_visual()
	await _case_sword_combo()
	await _case_sword_reach()
	await _case_sword_specials()
	await _case_save_roundtrip()
	await _case_inventory_menu()
	await _case_rack()

	print("Sword equipment: ", failures, " failures")
	saves.delete_save()
	quit(0 if failures == 0 else 1)

func _case_catalog() -> void:
	var sword := ItemCatalog.get_item(&"sword")
	_expect("catalog: sword exists", sword != null, "")
	if sword == null:
		return
	_expect("catalog: sword is weapon equipment", sword.equipment_slot == &"weapon" and sword.weapon_style == &"sword", "")
	_expect("catalog: sword has icon", sword.icon != null, "")
	_expect("catalog: senzu is not equipment", not ItemCatalog.get_item(&"senzu_bean").is_equipment(), "")

func _case_animations_built() -> void:
	var frames := player.animation_controller.sprite.sprite_frames
	for anim in ["sword_1", "sword_2", "sword_3", "sword_equip"]:
		for facing in FACINGS:
			var name := StringName("%s_%s" % [anim, facing])
			var ok := frames.has_animation(name) and frames.get_frame_count(name) >= 2
			_expect("anim: %s built" % name, ok, "")
			if ok:
				var size := frames.get_frame_texture(name, 0).get_size()
				_expect("anim: %s is 48x48" % name, size == Vector2(48, 48), str(size))
				_expect("anim: %s does not loop" % name, not frames.get_animation_loop(name), "")
	# Sword frames must differ from the punch they replace (sword pixels).
	var punch := frames.get_frame_texture(&"attack_1_right", 1).get_image()
	var slash := frames.get_frame_texture(&"sword_1_right", 1).get_image()
	_expect("anim: slash frame is not a punch frame", punch.get_size() != slash.get_size(), "")

func _case_equip_rules() -> void:
	inventory.remove_item(&"sword", 99)
	_expect("equip: fails without the item", not equipment.equip(&"sword"), "")
	_expect("equip: senzu cannot be equipped", not equipment.equip(&"senzu_bean"), "")
	_expect("toggle: nothing to equip", not player.toggle_weapon(), "")
	inventory.add_item(&"sword", 1)
	_expect("equip: works with the item", equipment.equip(&"sword"), "")
	_expect("equip: weapon slot holds sword", equipment.get_equipped(&"weapon") == &"sword", "")
	_expect("equip: sword attack kind", player._basic_attack_kind() == MeleeCombatComponent.ATTACK_SWORD, "")
	_expect("equip: item stays in inventory", inventory.has_item(&"sword"), "")
	_expect("toggle: unequips", not player.toggle_weapon(), "")
	_expect("toggle: punch again", player._basic_attack_kind() == MeleeCombatComponent.ATTACK_PUNCH, "")
	_expect("toggle: equips again", player.toggle_weapon(), "")
	inventory.remove_item(&"sword", 1)
	_expect("equip: losing the item unequips", equipment.get_equipped(&"weapon") == &"", "")
	inventory.add_item(&"sword", 1)
	player._equip_pose_left = 0.0

func _case_sheath_visual() -> void:
	var sheath := player.sword_sheath
	equipment.unequip(&"weapon")
	player.animation_controller.update_visual(&"idle", &"down", STEP)
	await process_frame
	_expect("sheath: hidden when unequipped", sheath.get_shown_key() == "", sheath.get_shown_key())
	equipment.equip(&"sword")
	_expect("equip: plays the draw pose", player._equip_pose_left > 0.0, "")
	player._equip_pose_left = 0.0
	for facing in FACINGS:
		player.animation_controller.update_visual(&"walk", facing, STEP)
		await process_frame
		_expect("sheath: full on back facing %s" % facing, sheath.get_shown_key() == "%s:full" % facing, sheath.get_shown_key())
	player.animation_controller.update_visual(&"sword_1", &"left", STEP)
	await process_frame
	_expect("sheath: empty while slashing", sheath.get_shown_key() == "left:empty", sheath.get_shown_key())
	var back := player.get_node("Visuals/SheathBack") as Sprite2D
	var front := player.get_node("Visuals/SheathFront") as Sprite2D
	var body := player.animation_controller.sprite
	_expect("sheath: back layer behind body", back.get_index() < body.get_index(), "")
	_expect("sheath: front layer over body", front.get_index() > body.get_index(), "")

func _case_sword_combo() -> void:
	equipment.equip(&"sword")
	player._equip_pose_left = 0.0
	melee.cancel_attack()
	var states: Array[StringName] = []
	_expect("combo: starts", melee.start_attack(&"right", player._basic_attack_kind()), "")
	states.append(melee.get_attack_state())
	var frame := 0
	while melee.is_attacking() and frame < 200:
		if frame % 6 == 0:
			melee.buffer_attack(&"right", player._basic_attack_kind())
		melee.tick_attack(STEP)
		if melee.is_attacking() and states[-1] != melee.get_attack_state():
			states.append(melee.get_attack_state())
		player.animation_controller.update_visual(melee.get_attack_state(), &"right", STEP)
		await physics_frame
		frame += 1
		if states.size() >= 4:
			break
	_expect("combo: sweep, thrust, leap, sweep", states.slice(0, 4) == [&"sword_1", &"sword_2", &"sword_3", &"sword_1"], str(states))
	melee.cancel_attack()
	player.animation_controller.update_visual(&"sword_3", &"up", STEP)
	_expect("combo: state maps to sword animation", player.animation_controller.sprite.animation == &"sword_3_up", String(player.animation_controller.sprite.animation))

func _case_sword_reach() -> void:
	# A target 30px away is out of punch range but inside the blade's reach.
	for kind in [MeleeCombatComponent.ATTACK_PUNCH, MeleeCombatComponent.ATTACK_SWORD]:
		player.global_position = Vector2(420, 360)
		var target := ENEMY_SCENE.instantiate() as DebugGokuEnemy
		game.add_child(target)
		target.set_physics_process(false)
		target.health_component.max_health = 10000
		target.health_component.restore_full()
		target.global_position = player.global_position + Vector2(30, 0)
		var hits: Array = []
		(target.get_node("Hurtbox") as HurtboxComponent).hit_received.connect(func(d: int, _f: Vector2): hits.append(d))
		await physics_frame
		melee.cancel_attack()
		melee.start_attack(&"right", kind)
		while melee.is_attacking():
			melee.tick_attack(STEP)
			await physics_frame
		if kind == MeleeCombatComponent.ATTACK_SWORD:
			_expect("reach: sword hits at 30px", hits.size() == 1, str(hits))
			_expect("reach: sword damage includes weapon bonus", not hits.is_empty() and hits[0] >= 18, str(hits))
		else:
			_expect("reach: punch misses at 30px", hits.is_empty(), str(hits))
		target.queue_free()
		await physics_frame

func _case_sword_specials() -> void:
	var cross := _select(&"cross_slash")
	special.loadout_component._cooldowns.clear()
	special.ki_component.restore_full()
	equipment.unequip(&"weapon")
	_expect("special: cross slash needs sword", special.get_cast_block_reason(cross) == "REQUER ESPADA", special.get_cast_block_reason(cross))
	_expect("special: kamehameha needs no sword", special.get_cast_block_reason(_data(&"kamehameha")) == "", "")
	equipment.equip(&"sword")
	player._equip_pose_left = 0.0
	_expect("special: cross slash castable with sword", special.start_cast(&"right", Vector2.RIGHT), special.get_cast_block_reason(cross))
	_expect("special: cross slash windup state", special.get_cast_state() == &"special_sword_leap_windup", String(special.get_cast_state()))
	player.animation_controller.update_visual(special.get_cast_state(), &"right", STEP)
	_expect("special: windup shows leap slash", player.animation_controller.sprite.animation == &"sword_3_right", String(player.animation_controller.sprite.animation))
	special.cancel_cast()
	_select(&"sword_blast")
	special.loadout_component._cooldowns.clear()
	_expect("special: sword blast castable", special.start_cast(&"right", Vector2.RIGHT), "")
	_expect("special: sword blast sweep state", special.get_cast_state() == &"special_sword_sweep", String(special.get_cast_state()))
	special.cancel_cast()

func _case_save_roundtrip() -> void:
	equipment.equip(&"sword")
	player._equip_pose_left = 0.0
	_expect("save: writes", saves.save_game(), "")
	equipment.unequip(&"weapon")
	_expect("save: loads", saves.load_game(), "")
	await physics_frame
	_expect("save: sword stays equipped", equipment.get_equipped(&"weapon") == &"sword", str(equipment.serialize_state()))
	_expect("save: sheath restored", player.sword_sheath.equipped, "")

func _case_inventory_menu() -> void:
	var menu := get_first_node_in_group("inventory_menu") as InventoryMenu
	_expect("menu: exists", menu != null, "")
	if menu == null:
		return
	equipment.unequip(&"weapon")
	menu.open()
	_expect("menu: pauses", paused and menu.is_open(), "")
	_expect("menu: lists sword", menu.select_item(&"sword"), "")
	menu.activate_selected()
	_expect("menu: equips sword", equipment.get_equipped(&"weapon") == &"sword", "")
	menu.activate_selected()
	_expect("menu: unequips sword", equipment.get_equipped(&"weapon") == &"", "")
	menu.close()
	_expect("menu: closes", not paused and not menu.is_open(), "")
	player._equip_pose_left = 0.0

func _case_rack() -> void:
	var rack := SwordRack.new()
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	rack.add_child(shape)
	game.add_child(rack)
	await process_frame
	inventory.remove_item(&"sword", 99)
	rack.interact(player)
	_expect("rack: gives the sword", inventory.get_quantity(&"sword") == 1, "")
	rack.interact(player)
	_expect("rack: only one sword", inventory.get_quantity(&"sword") == 1, "")
	var dialogue := get_first_node_in_group("dialogue_ui")
	if dialogue != null and dialogue.has_method("hide_dialogue"):
		dialogue.hide_dialogue()
	rack.queue_free()

func _select(id: StringName) -> SpecialAttackData:
	for i in special.abilities.size():
		if special.abilities[i].ability_id == id:
			special._selected_index = i
			return special.abilities[i]
	return null

func _data(id: StringName) -> SpecialAttackData:
	for data in special.abilities:
		if data.ability_id == id:
			return data
	return null

func _expect(label: String, ok: bool, detail: String) -> void:
	if not ok:
		failures += 1
	print("%s  %s%s" % ["PASS" if ok else "FAIL", label, "" if detail.is_empty() else "  [" + detail + "]"])
