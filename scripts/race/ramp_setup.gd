extends Node2D
## Single-car ramp jump: the player's garage car spawns on a flat start,
## rolls downhill under real gravity — same rig, same always-on engine
## every race car uses, nothing here is player-driven — launches off a
## ramp, and (hopefully) clears the gap to land on the far side.
##
## Reuses CarAssembler.assemble_from_car_data() (see car_assembler.gd) for
## the actual car-building — the same call random_race_setup.gd makes for
## the player's own lane — and the sibling RaceController purely for its
## Escape-to-exit handling. finish_x/max_duration are set far beyond
## anything this track can produce so RaceController's finish-line/win
## logic never fires; there's nothing to race against here, just a jump.

@export var race_controller_path: NodePath
@export var camera_path: NodePath

## On the flat start, comfortably clear of the floor. Went the other
## direction from an earlier attempt at this: a smaller gap (-3, even
## -15) turned out to make the actual problem WORSE, not better — logged
## the raw pre-clamp velocity every step (see the settle window below)
## and found the "bounce" isn't a drop-impact at all, it's the physics
## solver fighting a genuine overlap between a wheel and the floor at
## spawn, recomputing a large push-out correction fresh every step for
## as long as the overlap persists, shrinking only as those pushes
## gradually clear it. A wheel's own radius (up to ~47 on the chunkiest
## catalog parts) means a few pixels of body clearance can still leave
## the wheel itself buried; this is comfortably past that for every part
## in the catalog, so there's nothing left to correct in the first place.
const SPAWN_POSITION := Vector2(-200.0, -60.0)

## A permanent kick to every wheel's own rotation, for this whole scene.
## This is NOT CarBody.boost_force (the finish-line mechanic — a flat
## push on the chassis): a wheel forces its own rotation to
## target_angular_velocity every physics step regardless of what's
## pushing the chassis (see CarWheel), so on a weak engine (the worst
## tier-1 parts spin the wheels at just 0.8 rad/s) that slow-spinning
## wheel just acts as a drag brake against almost any body force — tried
## up to 160000 (matching RaceController's own finish slam) and most of
## it either got eaten by that resistance or, past some threshold,
## overwhelmed it entirely into an unrecoverable runaway spin that
## shattered the car in under 2 seconds. Boosting through the SAME
## mechanism the wheel actually obeys — its own target speed — sidesteps
## the fight completely and gives a real, bounded launch.
##
## A single fixed target doesn't read as "going downhill" though: the
## wheel ramps up to it in well under a second and then just holds, so
## once the car's moving there's nothing left for gravity to visibly add
## — same flavor of cap as the original bug, just no longer stalling.
## Instead the target itself climbs from START_ANGULAR_VELOCITY to
## MAX_ANGULAR_VELOCITY over the length of the Start+Downhill stretch (see
## _physics_process), so the car keeps genuinely speeding up for the
## whole way down, then holds at the max from there on — never dropping
## back down, so it's still always moving once it reaches the flat.
##
## MAX_ANGULAR_VELOCITY is well past the strongest engine in the catalog
## (the jet's 8.0 rad/s) — safe to push higher than the earlier flat/
## instant version of this boost dared to (that one snapped a fragile
## wheel clean off at a sudden 25 rad/s) specifically because part damage
## is paused for the descent (_disable_damage/_rearm_damage) and the
## climb here is gradual over several real seconds, not a single-step
## jump.
## Chasing the whole climb from as low as 1.0 rad/s worked fine when
## the Downhill was short — this same target value now has to cover a
## much longer x range (the tripled Downhill), which spreads its climb
## out much more gradually per unit of distance travelled. Set too low,
## the car never gets enough grip within the short flat Start segment to
## actually start moving in the first place — a heavy (MASS_MULTIPLIER)
## chassis just sits there barely rocking in place, since there's no
## slope yet to help and the target barely rises within that short a
## stretch. High enough here that the car reliably gets underway on the
## flat before the real, gradual climb across the hill even begins.
const START_ANGULAR_VELOCITY := 8.0
const MAX_ANGULAR_VELOCITY := 45.0
## How fast the wheel's spin ramps up to whatever its current target is —
## brisk enough to keep up with the target's own climb without lagging
## noticeably behind, and with MASS_MULTIPLIER now making the chassis
## much heavier, a snappier ramp is what keeps the wheel actually pulling
## that extra weight along instead of just slipping under it.
const MOTOR_ACCEL := 45.0
## Extra wheel target speed (rad/s) per radian the chassis is currently
## tilted nose-down. The car settles to roughly the local slope's own
## angle as it rolls along it (rolling contact naturally matches the
## chassis's pitch to the ground under it), so reading body.rotation is
## a direct, physical stand-in for "how steep is the ground right here"
## — no need to hand-author a slope-vs-x lookup, and it stays correct
## automatically however the curve's shape changes. Only counts while
## climbing (see the progress < 1.0 guard at the call site) and only
## the nose-down direction (negative/uphill tilt contributes nothing).
##
## The combined (distance climb + this) target is clamped to
## MAX_ANGULAR_VELOCITY at the call site, not left to add up freely —
## tried that first and even a single steep stretch of the curve (~30°,
## already well into the distance climb's own high end) pushed the
## total target past 60, which is untested territory this whole rig was
## never tuned for: speeds spiralled into the thousands, wheels
## snapped, and the car eventually tunnelled clean through the end of
## the track into the void. The clamp keeps this a "reach the same
## proven-safe top speed sooner on steep ground" boost, not a way past
## it.
const DOWNHILL_BOOST_PER_RADIAN := 8.0

