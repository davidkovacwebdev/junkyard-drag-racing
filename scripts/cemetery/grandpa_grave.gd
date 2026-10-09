@tool
class_name GrandpaGrave
extends StaticBody2D
## Grandpa's resting place, at the head of the cemetery's main path between
## two old graves. Nothing's here until his funeral is booked (Funeral);
## then his coffin waits on the grass in front of a pile of dug-up dirt,
## his empty wheelchair parked by its head end.
##
## Driving into the cemetery once it's time (or after making it to the gate
## in time) plays the ceremony (FuneralCutscene) straight away: the car is
## parked down the path, the music hushes, and everyone says goodbye. After
## that it's a grave for good: a long mound, a wooden cross, and the
## six-pack the player left him. His wheelchair goes to the player's garage
## as a whole car (body, wheels and a scooter motor), shown on crane-pen part
## cards once the ceremony's over.
##
## Origin at the foot of the coffin's middle, so it Y-sorts against the car
## and the mourners.

const SCENE_PATH := "res://cutscenes/funeral.tres"
const SIX_PACK := preload("res://scenes/items/icons/item_six_pack.tscn")
const WHEELCHAIR := preload("res://scenes/characters/props/empty_wheelchair.tscn")
## The car his wheelchair becomes in the garage.
const CHAIR_BODY := "res://scenes/parts/bodies/body_wheelchair.tscn"
const CHAIR_ENGINE := "res://scenes/parts/engines/engine_electric_scooter_motor.tscn"
const CHAIR_WHEEL := "res://scenes/parts/wheels/wheel_wheelchair.tscn"
const CHAIR_BODY_ID := &"body_wheelchair"

enum State { NONE, COFFIN, GRAVE }

const WOOD := UiPalette.SURFACE_DARK
const WOOD_SHADE := Color(0.32, 0.23, 0.15)
const BRASS := Color(0.8, 0.66, 0.3)
const CROSS_WOOD := UiPalette.SURFACE_BASE

## Where the car is parked for the ceremony, down the main path.
const CAR_SPOT := Vector2(0.0, 500.0)
## Relative to the grave: where each speaker stands to say their piece (off
## the coffin's head end, so it stays in view), and
## where whoever comes up with them stands.
const SPEAK_SPOT := Vector2(-140.0, 95.0)
const SECOND_SPEAKER_OFFSET := Vector2(-64.0, 18.0)
## The crowd, in a loose arc in front of the coffin.
const SHOPKEEPER_SPOT := Vector2(-250.0, 170.0)
const GORD_SPOT := Vector2(-165.0, 205.0)
const LOU_SPOT := Vector2(-95.0, 240.0)
const OPERATOR_SPOT := Vector2(115.0, 205.0)
const DARLENE_SPOT := Vector2(200.0, 175.0)
const GUS_SPOT := Vector2(275.0, 205.0)
const PLAYER_SPOT := Vector2(20.0, 255.0)
## Tiger, painted, standing in the back by the crypt.
const TIGER_SPOT := Vector2(255.0, -35.0)
## The six-pack, on the grass in front of the coffin's foot end.
const SIX_PACK_SPOT := Vector2(46.0, 26.0)
const SIX_PACK_SCALE := 0.55
## His wheelchair, by the coffin's head end; the prop is drawn in character
## space, so it's shrunk like the people around it.
const WHEELCHAIR_SPOT := Vector2(-128.0, -8.0)
const WHEELCHAIR_SCALE := 0.55

@export var display_name: String = "Grandpa's Grave"

var _state := State.NONE
var _six_pack: Node2D
var _wheelchair: Node2D
var _collision: CollisionShape2D
var _started := false
## The wheelchair went to the garage this visit (see `finish()`).
var _chair_given := false

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var shape := RectangleShape2D.new()
	shape.size = Vector2(180.0, 30.0)
	_collision = CollisionShape2D.new()
	_collision.shape = shape
	_collision.position = Vector2(0.0, -12.0)
	add_child(_collision)
	_six_pack = SIX_PACK.instantiate()
	_six_pack.position = SIX_PACK_SPOT
	_six_pack.scale = Vector2.ONE * SIX_PACK_SCALE
	add_child(_six_pack)
	_wheelchair = WHEELCHAIR.instantiate()
	_wheelchair.position = WHEELCHAIR_SPOT
	_wheelchair.scale = Vector2.ONE * WHEELCHAIR_SCALE
	add_child(_wheelchair)
	_refresh()
	if Funeral.is_ceremony_due():
		_start()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _current_state() != _state:
		_refresh()
	# Already in here when the time came.
	if not _started and Funeral.is_ceremony_due() and not Cutscenes.is_active():
		_start()

