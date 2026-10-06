class_name BirdRoost
extends Node2D
## A spot where birds sit until the car comes too close: the crows in the
## graveyard. Each perch is (x, y, height): the ground point the bird sorts by,
## in this node's space, and how high above it the bird sits (a tombstone top,
## the crypt roof, a branch). Birds that fly off come back once the car has
## been at least `return_distance` away for `return_delay` seconds, out of
## sight, so they never pop in on screen.

@export var species: Bird.Species = Bird.Species.CROW
@export var perches: Array[Vector3] = []
## Chance each perch is taken when the roost fills up.
@export_range(0.0, 1.0) var occupancy: float = 0.6
@export var return_distance: float = 1400.0
@export var return_delay: float = 8.0

var _birds: Dictionary = {}
var _away_time := 0.0
var _player: Node2D

func _ready() -> void:
	y_sort_enabled = true
	_player = get_tree().get_first_node_in_group(PlayerCar.GROUP) as Node2D
	_fill()

func _process(delta: float) -> void:
	if _player == null or _player.global_position.distance_to(global_position) < return_distance:
		_away_time = 0.0
		return
	_away_time += delta
	if _away_time >= return_delay:
		_away_time = 0.0
		_fill()

## Puts a bird on each empty perch that rolls under `occupancy`; at least one
## if the roost is empty.
func _fill() -> void:
	var empty: Array[int] = []
	for i in perches.size():
		if not is_instance_valid(_birds.get(i)):
			empty.append(i)
	var filled := 0
	for i in empty:
		if randf() < occupancy:
			_perch_bird(i)
			filled += 1
	if filled == 0 and empty.size() == perches.size() and not empty.is_empty():
		_perch_bird(empty.pick_random())

func _perch_bird(index: int) -> void:
	var perch := perches[index]
	var bird := Bird.new()
	bird.species = species
	bird.perch_height = perch.z
	# A pixel in front of whatever it sits on, so it sorts on top of it.
	bird.position = Vector2(perch.x, perch.y + 1.0)
	add_child(bird)
	_birds[index] = bird
