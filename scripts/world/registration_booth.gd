@tool
class_name RegistrationBooth
extends Obstacle
## The drag strip's sign-up booth on the world map: a patched red shack under a
## corrugated roof, a checkered awning over the ticket window (with an OPEN /
## SHUT card hung in it), an ENTRY board on the roof, a checkered flag on a
## leaning pole and a stack of spare tyres by the door. Flat polygons only.
##
## @tool so it shows up in the 2D editor (always drawn open there).
##
## Extends Obstacle so it keeps the duck-typed `display_name` / `interior_scene`
## interaction the PlayerCar looks for — but this scene ships no `ColorRect`,
## it draws itself in _draw() instead. Obstacle._ready() tolerates the missing
## rect and still sizes the collision shape from `size`.
##
## Only staffed 8 AM to 8 PM. Outside those hours it overrides the default
## "Press space to enter" prompt with a red closed notice (get_interact_prompt/
## get_interact_prompt_color, both duck-typed hooks PlayerCar's tooltip reads)
## and implements interact() itself so it can refuse to switch scenes — the
## default Obstacle/PlayerCar activation path has no refusal hook at all, only
## a target with its own interact() gets to say no.

## When the booth is open, local clock hours [OPEN_HOUR, CLOSE_HOUR).
const OPEN_HOUR := 8.0
const CLOSE_HOUR := 20.0  ## 8 PM.
const CLOSED_MESSAGE := "Closes at 8PM, open at 8AM"
const CLOSED_COLOR := Color(0.95, 0.2, 0.2, 1)
const OPEN_COLOR := Color(1, 1, 1, 1)

@export var wall_color: Color = Color(0.62, 0.24, 0.2, 1)
@export var roof_color: Color = UiPalette.STEEL_SHADE
@export var trim_color: Color = UiPalette.TRIM_OFF_WHITE
@export var door_color: Color = Color(0.4, 0.29, 0.19, 1)

const ROOF_H := 24.0
const ROOF_OVERHANG := 12.0
const ROOF_RIB_W := 8.0
const SKIRT_H := 8.0
const SIDING_GAP := 14.0
const SHADE_W := 16.0
const AWNING_H := 14.0
const AWNING_CELLS := 10
const WINDOW := Rect2(-72.0, -16.0, 70.0, 40.0)
const DOOR_W := 42.0
const DOOR_H := 62.0
const SIGN_SIZE := Vector2(92.0, 26.0)

const FLAG_POLE_LENGTH := 150.0
const FLAG_CELL := 14.0
## Cells along the pole (the hoisted short side).
const FLAG_ALONG := 3
## Cells outward from the pole (the long side, flying free).
const FLAG_OUT := 4
const FLAG_WAVE := 4.0

const CHECKER_LIGHT := Color(0.86, 0.84, 0.78)
const SIGN_BOARD := Color(0.85, 0.66, 0.12)
const RUST := Color(0.55, 0.28, 0.14, 0.6)

func _is_open() -> bool:
	var hour := DayNightCycle.get_hour()
	return hour >= OPEN_HOUR and hour < CLOSE_HOUR

## Overrides PlayerCar's default prompt while closed; empty string when open
## falls back to the default "Drag Strip: Press space to enter".
func get_interact_prompt() -> String:
	return "" if _is_open() else CLOSED_MESSAGE

func get_interact_prompt_color() -> Color:
	return OPEN_COLOR if _is_open() else CLOSED_COLOR

## Owns activation outright (rather than letting PlayerCar's default
## interior_scene switch run unconditionally) so it can refuse entry
## overnight.
func interact(_actor: Node = null) -> void:
	if not _is_open():
		return
	print(display_name)
	if interior_scene is PackedScene:
		get_tree().change_scene_to_packed(interior_scene)

var _drawn_open := false

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _is_open() != _drawn_open:
		queue_redraw()

func _draw() -> void:
	# DayNightCycle is an autoload, which doesn't exist in the editor.
	_drawn_open = Engine.is_editor_hint() or _is_open()
	var half := size / 2.0
	_draw_shadow(half)
	_draw_walls(half)
	_draw_window()
	_draw_door(half)
	_draw_awning(half)
	_draw_roof(half)
	_draw_sign(half)
	_draw_flag(half)
	FlatProps.draw_tire_stack(self, Vector2(half.x + 16.0, half.y - 4.0), 2, 14.0, 8.0)
	FlatProps.draw_tire_stack(self, Vector2(half.x + 38.0, half.y + 6.0), 1, 14.0, 8.0)

func _draw_shadow(half: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(-half.x + 8.0, half.y - 10.0), Vector2(half.x + 6.0, half.y - 10.0),
		Vector2(half.x + 20.0, half.y + 8.0), Vector2(-half.x + 20.0, half.y + 8.0),
	]), UiPalette.SHADOW)

