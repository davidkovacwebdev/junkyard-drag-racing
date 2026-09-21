extends Node2D
## Drag strip test harness: randomly assembles CAR_COUNT cars (random body,
## independent random front/back wheels, random engine) and registers them
## with the sibling RaceController — same CarAssembler wheel-physics rig as
## random_race_setup.gd (real gravity, rolling wheels, CarPartDamage/
## PartShatter breakage). The difference is the track and what it's for: this one
## runs on track_multi_test.tscn, where each lane's road is drawn as its own
## bendable strip, and that strip — along with the artwork of everything lying on
## it — is displaced so the cars wander across lane boundaries and look like
## they're trading paint.
##
## --- What moves, and why it has to be the artwork ------------------------------
##
## The wander is drawn, never simulated. Two things are displaced per lane, both
## by the same rule:
##
##   1. Every vertex of that lane's road strip (Lanes/LaneN/Road).
##   2. Every drawn piece on the lane — body, engine, each wheel, any debris —
##      through a wrapper node inside it.
##
## The cars' rigid bodies, their collision, and the lane's ground slab
## (Slabs/SlabN) do not move at all. That is not a style choice, it's the only
## version that survives, and it's worth knowing before touching any of this: a
## RigidBody2D's transform belongs to the physics server, so a body never
## follows a parent node's transform. Slide a lane's ground out from under a
## driving car and penetration forces tear that car apart inside ~120 frames
## (measured); shift the bodies along with the ground instead and the car loses
## about 17% of its traction and still starts shedding parts, because a rigid
## body teleported every frame never gets to warm start the contacts it's
## standing on (also measured). So the physics is left completely alone — five
## ordinary static lanes, five ordinary cars driving on them — and the illusion
## is drawn over the top.
##
## Because a car's art and its lane's road art are both displaced by the same
## function, the wheels stay planted on the road they think they're driving on.
##
## --- The drift is a shape, not a number ----------------------------------------
##
## The displacement is a function of x, not one offset per lane:
##
##     offset_at(x) = drift * 0.5 * (1 + cos(PI * |x - centre| / FALLOFF))
##
## a smooth bump: full height at `centre`, easing to nothing FALLOFF px away.
## `centre` rides the car (see _follower) and `drift` wanders between
## ±DRIFT_AMPLITUDE, so what the player sees is a bump travelling along the road
## with the car on top of it and a fading wake behind. The displacement is applied
## in *world* space (see _offset_art): local space would rotate it along with a
## spinning wheel and swing its art around the axle instead of just moving it,
## which is what broke the first attempt at this.
##
## The road is displaced by that same function, which is why it has to be a strip
## of vertices rather than a slab: the road's height under a piece is then exactly
## the offset that piece is drawn with, by construction, rather than two numbers
## that have to be kept in agreement by hand. See _setup_road_strip/_bend_road.
##
## --- Why a bump, rather than one offset per lane -------------------------------
##
## One number per lane can't express "this half is still moving, that half isn't",
## which a car breaking apart needs: with a single offset either the whole wreck
## drifts — the resting half sliding along a road it isn't driving on — or none of
## it does — the moving half stuck to stationary ground while its wheels turn.
## A function of x answers that for free, because the pieces don't have to agree:
## each is drawn at its own x, so a wreck that broke in half ends up with its
## moving half on the bump and its resting half out beyond it, drawn flat on flat
## road, which is exactly where it is.
##
## The price is that a car is rigid and the road isn't. A body's art is translated
## as one piece (at its own x), so its far end can sit a few px off the road, and
## each wheel takes the offset at its own x, so it can sit a few px off its own
## mount. At DRIFT_AMPLITUDE 70 with FALLOFF 700 that's under ~3px at a wheel and
## under ~7px at the end of the widest body (280px) — it reads as suspension, not
## as damage. The tradeoff is real all the same: shrink FALLOFF toward the size of
## a car and the car itself visibly bends; grow it toward the separation you want
## a stopped half to read as still at and the bump stops being local.
##
## --- Sorting, and the fake depth ----------------------------------------------
##
## Lanes/Lane0 is the top lane (smallest y) and is drawn first; Lane4 is the
## bottom one, drawn last, so the bottom lane reads as nearest. Cars copy their
## lane's z_index, and that's what makes a car drifting down over the lane below
## it cover that lane up: basic perspective, and the whole reason the lanes are
## allowed to visually overlap.
##
## --- What's real and what's faked ---------------------------------------------
##
## Real: the driving, the bouncing, the shattering. Faked: the up/down wander
## and the "collisions" it causes — approximated from proximity and answered
## with sparks only, no contact and no impulse. Every lane sits on its own
## collision bit (authored on Slabs/SlabN) so two cars can genuinely overlap on
## screen while the physics never sees more than one lane's worth of ground.
##
## --- Who the bump follows ------------------------------------------------------
##
## `centre` follows the car's *body* while it is still there — it is the car, and a
## stable centre for as long as it lasts — and otherwise whichever surviving piece
## is still carrying the most forward speed. So a car that broke in half keeps its
## bump on the half that is still driving, and the half that stopped falls outside
## it and is drawn flat.
##
## With nothing moving forward there is no follower at all: the bump unwinds to
## zero and the lane flattens back out. That's what keeps wrecked, flipped, jammed
## and still-dropping cars from weaving (see MIN_FORWARD_SPEED), and because it's
## decided from whichever piece is being followed, a half that is still rolling
## keeps its bump.
##
## Debris still has to be *drawn* on its lane, though, and it is spawned at runtime
## while the car is sliding along on its belly, long after the wrappers were built.
## _sync_art picks those fragments up as they appear.
##
## With `cosmetic_drift_enabled` off, none of the above fires: the lanes stay
## put and this is just a five-car drag race.

