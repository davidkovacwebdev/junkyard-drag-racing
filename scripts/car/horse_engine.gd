class_name HorseEngine
extends CarEngine
## A horse as an engine. The part's origin is the hitch on the body's
## EngineMount; the horse itself stands in front of the car and pulls it on a
## lead tied to that hitch.
##
## Once bolted on, `attach_to_body()` walks the horse out past the body's nose
## and stands it on the ground under the wheels, so it works on any body no
## matter where that body keeps its engine mount. Unattached (garage icons,
## pickups, the farm's paddock) it just stands next to the hitch.
##
## The gait is driven by how far the part actually moves, like
## SpinningPropeller, so it trots in a race, on the map and backs up when the
## car reverses, and idles (breathing, tail swish, head nod) when parked.

## Space between the body's nose and the horse's tail, in body pixels.
const GAP_TO_BODY := 20.0
## How far the horse's art reaches behind its own origin (tail tip).
const REAR_REACH := 75.0
## Wheels hang below their mounts by about a standard wheel's radius, which is
## where the ground is.
const WHEEL_RADIUS_GUESS := 36.0
## Distance covered by one full stride, in horse pixels.
const STRIDE_LENGTH := 150.0
## Speed (horse pixels/s) at which the gait is at full swing.
const FULL_GAIT_SPEED := 420.0
const LEG_SWING := 0.55
const KNEE_FOLD := 1.1
const TROT_BOUNCE := 5.0
const LEAD_SEGMENTS := 10
const LEAD_WIDTH := 3.0
const LEAD_SAG_IDLE := 18.0
const LEAD_SAG_PULLING := 2.0
## Grazing: how far the head dips, and the quick little nods as it chews.
const GRAZE_DIP := 1.3
const GRAZE_CHEWS := 7.0
const GRAZE_CHEW_NOD := 0.07

## Scales how fast the legs cycle for the distance covered. The map car sets
## this below 1 so the shrunk horse doesn't scurry.
var gait_rate := 1.0
## Head down at the ground, chewing (Grandpa's Tiger at his carrots), instead
## of the idle nod. Only while standing still.
var grazing := false

@onready var _harness: Node2D = $Harness
@onready var _lead: Polygon2D = $Harness/Lead
@onready var _horse: Node2D = $Harness/Horse
@onready var _torso: Node2D = $Harness/Horse/Torso
@onready var _neck: Node2D = $Harness/Horse/Torso/Neck
@onready var _ear: Node2D = $Harness/Horse/Torso/Neck/Ear
@onready var _tail: Node2D = $Harness/Horse/Torso/Tail
@onready var _lead_point: Marker2D = $Harness/Horse/Torso/Neck/LeadPoint
## Diagonal pairs move together (a trot): near-front with far-rear, far-front
## with near-rear.
@onready var _legs: Array[Node2D] = [
	$Harness/Horse/Torso/LegNearFront, $Harness/Horse/Torso/LegFarRear,
	$Harness/Horse/Torso/LegFarFront, $Harness/Horse/Torso/LegNearRear,
]
const _LEG_PHASE_OFFSETS := [0.0, 0.0, PI, PI]

var _previous_position: Vector2
var _has_previous_position := false
var _gait_phase := 0.0
var _gait_blend := 0.0
var _idle_time := 0.0
var _next_ear_flick := 2.0

func _ready() -> void:
	_harness.add_to_group(PartScale.OUTRIGGER_GROUP)
	_idle_time = randf() * 10.0
	_update_lead()

## A loose horse (the farm's paddock) has no hitch and no lead, and stands on
## the part's origin so it turns around on the spot.
func set_hitched(hitched: bool) -> void:
	for piece: CanvasItem in [$HitchPost, $HitchRing, _lead]:
		piece.visible = hitched
	if not hitched:
		_horse.position = Vector2.ZERO

## Walk the horse out in front of `body` and stand it on the ground, upright
## relative to the body. Called by CarBody.place_engine().
## The horse on its own, without the rope: CarView gives it its own collision
## shape apart from the car's.
func get_walker() -> Node2D:
	return _horse