## World x range the wheel target climbs across — the Start segment (car
## needs to already be moving before it even reaches the slope) through
## the end of the Downhill (node position.x 500 + its local run of 7500).
## Past this the target holds at MAX_ANGULAR_VELOCITY for good.
const CLIMB_START_X := -300.0
const CLIMB_END_X := 8000.0
## At the speeds this hill now reaches, basically ANY ground contact —
## the ramp's own lip, touching down off the jump — throws a Δv well
## past a fragile tier-1 wheel's already-low durability. Re-arming right
## after one of those spots just moves the same "breaks the moment
## tracking comes back on" problem around rather than fixing it. So
## durability only comes back right at the very end, a short stretch
## before the EndWall (position.x 12550, front face at 12510) —
## everything before that (the slide, the launch, the landing) is
## guaranteed to leave the car intact to actually make the jump; the
## wall is the one deliberate obstacle meant to end the run.
const DAMAGE_REARM_X := 12350.0

## How much heavier this scene makes the car's body than its part data
## says — a plain PinJoint2D wheel has no suspension to soak up contact
## noise (see _smooth_ride), and more mass
## means any given contact impulse moves the chassis proportionally
## less, which reads as weight instead of the light, jumpy bounce a
## lighter body was getting knocked around by. Also gives the wheels'
## forced spin more grip to bite into, converting more of it into real
## chassis speed instead of slipping — part of why MOTOR_ACCEL went up
## alongside this.
const MASS_MULTIPLIER := 3.0

var _player_car: CarAssembler.AssembledCar
var _damage_rearmed := false
var _gravity_reduced := false

func _ready() -> void:
	# Debug aid while tuning this track's geometry: draws every collision
	## shape (floor slabs, the downhill/ramp wedges, the end wall) with the
	# engine's normal translucent-green overlay, same as toggling Debug >
	# Visible Collision Shapes in the editor, but scoped to just this scene
	# instead of every run. Remove once the track's settled.
	get_tree().debug_collisions_hint = true

	var race_controller := get_node(race_controller_path) as RaceController
	var camera := get_node(camera_path) as CameraFollow

	var cars_container := Node2D.new()
	cars_container.name = "Cars"
	add_child(cars_container)

	var player_car := Inventory.get_selected_car()
	var car := CarAssembler.assemble_from_car_data(player_car, cars_container, SPAWN_POSITION)
	if car == null:
		return
	car.root.name = "Player_%s" % player_car.display_name
	race_controller.register_car(car.root.name, car)
	if camera != null:
		camera.targets = [car.body]
	_neutralize_autosteer(car)
	_disable_damage(car)
	_smooth_ride(car)
	_add_weight(car)
	_double_gravity(car)

	# Freeze every physics body in the rig for a couple of steps — not
	# just the chassis — before anything (gravity, the wheel motor, the
	# solver) gets a chance to run at all, giving the rig's freshly
	# instantiated PinJoint2D connections one moment to exist before
	# anything starts moving.
	car.body.freeze = true
	for wheel in car.wheels:
		wheel.freeze = true

	_player_car = car
	for wheel in car.wheels:
		wheel.target_angular_velocity = 0.0
		wheel.motor_accel = MOTOR_ACCEL

