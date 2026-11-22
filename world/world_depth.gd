class_name WorldDepth
extends RefCounted

# Draw order by the feet's Y: things lower on screen are drawn in front.
# Godot limits z_index to +-4096, and the open world is far taller than that,
# so depth is measured from a moving origin that follows the player (in
# steps, see WorldAmbientFX). Everything near the player keeps its exact
# pixel order; far away things are clamped, which is invisible off screen.
# Floors stay at z <= 0, so scenery and actors always stand above them.

const BASE := 1000
const MIN_Z := 1
const MAX_Z := 2900
const GROUP := &"world_depth_sorted"
const META_FOOT := &"world_depth_foot_y"
# How far above the player the origin sits, and the step it moves in.
const ORIGIN_LEAD := 1200.0
const ORIGIN_STEP := 512.0

static var origin_y: float = 0.0

static func z_for(foot_y: float) -> int:
	return clampi(BASE + roundi(foot_y - origin_y), MIN_Z, MAX_Z)

# Sort a static item by a fixed foot position (global Y). It is re-sorted
# whenever the origin moves.
static func place(item: CanvasItem, foot_y: float) -> void:
	item.z_as_relative = false
	item.set_meta(META_FOOT, foot_y)
	item.z_index = z_for(foot_y)
	if not item.is_in_group(GROUP):
		item.add_to_group(GROUP)

static func origin_for(player_y: float) -> float:
	return maxf(0.0, snappedf(player_y - ORIGIN_LEAD, ORIGIN_STEP))

# Moves the origin; returns true when it changed (static items re-sorted).
static func follow(tree: SceneTree, player_y: float) -> bool:
	var target := origin_for(player_y)
	if is_equal_approx(target, origin_y):
		return false
	origin_y = target
	for node in tree.get_nodes_in_group(GROUP):
		var item := node as CanvasItem
		if item != null and item.has_meta(META_FOOT):
			item.z_index = z_for(float(item.get_meta(META_FOOT)))
	return true
