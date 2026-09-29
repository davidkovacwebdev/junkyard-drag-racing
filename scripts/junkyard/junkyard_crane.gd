@tool
class_name JunkyardCrane
extends Node2D
## The junkyard's scrap crane: crawler tracks, a turret, a lattice mast and a
## boom reaching out over the heap, with a claw hanging off a trolley on it.
##
## This is the *machine*, not a driver: it owns the artwork and the rigging —
## where the trolley sits along the boom, how much cable the winch has paid out,
## how far the jaws are apart, and how the whole claw trails behind the trolley
## like a pendulum. Nothing in here decides what the crane should do about it.
## Two things drive it:
##
##   - the idle sway on its own, for a crane parked in the yard as scenery,
##   - `CraneRig`, which subclasses this and puts the player in the cab.
##
## `trolley`, `hoist` and `jaw_open` are the machine's controls, and they are
## the whole interface: whoever is driving writes them (through
## `place_trolley()` / `place_hoist()` / `set_jaw_open()`, so the rail ends and
## the winch drum do the clamping, not every caller), and the drawing and the
## `Claw` child follow on their own. Anything that wants to hang off the jaws —
## a load, an effect — parents to `Claw` and rides the cable for free.
##
## Origin is the tracks' ground contact and everything is drawn above it, so it
## Y-sorts against the car like every other prop in the world.

@export var track_width: float = 300.0
@export var track_height: float = 56.0
## Ground to the boom (the boom sits at the top of the mast).
@export var mast_height: float = 700.0
@export var mast_width: float = 66.0
## How far the boom reaches out past the mast in each direction (the -x side is
## the one over the heap; the +x side carries the counterweight).
@export var boom_reach: float = 620.0
@export var boom_tail: float = 300.0
@export var boom_height: float = 40.0
## Where the trolley parks when nobody is driving. Also the trolley's and the
## claw's starting position.
@export var trolley_offset: float = 520.0
## How far the claw hangs below the boom when parked.
@export var hoist_length: float = 175.0
@export var sway_amplitude: float = 0.06
@export var sway_speed: float = 0.7

@export_group("Claw")
## The clamshell grab: two half-round shells hinged at the top that close into
## one ring. This is the ring's outer radius, so the shut claw is twice this
## tall, measured down from the hinge.
@export var claw_radius: float = 34.0
## How thick each shell is. Chunky on purpose: it's also the collision wall the
## pen's claw shoves junk with, and a thin shell lets pieces slip through it.
@export var claw_thickness: float = 12.0

@export_group("Rigging")
## How far the trolley may run along the boom, in this node's own x: negative
## is back toward the counterweight, positive is out over the heap. That the
## claw hangs at `-trolley` is the drawing's business, not the driver's — these
## are the rail ends either way.
@export var trolley_min: float = -270.0
@export var trolley_max: float = 560.0
## Shortest and longest the winch will pay the cable out.
@export var hoist_min: float = 80.0
@export var hoist_max: float = 900.0

@export_group("Colors")
@export var steel_color: Color = Color(0.74, 0.62, 0.22, 1)
@export var rust_color: Color = Color(0.55, 0.3, 0.16, 1)
@export var dark_color: Color = Color(0.2, 0.2, 0.22, 1)
@export var cable_color: Color = Color(0.13, 0.13, 0.14, 1)

const TURRET_H := 74.0
const RAIL := 14.0
const LATTICE_STEP := 124.0
const BRACE_W := 10.0
const PYLON_H := 120.0
## How far below the claw block the shells hang from their hinge.
const HINGE_DROP := 6.0
## How far a shell swings out from shut to wide open, radians. The shells are
## rigid and rotated by this about the hinge (see `shell_rotation()`).
const JAW_SWING := 1.0
## Segments in one half of the ring: half a 14-gon, the round-thing budget.
const SHELL_SEGMENTS := 7

var _time: float = 0.0
## Current pendulum angle of the claw, radians. Positive swings it toward +x.
var _sway: float = 0.0
## Where the trolley is along the boom, and how much cable is out. The claw
## hangs at `-trolley`, so +x moves on these put the claw further out over the
## heap. Start at the exported parked values; the driver owns them after that.
var trolley: float = 0.0
var hoist: float = 0.0
## The node riding at the jaws. Anything parented here follows the claw.
var _claw: Node2D = null

