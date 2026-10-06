@tool
class_name Shipwreck
extends StaticBody2D
## An old wooden ship run aground: the hull lies keeled over on the beach with
## its stern down in the surf, a dark hole stove in its side and the mast
## snapped, a rag of sail still flapping. Its gag is the treasure chest half
## buried in the sand by the bow, waiting for a future quest. The hull groans
## now and then (`hull_creak`, via an AmbientCall in the scene). Flat polygons,
## origin on the ground under the middle of the hull so it Y-sorts against the
## car; the stern reaches left, out into the water.

const HULL := Color(0.42, 0.3, 0.2)
const DECK := Color(0.55, 0.4, 0.26)
const SAIL := Color(0.8, 0.76, 0.66)
const SEA := Color("3a7c9a")
const CHEST := Color(0.5, 0.33, 0.18)
const GOLD := UiPalette.ACCENT_YELLOW

const SAIL_FLAP_SPEED := 0.6
const SAIL_FLAP := 10.0

var _time := 0.0

func _ready() -> void:
	add_to_group(OffscreenCuller.GROUP)
	if Engine.is_editor_hint():
		return
	var shape := RectangleShape2D.new()
	shape.size = Vector2(420.0, 34.0)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(30.0, -17.0)
	add_child(collision)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	queue_redraw()

## Back to front: the snapped mast and its sail, the tipped deck showing over
## the gunwale, the hull with its keel shade and hole, the band of sea over the
## stern, then the chest in front.
func _draw() -> void:
	draw_colored_polygon(FlatProps.octagon(Vector2(50.0, 2.0), 290.0, 24.0), UiPalette.SHADOW)
	var mast_top := Vector2(-10.0, -250.0)
	draw_colored_polygon(FlatProps.sliver(Vector2(-40.0, -90.0), mast_top, 14.0), HULL.darkened(0.2))
	var flap := sin(_time * TAU * SAIL_FLAP_SPEED) * SAIL_FLAP
	draw_colored_polygon(PackedVector2Array([
		mast_top + Vector2(0.0, 14.0), mast_top + Vector2(96.0 + flap, 40.0),
		mast_top + Vector2(70.0 + flap * 0.5, 66.0), mast_top + Vector2(-8.0, 90.0),
	]), SAIL)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-210.0, -82.0), Vector2(170.0, -136.0), Vector2(210.0, -110.0), Vector2(-200.0, -60.0),
	]), DECK)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-220.0, -64.0), Vector2(210.0, -112.0), Vector2(250.0, -128.0), Vector2(200.0, -20.0),
		Vector2(140.0, 0.0), Vector2(-180.0, 0.0),
	]), HULL)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-196.0, -26.0), Vector2(220.0, -64.0), Vector2(200.0, -20.0), Vector2(140.0, 0.0), Vector2(-180.0, 0.0),
	]), HULL.darkened(0.2))
	draw_colored_polygon(PackedVector2Array([
		Vector2(10.0, -70.0), Vector2(56.0, -88.0), Vector2(80.0, -60.0), Vector2(50.0, -36.0), Vector2(16.0, -44.0),
	]), UiPalette.VOID)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-240.0, -14.0), Vector2(-80.0, -10.0), Vector2(-60.0, 14.0), Vector2(-240.0, 14.0),
	]), SEA)
	var chest := Vector2(300.0, 4.0)
	draw_rect(Rect2(chest + Vector2(-30.0, -30.0), Vector2(60.0, 30.0)), CHEST)
	draw_colored_polygon(PackedVector2Array([
		chest + Vector2(-32.0, -30.0), chest + Vector2(-26.0, -46.0), chest + Vector2(26.0, -46.0), chest + Vector2(32.0, -30.0),
	]), CHEST.darkened(0.2))
	draw_rect(Rect2(chest + Vector2(-7.0, -36.0), Vector2(14.0, 14.0)), GOLD)