@export var race_controller_path: NodePath
@export var camera_path: NodePath
## The track instance whose `Lanes` (drawn) and `Slabs` (collision) children are
## this race's lanes, in matching order.
@export var track_path: NodePath = ^"Track"
## Off = plain drag race: lanes stay put, no touches and no sparks faked.
@export var cosmetic_drift_enabled := true

const CAR_COUNT := 5
## Where the cars drop from, staggered along x by SPAWN_STAGGER_X so all five
## don't come down through the same column at once (wider than the widest body,
## ~280px) and SPAWN_HEIGHT_ABOVE_LANE above their lane's road surface, so they
## still fall onto it under real gravity.
const SPAWN_X := 150.0
const SPAWN_HEIGHT_ABOVE_LANE := 15.0
const SPAWN_STAGGER_X := 300.0

## --- Cosmetic up/down drift ---------------------------------------------------

## Peak height of the drift bump, in px: how far a piece sitting at the bump's
## centre is drawn off its own lane. Barely under half the lane spacing on
## purpose: two neighbours bumping toward each other can end up roughly a wheel's
## width apart, which is what "touching" should look like, without the lanes'
## drawn roads ever crossing.
const DRIFT_AMPLITUDE := 140.0
## How fast the bump's height eases toward its next target; slower than the
## targets change, so it reads as wandering rather than snapping.
const DRIFT_STEER_SPEED := 90.0
const DRIFT_HOLD_MIN := 0.4
const DRIFT_HOLD_MAX := 1.4
## Forward speed (px/s) a piece has to be doing before it can be followed, and so
## before its lane gets a bump at all. Drifting is part of driving, so a car that
## is stopped — wrecked, flipped, jammed against the wall, still dropping in at the
## start — flattens back out and sits honestly on its own lane until something on
## it is rolling forward again.
const MIN_FORWARD_SPEED := 25.0
## How much faster than the piece currently being followed another piece has to be
## before it takes the bump. Without a margin an intact car — whose body and wheels
## all move at the same speed — would trade the bump between them frame to frame,
## and since they sit up to ~150px apart the centre would visibly jitter.
const FOLLOWER_SPEED_MARGIN := 40.0
## How fast (1/s) the bump's centre chases the piece it follows. The lag this
## leaves is a few px at driving speed and doesn't matter; what it's for is a
## handover — the body dying, the bump moving to a fragment — not jumping the whole
## lane at once when the piece being followed changes.
const DRIFT_CENTRE_RESPONSE := 12.0
## Spacing of the road strip's vertices, in px: the road is drawn as columns this
## far apart, so a bump FALLOFF wide is spread over FALLOFF / this many of them.
## Halve it for a smoother curve at double the per-frame vertex cost.
const ROAD_COLUMN_WIDTH := 32.0