## How far apart the jaws are: 1.0 wide open, 0.0 shut. Only the drawing uses
## it, but it's what makes a grab read as a grab.
var jaw_open: float = 1.0:
	set = set_jaw_open

func _ready() -> void:
	trolley = trolley_offset
	hoist = hoist_length
	_claw = get_node_or_null("Claw") as Node2D
	if _claw == null:
		_claw = Node2D.new()
		_claw.name = "Claw"
		add_child(_claw)
	_update_claw()

func _process(delta: float) -> void:
	if sway_amplitude <= 0.0:
		return
	_time += delta
	_sway = sin(_time * sway_speed) * sway_amplitude
	_update_claw()
	queue_redraw()

# --- Controls ------------------------------------------------------------------

## Put the trolley at `value` along the boom, stopped by the rail ends.
func place_trolley(value: float) -> void:
	trolley = clampf(value, trolley_min, trolley_max)
	_update_claw()
	queue_redraw()

## Pay the winch in or out to `value`, stopped by the drum.
func place_hoist(value: float) -> void:
	hoist = clampf(value, hoist_min, hoist_max)
	_update_claw()
	queue_redraw()

## Open or shut the jaws. A tween may drive this directly, which is why it's a
## setter: the drawing and the redraw come along with it.
func set_jaw_open(value: float) -> void:
	jaw_open = clampf(value, 0.0, 1.0)
	queue_redraw()

## Where the jaws are in this node's own space: the trolley's spot along the
## boom, plus however much cable is out, plus the pendulum sway.
func claw_local() -> Vector2:
	var anchor := Vector2(-trolley, _boom_y() + boom_height * 0.5)
	return anchor + Vector2(sin(_sway), cos(_sway)) * hoist

## World position of the jaws — where a grab is aimed, and where a load or an
## effect parented to `Claw` ends up.
func claw_tip_global() -> Vector2:
	return to_global(claw_local())

## Where the claw parks: the exported trolley spot with the exported cable out.
func rest_claw_local() -> Vector2:
	return Vector2(-trolley_offset, _boom_y() + boom_height * 0.5 + hoist_length)

## Where the two shells hinge, in this node's space: just under the claw block,
## swinging with it.
func hinge_local() -> Vector2:
	return claw_local() + Vector2(0.0, HINGE_DROP).rotated(_sway)

## How far a shell is turned about the hinge right now, for `side` -1 (left)
## or +1 (right). Opening swings each shell's tip outward and up.
func shell_rotation(side: float) -> float:
	return _sway - side * JAW_SWING * jaw_open

## One shell in hinge space (hinge at the origin, +y down): half of a thick
## ring whose centre sits `claw_radius` below the hinge, on the `side` half.
## Shut, the two halves meet top and bottom and make the whole ring.
func shell_polygon(side: float) -> PackedVector2Array:
	var outer := claw_radius
	var inner := maxf(claw_radius - claw_thickness, 1.0)
	var centre := Vector2(0.0, claw_radius)
	var points := PackedVector2Array()
	for i in SHELL_SEGMENTS + 1:
		var angle := -PI * 0.5 + side * PI * float(i) / float(SHELL_SEGMENTS)
		points.append(centre + Vector2(cos(angle), sin(angle)) * outer)
	for i in range(SHELL_SEGMENTS, -1, -1):
		var angle := -PI * 0.5 + side * PI * float(i) / float(SHELL_SEGMENTS)
		points.append(centre + Vector2(cos(angle), sin(angle)) * inner)
	return points

## Shell fill: the right one is the shade step of the left, so the pair reads
## as one lit object without a separate shade strip.
func shell_color(side: float) -> Color:
	return steel_color.darkened(0.2 if side < 0.0 else 0.38)

## Keep the Claw node — and therefore anything parented to it — at the jaws.
func _update_claw() -> void:
	if _claw != null:
		_claw.position = claw_local()

func _tracks_top() -> float:
	return -track_height

func _turret_top() -> float:
	return -track_height - TURRET_H

func _boom_y() -> float:
	return -mast_height

# --- Drawing -------------------------------------------------------------------

