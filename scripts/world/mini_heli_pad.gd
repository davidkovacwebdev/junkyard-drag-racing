class_name MiniHeliPad
extends StaticBody2D
## Grandpa's homemade helicopter parked in his yard ("Test Pilot"), placed and
## shown or hidden by HeliTestStory. Once the quest's on, the car can climb in
## with E (duck-typed for PlayerCar: `display_name`, `interact()`); until
## then it has no name, so E still talks to Grandpa, who's busy whacking it.

const BODY_SIZE := Vector2(190.0, 34.0)

## "Grandpa's Helicopter" when it can be flown, otherwise empty.
var display_name: String = ""
var heli: MiniHeli
## Called with the car when the player climbs in.
var on_board: Callable

var _collision: CollisionShape2D

func _ready() -> void:
	heli = MiniHeli.new()
	add_child(heli)
	var shape := RectangleShape2D.new()
	shape.size = BODY_SIZE
	_collision = CollisionShape2D.new()
	_collision.shape = shape
	_collision.position = Vector2(20.0, -BODY_SIZE.y * 0.5)
	_collision.disabled = not visible
	add_child(_collision)

## Shown in the yard (and solid), or not there at all.
func set_shown(shown: bool) -> void:
	if visible == shown:
		return
	visible = shown
	_collision.set_deferred("disabled", not shown)

func get_interact_prompt() -> String:
	return "%s: Press E to climb in" % display_name

## Wins over Grandpa next to it once it can be flown.
func get_interact_priority() -> int:
	return 2

func interact(talker: Node = null) -> void:
	if display_name.is_empty() or not on_board.is_valid():
		return
	on_board.call(talker)