## --- Approximated cross-lane touches ------------------------------------------

## How close two cars have to be drawn to count as a simulated touch.
## TOUCH_Y_DISTANCE is most of a lane gap: neighbours that have drifted toward
## each other are "rubbing", two lanes apart can never get near enough.
const TOUCH_X_DISTANCE := 180.0
const TOUCH_Y_DISTANCE := 140.0
## Per-car cooldown, so one overlap sparks once instead of every frame it
## happens to stay close.
const TOUCH_COOLDOWN := 0.8

## Sparks are drawn above every lane, whatever depth the two cars were at.
const SPARK_Z := 100
const SPARK_COLOR := Color(1.0, 0.8, 0.25, 1.0)

var body_scenes: Array[PackedScene] = [
	preload("res://scenes/parts/bodies/body_plank.tscn"),
	preload("res://scenes/parts/bodies/body_wrecked_car.tscn"),
	preload("res://scenes/parts/bodies/body_fridge.tscn"),
	preload("res://scenes/parts/bodies/body_sofa.tscn"),
	preload("res://scenes/parts/bodies/body_boat.tscn"),
]

var wheel_scenes: Array[PackedScene] = [
	# wheel_bicycle.tscn removed on purpose — it's the one round/easy wheel,
	# and the point right now is maximum chaos from the wild shapes.
	preload("res://scenes/parts/wheels/wheel_square.tscn"),
	preload("res://scenes/parts/wheels/wheel_triangle.tscn"),
	preload("res://scenes/parts/wheels/wheel_toilet.tscn"),
	preload("res://scenes/parts/wheels/wheel_tv.tscn"),
]

var engine_scenes: Array[PackedScene] = [
	preload("res://scenes/parts/engines/engine_v6.tscn"),
	preload("res://scenes/parts/engines/engine_boiler.tscn"),
	preload("res://scenes/parts/engines/engine_propeller.tscn"),
	preload("res://scenes/parts/engines/engine_sail.tscn"),
	preload("res://scenes/parts/engines/engine_jet.tscn"),
]