func _draw() -> void:
	_draw_tracks()
	_draw_turret()
	_draw_mast()
	_draw_boom()
	_draw_hoist()

func _draw_tracks() -> void:
	var half := track_width * 0.5
	draw_rect(Rect2(-half, -track_height, track_width, track_height), dark_color)
	var wheel_r := track_height * 0.28
	for x: float in [-half + wheel_r + 6.0, half - wheel_r - 6.0]:
		draw_colored_polygon(FlatProps.octagon(Vector2(x, -track_height * 0.5), wheel_r, wheel_r), rust_color)

func _draw_turret() -> void:
	var half := track_width * 0.34
	var bottom := _tracks_top()
	var top := _turret_top()
	draw_rect(Rect2(-half, top, half * 2.0, bottom - top), steel_color)
	# cab window on the side that faces down the yard
	draw_rect(Rect2(-half + 12.0, top + 14.0, half * 0.9, TURRET_H - 30.0), dark_color)
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
			draw_colored_polygon(FlatProps.sliver(Vector2(-half, y), Vector2(half, y - LATTICE_STEP), BRACE_W), steel_color.darkened(0.3))
		else:
			draw_colored_polygon(FlatProps.sliver(Vector2(half, y), Vector2(-half, y - LATTICE_STEP), BRACE_W), steel_color.darkened(0.3))
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
	draw_colored_polygon(FlatProps.sliver(Vector2(0.0, y - PYLON_H + 2.0), Vector2(left + 30.0, top), 6.0), cable_color)
	draw_colored_polygon(FlatProps.sliver(Vector2(0.0, y - PYLON_H + 2.0), Vector2(right - 12.0, top), 6.0), cable_color)

	draw_rect(Rect2(left, top, right - left, RAIL), steel_color)
	draw_rect(Rect2(left, bottom - RAIL, right - left, RAIL), steel_color)
	var x := left
	var flip := false
	while x + LATTICE_STEP < right:
		if flip:
			draw_colored_polygon(FlatProps.sliver(Vector2(x, bottom - RAIL), Vector2(x + LATTICE_STEP, top + RAIL), BRACE_W), steel_color.darkened(0.3))
		else:
			draw_colored_polygon(FlatProps.sliver(Vector2(x, top + RAIL), Vector2(x + LATTICE_STEP, bottom - RAIL), BRACE_W), steel_color.darkened(0.3))
		flip = not flip
		x += LATTICE_STEP

	# counterweight block hanging off the tail
	draw_rect(Rect2(right - 62.0, top - 26.0, 62.0, boom_height + 52.0), rust_color)

func _draw_hoist() -> void:
	var y := _boom_y()
	var anchor := Vector2(-trolley, y + boom_height * 0.5)
	# the trolley rides the top chord and carries the sheave below the boom
	draw_rect(Rect2(anchor.x - 44.0, y - boom_height * 0.5 - 16.0, 88.0, 20.0),
			steel_color.darkened(0.15))
	draw_rect(Rect2(anchor.x - 34.0, anchor.y - 4.0, 68.0, 22.0), dark_color)

	var claw := claw_local()
	draw_colored_polygon(FlatProps.sliver(anchor + Vector2(-14.0, 16.0), claw + Vector2(-9.0, -6.0), 5.0), cable_color)
	draw_colored_polygon(FlatProps.sliver(anchor + Vector2(14.0, 16.0), claw + Vector2(9.0, -6.0), 5.0), cable_color)

	# the block the shells hinge on, swinging with the cables
	var block := Vector2(claw_radius * 0.8, claw_radius * 0.5)
	draw_set_transform(claw, _sway, Vector2.ONE)
	draw_rect(Rect2(-block.x * 0.5, HINGE_DROP + 4.0 - block.y, block.x, block.y), dark_color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_shells()

## The two clamshell halves, pivoting on the hinge rather than shrinking toward
## each other, so each keeps its solid shape at every opening. A subclass that
## builds the shells as real bodies (see `CraneRig`) draws them there instead.
func _draw_shells() -> void:
	var hinge := hinge_local()
	for side in PackedFloat32Array([-1.0, 1.0]):
		draw_set_transform(hinge, shell_rotation(side), Vector2.ONE)
		draw_colored_polygon(shell_polygon(side), shell_color(side))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
