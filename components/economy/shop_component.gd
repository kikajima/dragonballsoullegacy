class_name ShopComponent
extends Node

signal item_bought(item_id: StringName, amount: int, total_price: int)
signal item_sold(item_id: StringName, amount: int, total_price: int)
signal transaction_failed(reason: String)

@export var entries: Array[ShopEntryData] = []

func buy(
	entry_index: int,
	amount: int,
	inventory: InventoryComponent,
	wallet: WalletComponent
) -> bool:
	if (
		entry_index < 0
		or entry_index >= entries.size()
		or amount <= 0
		or inventory == null
		or wallet == null
	):
		transaction_failed.emit("Compra inválida.")
		return false

	var entry := entries[entry_index]
	if entry == null or entry.item_id == &"":
		transaction_failed.emit("Item inválido.")
		return false

	if not entry.infinite_stock and entry.stock < amount:
		transaction_failed.emit("Estoque insuficiente.")
		return false

	var total_price: int = maxi(entry.buy_price, 0) * amount
	if not wallet.spend(total_price):
		transaction_failed.emit("Zeni insuficiente.")
		return false

	inventory.add_item(entry.item_id, amount)

	if not entry.infinite_stock:
		entry.stock -= amount

	item_bought.emit(entry.item_id, amount, total_price)
	return true

func sell(
	entry_index: int,
	amount: int,
	inventory: InventoryComponent,
	wallet: WalletComponent
) -> bool:
	if (
		entry_index < 0
		or entry_index >= entries.size()
		or amount <= 0
		or inventory == null
		or wallet == null
	):
		transaction_failed.emit("Venda inválida.")
		return false

	var entry := entries[entry_index]
	if entry == null or entry.item_id == &"":
		transaction_failed.emit("Item inválido.")
		return false

	if inventory.get_quantity(entry.item_id) < amount:
		transaction_failed.emit("Quantidade insuficiente.")
		return false

	var total_price: int = maxi(entry.sell_price, 0) * amount
	if inventory.remove_item(entry.item_id, amount) != amount:
		transaction_failed.emit("Falha ao remover item.")
		return false

	wallet.add(total_price)

	if not entry.infinite_stock:
		entry.stock += amount

	item_sold.emit(entry.item_id, amount, total_price)
	return true
