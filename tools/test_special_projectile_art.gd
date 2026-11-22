extends SceneTree

const PROJECTILE = preload("res://combat/special/special_attack_projectile.tscn")
const ENEMY = preload("res://actors/enemies/debug_goku_enemy.tscn")
const EFFECT_PATH := "res://assets/sprites/effects/hu2/Effects.dmi"
var failures := 0
var visual_frames: Array[Dictionary] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	# Isolated actors: no GameSession/SaveManager, so this test cannot save over
	# player progress while exercising real damage, statuses and explosion queries.
	var arena := Node2D.new()
	root.add_child(arena)
	var caster := Node2D.new()
	arena.add_child(caster)
	caster.add_to_group("player")
	var sheet := DmiSpriteSheet.load_file(EFFECT_PATH)
	var directions := {&"right": Vector2.RIGHT, &"down": Vector2.DOWN, &"left": Vector2.LEFT, &"up": Vector2.UP}
	for ability in ["big_bang_attack", "burning_attack"]:
		var data := load("res://data/abilities/special/" + ability + ".tres") as SpecialAttackData
		var states: Array = SpecialAttackProjectile.HU2_PROJECTILE_STATES[data.effect_key]
		for facing in directions:
			var target := ENEMY.instantiate() as DebugGokuEnemy
			target.position = Vector2(1400, 1000)
			arena.add_child(target)
			target.set_physics_process(false)
			target.health_component.max_health = 1000
			target.health_component.restore_full()
			await physics_frame
			var projectile := PROJECTILE.instantiate() as SpecialAttackProjectile
			arena.add_child(projectile)
			projectile.set_physics_process(false)
			projectile.global_position = target.global_position
			projectile.setup(data, directions[facing], caster)
			var frames := projectile.sprite.sprite_frames
			check(frames.get_frame_count(&"fly") == 2, ability + " needs its 2 authored flight frames")
			# Impacts use the Legacy of Goku II explosion strip (HU2 "*Hit" is a
			# squashed beam head, not an explosion); see docs/SPECIAL_ATTACKS.md.
			var impact_rects: Array = SpecialAttackProjectile.EFFECT_IMPACT_RECTS[data.effect_key]
			check(frames.get_frame_count(&"impact") == impact_rects.size(), ability + " needs its authored LoG II impact frames")
			check(is_zero_approx(projectile.sprite.global_rotation), "Directional DMI art rotated twice: " + String(facing))
			for index in range(2):
				var actual := frames.get_frame_texture(&"fly", index).get_image().get_data()
				var expected := sheet.get_frame_texture(states[0], facing, index).get_image().get_data()
				check(actual == expected, "Flight pixels differ from HU2: " + ability + String(facing))
			var legacy := (load(SpecialAttackProjectile.EFFECT_SHEET_PATH) as Texture2D).get_image()
			for index in range(impact_rects.size()):
				var impact := frames.get_frame_texture(&"impact", index) as AtlasTexture
				check(
					impact != null and Rect2i(impact.region) == impact_rects[index]
					and impact.get_image().get_data() == legacy.get_region(impact_rects[index]).get_data(),
					"Impact pixels differ from LoG II: " + ability + String(facing)
				)
			check(projectile._speed == data.projectile_speed and projectile._max_distance == data.projectile_range, "Flight mechanics changed")
			visual_frames.append({"ability": ability, "direction": facing, "frames": frames})
			projectile._on_area_entered(target.hurtbox)
			check(target.health_component.current_health == 1000 - data.damage, "Damage changed: " + ability)
			if ability == "burning_attack":
				check(target.status_effect_component.has_status(&"stun"), "Burning Attack lost its stun")
			check(projectile.sprite.animation == &"impact", "Impact animation did not start")
			await process_frame
			check(projectile.collision_shape.disabled and projectile.collision_mask == 0, "Impact must stop dealing damage")
			projectile._physics_process(projectile.impact_duration + 0.01)
			check(projectile.is_queued_for_deletion(), "Impact lifetime changed")
			target.queue_free()
			await process_frame
	for ability in ["scatter_shot", "spirit_bomb"]:
		var data := load("res://data/abilities/special/" + ability + ".tres") as SpecialAttackData
		var projectile := PROJECTILE.instantiate() as SpecialAttackProjectile
		arena.add_child(projectile)
		projectile.set_physics_process(false)
		projectile.setup(data, Vector2.RIGHT, caster)
		check(projectile.sprite.sprite_frames.get_frame_count(&"fly") == 1, "Growth stages must not loop in flight: " + ability)
		projectile.queue_free()
	if DisplayServer.get_name() != "headless":
		show_gallery(arena)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://audit-skill-art-gallery.png")
	print("Special projectile art: ", "PASS" if failures == 0 else "FAIL", " — 8 directional damage/impact cases, exact HU2 pixels, stable GBA flight")
	quit(failures)

func show_gallery(arena: Node2D) -> void:
	var background := ColorRect.new()
	background.color = Color("203440")
	background.size = Vector2(480, 270)
	arena.add_child(background)
	for index in visual_frames.size():
		var entry := visual_frames[index]
		var column := index % 4
		var row := index / 4
		var label := Label.new()
		label.text = String(entry.direction)
		label.position = Vector2(110 + column * 80, 14 + row * 130)
		label.add_theme_font_size_override("font_size", 9)
		arena.add_child(label)
		for phase in ["fly", "impact"]:
			var sprite := AnimatedSprite2D.new()
			sprite.sprite_frames = entry.frames
			sprite.animation = StringName(phase)
			sprite.frame = 0
			sprite.position = Vector2(125 + column * 80, 55 + row * 130 + (45 if phase == "impact" else 0))
			arena.add_child(sprite)
	for row in range(2):
		var label := Label.new()
		label.text = "BIG BANG" if row == 0 else "BURNING"
		label.position = Vector2(8, 44 + row * 130)
		label.add_theme_font_size_override("font_size", 9)
		arena.add_child(label)