## Red board walls: siding seams, a shaded right side, a darker skirt and a rust
## bloom where the rain splashes up.
func _draw_walls(half: Vector2) -> void:
	var top := -half.y + ROOF_H
	draw_rect(Rect2(-half.x, top, size.x, half.y - top), wall_color)
	var seam_y := top + SIDING_GAP
	while seam_y < half.y - SKIRT_H:
		draw_rect(Rect2(-half.x, seam_y, size.x, 2.0), wall_color.darkened(0.14))
		seam_y += SIDING_GAP
	draw_colored_polygon(PackedVector2Array([
		Vector2(-half.x + 6.0, half.y - SKIRT_H), Vector2(-half.x + 18.0, half.y - 30.0),
		Vector2(-half.x + 34.0, half.y - 22.0), Vector2(-half.x + 40.0, half.y - SKIRT_H),
	]), RUST)
	draw_rect(Rect2(half.x - SHADE_W, top, SHADE_W, half.y - top), wall_color.darkened(0.2))
	draw_rect(Rect2(-half.x, half.y - SKIRT_H, size.x, SKIRT_H), wall_color.darkened(0.32))

## The ticket window: glass with one highlight sliver, a plank counter under it
## and a card that reads OPEN or CLOSED with the booth's hours.
func _draw_window() -> void:
	var frame := WINDOW.grow(4.0)
	draw_rect(frame, trim_color)
	draw_rect(Rect2(frame.end.x - 4.0, frame.position.y, 4.0, frame.size.y), trim_color.darkened(0.2))
	draw_rect(WINDOW, UiPalette.GLASS)
	draw_rect(Rect2(WINDOW.get_center().x - 1.5, WINDOW.position.y, 3.0, WINDOW.size.y), trim_color.darkened(0.2))
	draw_colored_polygon(PackedVector2Array([
		WINDOW.position + Vector2(5.0, 4.0), WINDOW.position + Vector2(13.0, 4.0),
		WINDOW.position + Vector2(9.0, 20.0), WINDOW.position + Vector2(3.0, 20.0),
	]), UiPalette.GLASS.lightened(0.25))

	var counter := Rect2(frame.position.x - 6.0, frame.end.y, frame.size.x + 12.0, 6.0)
	draw_rect(counter, UiPalette.SURFACE_BASE)
	draw_rect(Rect2(counter.position.x, counter.end.y, counter.size.x, 4.0), UiPalette.SURFACE_DARK)

	var open := _drawn_open
	var card := Rect2(WINDOW.get_center().x + 6.0, WINDOW.position.y + 12.0, 28.0, 14.0)
	draw_rect(Rect2(card.get_center().x - 0.5, WINDOW.position.y, 1.0, card.position.y - WINDOW.position.y), UiPalette.INK)
	draw_rect(card, CHECKER_LIGHT if open else UiPalette.DANGER_RED)
	draw_string(ThemeDB.fallback_font, card.position + Vector2(0.0, 11.0), "OPEN" if open else "SHUT",
			HORIZONTAL_ALIGNMENT_CENTER, card.size.x, 9, UiPalette.INK if open else CHECKER_LIGHT)

func _draw_door(half: Vector2) -> void:
	var door := Rect2(half.x - SHADE_W - DOOR_W - 10.0, half.y - DOOR_H, DOOR_W, DOOR_H)
	draw_rect(door.grow_individual(4.0, 4.0, 4.0, 0.0), trim_color)
	draw_rect(door, door_color)
	draw_rect(Rect2(door.end.x - 8.0, door.position.y, 8.0, door.size.y), door_color.darkened(0.2))
	for plank in [1, 2]:
		draw_rect(Rect2(door.position.x + plank * DOOR_W / 3.0, door.position.y, 2.0, door.size.y), door_color.darkened(0.15))
	draw_rect(Rect2(door.position.x + 4.0, door.position.y + DOOR_H * 0.3, DOOR_W - 12.0, 4.0), door_color.lightened(0.12))
	draw_colored_polygon(FlatProps.octagon(Vector2(door.end.x - 13.0, door.position.y + DOOR_H * 0.55), 2.5, 2.5), trim_color)
	draw_rect(Rect2(door.position.x - 8.0, half.y - 2.0, DOOR_W + 16.0, 7.0), UiPalette.POST_GREY)

## Checkered cloth under the roof edge, each cell sagging a little at the
## bottom so it reads as fabric.
func _draw_awning(half: Vector2) -> void:
	var top := -half.y + ROOF_H
	var left := WINDOW.position.x - 14.0
	var cell_w := (WINDOW.size.x + 28.0) / float(AWNING_CELLS)
	for i in AWNING_CELLS:
		var x := left + i * cell_w
		var sag := 3.0 if i % 2 == 0 else 0.0
		var color := CHECKER_LIGHT if i % 2 == 0 else UiPalette.INK
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, top), Vector2(x + cell_w, top),
			Vector2(x + cell_w, top + AWNING_H + 3.0 - sag), Vector2(x, top + AWNING_H + sag),
		]), color)

