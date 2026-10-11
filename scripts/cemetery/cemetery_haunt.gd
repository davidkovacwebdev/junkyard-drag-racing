class_name CemeteryHaunt
extends Node
## The cemetery after dark. Between `START_HOUR` (11 PM) and `END_HOUR`
## (3 AM) nobody's visiting (the Drag Queen's parents stay home, see
## DragQueenGrave), and honking the horn in here wakes the dead: skeletons
## claw up out of the graves around the car and run it down
## (CemeterySkeleton). The first honk slams a screaming skull over the
## screen (JumpscareFace) and raises a big wave with a wobbly organ sting; every honk after that raises a few more, up to `MAX_SKELETONS` at
## once.
##
## Added by CemeteryGrounds, which hands over where the graves are.

const START_HOUR := 23.0
const END_HOUR := 3.0
const FIRST_WAVE := 5
const NEXT_WAVE := 2
const MAX_SKELETONS := 9
## Skeletons come up at graves this far from the car: close enough to be
## scary, far enough to get a head start.
const RISE_DISTANCE := Vector2(300.0, 950.0)
## A bit of a gap between them climbing out.
const RISE_GAP := 0.25

## Where the graves are, in `grounds` space.
var grave_spots: Array[Vector2] = []
## The Y-sorted node the skeletons join, with the car and the graves.
var grounds: Node2D
## The fenced lot, in `grounds` space: nobody climbs up outside it.
var lot: Rect2

var _was_honking := false
var _woken := false

## Whether it's the dead of night right now.
static func is_witching_hour() -> bool:
	var hour := DayNightCycle.get_hour()
	return hour >= START_HOUR or hour < END_HOUR

func _process(_delta: float) -> void:
	var car := get_tree().get_first_node_in_group(PlayerCar.GROUP) as PlayerCar
	var honking := car != null and car.is_honking()
	if honking and not _was_honking and is_witching_hour() and not Cutscenes.is_active():
		_wake(car)
	_was_honking = honking

func _wake(car: PlayerCar) -> void:
	var count := NEXT_WAVE if _woken else FIRST_WAVE
	if not _woken:
		JumpscareFace.scare(self)
		Sfx.play(&"haunt_sting", -4.0, 0.0)
	_woken = true
	count = mini(count, MAX_SKELETONS - get_tree().get_nodes_in_group(&"cemetery_skeleton").size())
	var car_at := grounds.to_local(car.global_position)
	var spots := grave_spots.filter(func(at: Vector2) -> bool:
		var distance := at.distance_to(car_at)
		return distance > RISE_DISTANCE.x and distance < RISE_DISTANCE.y)
	spots.shuffle()
	# Not enough graves out there (a clearing, the gate): up out of the bare
	# dirt around the car instead.
	while spots.size() < count:
		var at := car_at + Vector2.from_angle(randf() * TAU) * randf_range(RISE_DISTANCE.x, RISE_DISTANCE.y * 0.7)
		spots.append(at.clamp(lot.position + Vector2.ONE * 80.0, lot.end - Vector2.ONE * 80.0))
	for i in mini(count, spots.size()):
		var skeleton := CemeterySkeleton.new()
		skeleton.add_to_group(&"cemetery_skeleton")
		# Just in front of the stone, not inside it.
		skeleton.position = spots[i] + Vector2(randf_range(-20.0, 20.0), 24.0)
		grounds.add_child(skeleton)
		await get_tree().create_timer(RISE_GAP).timeout
