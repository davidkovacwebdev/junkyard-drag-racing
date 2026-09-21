class_name RegistrationBooth
extends Obstacle
## The drag strip's sign-up booth on the world map: a small building with a
## checkered awning, a "REGISTRATION" sign, and a racing flag on a pole
## leaning diagonally up.
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

@export var wall_color: Color = Color(0.74, 0.24, 0.2, 1)
@export var roof_color: Color = Color(0.27, 0.27, 0.31, 1)
@export var trim_color: Color = Color(0.96, 0.93, 0.85, 1)
@export var window_color: Color = Color(0.62, 0.79, 0.86, 1)
@export var door_color: Color = Color(0.33, 0.22, 0.16, 1)

const ROOF_H := 24.0
const ROOF_OVERHANG := 10.0
const SKIRT_H := 10.0
const AWNING_H := 14.0
const AWNING_CELLS := 12
const WINDOW_H := 32.0
const WINDOW_Y := -8.0
const DOOR_W := 50.0
const DOOR_H := 44.0

const FLAG_POLE_LENGTH := 150.0
## How far down the pole from the tip the cloth's top edge sits.
const FLAG_DROP := 8.0
const FLAG_CELL := 15.0
## Cells measured along the pole (the short side, attached to the pole).
const FLAG_ALONG := 3
## Cells measured outward from the pole (the long side, flying free).
const FLAG_OUT := 4

const POLE_COLOR := Color(0.72, 0.72, 0.75, 1)
const CHECKER_LIGHT := Color(1, 1, 1, 1)
const CHECKER_DARK := Color(0.08, 0.08, 0.09, 1)

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

func _draw() -> void:
	var half := size / 2.0
	_draw_walls(half)
	_draw_windows_and_door(half)
	_draw_awning(half)
	_draw_roof(half)
	_draw_flag(half)

func _draw_walls(half: Vector2) -> void:
	draw_rect(Rect2(-half, size), wall_color)
	# Darker skirting band so the building reads as resting on the ground.
	draw_rect(Rect2(-half.x, half.y - SKIRT_H, size.x, SKIRT_H), wall_color.darkened(0.28))

## Two windows across the front with the door centred underneath them.
func _draw_windows_and_door(half: Vector2) -> void:
	var side_margin := 12.0
	var gap := 12.0
	var window_w := (size.x - side_margin * 2.0 - gap) / 2.0
	_draw_window(Rect2(-half.x + side_margin, WINDOW_Y, window_w, WINDOW_H))
	_draw_window(Rect2(half.x - side_margin - window_w, WINDOW_Y, window_w, WINDOW_H))

	var door := Rect2(-DOOR_W / 2.0, half.y - DOOR_H, DOOR_W, DOOR_H)
	draw_rect(door.grow(3.0), trim_color)
	draw_rect(door, door_color)
	draw_circle(Vector2(door.end.x - 9.0, door.position.y + DOOR_H * 0.5), 3.0, trim_color)
	# Entry step spilling toward the track.
	draw_rect(Rect2(-DOOR_W / 2.0 - 12.0, half.y, DOOR_W + 24.0, 8.0), trim_color.darkened(0.4))

func _draw_window(rect: Rect2) -> void:
	draw_rect(rect.grow(3.0), trim_color)
	draw_rect(rect, window_color)
	var center := rect.get_center()
	draw_line(Vector2(center.x, rect.position.y), Vector2(center.x, rect.end.y), trim_color, 3.0)
	draw_line(Vector2(rect.position.x, center.y), Vector2(rect.end.x, center.y), trim_color, 3.0)

## Checkered race-flag band tucked under the roof.
func _draw_awning(half: Vector2) -> void:
	var top := -half.y + ROOF_H
	var cell_w := size.x / float(AWNING_CELLS)
	for i in AWNING_CELLS:
		var color: Color = CHECKER_LIGHT if i % 2 == 0 else CHECKER_DARK
		draw_rect(Rect2(-half.x + i * cell_w, top, cell_w, AWNING_H), color)

func _draw_roof(half: Vector2) -> void:
	var width := size.x + ROOF_OVERHANG * 2.0
	draw_rect(Rect2(-half.x - ROOF_OVERHANG, -half.y, width, ROOF_H), roof_color)
	# Cream fascia along the roof's leading edge.
	draw_rect(Rect2(-half.x - ROOF_OVERHANG, -half.y + ROOF_H - 4.0, width, 4.0), trim_color)

## Pole leaning up-and-right off the roof's left corner, with a checkered
## cloth flying off its upper end. Everything is drawn inside a rotated
## transform whose +x axis runs along the pole, so the cloth leans with the
## pole instead of standing upright; the pole tip stays visible past it.
## Pole leaning up-and-right off the roof's left corner, with a checkered
## cloth flying off it. Everything is drawn inside a rotated transform whose
## +x axis runs along the pole and +y points away from it, so the cloth's
## long side extends outward from the pole and its short side is hoisted
## along the pole.
func _draw_flag(half: Vector2) -> void:
	var pole_base := Vector2(-half.x + 12.0, -half.y)
	# -45°: local +x runs up-and-right along the pole, local +y is the
	# perpendicular the cloth flies out along.
	var lean := -PI / 4.0

	draw_set_transform(pole_base, lean, Vector2.ONE)

	draw_line(Vector2.ZERO, Vector2(FLAG_POLE_LENGTH, 0.0), POLE_COLOR, 5.0)
	draw_circle(Vector2(FLAG_POLE_LENGTH, 0.0), 6.0, trim_color)

	# Cloth's hoist edge starts FLAG_DROP down the pole from the tip.
	var hoist := FLAG_POLE_LENGTH - FLAG_DROP - FLAG_ALONG * FLAG_CELL
	for along in FLAG_ALONG:
		for out in FLAG_OUT:
			var color: Color = CHECKER_LIGHT if (along + out) % 2 == 0 else CHECKER_DARK
			draw_rect(Rect2(hoist + along * FLAG_CELL, out * FLAG_CELL, FLAG_CELL, FLAG_CELL), color)
	var cloth := Rect2(hoist, 0.0, FLAG_ALONG * FLAG_CELL, FLAG_OUT * FLAG_CELL)
	draw_rect(cloth, CHECKER_DARK, false, 2.0)

	# Restore the transform so nothing after this gets rotated by accident.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
