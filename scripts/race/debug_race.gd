class_name DebugRace
## T at a race entrance on the map: the same race scene, but every car in it
## (the player's lane too) is a fully random pick from the part catalog, and
## nothing is recorded or paid out. For testing parts and tracks.
##
## A fresh scene can't take parameters, so the map sets the request right
## before switching and the race setup consumes it in its _ready().

static var _requested := false

static func request() -> void:
	_requested = true

## True once for the race the request was made for, then false again.
static func consume() -> bool:
	var was_requested := _requested
	_requested = false
	return was_requested

## A random body with a random engine and an independently random wheel on
## every mount.
static func random_car() -> CarModelData:
	var car := CarModelData.new()
	car.body = PartDatabase.bodies.pick_random().duplicate()
	car.engine = PartDatabase.engines.pick_random().duplicate()
	car.wheels = []
	for i in PartDatabase.wheel_mount_count(car.body):
		car.wheels.append(PartDatabase.wheels.pick_random().duplicate())
	return car
