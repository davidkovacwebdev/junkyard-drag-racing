@tool
class_name PanFactory
extends Obstacle
## A small pan factory on Chad's island: a tin shed under a sawtooth factory
## roof, with a giant frying pan (an egg frying in it) propped on top for a
## sign. Drive up and press E to go in and bend loose parts with hammers
## (PanFactoryScreen). Flat polygons only, drawn centred on the origin like
## ForgeBuilding. Somebody inside is always banging on something.

const WALL := Color(0.5, 0.55, 0.52)
const WALL_SHADE := Color(0.4, 0.45, 0.42)
const ROOF := Color(0.34, 0.36, 0.38)
const PAN := Color(0.2, 0.2, 0.22)
const PAN_HANDLE := Color(0.46, 0.33, 0.22)
const EGG_WHITE := Color(0.92, 0.9, 0.84)
const YOLK := Color(0.95, 0.75, 0.1)

const WALL_TOP := -30.0
const TOOTH_RISE := 46.0
const TEETH := 3
const DOOR := Rect2(-60.0, 18.0, 96.0, 77.0)
const CHIMNEY := Rect2(-118.0, -118.0, 26.0, 70.0)
const PAN_CENTER := Vector2(26.0, -84.0)
const PAN_RADIUS := Vector2(46.0, 30.0)

## Drive further than this and the screen closes itself.
@export var dialog_range: float = 420.0
@export var hit_price: int = 50

var _screen: PanFactoryScreen
var _actor: Node2D = null

func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	_screen = PanFactoryScreen.new()
	_screen.hit_price = hit_price
	add_child(_screen)
	_screen.closed.connect(func() -> void: _actor = null)
	var banging := AmbientCall.new()
	banging.sound_name = &"pan_bonk"
	banging.interval_range = Vector2(2.0, 5.0)
	banging.pitch_variation = 0.3
	banging.volume_db = -14.0
	banging.max_distance = 1100.0
	banging.position = DOOR.get_center() + art_origin()
	add_child(banging)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or _screen == null or not _screen.is_open():
		return
	if not is_instance_valid(_actor) or global_position.distance_to(_actor.global_position) > dialog_range:
		_screen.close()

func get_interact_prompt() -> String:
	return "%s: Press E to bend parts ($%d a whack)" % [display_name, hit_price]

func interact(actor: Node = null) -> void:
	if _screen.is_open() or Cutscenes.is_active():
		return
	_actor = actor as Node2D
	Sfx.play(&"door_close", -4.0)
	_screen.open()

func _draw() -> void:
	draw_set_transform(art_origin())
	var half := size / 2.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(-half.x + 8.0, half.y - 10.0), Vector2(half.x + 6.0, half.y - 10.0),
		Vector2(half.x + 24.0, half.y + 10.0), Vector2(-half.x + 22.0, half.y + 10.0),
	]), UiPalette.SHADOW)
	draw_rect(CHIMNEY, ROOF)
	_draw_roof(half)
	draw_rect(Rect2(-half.x, WALL_TOP, size.x, half.y - WALL_TOP), WALL)
	draw_rect(Rect2(half.x - 20.0, WALL_TOP, 20.0, half.y - WALL_TOP), WALL_SHADE)
	draw_rect(DOOR, UiPalette.VOID)
	_draw_pan()

## The factory's sawtooth roof: steep faces to the left, long slopes right.
func _draw_roof(half: Vector2) -> void:
	var points := PackedVector2Array([Vector2(half.x + 8.0, WALL_TOP + 4.0), Vector2(-half.x - 8.0, WALL_TOP + 4.0)])
	var tooth := (size.x + 16.0) / TEETH
	for i in TEETH:
		var left := -half.x - 8.0 + tooth * i
		points.append(Vector2(left, WALL_TOP - TOOTH_RISE + (i % 2) * 4.0))
		points.append(Vector2(left + tooth, WALL_TOP))
	draw_colored_polygon(points, ROOF)

## The rooftop sign: a giant frying pan, handle out to the right, frying an egg.
func _draw_pan() -> void:
	draw_colored_polygon(FlatProps.sliver(PAN_CENTER + Vector2(PAN_RADIUS.x - 6.0, 2.0),
			PAN_CENTER + Vector2(PAN_RADIUS.x + 58.0, -14.0), 12.0), PAN_HANDLE)
	draw_colored_polygon(FlatProps.octagon(PAN_CENTER, PAN_RADIUS.x, PAN_RADIUS.y), PAN)
	draw_colored_polygon(FlatProps.octagon(PAN_CENTER + Vector2(-6.0, -2.0), 28.0, 17.0), EGG_WHITE)
	draw_colored_polygon(FlatProps.octagon(PAN_CENTER + Vector2(-2.0, -4.0), 10.0, 8.0), YOLK)