## Everything one lane needs to drift: the road strip that gets bent, the car
## riding on it, the wrappers its artwork hangs off, and the two numbers that
## describe the bump — how far it rises (`drift`) and where it sits (`centre`).
class LaneState:
	## How far the bump reaches, in px: the offset is `drift` at `centre` and eases
	## to nothing FALLOFF away. Long enough that the offset barely varies across one
	## car (280px at the widest), short enough that a half broken off and left a few
	## car lengths behind reads as completely still. See this file's header.
	const FALLOFF := 700.0

	var lane := 0
	## The lane's road art, bent rather than moved. Nothing with physics in it lives
	## under here — nor may it ever.
	var lane_art: Node2D
	var car: CarAssembler.AssembledCar
	## One `DriftArt` wrapper per drawn rigid piece on this lane: the car's body
	## (with its engine), one per wheel, and one for every fragment it sheds when
	## that part shatters.
	var art: Array[Node2D] = []
	## The road strip being bent: its vertices' x (baked once, in the strip's own
	## space) and the y of its top and bottom edges with the bump at zero.
	var road: Polygon2D = null
	var road_x := PackedFloat32Array()
	var road_top := 0.0
	var road_bottom := 0.0
	## Peak height of this lane's bump, eased toward `target`.
	var drift := 0.0
	var target := 0.0
	var hold := 0.0
	var cooldown := 0.0
	## World x the bump is centred on: wherever the piece being followed is, eased.
	var centre := 0.0

	## How far a piece drawn at world x sits off its own lane right now. The road
	## strip and every piece on the lane are both displaced by this one function,
	## which is what keeps them together — and what lets two pieces of the same
	## wreck be drawn differently, if that's where they are.
	func offset_at(x: float) -> float:
		var d := absf(x - centre)
		if d >= FALLOFF:
			return 0.0
		return drift * 0.5 * (1.0 + cos(PI * d / FALLOFF))

	## Where this car is *drawn*: where it actually is, plus the offset at its own
	## x. This is the same coordinate its lane's road is drawn at, so the faked
	## touches compare exactly what the player sees.
	func visual_position() -> Vector2:
		if not is_instance_valid(car.body):
			return Vector2.ZERO
		var pos := car.body.global_position
		return pos + Vector2(0.0, offset_at(pos.x))

var _lanes: Array[Node2D] = []
## Same order as _lanes: the static ground each lane's cars stand on.
var _slabs: Array[StaticBody2D] = []
## Each lane's road surface in world space. The road strips are bent rather than
## moved, so a lane's own y is its road surface and stays that way.
var _surface_y: Array[float] = []
var _wall: CollisionObject2D = null
var _states: Array[LaneState] = []

func _ready() -> void:
	var race_controller := get_node_or_null(race_controller_path) as RaceController
	var camera := get_node_or_null(camera_path) as CameraFollow
	_collect_lanes()
	if _lanes.size() < CAR_COUNT or _slabs.size() < CAR_COUNT:
		push_error("RaceTestLane wants %d lanes under the track's 'Lanes' and 'Slabs' nodes (see track_multi_test.tscn) but found %d/%d." % [CAR_COUNT, _lanes.size(), _slabs.size()])
		return

	# Cars live in a plain static container: nothing that moves gets to be an
	# ancestor of a rigid body (see this file's header for what that costs).
	var cars := Node2D.new()
	cars.name = "Cars"
	add_child(cars)

	var camera_targets: Array[Node2D] = []

	# The player's own garage car races in the top lane, so whatever they
	# assembled in the garage is what they drive here too.
	var lane := 0
	var player_car := Inventory.get_selected_car()
	if player_car != null and player_car.body != null and not player_car.body.scene_path.is_empty():
		var car := _assemble_player_car(player_car, lane, cars)
		_register_car("Player_%s" % player_car.display_name, lane, car, race_controller, camera_targets)
		lane += 1

	for i in range(lane, CAR_COUNT):
		var body_scene: PackedScene = body_scenes[randi() % body_scenes.size()]
		var wheel_front: PackedScene = wheel_scenes[randi() % wheel_scenes.size()]
		var wheel_back: PackedScene = wheel_scenes[randi() % wheel_scenes.size()]
		var engine_scene: PackedScene = engine_scenes[randi() % engine_scenes.size()]

		var car := CarAssembler.assemble(body_scene, [wheel_front, wheel_back], engine_scene, cars, _spawn_position(i))
		var car_name := "Car%d_%s_%s+%s_%s" % [
			i,
			body_scene.resource_path.get_file().trim_suffix(".tscn"),
			wheel_front.resource_path.get_file().trim_suffix(".tscn"),
			wheel_back.resource_path.get_file().trim_suffix(".tscn"),
			engine_scene.resource_path.get_file().trim_suffix(".tscn"),
		]
		_register_car(car_name, i, car, race_controller, camera_targets)

	if camera != null:
		camera.targets = camera_targets

