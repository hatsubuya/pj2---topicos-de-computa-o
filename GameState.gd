extends Node
class_name GameState

static var current_ammo: int = -1
static var collected_lock_digits: Array = []
static var collected_pickup_ids: Array = []

static func is_pickup_collected(id: String) -> bool:
	return collected_pickup_ids.has(id)

static func mark_pickup_collected(id: String) -> void:
	if not collected_pickup_ids.has(id):
		collected_pickup_ids.append(id)