## How many physics steps the rig stays frozen before unfreezing and
## starting the settle-then-climb sequence below.
const FREEZE_STEPS := 3
## Once unfrozen, held at zero wheel rotation for this long so the car
## finishes settling under plain gravity before the motor's own kick
## lands on top of it too.
##
## SPAWN_POSITION's clearance is what actually matters for avoiding a
## visible "hop" at spawn, not this window on its own — too small a gap
## (tried -3, even the original -15) left a wheel's own collision shape
## still slightly overlapping the floor at spawn, and the solver was
## recomputing a large push-out correction fresh every physics step for
## as long as that overlap persisted, not just once — logged the raw
## pre-clamp velocity every step to confirm (a magnitude-40 clamp landed
## on it each step, and the RAW value was still ~330+ the very next step
## regardless). SPAWN_POSITION now clears every wheel in the catalog with
## room to spare, so there's no overlap left to correct in the first
## place; this window+clamp just keeps the resulting ordinary fall from
## that height looking gentle instead of like a sudden drop.
const SETTLE_DURATION := 0.3
## Body speed is clamped to this during that same window.
const SETTLE_MAX_SPEED := 40.0

var _elapsed := 0.0
var _freeze_steps_left := FREEZE_STEPS

func _physics_process(delta: float) -> void:
	if _player_car == null or not is_instance_valid(_player_car.body):
		return
	if _freeze_steps_left > 0:
		_freeze_steps_left -= 1
		if _freeze_steps_left == 0:
			_player_car.body.freeze = false
			for wheel in _player_car.wheels:
				if is_instance_valid(wheel):
					wheel.freeze = false
		return
	_elapsed += delta
	if _elapsed < SETTLE_DURATION:
		# Just a gentle fall speed cap for the actual drop from
		# SPAWN_POSITION down to the road, on top of the freeze above.
		var body := _player_car.body
		var speed := body.linear_velocity.length()
		if speed > SETTLE_MAX_SPEED:
			body.linear_velocity *= SETTLE_MAX_SPEED / speed
		return
	var progress := inverse_lerp(CLIMB_START_X, CLIMB_END_X, _player_car.body.global_position.x)
	var target := lerpf(START_ANGULAR_VELOCITY, MAX_ANGULAR_VELOCITY, clampf(progress, 0.0, 1.0))
	if progress < 1.0:
		target = clampf(target + _downhill_boost(_player_car.body.rotation), START_ANGULAR_VELOCITY, MAX_ANGULAR_VELOCITY)
	for wheel in _player_car.wheels:
		if is_instance_valid(wheel):
			wheel.target_angular_velocity = target
	if not _damage_rearmed and _player_car.body.global_position.x >= DAMAGE_REARM_X:
		_damage_rearmed = true
		_rearm_damage()
	if not _gravity_reduced and _player_car.body.global_position.x >= CLIMB_END_X:
		_gravity_reduced = true
		_reduce_gravity_on_ramp(_player_car)

## Positive rotation is nose-down in this scene (confirmed empirically —
## the car reads ~20-40° through the steepest part of the Downhill curve),
## so only positive tilt counts as "downhill" here; a nose-up moment
## (settling, a bounce) contributes no boost rather than working against
## the car.
func _downhill_boost(body_rotation: float) -> float:
	return maxf(0.0, body_rotation) * DOWNHILL_BOOST_PER_RADIAN

## CarAssembler bolts a CarAutosteer onto every car body — a real vertical
## force (fast noise, hundreds of newtons) that makes cars wander up/down
## a bit, meant for the multi-lane drag strip where that's what lets cars
## drift into a neighboring lane. This is a single-lane jump: any up/down
## wander is just unwanted noise fighting a clean run down the hill and a
## predictable launch arc, so it's switched off — same pattern
## single_lane_race_setup.gd uses to neutralize it for its own reasons.
func _neutralize_autosteer(car: CarAssembler.AssembledCar) -> void:
	if not is_instance_valid(car.body):
		return
	for child in car.body.get_children():
		if child is CarAutosteer:
			child.set_physics_process(false)