func _physics_process(delta: float) -> void:
	if not cosmetic_drift_enabled:
		return
	for state in _states:
		state.cooldown = maxf(state.cooldown - delta, 0.0)
		_steer(state, delta)
	_check_touches()

## The drift is drawn here rather than in _physics_process so the offsets are
## computed from the transforms the physics step just produced and applied
## before the frame is rendered. Doing it a step early leaves every wheel's art
## one frame behind its own rotation, and that jitter is the one thing a faked
## position isn't allowed to have.
func _process(_delta: float) -> void:
	if not cosmetic_drift_enabled:
		return
	for state in _states:
		_bend_road(state)
		_sync_art(state)
		# Backwards, so pruning a wrapper whose part shattered mid-loop can't
		# disturb the entries still to be visited.
		for i in range(state.art.size() - 1, -1, -1):
			var wrapper := state.art[i]
			if not is_instance_valid(wrapper):
				state.art.remove_at(i)
				continue
			_offset_art(state, wrapper)

## Wires one assembled car into its lane: put it on that lane's collision bit,
## register it for the race, and hand it a drift state.
func _register_car(car_name: String, lane: int, car: CarAssembler.AssembledCar, race_controller: RaceController, camera_targets: Array[Node2D]) -> void:
	car.root.name = car_name
	# Fake depth, for free: the car draws in its lane's layer, the same one that
	# lane's road art draws at, so the bottom lane's car reads as nearest.
	car.root.z_index = _lanes[lane].z_index
	_neutralize_autosteer(car)
	_apply_lane_collision(car, _slabs[lane])

	var state := LaneState.new()
	state.lane = lane
	state.lane_art = _lanes[lane]
	state.car = car
	# Start the bump where the car lands, rather than at x = 0: it would otherwise
	# swallow the first frames sliding itself into place.
	state.centre = _spawn_position(lane).x
	_setup_road_strip(state)
	_setup_drift_art(state)
	_states.append(state)
	camera_targets.append(car.body)

	if race_controller != null:
		race_controller.register_car(car_name, car)

## CarAssembler bolts a CarAutosteer onto every car body, and that thing
## applies a real vertical force (fast noise, hundreds of newtons) — exactly
## the up/down shove this harness fakes cosmetically instead. Left on it would
## fight the drift and shove cars into lanes they are not allowed to touch, so
## it is switched off here: nothing about a car's up/down motion is simulated.
func _neutralize_autosteer(car: CarAssembler.AssembledCar) -> void:
	if not is_instance_valid(car.body):
		return
	for child in car.body.get_children():
		if child is CarAutosteer:
			child.set_physics_process(false)

## Layers are authored on the track's per-lane ground slabs
## (Slabs/SlabN in track_multi_test.tscn): one collision bit per lane, plus the
## end wall's. Handing each car its own lane's bit is what lets drifting cars
## visually overlap without ever colliding — the physics never sees two lanes
## at once.
func _apply_lane_collision(car: CarAssembler.AssembledCar, slab: StaticBody2D) -> void:
	var layer := slab.collision_layer
	var mask := layer
	if _wall != null:
		mask |= _wall.collision_layer
	car.body.collision_layer = layer
	car.body.collision_mask = mask
	for wheel in car.wheels:
		wheel.collision_layer = layer
		wheel.collision_mask = mask

## The drawn lanes and the static ground under them, in matching order:
## Lanes/Lane0 (top lane, drawn first) .. Lane4 (bottom lane, drawn last, reads
## as nearest) over Slabs/Slab0 .. Slab4.
func _collect_lanes() -> void:
	_lanes.clear()
	_slabs.clear()
	_surface_y.clear()
	var track := get_node_or_null(track_path)
	if track == null:
		return
	_wall = track.get_node_or_null("EndWall") as CollisionObject2D
	var lanes := track.get_node_or_null("Lanes")
	var slabs := track.get_node_or_null("Slabs")
	if lanes == null or slabs == null:
		return
	for child in lanes.get_children():
		if child is Node2D:
			_lanes.append(child)
			# The road itself never moves (only its vertices bend), so the lane
			# node's own y is where that lane's road surface is.
			_surface_y.append((child as Node2D).global_position.y)
	for child in slabs.get_children():
		if child is StaticBody2D:
			_slabs.append(child)