func attach_to_body(body: CarBody) -> void:
	var nose := -INF
	var ground := -INF
	for child in body.get_children():
		if child is Polygon2D:
			var polygon := child as Polygon2D
			for vertex in polygon.polygon:
				var point := polygon.transform * vertex
				nose = maxf(nose, point.x)
				ground = maxf(ground, point.y)
	for mount in body.get_wheel_mounts():
		ground = maxf(ground, mount.position.y + WHEEL_RADIUS_GUESS)
	if nose == -INF:
		return
	var stand_in_body := Vector2(nose + GAP_TO_BODY + REAR_REACH * _horse.scale.x, ground)
	_horse.position = transform.affine_inverse() * stand_in_body
	_horse.rotation = -rotation
	_update_lead()

func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	var travelled := _forward_travel()
	var speed := absf(travelled) / delta
	_gait_blend = lerpf(_gait_blend, clampf(speed / FULL_GAIT_SPEED, 0.0, 1.0), clampf(6.0 * delta, 0.0, 1.0))
	_gait_phase = wrapf(_gait_phase + travelled / STRIDE_LENGTH * TAU * gait_rate, 0.0, TAU)
	_idle_time += delta
	_animate_legs()
	_animate_body()
	_animate_ear(delta)
	_update_lead()

## Distance moved since last frame along the horse's own forward axis, in the
## horse's own pixels, so the stride matches whether the car is shrunk down on
## the map or full size in a race, and goes negative when reversing.
func _forward_travel() -> float:
	var position_now := _horse.global_position
	var travelled := 0.0
	if _has_previous_position:
		var forward := _horse.global_transform.x
		var world_scale := forward.length()
		if world_scale > 0.0:
			travelled = (position_now - _previous_position).dot(forward / world_scale) / world_scale
	_previous_position = position_now
	_has_previous_position = true
	return travelled

func _animate_legs() -> void:
	for i in _legs.size():
		var step: float = _gait_phase + _LEG_PHASE_OFFSETS[i]
		var leg := _legs[i]
		leg.rotation = -sin(step) * LEG_SWING * _gait_blend
		var knee := leg.get_node("Knee") as Node2D
		knee.rotation = maxf(0.0, cos(step)) * KNEE_FOLD * _gait_blend

func _animate_body() -> void:
	var breathing := sin(_idle_time * 2.2) * 0.8 * (1.0 - _gait_blend)
	var bounce := -absf(sin(_gait_phase)) * TROT_BOUNCE * _gait_blend
	_torso.position.y = bounce + breathing
	var idle_nod := sin(_idle_time * 0.7) * 0.06
	var trot_nod := sin(_gait_phase * 2.0) * 0.08
	if grazing:
		idle_nod = GRAZE_DIP + sin(_idle_time * GRAZE_CHEWS) * GRAZE_CHEW_NOD
	_neck.rotation = lerpf(idle_nod, trot_nod, _gait_blend)
	var swish := sin(_idle_time * 1.6) * 0.18
	_tail.rotation = lerpf(swish, 0.9 + sin(_gait_phase * 2.0) * 0.1, _gait_blend)

func _animate_ear(delta: float) -> void:
	_next_ear_flick -= delta
	if _next_ear_flick <= 0.0:
		_next_ear_flick = randf_range(2.0, 5.0)
		_ear.rotation = -0.5
	_ear.rotation = lerpf(_ear.rotation, 0.0, clampf(8.0 * delta, 0.0, 1.0))

## A rope ribbon from the hitch to the horse's collar, sagging when slack and
## pulled straight when the horse is working.
func _update_lead() -> void:
	var start := _harness.to_local(global_position)
	var end := _harness.to_local(_lead_point.global_position)
	var sag := lerpf(LEAD_SAG_IDLE, LEAD_SAG_PULLING, _gait_blend)
	var along := end - start
	if along.length() < 0.01:
		return
	var side := along.orthogonal().normalized() * LEAD_WIDTH * 0.5
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	for i in LEAD_SEGMENTS + 1:
		var t := float(i) / LEAD_SEGMENTS
		var point := start + along * t + Vector2(0.0, 4.0 * sag * t * (1.0 - t))
		top.append(point - side)
		bottom.append(point + side)
	bottom.reverse()
	_lead.polygon = top + bottom
