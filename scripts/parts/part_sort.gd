class_name PartSort
extends RefCounted
## Orders for the part lists (garage, forge stash, F1 menu). Speed and
## durability go best first, mass lightest first, all by the same stat-bar
## ratings the cards show, so the order matches the bars. Ties go by name.

enum Key { NAME, SPEED, DURABILITY, MASS }

const LABELS := {
	Key.NAME: "Name",
	Key.SPEED: "Speed",
	Key.DURABILITY: "Durability",
	Key.MASS: "Mass",
}

## True when `a` goes before `b`, for sort_custom.
static func comes_before(a: PartData, b: PartData, key: PartSort.Key) -> bool:
	var a_value := _value(a, key)
	var b_value := _value(b, key)
	if not is_equal_approx(a_value, b_value):
		return a_value > b_value
	return a.display_name < b.display_name

static func _value(part: PartData, key: PartSort.Key) -> float:
	match key:
		Key.SPEED:
			return part.speed_rating_fraction()
		Key.DURABILITY:
			return part.durability_rating_fraction()
		Key.MASS:
			return -part.mass_rating_fraction()
	return 0.0
