class_name JunkyardYard
extends Node2D
## The junkyard lot itself: dirt, tire ruts and the perimeter fence, all painted
## in one `_draw()`.
##
## It's the scene's root on purpose. A node draws itself *before* its children,
## so everything painted here lands behind the y-sorted `Yard` child — which is
## what we want for ground, and good enough for a fence you're standing inside
## of. The four walls that stop the car driving off the lot are plain
## StaticBody2Ds authored in the scene; `yard_size` is the contract between the
## two (the walls sit on this rectangle, the fence is drawn along it).

## The fenced area. The walls in junkyard.tscn are placed on this rectangle, so
## changing it here means moving them there too.
@export var yard_size: Vector2 = Vector2(1900, 1200)
## Extra dirt past the walls, so the camera never sees past the edge of the lot.
@export var margin: float = 420.0
@export var post_spacing: float = 170.0
@export var fence_height: float = 96.0
## Width of the gap in the front fence where the car drives in.
@export var gate_half_width: float = 130.0
@export var seed: int = 7

@export_group("Colors")
@export var dirt_color: Color = Color(0.46, 0.39, 0.28, 1)
@export var yard_color: Color = Color(0.42, 0.36, 0.26, 1)
@export var stain_color: Color = Color(0.16, 0.14, 0.11, 0.35)
@export var rut_color: Color = Color(0.34, 0.29, 0.21, 0.55)
@export var fence_color: Color = Color(0.4, 0.31, 0.22, 1)
@export var fence_top_color: Color = Color(0.47, 0.37, 0.25, 1)

func _draw() -> void:
	var margin_vec := Vector2.ONE * margin
	draw_rect(Rect2(-yard_size / 2.0 - margin_vec, yard_size + margin_vec * 2.0), dirt_color)
	# The compacted inner lot, so the yard reads as a made surface fenced off
	# from the surrounding sand.
	draw_rect(Rect2(-yard_size / 2.0, yard_size), yard_color)
	_draw_stains()
	_draw_ruts()
	_draw_fence()

## Oil stains and puddles, deterministic from `seed`.
func _draw_stains() -> void:
	var rng := _rng()
	var half := yard_size / 2.0
	for i in 14:
		var pos := Vector2(
				rng.randf_range(-half.x + 80.0, half.x - 80.0),
				rng.randf_range(-half.y + 80.0, half.y - 80.0))
		draw_circle(pos, rng.randf_range(24.0, 58.0), stain_color)

## Long shallow ruts where cars have been dragged across the lot.
func _draw_ruts() -> void:
	var rng := _rng()
	for i in 4:
		var y := rng.randf_range(-420.0, 420.0)
		var width := rng.randf_range(1200.0, 1800.0)
		draw_rect(Rect2(-width * 0.5, y, width, 7.0), rut_color)
		draw_rect(Rect2(-width * 0.5, y + 34.0, width, 7.0), rut_color)

func _draw_fence() -> void:
	var half := yard_size / 2.0
	_draw_side(Vector2(-half.x, -half.y), Vector2(half.x, -half.y), false)
	# Front fence has the gate opening in the middle, where the car came in.
	_draw_side(Vector2(-half.x, half.y), Vector2(half.x, half.y), true)
	_draw_side(Vector2(-half.x, -half.y), Vector2(-half.x, half.y), false)
	_draw_side(Vector2(half.x, -half.y), Vector2(half.x, half.y), false)
	if gate_half_width > 0.0:
		_draw_gate_posts(half.y)

## One run of fence: posts at even spacing with three rails threaded through
## them. `with_gate` leaves a gap in the middle for the entrance (front side
## only — the gap maths assumes a horizontal run centred on x = 0).
func _draw_side(from: Vector2, to: Vector2, with_gate: bool) -> void:
	var length := from.distance_to(to)
	var steps := maxi(1, int(length / post_spacing))
	for i in steps + 1:
		var t := float(i) / float(steps)
		var p := from.lerp(to, t)
		if with_gate and absf(p.x) < gate_half_width:
			continue
		draw_rect(Rect2(p.x - 5.0, p.y - fence_height, 10.0, fence_height), fence_color)
	if with_gate and gate_half_width > 0.0:
		_draw_rails(from, Vector2(-gate_half_width, from.y))
		_draw_rails(Vector2(gate_half_width, from.y), to)
	else:
		_draw_rails(from, to)

func _draw_rails(from: Vector2, to: Vector2) -> void:
	var up := Vector2(0.0, -1.0)
	for offset in PackedFloat32Array([20.0, 54.0, 86.0]):
		draw_line(from + up * offset, to + up * offset, fence_color, 3.0)

## Two taller, lighter posts framing the way in.
func _draw_gate_posts(front_y: float) -> void:
	for x in PackedFloat32Array([-gate_half_width, gate_half_width]):
		draw_rect(Rect2(x - 8.0, front_y - fence_height - 40.0, 16.0, fence_height + 40.0),
				fence_top_color)

func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	if seed == 0:
		rng.randomize()
	else:
		rng.seed = seed
	return rng
