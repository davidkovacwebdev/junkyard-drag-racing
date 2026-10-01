class_name CarBody
extends RigidBody2D
## Physics body for a car's BODY part. Wheels hang off this on sprung
## suspension at the body's "WheelMount*" Marker2D children (see
## CarAssembler._suspend_wheel). Normal driving
## is pushed entirely by its wheels' real ground friction transmitted back
## through those joints (see car_wheel.gd) — `boost_force` is a separate,
## optional continuous push RaceController applies once a car crosses the
## finish line, so it genuinely accelerates over the runway into the wall
## rather than getting an instant velocity snap.

@export var part_data: BodyPartData

var boost_force: float = 0.0

func _ready() -> void:
	if part_data != null:
		mass = part_data.mass
	can_sleep = false
	# The finish-line boost gets fast enough to cross the whole EndWall in
	# under one physics tick without this — continuous collision detection
	# keeps the wall an actual wall instead of something cars phase through.
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE

func _physics_process(_delta: float) -> void:
	if boost_force != 0.0:
		apply_central_force(Vector2(boost_force, 0.0))

## Returns this body's WheelMount marker children, in child order.
func get_wheel_mounts() -> Array[Marker2D]:
	var mounts: Array[Marker2D] = []
	for child in get_children():
		if child is Marker2D and child.name.begins_with("WheelMount"):
			mounts.append(child)
	return mounts

## The body's lamps, in child order. Empty for bodies without any.
func get_headlight_mounts() -> Array[HeadlightMount]:
	var mounts: Array[HeadlightMount] = []
	for child in get_children():
		if child is HeadlightMount:
			mounts.append(child)
	return mounts

## Returns this body's "EngineMount" marker — the spot on this body's art
## where an installed engine belongs (a car's hood, a fridge's top, a
## boat's stern, ...). Null if the body declares none.
func get_engine_mount() -> Marker2D:
	for child in get_children():
		if child is Marker2D and child.name.begins_with("EngineMount"):
			return child
	return null

## Snaps an installed engine (or other mount decoration) onto this body's
## EngineMount so it sits where the body's art expects it instead of on
## the body's origin. Engines are authored with their origin at their
## mounting base (+y down, body extending up), so no extra offset is
## needed. Falls back to leaving the engine at its own position when the
## body has no mount. An engine that has to fit itself around the body (the
## horse walks out in front of it) gets `attach_to_body()` called afterwards.
func place_engine(engine: Node2D) -> void:
	var mount := get_engine_mount()
	if mount != null:
		engine.position = mount.position
		engine.rotation = mount.rotation
	if engine.has_method("attach_to_body"):
		engine.call("attach_to_body", self)

## Optional hand-placed spots, by AccessoryPartData.Spot. A body without one
## gets the spot worked out from its collision outline (see _computed_spot).
const ACCESSORY_MOUNT_NAMES := {
	AccessoryPartData.Spot.FRONT: "AccessoryMountFront",
	AccessoryPartData.Spot.TOP: "AccessoryMountTop",
	AccessoryPartData.Spot.REAR: "AccessoryMountRear",
}
## The front spot sits this far down the body's height, about bumper level.
const FRONT_SPOT_HEIGHT := 0.6
## The rear spot sits on the deck this far in from the back end.
const REAR_SPOT_INSET := 0.1
## The top spot keeps this share of the body's width clear of the engine.
const TOP_SPOT_ENGINE_CLEARANCE := 0.2
const TOP_SPOT_SAMPLES := 24

## Where an accessory for `spot` is bolted on, in this body's space. Front
## accessories are authored reaching +x from their origin, rear ones -x and top
## ones -y, so the spot is a point on the body's outline.
func get_accessory_mount(spot: AccessoryPartData.Spot) -> Vector2:
	if spot == AccessoryPartData.Spot.SKIN:
		return Vector2.ZERO
	var marker := get_node_or_null(NodePath(ACCESSORY_MOUNT_NAMES[spot])) as Marker2D
	if marker != null:
		return marker.position
	return _computed_spot(spot)

## Seats `accessory` on its spot, then lets it fit itself to the body.
func place_accessory(accessory: CarAccessory) -> void:
	var spot := accessory.part_data.spot if accessory.part_data != null else AccessoryPartData.Spot.TOP
	accessory.position = get_accessory_mount(spot)
	accessory.attach_to_body(self)

## The highest point of the body's outline straight above or below `x`.
func top_surface_y(x: float) -> float:
	var outline := outline_polygon()
	var top := INF
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		if (a.x <= x and b.x >= x) or (b.x <= x and a.x >= x):
			var t := 0.5 if is_equal_approx(a.x, b.x) else (x - a.x) / (b.x - a.x)
			top = minf(top, lerpf(a.y, b.y, t))
	return top if top < INF else _outline_bounds(outline).position.y

func outline_bounds() -> Rect2:
	return _outline_bounds(outline_polygon())

## The body's collision outline in its own space.
func outline_polygon() -> PackedVector2Array:
	for child in get_children():
		if child is CollisionPolygon2D:
			var collider := child as CollisionPolygon2D
			return collider.transform * collider.polygon
	var art := PackedVector2Array()
	var bounds := PartScale.measure_bounds(self)
	art.append_array([bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)])
	return art

func _computed_spot(spot: AccessoryPartData.Spot) -> Vector2:
	var outline := outline_polygon()
	var bounds := _outline_bounds(outline)
	match spot:
		AccessoryPartData.Spot.FRONT:
			var y := bounds.position.y + bounds.size.y * FRONT_SPOT_HEIGHT
			return Vector2(_rightmost_x_at(outline, y, bounds.end.x), y)
		AccessoryPartData.Spot.REAR:
			var x := bounds.position.x + bounds.size.x * REAR_SPOT_INSET
			return Vector2(x, top_surface_y(x))
	return _top_spot(bounds)

## The highest point of the outline that isn't where the engine sits, nearest
## the middle when there's a tie (a flat roof).
func _top_spot(bounds: Rect2) -> Vector2:
	var engine_mount := get_engine_mount()
	var clearance := bounds.size.x * TOP_SPOT_ENGINE_CLEARANCE
	var best := Vector2(bounds.get_center().x, bounds.position.y)
	var best_score := INF
	for i in TOP_SPOT_SAMPLES:
		var x := lerpf(bounds.position.x, bounds.end.x, (i + 0.5) / TOP_SPOT_SAMPLES)
		if engine_mount != null and absf(x - engine_mount.position.x) < clearance:
			continue
		var y := top_surface_y(x)
		var score := y + absf(x - bounds.get_center().x) * 0.05
		if score < best_score:
			best_score = score
			best = Vector2(x, y)
	return best

static func _rightmost_x_at(outline: PackedVector2Array, y: float, fallback: float) -> float:
	var rightmost := -INF
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		if (a.y <= y and b.y >= y) or (b.y <= y and a.y >= y):
			var t := 0.5 if is_equal_approx(a.y, b.y) else (y - a.y) / (b.y - a.y)
			rightmost = maxf(rightmost, lerpf(a.x, b.x, t))
	return rightmost if rightmost > -INF else fallback

static func _outline_bounds(outline: PackedVector2Array) -> Rect2:
	var bounds := Rect2(outline[0], Vector2.ZERO)
	for point in outline:
		bounds = bounds.expand(point)
	return bounds
