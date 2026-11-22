class_name ShopCatalog
extends RefCounted

# What each shop sells. Prices come from ItemData (buy_price, sell_value).

const SHOPS := {
	&"west_city": {
		"title": "West City Market",
		"items": [&"rice_ball", &"chicken_leg", &"energy_drink", &"senzu_bean",
			&"wild_fruit", &"scrap_metal", &"circuit_chip",
			&"weighted_armbands", &"weighted_vest", &"weighted_boots",
			&"small_pouch", &"travel_bag", &"capsule_case", &"dragon_radar"],
	},
	&"ginger_town": {
		"title": "Ginger Town Stall",
		"items": [&"rice_ball", &"chicken_leg", &"energy_drink", &"wild_fruit",
			&"weighted_boots", &"small_pouch"],
	},
}

static func get_title(shop_id: StringName) -> String:
	return SHOPS.get(shop_id, {}).get("title", "Shop")

# A ShopComponent stocked from the catalog (infinite stock).
static func make_shop(shop_id: StringName) -> ShopComponent:
	var shop := ShopComponent.new()
	shop.name = "Shop"
	var entries: Array[ShopEntryData] = []
	for item_id: StringName in SHOPS.get(shop_id, {}).get("items", []):
		var data := ItemCatalog.get_item(item_id)
		if data == null:
			continue
		var entry := ShopEntryData.new()
		entry.item_id = item_id
		entry.buy_price = data.get_buy_price()
		entry.sell_price = data.sell_value
		entry.infinite_stock = true
		entries.append(entry)
	shop.entries = entries
	return shop
