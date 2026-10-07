@tool
class_name DerbyPit
extends Node2D
## The demolition derby on the world map: an oval mud pit ringed with tyre
## stacks (open at the front), two crushed cars left in the mud, a floodlight
## at the back and a DERBY board. The mud is drawn on this node, which sits
## below the car; the tyre stacks, wrecks, floodlight and board are standing
## pieces at their own ground points so they Y-sort against the car, and only
## the foot of each is solid.
##
## @tool so it's visible in the editor.

const MUD := Color(0.42, 0.32, 0.22)
const MUD_SHADE := Color(0.34, 0.26, 0.18)
const BOARD := Color(0.85, 0.66, 0.12)
const LAMP := Color(0.96, 0.9, 0.62)
const WRECK_PAINTS: Array[Color] = [Color(0.30, 0.40, 0.55), Color(0.62, 0.22, 0.18)]

const PIT_RADIUS := Vector2(560.0, 300.0)
## Tyre stacks around the rim, skipping the front where cars drive in.
const RIM_STACKS := 9
const RIM_GAP_ANGLE := 0.7
const STACK_RADIUS := 34.0
const STACK_TIRES := 3
const STACK_TIRE_HEIGHT := 16.0
const WRECKS: Array[Rect2] = [Rect2(-260.0, -80.0, 170.0, 80.0), Rect2(120.0, 20.0, 190.0, 84.0)]
const POLE_BASE := Vector2(420.0, -330.0)
const POLE_HEIGHT := 320.0
const BOARD_RECT := Rect2(-170.0, -560.0, 220.0, 70.0)
const BOARD_POST_HEIGHT := 60.0

var _art := TriangleBatch.new()

func _ready() -> void:
	for base in _stack_bases():
		FlatProps.add_standing_piece(self, base, _draw_stack.bind(base))
	for i in WRECKS.size():
		FlatProps.add_standing_piece(self, Vector2(WRECKS[i].get_center().x, WRECKS[i].end.y), _draw_wreck.bind(i))
	FlatProps.add_standing_piece(self, POLE_BASE, _draw_floodlight)
	FlatProps.add_standing_piece(self, Vector2(BOARD_RECT.get_center().x, BOARD_RECT.end.y + BOARD_POST_HEIGHT), _draw_board)
	if Engine.is_editor_hint():
		return
	for base in _stack_bases():
		RoundedRectShape.add_solid(self, Rect2(base.x - STACK_RADIUS, base.y - 16.0, STACK_RADIUS * 2.0, 24.0))
	for wreck in WRECKS:
		RoundedRectShape.add_solid(self, Rect2(wreck.position.x, wreck.end.y - 30.0, wreck.size.x, 30.0))
	RoundedRectShape.add_solid(self, Rect2(BOARD_RECT.position.x, BOARD_RECT.end.y + BOARD_POST_HEIGHT - 16.0, BOARD_RECT.size.x, 16.0))
	RoundedRectShape.add_solid(self, Rect2(POLE_BASE.x - 16.0, POLE_BASE.y - 14.0, 32.0, 18.0))

func _draw() -> void:
	_art.clear()
	_art.draw_colored_polygon(FlatProps.octagon(Vector2.ZERO, PIT_RADIUS.x, PIT_RADIUS.y), MUD)
	_art.draw_colored_polygon(FlatProps.octagon(Vector2(40.0, 60.0), PIT_RADIUS.x * 0.8, PIT_RADIUS.y * 0.7), MUD_SHADE)
	_art.commit(self)
	_art.clear()

func _draw_stack(_canvas: Node2D, art: TriangleBatch, base: Vector2) -> void:
	FlatProps.draw_tire_stack(art, base, STACK_TIRES, STACK_RADIUS, STACK_TIRE_HEIGHT)

func _draw_wreck(_canvas: Node2D, art: TriangleBatch, index: int) -> void:
	var wreck := WRECKS[index]
	var paint := WRECK_PAINTS[index]
	art.draw_rect(wreck, paint)
	art.draw_rect(Rect2(wreck.position.x, wreck.end.y - wreck.size.y * 0.3, wreck.size.x, wreck.size.y * 0.3), paint.darkened(0.22))
	art.draw_colored_polygon(FlatProps.sliver(wreck.position + Vector2(18.0, 26.0),
			Vector2(wreck.end.x - 18.0, wreck.position.y + 18.0), 14.0), UiPalette.GLASS)

func _draw_floodlight(_canvas: Node2D, art: TriangleBatch) -> void:
	art.draw_rect(Rect2(POLE_BASE.x - 8.0, POLE_BASE.y - POLE_HEIGHT, 16.0, POLE_HEIGHT), UiPalette.POST_GREY)
	art.draw_rect(Rect2(POLE_BASE.x - 60.0, POLE_BASE.y - POLE_HEIGHT - 44.0, 120.0, 48.0), UiPalette.STEEL_DARK)
	art.draw_rect(Rect2(POLE_BASE.x - 50.0, POLE_BASE.y - POLE_HEIGHT - 36.0, 100.0, 26.0), LAMP)

func _draw_board(canvas: Node2D, art: TriangleBatch) -> void:
	for post_x: float in [BOARD_RECT.position.x + 30.0, BOARD_RECT.end.x - 38.0]:
		art.draw_rect(Rect2(post_x, BOARD_RECT.end.y, 8.0, BOARD_POST_HEIGHT), UiPalette.POST_GREY)
	art.draw_rect(BOARD_RECT, BOARD)
	art.draw_rect(Rect2(BOARD_RECT.end.x - 12.0, BOARD_RECT.position.y, 12.0, BOARD_RECT.size.y), BOARD.darkened(0.2))
	art.commit(canvas)
	art.clear()
	canvas.draw_string(ThemeDB.fallback_font, BOARD_RECT.position + Vector2(0.0, 50.0), "DERBY",
			HORIZONTAL_ALIGNMENT_CENTER, BOARD_RECT.size.x - 12.0, 44, UiPalette.DANGER_RED)

## Evenly round the rim, leaving the front (bottom) open.
func _stack_bases() -> Array[Vector2]:
	var bases: Array[Vector2] = []
	var start := PI * 0.5 + RIM_GAP_ANGLE
	var span := TAU - RIM_GAP_ANGLE * 2.0
	for i in RIM_STACKS:
		var angle := start + span * float(i) / float(RIM_STACKS - 1)
		bases.append(Vector2(cos(angle) * (PIT_RADIUS.x + 20.0), sin(angle) * (PIT_RADIUS.y + 20.0)))
	return bases