## Corrugated sheet roof, slightly out of level, with a darker front lip.
func _draw_roof(half: Vector2) -> void:
	var left := -half.x - ROOF_OVERHANG
	var right := half.x + ROOF_OVERHANG
	var top := -half.y
	var droop := 3.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(left, top), Vector2(right, top + droop),
		Vector2(right, top + ROOF_H + droop), Vector2(left, top + ROOF_H),
	]), roof_color)
	var x := left + ROOF_RIB_W
	while x < right - ROOF_RIB_W:
		var y_shift := droop * inverse_lerp(left, right, x)
		draw_rect(Rect2(x, top + y_shift, ROOF_RIB_W * 0.5, ROOF_H - 5.0), UiPalette.STEEL_BASE)
		x += ROOF_RIB_W * 2.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(left, top + ROOF_H - 5.0), Vector2(right, top + ROOF_H - 5.0 + droop),
		Vector2(right, top + ROOF_H + droop), Vector2(left, top + ROOF_H),
	]), UiPalette.STEEL_DARK)
	draw_colored_polygon(PackedVector2Array([
		Vector2(left + 20.0, top + 6.0), Vector2(left + 44.0, top + 7.0),
		Vector2(left + 40.0, top + 16.0), Vector2(left + 18.0, top + 15.0),
	]), UiPalette.RUST)

## ENTRY board propped on two stubby posts on the roof.
func _draw_sign(half: Vector2) -> void:
	var board := Rect2(Vector2(-66.0, -half.y - SIGN_SIZE.y - 12.0), SIGN_SIZE)
	for post_x: float in [board.position.x + 12.0, board.end.x - 16.0]:
		draw_rect(Rect2(post_x, board.end.y, 4.0, 14.0), UiPalette.POST_GREY)
	var pivot := board.get_center()
	draw_set_transform(pivot, deg_to_rad(2.0), Vector2.ONE)
	var local := Rect2(board.position - pivot, board.size)
	draw_rect(Rect2(local.position + Vector2(3.0, 4.0), local.size), UiPalette.SHADOW)
	draw_rect(local, SIGN_BOARD)
	draw_rect(Rect2(local.end.x - 6.0, local.position.y, 6.0, local.size.y), SIGN_BOARD.darkened(0.2))
	draw_rect(Rect2(local.position.x, local.end.y - 4.0, local.size.x, 4.0), SIGN_BOARD.darkened(0.3))
	draw_string(ThemeDB.fallback_font, local.position + Vector2(0.0, 17.0), "ENTRY",
			HORIZONTAL_ALIGNMENT_CENTER, local.size.x - 6.0, 16, UiPalette.INK)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Pole leaning up-and-right off the roof's right corner with a checkered cloth
## rippling off it. Drawn in a rotated transform whose +x runs along the pole
## and +y points away from it.
func _draw_flag(half: Vector2) -> void:
	var pole_base := Vector2(half.x - 6.0, -half.y + 4.0)
	draw_set_transform(pole_base, -PI / 4.0, Vector2.ONE)
	draw_colored_polygon(FlatProps.sliver(Vector2.ZERO, Vector2(FLAG_POLE_LENGTH, 0.0), 5.0), UiPalette.STEEL_BASE)
	draw_colored_polygon(FlatProps.sliver(Vector2(0.0, 1.5), Vector2(FLAG_POLE_LENGTH, 1.5), 2.0), UiPalette.STEEL_DARK)
	draw_colored_polygon(FlatProps.octagon(Vector2(FLAG_POLE_LENGTH, 0.0), 5.0, 5.0), trim_color)

	var hoist := FLAG_POLE_LENGTH - 8.0 - FLAG_ALONG * FLAG_CELL
	for along in FLAG_ALONG:
		for out in FLAG_OUT:
			var color := CHECKER_LIGHT if (along + out) % 2 == 0 else UiPalette.INK
			draw_colored_polygon(PackedVector2Array([
				_flag_point(hoist, along, out), _flag_point(hoist, along + 1, out),
				_flag_point(hoist, along + 1, out + 1), _flag_point(hoist, along, out + 1),
			]), color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## A cloth grid corner, pushed along the pole by a ripple that grows toward the
## free end.
func _flag_point(hoist: float, along: int, out: int) -> Vector2:
	var ripple := sin(out * 1.4) * FLAG_WAVE * (float(out) / FLAG_OUT)
	return Vector2(hoist + along * FLAG_CELL + ripple, out * FLAG_CELL)
