class_name NightDiggerSpawner
extends Node
## Puts the masked digger's pickup (NightDiggerTruck) out on the roads while
## "Graveyard Shift" is on and it's night, and clears it away again come
## morning, once it's out of sight. Once the quest's done it puts the
## TreasureDigSpot Gus marked on the map. Added by StoryDirector.

const CHECK_INTERVAL := 1.0
## It only drives about while it's at least this dark (DayNightCycle).
const NIGHT_FROM := 0.5
## Morning: it only vanishes while this far from the player's car.
const DESPAWN_DISTANCE := 1600.0

var sortables: Node
var _truck: NightDiggerTruck = null
var _timer := 0.0

func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = CHECK_INTERVAL
	if Quests.is_complete(NightDiggerTruck.QUEST.id):
		TreasureDigSpot.place(sortables)
	elif not Cutscenes.is_active():
		TreasureDigSpot.remove(sortables)
	var wanted := digger_out()
	if wanted and not is_instance_valid(_truck) and not Cutscenes.is_active():
		_truck = NightDiggerTruck.spawn(sortables)
	elif not wanted and is_instance_valid(_truck) and not _truck.broken and _out_of_sight():
		_truck.queue_free()
		_truck = null

## Whether Gus is out digging in his pickup right now (and so not at his
## forge, see ForgeSmith): "Graveyard Shift" is on and it's dark.
static func digger_out() -> bool:
	return Quests.has_quest(NightDiggerTruck.QUEST.id) \
			and DayNightCycle.get_night_factor() >= NIGHT_FROM

func _out_of_sight() -> bool:
	var car := get_tree().get_first_node_in_group(PlayerCar.GROUP) as Node2D
	return car == null or car.global_position.distance_to(_truck.global_position) > DESPAWN_DISTANCE \
			or not Quests.has_quest(NightDiggerTruck.QUEST.id)
