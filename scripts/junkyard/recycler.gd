@tool
class_name Recycler
extends Obstacle
## The junkyard's recycler: a green shredder box under a steel hopper (an old
## tyre half swallowed in its mouth), with a chute spitting scrap onto a little
## pile. Drive up and press E for its panel (RecyclerScreen): shred loose parts
## into scrap, and swap scrap for cash and back. Flat polygons only, drawn
## centred on the origin like ForgeBuilding.
##
## JunkyardYard adds it to the yard from code (see `SPOT`), not junkyard.tscn.

## Where it stands in the yard: right of the crane, clear of the dealer's stall.
const SPOT := Vector2(690.0, -60.0)

const BODY := Color(0.36, 0.45, 0.36)
const BODY_SHADE := Color(0.28, 0.36, 0.28)
const HOPPER := Color(0.5, 0.52, 0.54)
const TIRE := Color(0.14, 0.14, 0.15)
const HUB := Color(0.62, 0.64, 0.66)
const SCRAP_PILE := Color(0.45, 0.33, 0.24)

const BODY_TOP := -20.0
const HOPPER_TOP := -82.0
const HOPPER_LIP := 14.0

## Drive further than this and the panel closes itself.
@export var dialog_range: float = 360.0

var _screen: RecyclerScreen
var _actor: Node2D = null

func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	_screen = RecyclerScreen.new()
	add_child(_screen)
	_screen.closed.connect(func() -> void: _actor = null)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or _screen == null or not _screen.is_open():
		return
	if not is_instance_valid(_actor) or global_position.distance_to(_actor.global_position) > dialog_range:
		_screen.close()

func get_interact_prompt() -> String:
	return "%s: Press E to recycle (%d scrap, $%d)" % [display_name, Inventory.scrap, Inventory.money]

func interact(actor: Node = null) -> void:
	if _screen.is_open() or Cutscenes.is_active():
		return
	_actor = actor as Node2D
	Sfx.play(&"ignition_click", -6.0)
	_screen.open()

func _draw() -> void:
	draw_set_transform(art_origin())
	var half := size / 2.0
	var body_left := -half.x + 30.0
	var body_right := half.x - 50.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(body_left + 8.0, half.y - 10.0), Vector2(half.x + 6.0, half.y - 10.0),
		Vector2(half.x + 24.0, half.y + 10.0), Vector2(body_left + 22.0, half.y + 10.0),
	]), UiPalette.SHADOW)
	# The chute out the right side, and what it's spat out.
	draw_colored_polygon(PackedVector2Array([
		Vector2(body_right - 6.0, 20.0), Vector2(body_right + 40.0, 52.0),
		Vector2(body_right + 40.0, 72.0), Vector2(body_right - 6.0, 46.0),
	]), BODY_SHADE)
	draw_colored_polygon(PackedVector2Array([
		Vector2(body_right + 18.0, half.y), Vector2(body_right + 30.0, half.y - 16.0),
		Vector2(body_right + 44.0, half.y - 20.0), Vector2(body_right + 58.0, half.y - 8.0),
		Vector2(half.x + 4.0, half.y),
	]), SCRAP_PILE)
	draw_rect(Rect2(body_left, BODY_TOP, body_right - body_left, half.y - BODY_TOP), BODY)
	draw_rect(Rect2(body_right - 22.0, BODY_TOP, 22.0, half.y - BODY_TOP), BODY_SHADE)
	# The hopper: wide at the top, narrowing into the box.
	var middle := (body_left + body_right) / 2.0
	var top_half := (body_right - body_left) / 2.0 + 26.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(middle - top_half, HOPPER_TOP), Vector2(middle + top_half, HOPPER_TOP + 4.0),
		Vector2(body_right - 12.0, BODY_TOP + 2.0), Vector2(body_left + 12.0, BODY_TOP + 2.0),
	]), HOPPER)
	# The gag: a tyre half gone into the mouth.
	var tire_at := Vector2(middle + 18.0, HOPPER_TOP + 6.0)
	draw_colored_polygon(FlatProps.octagon(tire_at, 30.0, 30.0), TIRE)
	draw_colored_polygon(FlatProps.octagon(tire_at, 11.0, 11.0), HUB)
	draw_colored_polygon(PackedVector2Array([
		Vector2(middle - top_half + 8.0, HOPPER_TOP + 2.0), Vector2(middle + top_half - 8.0, HOPPER_TOP + 5.0),
		Vector2(middle + top_half - 22.0, HOPPER_TOP + HOPPER_LIP + 6.0), Vector2(middle - top_half + 22.0, HOPPER_TOP + HOPPER_LIP + 4.0),
	]), UiPalette.VOID)
