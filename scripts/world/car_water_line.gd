class_name CarWaterLine
extends Node2D
## A car sinking into the sea (see PlayerCar's Wading exports). The car's
## visual is put inside this node with `hold()`; while it's wet, everything
## below a bobbing waterline is clipped away so the real sea shows through, and
## a chunky foam ripple is drawn across the car at that line. One polygon.
## `level` 0 is dry (no clipping at all); 1 is sunk as far as it goes.

const FOAM_COLOR := Color("d8ece8")

## How far up the car the waterline sits, as a share of its height from the
## bottom of the wheels, at a touch of water and when fully sunk.
@export_range(0.0, 1.0) var shallow_fraction: float = 0.1
@export_range(0.0, 1.0) var sunk_fraction: float = 0.28
## How far the foam ripple reaches past each side of the car.
@export var foam_overhang: float = 10.0
@export var foam_thickness: float = 7.0
@export var bob_height: float = 2.5
@export var bob_speed: float = 3.0
## Reach of the clip above the waterline; anything taller than the car will do.
const MASK_REACH := 600.0

var level: float = 0.0:
	set(value):
		if is_equal_approx(value, level):
			return
		if level <= 0.0 and value > 0.0:
			_car_bounds = PartScale.measure_bounds(_clip)
		level = value
		_clip.clip_children = CanvasItem.CLIP_CHILDREN_ONLY if level > 0.0 else CanvasItem.CLIP_CHILDREN_DISABLED
		_redraw()

var _time: float = 0.0
## The held car's art, measured as it gets wet, so any car sinks the same share.
var _car_bounds := Rect2(-65.0, -30.0, 130.0, 60.0)
var _clip := Node2D.new()
var _foam := Node2D.new()

func _init() -> void:
	add_child(_clip)
	add_child(_foam)
	_clip.draw.connect(_draw_mask)
	_foam.draw.connect(_draw_foam)

## Moves `visual` in here, so it's the thing that gets cut off at the waterline.
func hold(visual: Node2D) -> void:
	visual.get_parent().remove_child(visual)
	_clip.add_child(visual)

func _process(delta: float) -> void:
	if level <= 0.0:
		return
	_time += delta
	_redraw()

func _redraw() -> void:
	_clip.queue_redraw()
	_foam.queue_redraw()

func _surface() -> float:
	var fraction := lerpf(shallow_fraction, sunk_fraction, level)
	return _car_bounds.end.y - _car_bounds.size.y * fraction + sin(_time * bob_speed) * bob_height

func _draw_mask() -> void:
	if level <= 0.0:
		return
	var surface := _surface()
	var tilt := sin(_time * bob_speed * 0.7) * bob_height
	_clip.draw_colored_polygon(PackedVector2Array([
		Vector2(-MASK_REACH, -MASK_REACH), Vector2(MASK_REACH, -MASK_REACH),
		Vector2(MASK_REACH, surface - tilt), Vector2(-MASK_REACH, surface + tilt),
	]), Color.WHITE)

func _draw_foam() -> void:
	if level <= 0.0:
		return
	var surface := _surface()
	var tilt := sin(_time * bob_speed * 0.7) * bob_height
	var half_width := _car_bounds.size.x * 0.5 + foam_overhang
	var center := _car_bounds.get_center().x
	var left := Vector2(center - half_width, surface + tilt)
	var middle := Vector2(center + half_width * 0.1, surface - bob_height * 0.5)
	var right := Vector2(center + half_width, surface - tilt)
	var down := Vector2(0.0, foam_thickness)
	_foam.draw_colored_polygon(PackedVector2Array([
		left - down * 0.5, middle - down * 0.5, right - down * 0.5,
		right + down * 0.5, middle + down * 0.5, left + down * 0.5,
	]), FOAM_COLOR)
