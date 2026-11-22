class_name SpecialAreaFlash
extends Node2D

# Blinding flash for area-stun specials (Peace Sign Pose). A bright burst at
# the caster followed by a ring that expands to the real stun radius, so the
# affected area is readable.

const DURATION := 0.42

var _radius: float = 60.0
var _elapsed: float = 0.0

static func spawn(caster: Node2D, radius: float) -> SpecialAreaFlash:
	if caster == null or not caster.is_inside_tree():
		return null
	var flash := SpecialAreaFlash.new()
	flash._radius = maxf(radius, 8.0)
	flash.z_index = 5
	var parent: Node = caster.get_tree().current_scene
	if parent == null:
		parent = caster.get_parent()
	parent.add_child(flash)
	var level := ElevationLevel.of(caster)
	flash.global_position = caster.global_position + Vector2(0, -10) + ElevationLevel.lift(level)
	ElevationLevel.apply_draw_order(flash, level)
	return flash

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= DURATION:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t: float = clampf(_elapsed / DURATION, 0.0, 1.0)
	var fade: float = 1.0 - t
	# Core burst: brief and bright, shrinking as the ring travels out.
	var core: float = lerpf(14.0, 4.0, t)
	draw_circle(Vector2.ZERO, core * 1.8, Color(1.0, 1.0, 0.75, 0.35 * fade))
	draw_circle(Vector2.ZERO, core, Color(1.0, 1.0, 1.0, fade))
	for index in range(8):
		var angle: float = index * TAU / 8.0 + PI / 8.0
		var length: float = core * (2.6 if index % 2 == 0 else 1.7)
		draw_line(
			Vector2.from_angle(angle) * core * 0.6,
			Vector2.from_angle(angle) * length,
			Color(1.0, 1.0, 0.6, fade),
			1.0
		)
	var ring: float = _radius * sqrt(t)
	draw_circle(Vector2.ZERO, ring, Color(1.0, 1.0, 0.85, 0.12 * fade))
	draw_arc(Vector2.ZERO, ring, 0.0, TAU, 56, Color(1.0, 1.0, 0.7, 0.9 * fade), 2.0)
