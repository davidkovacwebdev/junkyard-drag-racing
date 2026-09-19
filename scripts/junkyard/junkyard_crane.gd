class_name JunkyardCrane
extends Node2D
## The junkyard's scrap crane: crawler tracks, a turret, a lattice mast and a
## boom reaching out over the heap with a claw hanging from a trolley on it.
##
## Visual only for now — nothing here grabs anything yet. It's in place so the
## "collect the heap" feature has something to hang off later, which is why
## every dimension is an export: the claw has to hover over wherever the pile
## actually is.
##
## Origin is the tracks' ground contact and everything is drawn above it, so it
## Y-sorts against the car like every other prop. The claw swings a little on
## its cables so the yard doesn't look frozen; set `sway_amplitude` to 0 to
## freeze it.

@export var track_width: float = 300.0
@export var track_height: float = 56.0
## Ground to the boom (the boom sits at the top of the mast).
@export var mast_height: float = 700.0
@export var mast_width: float = 66.0
## How far the boom reaches out past the mast in each direction (-x is where
## the heap is).
@export var boom_reach: float = 620.0
@export var boom_tail: float = 190.0
@export var boom_height: float = 40.0
## Where along the boom the trolley (and so the claw) hangs.
@export var trolley_offset: float = 520.0
@export var hoist_length: float = 175.0
@export var sway_amplitude: float = 0.06
@export var sway_speed: float = 0.7

@export_group("Colors")
@export var steel_color: Color = Color(0.74, 0.62, 0.22, 1)
@export var rust_color: Color = Color(0.55, 0.3, 0.16, 1)
@export var dark_color: Color = Color(0.2, 0.2, 0.22, 1)
@export var cable_color: Color = Color(0.13, 0.13, 0.14, 1)
@export var trim_color: Color = Color(0.87, 0.84, 0.72, 1)

const TURRET_H := 74.0
const RAIL := 8.0
const LATTICE_STEP := 62.0
const BRACE_W := 4.0
const PYLON_H := 120.0
## How far below the claw block the jaws reach.
const JAW_DROP := 52.0

var _time: float = 0.0
var _sway: float = 0.0

func _process(delta: float) -> void:
	if sway_amplitude <= 0.0:
		return
	_time += delta
	_sway = sin(_time * sway_speed) * sway_amplitude
	queue_redraw()

func _tracks_top() -> float:
	return -track_height

func _turret_top() -> float:
	return -track_height - TURRET_H

func _boom_y() -> float:
	return -mast_height

func _draw() -> void:
	_draw_tracks()
	_draw_turret()
	_draw_mast()
	_draw_boom()
	_draw_hoist()

func _draw_tracks() -> void:
	var half := track_width * 0.5
	draw_rect(Rect2(-half, -track_height, track_width, track_height), dark_color)
	var plates := int(track_width / 26.0)
	for i in plates + 1:
		var x := -half + 6.0 + float(i) * 26.0
		if x > half - 4.0:
			break
		draw_line(Vector2(x, -track_height + 7.0), Vector2(x, -7.0),
				Color(1, 1, 1, 0.06), 3.0)
	var wheel_r := track_height * 0.28
	draw_circle(Vector2(-half + wheel_r + 6.0, -track_height * 0.5), wheel_r, rust_color)
	draw_circle(Vector2(half - wheel_r - 6.0, -track_height * 0.5), wheel_r, rust_color)

func _draw_turret() -> void:
	var half := track_width * 0.34
	var bottom := _tracks_top()
	var top := _turret_top()
	draw_rect(Rect2(-half, top, half * 2.0, bottom - top), steel_color)
	# cab window on the side that faces down the yard
	draw_rect(Rect2(-half + 12.0, top + 14.0, half * 0.9, TURRET_H - 30.0), dark_color)
	draw_rect(Rect2(-half + 12.0, top + 14.0, half * 0.9, TURRET_H - 30.0), trim_color, false, 3.0)
	# exhaust stack
	draw_rect(Rect2(half - 26.0, top - 34.0, 12.0, 34.0), rust_color)

