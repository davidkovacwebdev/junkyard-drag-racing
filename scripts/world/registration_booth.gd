@tool
class_name RegistrationBooth
extends Obstacle
## The drag strip's sign-up booth on the world map: a red shack under a tin
## roof, a checkered awning over the ticket window (with an OPEN / SHUT card
## hung in it), an ENTRY board on the roof, a checkered flag on a leaning pole
## and a stack of spare tyres by the door. Flat polygons only.
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

## The race DragStripMenu (this booth's interior_scene) sends the player into.
@export_file("*.tscn") var race_scene_path: String = "res://scenes/race/race_drag_strip.tscn"
@export var wall_color: Color = Color(0.62, 0.24, 0.2, 1)
@export var roof_color: Color = UiPalette.STEEL_SHADE
@export var trim_color: Color = UiPalette.TRIM_OFF_WHITE
@export var door_color: Color = Color(0.4, 0.29, 0.19, 1)

const ROOF_H := 24.0
const ROOF_OVERHANG := 12.0
const SHADE_W := 16.0
const AWNING_H := 14.0
const AWNING_CELLS := 5
const WINDOW := Rect2(-72.0, -16.0, 70.0, 40.0)
const DOOR_W := 42.0
const DOOR_H := 62.0
const SIGN_SIZE := Vector2(92.0, 26.0)

const FLAG_POLE_LENGTH := 150.0
const FLAG_CELL := 16.0
## Cells along the pole (the hoisted short side).
const FLAG_ALONG := 2
## Cells outward from the pole (the long side, flying free).
const FLAG_OUT := 3

const CHECKER_LIGHT := Color(0.86, 0.84, 0.78)
const SIGN_BOARD := Color(0.85, 0.66, 0.12)

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
	RaceProgression.menu_race_scene = race_scene_path
	RaceProgression.menu_venue_name = display_name
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
	FlatProps.draw_tire_stack(self, Vector2(half.x + 18.0, half.y), 2, 14.0, 8.0)

func _draw_shadow(half: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(-half.x + 8.0, half.y - 10.0), Vector2(half.x + 6.0, half.y - 10.0),
		Vector2(half.x + 20.0, half.y + 8.0), Vector2(-half.x + 20.0, half.y + 8.0),
	]), UiPalette.SHADOW)

func _draw_walls(half: Vector2) -> void:
	var top := -half.y + ROOF_H
	draw_rect(Rect2(-half.x, top, size.x, half.y - top), wall_color)
	draw_rect(Rect2(half.x - SHADE_W, top, SHADE_W, half.y - top), wall_color.darkened(0.2))

## The ticket window: framed glass with a card that reads OPEN or SHUT.
func _draw_window() -> void:
	draw_rect(WINDOW.grow(4.0), trim_color)
	draw_rect(WINDOW, UiPalette.GLASS)
	var open := _drawn_open
	var card := Rect2(WINDOW.get_center().x + 4.0, WINDOW.position.y + 10.0, 30.0, 16.0)
	draw_rect(card, CHECKER_LIGHT if open else UiPalette.DANGER_RED)
	draw_string(ThemeDB.fallback_font, card.position + Vector2(0.0, 12.0), "OPEN" if open else "SHUT",
			HORIZONTAL_ALIGNMENT_CENTER, card.size.x, 9, UiPalette.INK if open else CHECKER_LIGHT)

func _draw_door(half: Vector2) -> void:
	var door := Rect2(half.x - SHADE_W - DOOR_W - 10.0, half.y - DOOR_H, DOOR_W, DOOR_H)
	draw_rect(door, door_color)
	draw_rect(Rect2(door.end.x - 12.0, door.position.y + DOOR_H * 0.5, 5.0, 5.0), trim_color)

## Checkered cloth under the roof edge.
func _draw_awning(half: Vector2) -> void:
	var top := -half.y + ROOF_H
	var left := WINDOW.position.x - 14.0
	var cell_w := (WINDOW.size.x + 28.0) / float(AWNING_CELLS)
	for i in AWNING_CELLS:
		draw_rect(Rect2(left + i * cell_w, top, cell_w, AWNING_H), CHECKER_LIGHT if i % 2 == 0 else UiPalette.INK)

## Tin roof, slightly out of level.
func _draw_roof(half: Vector2) -> void:
	var left := -half.x - ROOF_OVERHANG
	var right := half.x + ROOF_OVERHANG
	var top := -half.y
	var droop := 3.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(left, top), Vector2(right, top + droop),
		Vector2(right, top + ROOF_H + droop), Vector2(left, top + ROOF_H),
	]), roof_color)

## ENTRY board propped on two stubby posts on the roof.
func _draw_sign(half: Vector2) -> void:
	var board := Rect2(Vector2(-66.0, -half.y - SIGN_SIZE.y - 12.0), SIGN_SIZE)
	for post_x: float in [board.position.x + 12.0, board.end.x - 16.0]:
		draw_rect(Rect2(post_x, board.end.y, 5.0, 14.0), UiPalette.POST_GREY)
	var pivot := board.get_center()
	draw_set_transform(pivot, deg_to_rad(2.0), Vector2.ONE)
	var local := Rect2(board.position - pivot, board.size)
	draw_rect(local, SIGN_BOARD)
	draw_string(ThemeDB.fallback_font, local.position + Vector2(0.0, 18.0), "ENTRY",
			HORIZONTAL_ALIGNMENT_CENTER, local.size.x, 16, UiPalette.INK)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Pole leaning up-and-right off the roof's right corner with a checkered cloth
## off its tip. Drawn in a rotated transform whose +x runs along the pole and +y
## points away from it.
func _draw_flag(half: Vector2) -> void:
	draw_set_transform(Vector2(half.x - 6.0, -half.y + 4.0), -PI / 4.0, Vector2.ONE)
	draw_colored_polygon(FlatProps.sliver(Vector2.ZERO, Vector2(FLAG_POLE_LENGTH, 0.0), 5.0), UiPalette.STEEL_BASE)
	var hoist := FLAG_POLE_LENGTH - FLAG_ALONG * FLAG_CELL
	for along in FLAG_ALONG:
		for out in FLAG_OUT:
			draw_rect(Rect2(hoist + along * FLAG_CELL, out * FLAG_CELL, FLAG_CELL, FLAG_CELL),
					CHECKER_LIGHT if (along + out) % 2 == 0 else UiPalette.INK)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
