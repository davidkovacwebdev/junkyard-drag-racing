@tool
class_name RallyTrack
extends Node2D
## The rally stage's track: the drag strip's five lanes, but the road rolls up
## and down over hills instead of running flat. Same node layout as
## track_multi_test.tscn (Lanes, Slabs, EndWall), so single_lane_race_setup.gd
## races it unchanged: it only asks surface_offset_at() how far the road has
## risen or dropped at a given x.
##
## One height profile drives everything: the collision under every lane (built
## here at startup, on each Slabs/SlabN), the painted road (RallyTrackArt) and
## where the harness spawns cars and scatters hazards. Flat at both ends, so the
## start drop and the finish wall behave exactly like the drag strip's.

## Negative is uphill (screen y grows downward).
@export var hill_height := 140.0
@export var hill_length := 2000.0
## Short bumps laid over the big hills, so crests kick the cars into the air.
@export var bump_height := 28.0
@export var bump_length := 700.0
## The road eases from flat into the hills between these two x's, and back out
## to flat between the last two.
@export var hills_start := Vector2(500.0, 1100.0)
@export var hills_end := Vector2(4600.0, 5100.0)
## Where the collision runs, along the track. Matches the drag strip's ground.
@export var left := -1600.0
@export var right := 6800.0
## How deep each lane's ground is under its surface. Thick so fast wheels
## can't tunnel through a crest.
const SLAB_DEPTH := 200.0
const COLUMN_WIDTH := 40.0

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var slabs := get_node_or_null("Slabs")
	if slabs == null:
		return
	for slab in slabs.get_children():
		if slab is StaticBody2D:
			build_slab_collision(slab)

## How far the road surface sits below (positive) or above (negative) its flat
## lane line at track x.
func surface_offset_at(x: float) -> float:
	var envelope := smoothstep(hills_start.x, hills_start.y, x) * (1.0 - smoothstep(hills_end.x, hills_end.y, x))
	if envelope <= 0.0:
		return 0.0
	var from_start := x - hills_start.x
	return -envelope * (hill_height * sin(TAU * from_start / hill_length)
			+ bump_height * sin(TAU * from_start / bump_length + 1.3))

## Column x's the surface is sampled at, left to right.
func sample_xs() -> PackedFloat32Array:
	var xs := PackedFloat32Array()
	var columns := int(ceilf((right - left) / COLUMN_WIDTH))
	for i in columns + 1:
		xs.append(lerpf(left, right, float(i) / float(columns)))
	return xs

## A band between two flat y's, bent onto the road: its top edge left to right,
## then its bottom edge back. What the track art paints with.
func surface_band(band_top: float, band_bottom: float) -> PackedVector2Array:
	var xs := sample_xs()
	var points := PackedVector2Array()
	for x in xs:
		points.append(Vector2(x, band_top + surface_offset_at(x)))
	for i in range(xs.size() - 1, -1, -1):
		points.append(Vector2(xs[i], band_bottom + surface_offset_at(xs[i])))
	return points

## A band SLAB_DEPTH thick whose top edge is the road surface, in the slab's
## own space. Slabs are authored at x = 0 on their lane's flat road line.
func build_slab_collision(slab: StaticBody2D) -> void:
	var surface := PackedVector2Array()
	var underside := PackedVector2Array()
	for x in sample_xs():
		var y := surface_offset_at(x)
		surface.append(Vector2(x, y))
		underside.append(Vector2(x, y + SLAB_DEPTH))
	underside.reverse()
	surface.append_array(underside)
	var shape := CollisionPolygon2D.new()
	shape.polygon = surface
	slab.add_child(shape)