func _draw_mast() -> void:
	var top := _boom_y()
	var bottom := _turret_top()
	var half := mast_width * 0.5
	for x in PackedFloat32Array([-half, half]):
		draw_rect(Rect2(x - RAIL * 0.5, top, RAIL, bottom - top), steel_color)
	var y := bottom
	var flip := false
	while y - LATTICE_STEP > top:
		if flip:
			draw_line(Vector2(-half, y), Vector2(half, y - LATTICE_STEP),
					steel_color.darkened(0.3), BRACE_W)
		else:
			draw_line(Vector2(half, y), Vector2(-half, y - LATTICE_STEP),
					steel_color.darkened(0.3), BRACE_W)
		flip = not flip
		y -= LATTICE_STEP

func _draw_boom() -> void:
	var y := _boom_y()
	var left := -boom_reach
	var right := boom_tail
	var top := y - boom_height * 0.5
	var bottom := y + boom_height * 0.5

	# pylon above the mast with the two tie cables holding the boom up
	draw_rect(Rect2(-RAIL, y - PYLON_H, RAIL * 2.0, PYLON_H), steel_color)
	draw_line(Vector2(0.0, y - PYLON_H + 2.0), Vector2(left + 30.0, top), cable_color, 3.0)
	draw_line(Vector2(0.0, y - PYLON_H + 2.0), Vector2(right - 12.0, top), cable_color, 3.0)

	draw_rect(Rect2(left, top, right - left, RAIL), steel_color)
	draw_rect(Rect2(left, bottom - RAIL, right - left, RAIL), steel_color)
	var x := left
	var flip := false
	while x + LATTICE_STEP < right:
		if flip:
			draw_line(Vector2(x, bottom - RAIL), Vector2(x + LATTICE_STEP, top + RAIL),
					steel_color.darkened(0.3), BRACE_W)
		else:
			draw_line(Vector2(x, top + RAIL), Vector2(x + LATTICE_STEP, bottom - RAIL),
					steel_color.darkened(0.3), BRACE_W)
		flip = not flip
		x += LATTICE_STEP

	# counterweight block hanging off the tail
	draw_rect(Rect2(right - 62.0, top - 26.0, 62.0, boom_height + 52.0), rust_color)
	draw_rect(Rect2(right - 62.0, top - 26.0, 62.0, boom_height + 52.0), dark_color, false, 3.0)

func _draw_hoist() -> void:
	var y := _boom_y()
	var anchor := Vector2(-trolley_offset, y + boom_height * 0.5)
	# the trolley rides the top chord and carries the sheave below the boom
	draw_rect(Rect2(anchor.x - 44.0, y - boom_height * 0.5 - 16.0, 88.0, 20.0),
			steel_color.darkened(0.15))
	draw_rect(Rect2(anchor.x - 34.0, anchor.y - 4.0, 68.0, 22.0), dark_color)

	var claw := anchor + Vector2(sin(_sway), cos(_sway)) * hoist_length
	draw_line(anchor + Vector2(-14.0, 16.0), claw + Vector2(-9.0, -6.0), cable_color, 3.0)
	draw_line(anchor + Vector2(14.0, 16.0), claw + Vector2(9.0, -6.0), cable_color, 3.0)

	# jaws swing with the cables, so the claw hangs like a pendulum
	draw_set_transform(claw, _sway, Vector2.ONE)
	draw_rect(Rect2(-16.0, -14.0, 32.0, 24.0), dark_color)
	var steel := steel_color.darkened(0.25)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-16.0, 6.0), Vector2(-4.0, 10.0),
		Vector2(-16.0, JAW_DROP), Vector2(-32.0, JAW_DROP - 10.0),
	]), steel)
	draw_colored_polygon(PackedVector2Array([
		Vector2(16.0, 6.0), Vector2(4.0, 10.0),
		Vector2(16.0, JAW_DROP), Vector2(32.0, JAW_DROP - 10.0),
	]), steel)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
