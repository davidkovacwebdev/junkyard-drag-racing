class_name SoftBodyWobble
extends Node
## Makes a soft body part (the mattress) bend like a floppy slab. It watches
## its parent's movement rather than physics contacts, so it works the same on
## a racing RigidBody2D as on the frozen art riding the map car: any sudden
## change of velocity (a landing, a wall, a hard stop, flooring it) kicks a
## damped spring that arches the art between its wheels and leans it back.
##
## The bend is a parabola that is zero at the wheel mounts: a positive bend
## sags the middle down and curls the overhanging ends up, a negative one
## arches the middle up. Polygons are subdivided once so their long straight
## edges have enough points to actually curve.

## Where the art is anchored, in the parent's local space: the bend is
## measured from here and the lean pivots on its height.
@export var pivot: Vector2 = Vector2.ZERO
## Half the distance between the wheel mounts: where the slab is held up and
## doesn't bend.
@export var support_half_width: float = 62.0
## How far the middle droops when nothing is happening, in px.
@export var rest_sag: float = 3.0
@export var stiffness: float = 140.0
@export var damping: float = 5.0
## Bend speed (px/s) gained per px/s of sudden vertical velocity change.
@export var bend_sensitivity: float = 0.35
## Lean speed gained per px/s of sudden horizontal velocity change.
@export var lean_sensitivity: float = 0.004
@export var max_bend: float = 16.0
@export var max_lean: float = 0.35
## Longest straight edge left after subdividing, in px.
@export var segment_length: float = 6.0

var _parent: Node2D
var _rest_polygons: Dictionary = {}
var _rest_transforms: Dictionary = {}
var _previous_position: Vector2
var _previous_velocity: Vector2
var _frames_tracked: int = 0
var _bend: float = 0.0
var _bend_speed: float = 0.0
var _lean: float = 0.0
var _lean_speed: float = 0.0

func _ready() -> void:
	_parent = get_parent() as Node2D

func _physics_process(delta: float) -> void:
	if _parent == null or delta <= 0.0:
		return
	var current_position := _parent.global_position
	var velocity := (current_position - _previous_position) / delta
	_previous_position = current_position
	var delta_velocity := velocity - _previous_velocity
	_previous_velocity = velocity
	# The first two frames have no real previous position/velocity to compare.
	_frames_tracked += 1
	if _frames_tracked > 2:
		# In the parent's own frame, so a tilted or mirrored car still bends
		# along its own up and leans against its own forward.
		var local_kick := _parent.global_transform.affine_inverse().basis_xform(delta_velocity)
		# Inertia: pushed up (a landing) sags the middle, pushed forward leans back.
		_bend_speed -= local_kick.y * bend_sensitivity
		_lean_speed -= local_kick.x * lean_sensitivity

	_bend_speed += (-stiffness * _bend - damping * _bend_speed) * delta
	_lean_speed += (-stiffness * _lean - damping * _lean_speed) * delta
	_bend = clampf(_bend + _bend_speed * delta, -max_bend, max_bend)
	_lean = clampf(_lean + _lean_speed * delta, -max_lean, max_lean)
	_apply()

## Kicks the bend by hand, e.g. when the part is dropped onto a car in the
## garage where nothing actually moves.
func poke(amount: float) -> void:
	_bend_speed += amount

## Where a point of the resting art moves to, in the parent's space.
func _deform(point: Vector2) -> Vector2:
	var along := (point.x - pivot.x) / support_half_width
	var sag := (_bend + rest_sag) * (1.0 - along * along)
	return Vector2(point.x + _lean * (pivot.y - point.y), point.y + sag)

## Slope of the bent surface at `x`, so things riding on it tilt with it.
func _slope(x: float) -> float:
	var along := (x - pivot.x) / support_half_width
	return -2.0 * (_bend + rest_sag) * along / support_half_width

func _apply() -> void:
	_apply_to_children_of(_parent)

## Recurses into plain Node2D groups because races can move the art under a
## wrapper node (see SingleLaneRaceSetup._wrap_art).
func _apply_to_children_of(node: Node) -> void:
	for child in node.get_children():
		if child is Polygon2D:
			_bend_polygon(child)
		elif child is CarEngine:
			_ride_surface(child)
		elif child.get_class() == "Node2D":
			_apply_to_children_of(child)

func _bend_polygon(polygon_node: Polygon2D) -> void:
	if not _rest_polygons.has(polygon_node):
		_rest_polygons[polygon_node] = _subdivide(polygon_node.polygon)
		_rest_transforms[polygon_node] = polygon_node.transform
	var rest_points: PackedVector2Array = _rest_polygons[polygon_node]
	var node_transform: Transform2D = _rest_transforms[polygon_node]
	var to_local := node_transform.affine_inverse()
	var bent := PackedVector2Array()
	bent.resize(rest_points.size())
	for i in rest_points.size():
		bent[i] = to_local * _deform(node_transform * rest_points[i])
	polygon_node.polygon = bent

func _ride_surface(engine: Node2D) -> void:
	if not _rest_transforms.has(engine):
		_rest_transforms[engine] = engine.transform
	var rest: Transform2D = _rest_transforms[engine]
	engine.position = _deform(rest.origin)
	engine.rotation = rest.get_rotation() + atan(_slope(rest.origin.x))

func _subdivide(points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in points.size():
		var start := points[i]
		var end := points[(i + 1) % points.size()]
		var steps := maxi(1, ceili(start.distance_to(end) / segment_length))
		for step in steps:
			result.append(start.lerp(end, float(step) / steps))
	return result
