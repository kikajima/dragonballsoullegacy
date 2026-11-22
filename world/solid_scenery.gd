extends RefCounted

# Ground footprints, in each prop's local coordinates. Floor art, rugs,
# checkpoints, portal markers and effects remain walkable deliberately.
# Keep this separate from interaction Areas: Areas never stop a moving body.
static func apply(world: Node2D) -> void:
	match String(world.name):
		"KameIsland":
			for tree in ["PalmTreeLeft", "PalmTreeRight", "PalmTreeSouth", "PalmTreeNorthWest", "PalmTreeNorthEast"]:
				var palm := world.get_node_or_null(tree) as CanvasItem
				if palm != null and palm.visible:
					set_footprint(palm, Rect2(-7, 22, 14, 26))
			set_footprint(world.get_node("BeachUmbrella"), Rect2(-5, 18, 10, 14))
			set_footprint(world.get_node("BeachChair"), Rect2(-24, -10, 48, 24))
			set_footprint(world.get_node("BeachGuide"), Rect2(-17, 3, 34, 10))
			set_footprint(world.get_node("TravelCapsule"), Rect2(-56, -20, 112, 96))
			# Approach the ship from the dock, not through its hull.
			world.get_node("WestCityBoat").position = Vector2(700, 419)
		"KameHouseInterior":
			# These objects must also be solid when optional replacement art is absent.
			for entry in [["TV", Rect2(-24, -3, 48, 20)], ["Fridge", Rect2(-11, 6, 22, 24)],
				["Sofa", Rect2(-16, -20, 32, 44)], ["CoffeeTable", Rect2(-24, -10, 48, 24)]]:
				set_footprint(world.get_node(entry[0]), entry[1])
			# Travel uses the Exit interaction; the gap must not lead outside the room.
			set_footprint(world.get_node("Walls"), Rect2(264, 335, 16, 18))
		"CapsuleTrainingChamber":
			for entry in [["GravityConsole", Rect2(-23, -12, 46, 24)],
				["SparringConsole", Rect2(-23, -11, 46, 24)],
				["RecoveryStation", Rect2(-16, -8, 32, 36)],
				["PunchingBag", Rect2(-9, 0, 18, 12)],
				["Treadmill", Rect2(-31, -12, 62, 24)]]:
				set_footprint(world.get_node(entry[0]), entry[1])
		"WestCityOutskirts":
			var ship := world.get_node_or_null("TravelCapsule") as Node2D
			if ship != null:
				set_footprint(ship, Rect2(-56, -20, 112, 96))
				WorldDepth.place(ship, ship.to_global(Vector2(0, 76)).y)
		"RockyWastes":
			# RockSlide art is 192 pixels wide, wider than the old placeholders.
			for entry in [["RockA", 40.0], ["RockC", 28.0]]:
				var rock := world.get_node(entry[0]) as Node2D
				if rock.has_node("LibraryArt"):
					set_footprint(rock, Rect2(-96, entry[1] - 64, 192, 64))

static func set_footprint(prop: Node2D, rect: Rect2) -> void:
	var body := prop as StaticBody2D
	var collision: CollisionShape2D
	if body != null:
		collision = body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null:
		body = prop.get_node_or_null("Footprint") as StaticBody2D
		if body == null:
			body = StaticBody2D.new()
			body.name = "Footprint"
			prop.add_child(body)
		body.position = Vector2.ZERO
		for child in body.get_children():
			if child is CollisionShape2D:
				collision = child
				break
		if collision == null:
			collision = CollisionShape2D.new()
			collision.name = "CollisionShape2D"
			body.add_child(collision)
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	collision.position = rect.get_center()
	collision.disabled = false
