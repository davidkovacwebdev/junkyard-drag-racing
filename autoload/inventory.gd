extends Node
## Placeholder player inventory (autoload singleton "Inventory"). Holds
## which cars the player owns and how many the garage can currently hold.
##
## No save/load yet — that's planned, not built. When it lands, owned_cars
## being a plain Array[CarModelData] of Resources means it can be written
## straight out with ResourceSaver (or ResourceSaver.save each entry into
## a save-game folder) without restructuring this data; garage_capacity
## is one raw int that just needs to land in the same save blob.

var garage_capacity: int = 2
var owned_cars: Array[CarModelData] = []

const _STARTER_POOL := [
	{"id": &"rustbucket", "name": "Rustbucket", "color": Color(0.55, 0.32, 0.18)},
	{"id": &"bumper_special", "name": "Bumper Special", "color": Color(0.6, 0.15, 0.15)},
	{"id": &"blue_streak", "name": "Blue Streak", "color": Color(0.2, 0.35, 0.6)},
	{"id": &"junker", "name": "Junker", "color": Color(0.35, 0.4, 0.28)},
	{"id": &"sunburst", "name": "Sunburst", "color": Color(0.75, 0.55, 0.15)},
]

func _ready() -> void:
	var pool := _STARTER_POOL.duplicate()
	pool.shuffle()
	for entry in pool.slice(0, garage_capacity):
		var car := CarModelData.new()
		car.id = entry["id"]
		car.display_name = entry["name"]
		car.body_color = entry["color"]
		owned_cars.append(car)
