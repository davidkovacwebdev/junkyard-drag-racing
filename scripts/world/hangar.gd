class_name Hangar
extends Node2D
## A drive-in aircraft hangar out in the desert. The front wall has one huge
## open door; the footprint behind it is hollow, walled in on the other three
## sides, so the car can roll straight in.
##
## Anything inside sits behind the front wall in the Y-sort, so it's hidden
## from the road. Once the player's car is inside, the front wall fades out and
## the back wall fades in (a dollhouse cutaway) so you can see what's parked
## there. See `HangarPiece` for the art.

const WIDTH := 600.0
const DEPTH := 300.0
const WALL := 20.0
const DOOR_WIDTH := 300.0
const DOOR_HEIGHT := 210.0
const ROOF_RISE := 50.0
const BACK_WALL_HEIGHT := 150.0
const APRON := 140.0

## How fast the cutaway fades in and out, in full fades per second.
const REVEAL_SPEED := 5.0

## Played the moment the car rolls in, while anything is still parked inside.
@export var reveal_sound: StringName = &"ufo_reveal"
@export var reveal_volume_db: float = -6.0

var _reveal := 0.0
var _player_inside := false

@onready var _facade: HangarPiece = $Facade
@onready var _interior: HangarPiece = $Interior

func _ready() -> void:
	_build_walls()

func _build_walls() -> void:
	var half := WIDTH / 2.0
	var walls := StaticBody2D.new()
	walls.name = "Walls"
	add_child(walls)
	for rect: Rect2 in [
		Rect2(-half, -DEPTH, WALL, DEPTH),
		Rect2(half - WALL, -DEPTH, WALL, DEPTH),
		Rect2(-half, -DEPTH, WIDTH, WALL),
		Rect2(-half, -WALL, half - DOOR_WIDTH / 2.0, WALL),
		Rect2(DOOR_WIDTH / 2.0, -WALL, half - DOOR_WIDTH / 2.0, WALL),
	]:
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		var collision := CollisionShape2D.new()
		collision.shape = shape
		collision.position = rect.get_center()
		walls.add_child(collision)

func _process(delta: float) -> void:
	var inside := _is_player_inside()
	if inside and not _player_inside and _has_contents():
		Sfx.play(reveal_sound, reveal_volume_db)
	_player_inside = inside
	var target := 1.0 if inside else 0.0
	if is_equal_approx(_reveal, target):
		return
	_reveal = move_toward(_reveal, target, REVEAL_SPEED * delta)
	_facade.reveal = _reveal
	_interior.reveal = _reveal

func _is_player_inside() -> bool:
	var player := get_tree().get_first_node_in_group(PlayerCar.GROUP) as Node2D
	if player == null:
		return false
	var local := to_local(player.global_position)
	var inner_half := WIDTH / 2.0 - WALL
	return absf(local.x) < inner_half and local.y < 0.0 and local.y > -DEPTH + WALL

func _has_contents() -> bool:
	for child in get_children():
		if child is HangarUfo and not (child as HangarUfo).display_name.is_empty():
			return true
	return false