## Each wheel bolts to the body through a plain PinJoint2D — a rigid pin
## with no spring or damping, i.e. no suspension. Any tiny per-step noise
## in how the solver resolves wheel-ground contact transmits straight
## into the chassis undamped, and at the wheel speeds this scene reaches
## (up to MAX_ANGULAR_VELOCITY, well past anything the drag strip ever
## runs) that noise becomes a visible, constant jitter — reads as "the
## ground is uneven" even on this track's single dead-straight downhill
## slope. Godot's own per-body damping smooths exactly this kind of
## continuous contact noise without touching CarBody/CarWheel/
## CarAssembler (every other scene's cars stay exactly as rigid as
## before). REPLACE mode so this is the car's only source of damping —
## with COMBINE (the default) it'd stack on top of the project's own
## default damp and be harder to reason about.
## GRAVITY_SCALE (below) means a much harder landing than this value was
## originally tuned for — the extra impact speed at touchdown was enough
## to fully tumble the chassis end-over-end into landing upside down
## with no suspension to catch it, wheels then spinning uselessly
## forever with nothing to grip. Damping rotation harder absorbs that
## extra tumble before it can complete a flip, without touching forward
## speed at all (angular_damp is rotation-only).
const ANGULAR_DAMP := 40.0

func _smooth_ride(car: CarAssembler.AssembledCar) -> void:
	if not is_instance_valid(car.body):
		return
	car.body.angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	car.body.angular_damp = ANGULAR_DAMP

func _add_weight(car: CarAssembler.AssembledCar) -> void:
	if is_instance_valid(car.body):
		car.body.mass *= MASS_MULTIPLIER

## RigidBody2D.gravity_scale, not the project's global gravity setting —
## scoped to just this rig so nothing else in the game gets pulled down
## twice as hard. Applied to the wheels too, not just the chassis: they're
## separate RigidBody2Ds connected only by a plain PinJoint2D, so leaving
## them at normal gravity while the body falls twice as fast would just
## stress that joint instead of actually speeding up the whole car.
const GRAVITY_SCALE := 2.0

func _double_gravity(car: CarAssembler.AssembledCar) -> void:
	if is_instance_valid(car.body):
		car.body.gravity_scale = GRAVITY_SCALE
	for wheel in car.wheels:
		if is_instance_valid(wheel):
			wheel.gravity_scale = GRAVITY_SCALE

## Applied once at CLIMB_END_X (see _physics_process) — the same point
## the Ramp itself begins, so this fires right as the car reaches it.
## Below normal (1.0), not just back down to it: the doubled
## GRAVITY_SCALE is what gives the downhill its fast, weighty feel, but
## carried through the jump it yanks the car back down almost as soon as
## it leaves the ramp. Wheels get the same reduction as the body, same
## reasoning as _double_gravity — keeps the PinJoint2D from being asked
## to hold two differently-falling bodies together.
const RAMP_GRAVITY_SCALE := 0.75

func _reduce_gravity_on_ramp(car: CarAssembler.AssembledCar) -> void:
	if is_instance_valid(car.body):
		car.body.gravity_scale = RAMP_GRAVITY_SCALE
	for wheel in car.wheels:
		if is_instance_valid(wheel):
			wheel.gravity_scale = RAMP_GRAVITY_SCALE

## CarPartDamage tracks impact momentum (mass * |Δv| per physics step) and
## breaks a part once enough of it accumulates — meant for real collisions
## (slamming into the end wall, a pileup), not the ordinary jolts of a
## fast, bumpy ride down a real slope. A junk wheel's own shape isn't
## round, so even a clean run down this hill throws enough per-step
## velocity spikes to snap one off well before the car ever reaches the
## ramp, which defeats the whole point of a jump scene: the player should
## always get to see their car launch, not lose a wheel partway down a
## hill they had no control over. Only paused for the descent, though —
## see _rearm_damage, called once the car reaches the flat Runway — so a
## real crash into the end wall still breaks the car like it should.
var _damage_trackers: Array[CarPartDamage] = []

func _disable_damage(car: CarAssembler.AssembledCar) -> void:
	var bodies: Array[RigidBody2D] = [car.body]
	for wheel in car.wheels:
		bodies.append(wheel)
	for body in bodies:
		if not is_instance_valid(body):
			continue
		for child in body.get_children():
			if child is CarPartDamage:
				child.set_physics_process(false)
				_damage_trackers.append(child)

## Called once the car clears DAMAGE_REARM_X (see _physics_process): the
## descent's own contact noise is done tripping breakage by now, so hand
## durability back control for whatever happens next — the ramp launch,
## the landing, or slamming into the end wall. resync() first so the
## first step back doesn't compare against a Δv reading stale from before
## the pause and register a hit that never happened.
func _rearm_damage() -> void:
	for tracker in _damage_trackers:
		if is_instance_valid(tracker):
			tracker.resync()
			tracker.set_physics_process(true)
