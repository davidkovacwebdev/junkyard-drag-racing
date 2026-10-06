@tool
class_name OilRig
extends Node2D
## An offshore oil rig standing in the sea off the west coast: a steel deck on
## three legs, a crew block, the tall red derrick (its one feature) and a flare
## boom with a flickering flame on the end. It stands past the shallows the car
## can wade into, so it has no collision. Distant clanks carry over the water
## (`rig_clank`, via an AmbientCall in the scene). Origin on the waterline under
## the middle leg so it Y-sorts with the other coast pieces.

const STEEL := Color(0.52, 0.54, 0.56)
const CREW_BLOCK := UiPalette.TRIM_OFF_WHITE
const DERRICK := Color(0.64, 0.2, 0.17)
const SEA := Color("3a7c9a")
const FLAME_OUTER := Color(0.92, 0.46, 0.14)
const FLAME_INNER := UiPalette.ACCENT_YELLOW

const DECK_TOP := -170.0
const DECK_HEIGHT := 30.0
const DECK_HALF_WIDTH := 170.0
const LEG_X: Array[float] = [-120.0, 0.0, 120.0]
const FLARE_TIP := Vector2(290.0, -300.0)
const FLICKER_SPEED := 7.0

var _time := 0.0

func _ready() -> void:
	add_to_group(OffscreenCuller.GROUP)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	queue_redraw()

func _draw() -> void:
	var deck_bottom := DECK_TOP + DECK_HEIGHT
	for i in LEG_X.size():
		var leg_color := STEEL.darkened(0.3) if i == 1 else STEEL.darkened(0.15)
		draw_colored_polygon(FlatProps.sliver(Vector2(LEG_X[i], deck_bottom), Vector2(LEG_X[i] * 1.12, 8.0), 20.0), leg_color)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-170.0, -6.0), Vector2(170.0, -10.0), Vector2(176.0, 12.0), Vector2(-166.0, 14.0),
	]), SEA)
	draw_colored_polygon(FlatProps.sliver(Vector2(DECK_HALF_WIDTH - 20.0, DECK_TOP + 6.0), FLARE_TIP, 10.0), STEEL.darkened(0.15))
	draw_rect(Rect2(-DECK_HALF_WIDTH, DECK_TOP, DECK_HALF_WIDTH * 2.0, DECK_HEIGHT), STEEL)
	draw_rect(Rect2(-DECK_HALF_WIDTH, deck_bottom - 10.0, DECK_HALF_WIDTH * 2.0, 10.0), STEEL.darkened(0.2))
	draw_rect(Rect2(-150.0, DECK_TOP - 70.0, 120.0, 70.0), CREW_BLOCK)
	draw_colored_polygon(PackedVector2Array([
		Vector2(10.0, DECK_TOP), Vector2(54.0, DECK_TOP - 270.0), Vector2(70.0, DECK_TOP - 270.0), Vector2(114.0, DECK_TOP),
		Vector2(90.0, DECK_TOP), Vector2(62.0, DECK_TOP - 150.0), Vector2(34.0, DECK_TOP),
	]), DERRICK)
	var flicker := 1.0 + sin(_time * FLICKER_SPEED) * 0.15 + sin(_time * FLICKER_SPEED * 2.3) * 0.1
	draw_colored_polygon(FlatProps.flame(FLARE_TIP, 26.0, 60.0 * flicker), FLAME_OUTER)
	draw_colored_polygon(FlatProps.flame(FLARE_TIP + Vector2(0.0, -4.0), 13.0, 34.0 * flicker), FLAME_INNER)
