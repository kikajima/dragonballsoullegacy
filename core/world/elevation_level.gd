class_name ElevationLevel
extends RefCounted

# Vertical layers of a map. Every fighter is on exactly one level, and every
# skill (melee, ki blast, special projectile, beam, area effect) inherits the
# level of whoever used it. Skills only touch fighters, projectiles and
# scenery on that same level, and are drawn at that level's height.
#
#   UNDERGROUND (-1)  reserved: caves/tunnels under the current map.
#   GROUND       (0)  walking.
#   AIR          (1)  flying over the current map.
#
# Level of an actor: AIR while its FlightComponent is flying; otherwise the
# `elevation_level` metadata on the actor (set it to UNDERGROUND for
# underground areas), defaulting to GROUND. Skill nodes carry the metadata
# themselves (see `tag`).

const UNDERGROUND := -1
const GROUND := 0
const AIR := 1

const META: StringName = &"elevation_level"
# Screen-space lift of everything drawn on the AIR level.
const AIR_HEIGHT := 12.0
const NAMES := {UNDERGROUND: "Underground", GROUND: "Ground", AIR: "Air"}
# Air skills draw above every roof/tree (ground depth tops out near 1720)
# and around airborne fighters (ground depth + 1000).
const AIR_DRAW_Z := 2900

static func of(node: Node) -> int:
	var current := node
	while current != null:
		if current is CharacterBody2D:
			return actor_level(current)
		if current.has_meta(META):
			return int(current.get_meta(META))
		current = current.get_parent()
	return GROUND

static func actor_level(actor: Node) -> int:
	if actor == null:
		return GROUND
	var flight := actor.get_node_or_null("Components/FlightComponent") as FlightComponent
	if flight != null and flight.is_flying:
		return AIR
	if actor.has_meta(META):
		return int(actor.get_meta(META))
	return GROUND

static func same(a: Node, b: Node) -> bool:
	return of(a) == of(b)

# Marks a skill node (projectile, beam, effect) as living on `level`.
static func tag(node: Node, level: int) -> void:
	node.set_meta(META, level)

# Scenery (physics layer 1) only exists on the ground. Flyers pass over it;
# the underground will get its own blockers.
static func blocks_scenery(level: int) -> bool:
	return level == GROUND

static func lift(level: int) -> Vector2:
	if level == AIR:
		return Vector2(0.0, -AIR_HEIGHT)
	return Vector2.ZERO

static func level_name(level: int) -> String:
	return NAMES.get(level, "Ground")

# Shifts the visible children of a rotated skill node up to its level's
# height. Collision shapes and areas stay on the ground plane, where every
# hurtbox lives, so contact is unchanged.
static func apply_visual_lift(root: Node2D, level: int) -> void:
	var offset := lift(level).rotated(-root.global_rotation)
	for child in root.get_children():
		var item := child as Node2D
		if item == null or item is CollisionShape2D or item is CollisionPolygon2D or item is CollisionObject2D:
			continue
		if not item.has_meta(&"_elevation_base"):
			item.set_meta(&"_elevation_base", item.position)
		item.position = (item.get_meta(&"_elevation_base") as Vector2) + offset

# Air-level skill effects are drawn above all ground scenery.
static func apply_draw_order(node: CanvasItem, level: int) -> void:
	if level == AIR:
		node.z_as_relative = false
		node.z_index = AIR_DRAW_Z