## Picks a new bump height every so often and eases toward it, so the wander looks
## like steering rather than snapping — and walks the bump's centre onto whatever
## piece is being followed.
##
## With nothing moving forward there is no follower: the bump unwinds to nothing
## (the lane flattens back out) and the centre is left where it is, so a wreck that
## has stopped only has to relax, not travel.
func _steer(state: LaneState, delta: float) -> void:
	var follower := _follower(state)
	if follower == null:
		state.target = 0.0
		state.hold = 0.0
		state.drift = move_toward(state.drift, 0.0, DRIFT_STEER_SPEED * delta)
		return
	# Framerate-independent ease, so the centre can't jump when the piece it's
	# following changes (the body dying) and can't lag far enough behind to matter
	# when it doesn't.
	state.centre = lerpf(state.centre, follower.global_position.x, 1.0 - exp(-DRIFT_CENTRE_RESPONSE * delta))
	state.hold -= delta
	if state.hold <= 0.0:
		state.target = randf_range(-DRIFT_AMPLITUDE, DRIFT_AMPLITUDE)
		state.hold = randf_range(DRIFT_HOLD_MIN, DRIFT_HOLD_MAX)
	state.drift = move_toward(state.drift, state.target, DRIFT_STEER_SPEED * delta)

## The piece this lane's bump follows: the car's body while it is still there, or
## failing that whichever surviving piece is carrying the most forward speed. So a
## car that broke in half keeps its bump on the half that is still driving, and the
## half that stopped is simply left outside the bump, drawn flat on flat road.
##
## Null when nothing on the lane is moving forward at all — that's what flattens
## the lane, and what keeps a wreck from weaving. Only forward speed counts: a car
## bouncing vertically off a landing, or spinning in place, isn't going anywhere.
##
## The body wins ties (FOLLOWER_SPEED_MARGIN) because an intact car's body and
## wheels all move at the same speed, and centring on whichever wheel was a hair
## ahead would flicker the centre ~150px from frame to frame.
func _follower(state: LaneState) -> RigidBody2D:
	if not is_instance_valid(state.car.root):
		return null
	var best: RigidBody2D = null
	var best_speed := MIN_FORWARD_SPEED
	if is_instance_valid(state.car.body):
		best = state.car.body
		best_speed = state.car.body.linear_velocity.x
	for child in state.car.root.get_children():
		if child is RigidBody2D and child != best:
			var speed: float = (child as RigidBody2D).linear_velocity.x
			if speed > best_speed + FOLLOWER_SPEED_MARGIN:
				best_speed = speed
				best = child
	if best_speed <= MIN_FORWARD_SPEED:
		return null
	return best

## Hangs every bit of a car's artwork off a `DriftArt` wrapper, so the drift has
## something to move that isn't physics: the Polygon2D art, plus the engine
## (a Node2D of art mounted on the body). Collision shapes, wheel/engine mount
## markers and everything else stay exactly where the physics put them.
##
## Debris from parts that shatter later is handled by _sync_art, which picks up
## fragments as they appear.
func _setup_drift_art(state: LaneState) -> void:
	state.art.clear()
	state.art.append(_wrap_art(state.car.body, state.car.engine))
	for wheel in state.car.wheels:
		state.art.append(_wrap_art(wheel))

