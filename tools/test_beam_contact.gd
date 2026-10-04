extends SceneTree

var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _target(position: Vector2) -> HurtboxComponent:
	var actor := Node2D.new()
	actor.position = position
	var health := HealthComponent.new()
	health.name = "Health"
	health.max_health = 1000
	actor.add_child(health)
	var hurtbox := HurtboxComponent.new()
	hurtbox.health_component_path = NodePath("../Health")
	hurtbox.collision_layer = 4
	hurtbox.collision_mask = 0
	hurtbox.invulnerability_duration = 0.1
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(16, 16)
	collision.shape = rectangle
	hurtbox.add_child(collision)
	actor.add_child(hurtbox)
	root.add_child(actor)
	return hurtbox

func _run() -> void:
	var scene := load("res://combat/special/special_attack_beam.tscn") as PackedScene
	var data := load("res://data/abilities/special/kamehameha.tres") as SpecialAttackData
	for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		for distance in [12.0, 40.0, 100.0]:
			var origin := Vector2(400, 400)
			var first := _target(origin + direction * distance)
			var second := _target(origin + direction * (distance + 64.0))
			var beam := scene.instantiate() as SpecialAttackBeam
			root.add_child(beam)
			beam.set_physics_process(false)
			beam.global_position = origin
			await physics_frame
			await physics_frame
			beam.setup(data, direction, null, 0.0)
			beam.rotation = direction.angle()
			beam._refresh_geometry()
			var contact_length := beam._resolved_length
			_check(contact_length < distance, "Beam must end at front of first target")
			beam._apply_damage_tick()
			_check(first.health_component.current_health == 992, "First target must receive one pulse")
			_check(second.health_component.current_health == 1000, "Second target must be protected")
			_check(first.is_invulnerable(), "Hit must activate invulnerability")
			beam._refresh_geometry()
			_check(is_equal_approx(beam._resolved_length, contact_length), "Invulnerability must not extend beam")
			beam._apply_damage_tick()
			_check(first.health_component.current_health == 992, "Invulnerability must prevent repeated damage")
			_check(second.health_component.current_health == 1000, "Invulnerable target must still shield second target")
			for segment in beam._kame_segments:
				var forward_scale: float = segment.scale.x if direction.x != 0 else segment.scale.y
				_check(segment.position.x + 16.0 * forward_scale <= distance - 8.0 + 0.01, "Visual must not cross target front")
			first.health_component.take_damage(1000)
			beam._refresh_geometry()
			_check(beam._resolved_length > contact_length, "Dead target must release beam")
			beam.queue_free()
			first.get_parent().queue_free()
			second.get_parent().queue_free()
			await process_frame
	print("Beam contact regression: %s (12 scenarios)" % ("PASS" if failures == 0 else "FAIL: %d" % failures))
	quit(0 if failures == 0 else 1)
