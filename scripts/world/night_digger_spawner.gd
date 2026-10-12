class_name NightDiggerSpawner
extends Node
## Puts the masked digger's pickup (NightDiggerTruck) out on the roads at
## night from the moment the player starts asking around about the treasure
## until Gus is caught (whether or not the beggar has told them about him),
## and sends it home at sunrise, wherever it is (NightDiggerTruck.go_home()).
## Once Gus is
## caught it puts the TreasureDigSpot he marked on the map. Added by
## StoryDirector.

const CHECK_INTERVAL := 1.0
## It only drives about while it's at least this dark (DayNightCycle).
const NIGHT_FROM := 0.5

var sortables: Node
var _truck: NightDiggerTruck = null
var _timer := 0.0

func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = CHECK_INTERVAL
	if TreasureStory.gus_caught():
		TreasureDigSpot.place(sortables)
	elif not Cutscenes.is_active():
		TreasureDigSpot.remove(sortables)
	var wanted := digger_out()
	if wanted and not is_instance_valid(_truck) and not Cutscenes.is_active():
		_truck = NightDiggerTruck.spawn(sortables)
	elif not wanted and is_instance_valid(_truck) and not _truck.broken and not Cutscenes.is_active():
		_truck.go_home()
		_truck = null

## Whether Gus is out digging in his pickup right now (and so not at his
## forge, see ForgeSmith): it's dark, the player is asking around ("Ask
## Around" or "Graveyard Shift" is on) and he hasn't been caught. While Chad
## is on his way to the forge with the player he stays home.
static func digger_out() -> bool:
	if TreasureStory.gus_caught() or Quests.has_quest(TreasureStory.VISIT.id):
		return false
	if not (Quests.has_quest(TreasureStory.RUMORS) or Quests.has_quest(NightDiggerTruck.QUEST.id)):
		return false
	return DayNightCycle.get_night_factor() >= NIGHT_FROM