## Wraps any rigid piece of this car that hasn't got a wrapper yet — in
## practice, the fragments PartShatter spawns onto the car's root when a part
## breaks, which happens mid-race with no chance to build a wrapper at setup
## time. They get wrapped the frame they appear and drawn with the lane's drift
## like every other piece on that lane; one left alone would be drawn on the
## true ground while the road above it is bent away.
func _sync_art(state: LaneState) -> void:
	if not is_instance_valid(state.car.root):
		return
	for child in state.car.root.get_children():
		if child is RigidBody2D and child.get_node_or_null("DriftArt") == null:
			var wrapper := _wrap_art(child)
			# Offset straight away, at this piece's own x: applying it on the
			# next frame instead would draw the fragment at the wrong height for
			# one frame, and at these amplitudes a one-frame hop is visible.
			_offset_art(state, wrapper)
			state.art.append(wrapper)

## Wraps `part`'s Polygon2D children (and `extra`, if given) in a new child node
## the drift can move. `reparent(wrapper, false)` keeps each child's local
## transform and the wrapper starts at its parent's origin, so nothing moves on
## the frame this runs.
func _wrap_art(part: Node2D, extra: Node2D = null) -> Node2D:
	var wrapper := Node2D.new()
	wrapper.name = "DriftArt"
	part.add_child(wrapper)
	for child in part.get_children():
		if child is Polygon2D or (extra != null and child == extra):
			child.reparent(wrapper, false)
	return wrapper

## Draws one wrapper's art at the offset its own piece's x calls for, in world
## space, so the wrapper is a plain translation that no rotation of the part can
## touch: a wheel's art still spins about its own centre, it's just drawn a
## little higher or lower. Offsetting in the part's own space instead would
## rotate the offset along with the wheel, swinging the art around the axle
## rather than moving it — the local-space version is what looked broken.
##
## Read off the piece rather than taken as one offset for the whole car on
## purpose: it's what lets a wreck that broke in half have one half drawn on the
## bump and the other lying still on flat road.
func _offset_art(state: LaneState, wrapper: Node2D) -> void:
	var part := wrapper.get_parent() as Node2D
	if part == null:
		return
	var pos := part.global_position
	wrapper.global_position = pos + Vector2(0.0, state.offset_at(pos.x))

## Rebuilds a lane's authored road art — four corners, which can only slide as a
## slab — as a strip of columns, so each column can be pushed up or down on its
## own and the road can bend along with the cars on it. Baked once: the columns' x
## never change, only their y is rewritten per frame (see _bend_road).
func _setup_road_strip(state: LaneState) -> void:
	var road := state.lane_art.get_node_or_null("Road") as Polygon2D
	if road == null:
		push_error("Lane %d's road art has no 'Road' Polygon2D to bend (see track_multi_test.tscn)." % state.lane)
		return
	# The authored road is a plain rectangle, but PackedVector2Array has no
	# get_rect(), so take the bounds of its corners by hand.
	var left := road.polygon[0].x
	var right := road.polygon[0].x
	var top := road.polygon[0].y
	var bottom := road.polygon[0].y
	for point in road.polygon:
		left = minf(left, point.x)
		right = maxf(right, point.x)
		top = minf(top, point.y)
		bottom = maxf(bottom, point.y)
	state.road = road
	state.road_top = top
	state.road_bottom = bottom
	# + 1 so the last column lands exactly on the far end of the road.
	var columns := maxi(2, int(ceilf((right - left) / ROAD_COLUMN_WIDTH)) + 1)
	state.road_x = PackedFloat32Array()
	state.road_x.resize(columns)
	for i in columns:
		state.road_x[i] = lerpf(left, right, float(i) / float(columns - 1))

