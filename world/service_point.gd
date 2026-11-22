class_name ServicePoint
extends StaticBody2D

# A solid prop the player can use: a shop stall (opens ShopMenu) or a
# workbench (opens CraftingMenu). Builds its own sprite, base collision and
# interaction area, so it can be dropped into any scene or made from code.

@export_enum("shop", "workbench") var kind: String = "shop"
@export var shop_id: StringName = &"west_city"
@export var texture: Texture2D
@export var label: String = ""
# Solid base, centered on the node (the feet of the prop).
@export var base_size: Vector2 = Vector2(80, 14)

const SHOP_TEXTURE := "res://assets/vendor/hu2/Icons/Images/FoodShop.png"
const WORKBENCH_TEXTURE := "res://assets/sprites/environment/gba_furniture/terminal.png"

func _ready() -> void:
	add_to_group("service_point")
	collision_layer = 1
	collision_mask = 0
	if texture == null:
		texture = load(SHOP_TEXTURE if kind == "shop" else WORKBENCH_TEXTURE) as Texture2D
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = texture
	sprite.centered = true
	if texture != null:
		sprite.position = Vector2(0, -texture.get_height() / 2.0 + base_size.y / 2.0)
	add_child(sprite)
	WorldDepth.place(sprite, global_position.y + base_size.y / 2.0)

	var body := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = base_size
	body.shape = rect
	add_child(body)

	var area := Area2D.new()
	area.name = "InteractionArea"
	area.collision_layer = 64
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true
	area.position = Vector2(0, base_size.y / 2.0 + 8.0)
	var area_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 22.0
	area_shape.shape = circle
	area.add_child(area_shape)
	add_child(area)

func get_display_name() -> String:
	if not label.is_empty():
		return label
	return ShopCatalog.get_title(shop_id) if kind == "shop" else "Capsule Workbench"

func get_interaction_label() -> String:
	return ("Shop at " if kind == "shop" else "Use ") + get_display_name()

func interact(_actor: Node) -> void:
	if kind == "shop":
		var menu := get_tree().get_first_node_in_group("shop_menu") as ShopMenu
		if menu != null:
			menu.open_shop(shop_id)
	else:
		var menu := get_tree().get_first_node_in_group("crafting_menu") as CraftingMenu
		if menu != null:
			menu.open_menu(get_display_name())