func _start() -> void:
	_started = true
	Music.hush(true, 0.6)
	_play.call_deferred()

func _play() -> void:
	# Let the camera settle in first.
	await get_tree().process_frame
	var scene := ResourceLoader.load(SCENE_PATH, "", ResourceLoader.CACHE_MODE_REPLACE) as FuneralCutscene
	if scene != null:
		scene.grave = self
		await Cutscenes.play(scene)
	finish()
	Music.hush(false)
	if _chair_given:
		var car := Inventory.owned_cars.back() as CarModelData
		Sfx.play(&"part_pickup", -4.0, 0.0)
		Sfx.play(&"wheelchair_squeak", -6.0, 0.0)
		var parts: Array[PartData] = [car.body, car.wheels[0], car.engine]
		await Cutscenes.part_cards(parts, "Grandpa's Wheelchair is in your garage!", 4.0)

## The ceremony's over: into the ground he goes, and his wheelchair goes to
## the player's garage. FuneralCutscene calls it under the last fade, and
## it's called again once the cutscene is over in case that was skipped.
func finish() -> void:
	if not Funeral.held and not Inventory.owns_car_with_body(CHAIR_BODY_ID):
		Inventory.give_car(Inventory.build_car(CHAIR_BODY, CHAIR_ENGINE, CHAIR_WHEEL))
		_chair_given = true
	if not Funeral.held:
		Funeral.hold()
	_refresh()

## Parks the car down the path, out of the way of the crowd.
func park_car() -> void:
	var car := get_tree().get_first_node_in_group(PlayerCar.GROUP) as Node2D
	if car != null:
		car.global_position = global_position + CAR_SPOT

static func _current_state() -> State:
	if Funeral.held:
		return State.GRAVE
	if Funeral.is_pending():
		return State.COFFIN
	return State.NONE

func _refresh() -> void:
	_state = _current_state()
	visible = _state != State.NONE
	_collision.disabled = _state == State.NONE
	show_six_pack(_state == State.GRAVE)
	_wheelchair.visible = _state == State.COFFIN
	queue_redraw()

func show_six_pack(shown: bool) -> void:
	if _six_pack != null:
		_six_pack.visible = shown

func spot(local: Vector2) -> Vector2:
	return global_position + local

func get_interact_prompt() -> String:
	if _state == State.GRAVE:
		return "Here lies Eugen. He never found the Junkyard Treasure."
	return ""

func _draw() -> void:
	if Engine.is_editor_hint() or _state == State.COFFIN:
		_draw_coffin()
	elif _state == State.GRAVE:
		_draw_grave()

## A plain dark coffin lying on the grass (wide at the shoulders, on the
## left), its lid seen from a little above, one brass handle along the side,
## in front of the dirt dug out for it.
func _draw_coffin() -> void:
	draw_colored_polygon(FlatProps.octagon(Vector2(8.0, -2.0), 104.0, 18.0), UiPalette.SHADOW)
	draw_colored_polygon(FlatProps.octagon(Vector2(14.0, -40.0), 96.0, 26.0), GraveyardProp.MOUND)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-88.0, -24.0), Vector2(-50.0, -18.0), Vector2(88.0, -22.0),
		Vector2(88.0, -6.0), Vector2(-50.0, 0.0), Vector2(-88.0, -8.0),
	]), WOOD_SHADE)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-88.0, -40.0), Vector2(-50.0, -47.0), Vector2(88.0, -41.0),
		Vector2(88.0, -22.0), Vector2(-50.0, -18.0), Vector2(-88.0, -24.0),
	]), WOOD)
	draw_colored_polygon(FlatProps.sliver(Vector2(-34.0, -9.0), Vector2(56.0, -11.0), 5.0), BRASS)

## A fresh mound with a wooden cross at its head.
func _draw_grave() -> void:
	draw_colored_polygon(FlatProps.octagon(Vector2(8.0, -4.0), 96.0, 18.0), UiPalette.SHADOW)
	draw_colored_polygon(FlatProps.octagon(Vector2(0.0, -10.0), 86.0, 20.0), GraveyardProp.MOUND)
	draw_set_transform(Vector2(-66.0, -14.0), deg_to_rad(-3.0), Vector2.ONE)
	draw_rect(Rect2(-6.0, -78.0, 12.0, 78.0), CROSS_WOOD)
	draw_rect(Rect2(-24.0, -60.0, 48.0, 12.0), CROSS_WOOD)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