## Bends one lane's road strip into that lane's current drift. Every column's y is
## recomputed from the same offset_at() the pieces on this lane are drawn with, so
## the road's height under a piece is exactly that piece's offset — the pieces and
## the road they're standing on can't disagree, because there's only one rule.
func _bend_road(state: LaneState) -> void:
	if state.road == null or not is_instance_valid(state.road):
		return
	var columns := state.road_x.size()
	var points := PackedVector2Array()
	points.resize(columns * 2)
	var left := state.road.global_position.x
	# Top edge left to right, then bottom edge right to left: a proper closed
	# rectangle, which is what the Polygon2D triangulation expects. The first
	# `columns` entries are the top row, the rest are the bottom row mirrored.
	for i in columns:
		var offset := state.offset_at(left + state.road_x[i])
		var x := state.road_x[i]
		points[i] = Vector2(x, state.road_top + offset)
		points[columns * 2 - 1 - i] = Vector2(x, state.road_bottom + offset)
	state.road.polygon = points

func _check_touches() -> void:
	for i in _states.size():
		var a := _states[i]
		if not _is_racing(a) or a.cooldown > 0.0:
			continue
		for j in range(i + 1, _states.size()):
			var b := _states[j]
			if not _is_racing(b) or b.cooldown > 0.0:
				continue
			if _would_touch(a, b):
				_touch(a, b)

func _is_racing(state: LaneState) -> bool:
	return is_instance_valid(state.car.body)

## Faked contact, out of nothing but the two cars' drawn positions: close enough
## along the strip, close enough across it. Nothing else is consulted — the cars
## never actually collide, this is the stand-in for it.
func _would_touch(a: LaneState, b: LaneState) -> bool:
	var pos_a := a.visual_position()
	var pos_b := b.visual_position()
	if absf(pos_a.x - pos_b.x) > TOUCH_X_DISTANCE:
		return false
	return absf(pos_a.y - pos_b.y) <= TOUCH_Y_DISTANCE

## Sparks, and nothing else: the faked contact deliberately has no say in
## either car's velocity, so a rubbing pair carries on driving exactly as its
## own physics says it should.
func _touch(a: LaneState, b: LaneState) -> void:
	a.cooldown = TOUCH_COOLDOWN
	b.cooldown = TOUCH_COOLDOWN
	_spawn_sparks((a.visual_position() + b.visual_position()) * 0.5)

func _spawn_sparks(at: Vector2) -> void:
	var particles := CPUParticles2D.new()
	particles.name = "Sparks"
	particles.z_index = SPARK_Z
	particles.one_shot = true
	particles.amount = 14
	particles.lifetime = 0.35
	particles.explosiveness = 1.0
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 90.0
	particles.initial_velocity_max = 240.0
	particles.gravity = Vector2(0.0, 500.0)
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = SPARK_COLOR
	add_child(particles)
	particles.global_position = at
	particles.emitting = true
	var cleanup := get_tree().create_timer(particles.lifetime + 0.2)
	cleanup.timeout.connect(particles.queue_free)

## SPAWN_HEIGHT_ABOVE_LANE above the lane's own road surface, so the car still
## drops onto it under real gravity. World space, not lane-local: the cars are
## not parented to the lanes.
func _spawn_position(lane: int) -> Vector2:
	return Vector2(SPAWN_X + lane * SPAWN_STAGGER_X, _surface_y[lane] - SPAWN_HEIGHT_ABOVE_LANE)

## Builds the player's selected garage car into the race. Reuses the exact
## part scene paths stored on the CarModelData, so the racing rig is the
## same body/wheels/engine the garage preview (and world player) show.
func _assemble_player_car(car_data: CarModelData, lane: int, parent: Node) -> CarAssembler.AssembledCar:
	var body_scene: PackedScene = load(car_data.body.scene_path)
	var wheel_scenes: Array[PackedScene] = []
	for wheel in car_data.wheels:
		if wheel != null and not wheel.scene_path.is_empty():
			wheel_scenes.append(load(wheel.scene_path))
	var engine_scene: PackedScene = null
	if car_data.engine != null and not car_data.engine.scene_path.is_empty():
		engine_scene = load(car_data.engine.scene_path)
	return CarAssembler.assemble(body_scene, wheel_scenes, engine_scene, parent, _spawn_position(lane))
