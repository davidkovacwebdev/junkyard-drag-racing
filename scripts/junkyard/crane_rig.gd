class_name CraneRig
extends JunkyardCrane
## The scrap crane with someone in the cab — the machine the player drives in
## the crane pen, and the whole of that minigame.
##
## `JunkyardCrane` supplies the artwork and the rigging; this adds the driver,
## and the driver has exactly two controls:
##
##   - A / D roll the trolley along the boom, lining the claw up over a spot in
##     the heap (arrow keys do the same thing, for anyone who'd rather not reach
##     for WASD). They keep working while the claw goes down, until it shuts,
##     so a drop can be steered,
##   - Space drops the claw, and Space again shuts it. The claw eases to a stop
##     on the first thing it touches, hangs there open for `auto_close_delay`
##     and then shuts by itself; pressing Space before that shuts it right
##     where it is. Either way the winch then hauls up whatever the jaws have
##     hold of.
##
## The claw here is real. Its two clamshell halves are heavy `RigidBody2D`s in
## the same physics world as the heap, servoed every tick toward the pose the
## rigging says they should have (hinge under the block, turned by `jaw_open`).
## Heavy is the point: going down, the shells' outer faces shove the junk aside
## instead of passing through it, and closing, their tips sweep in along the
## bottom and scoop up what's between them. Something too big or too wedged
## wins — the shell stalls against it and the claw comes up half open, maybe
## dropping what it had.
##
## The winch is deliberately not on a key of its own: the claw finds the top of
## the pile by itself. The player picks where (A / D) and when the jaws bite
## (Space) — early, to snatch at something on the way down, or left alone to
## shut by itself once it's settled around a piece.
##
## What you walk away with is decided by physics, not a query: when the claw is
## back at the trolley, every heap piece whose centre is inside the closed ring
## is the haul. Every dig costs `grab_cost` up front, catch or miss; being told
## you can't afford one is free.
##
## The machine reports, it doesn't bank: `dug` fires once per piece with the
## item and what it was worth, `dig_finished` when the claw is back at the
## trolley, and the pen (or whoever else owns the crane) decides what to do with
## the haul.
##
## The claw swings like a real pendulum on its cable. The trolley speeds up and
## brakes rather than starting and stopping dead, and every start, stop and
## knock against a rail end sets the claw swinging; a long cable swings slow
## and wide. Lining up a dig means letting the swing die down first, or timing
## the drop to it. Once the shells are in the junk the heap holds them, so the
## swing dies fast.
##
## Shutting stops on the first piece both shells are pressing on, so the jaws
## hold it rather than squeezing on until it pops out from between them.

## One piece hauled out of the heap: `part` is the car part it was (null for
## plain junk), `scrap` what the junk is worth. Exactly one of them is set.
##
## Fires once per piece in a haul, *before* the piece is freed, so a handler can
## still read it.
signal dug(item: Node2D, part: PartData, scrap: int)
## The claw came up empty.
signal missed()
## The wallet couldn't cover a dig, so the claw never went down.
signal denied()
## The claw is back at the trolley and the dig is over. `caught` is how many
## pieces came up — 0 for a miss. The crane is idle again by the time this
## lands.
signal dig_finished(caught: int)

const SIDES: Array[float] = [-1.0, 1.0]

## The heap this crane works: what counts as loot inside the shut claw.
@export var heap_path: NodePath = ^"../Heap"
## What one dig costs, taken off the wallet as the claw sets off, whether or not
## it comes up with anything.
@export var grab_cost: int = 100
## Trolley top speed along the boom.
@export var trolley_speed: float = 380.0
## How hard the trolley speeds up and brakes, px/s². Lower is a heavier,
## swingier crane: every change of speed is a shove on the hanging claw.
@export var trolley_accel: float = 700.0
## How far below its parked height the winch will pay the cable out at most.
## A limit, not a destination: the claw stops wherever the shells stall and only
## comes down this far when nothing stops it.
@export var dig_depth: float = 260.0
## How fast the winch pays out and hauls back.
@export var dig_speed: float = 300.0
## How much further the claw eases down after the shells first touch
## something, before it stops and shuts. About half the open claw's reach, so
## the tips sink around the piece they met rather than stopping on top of it.
@export var bite_depth: float = 22.0
## The jaws have to be shut at least this far (1 open, 0 shut) before a piece
## both shells are pressing on stops them.
@export var bite_min_close: float = 0.65
## How long the shells take to open or shut. Slow enough to scoop: a snap shut
## just flicks junk out from under the tips.
@export var jaw_time: float = 0.45
## How long the claw hangs open once it has settled, waiting for Space,
## before it shuts by itself.
@export var auto_close_delay: float = 0.35
## How long a hauled piece takes to disappear once the claw is up.
@export var vanish_time: float = 0.45
## Cleared by whatever owns the crane to take the controls off the player (a
## scene change on its way, a cutscene); the claw ignores A / D / Space then.
@export var controls_enabled: bool = true

@export_group("Swing")
## Gravity on the swinging claw, px/s². With the cable length it sets the
## swing's pace: a 300 px cable swings back and forth in about 3.5 s.
@export var swing_gravity: float = 980.0
## How much of the trolley's change of speed reaches the claw. 1 is a free
## pendulum, which swings wide enough off one stop to make aiming a chore.
@export var swing_kick: float = 0.8
## How fast a free swing dies down, per second.
@export var swing_damping: float = 0.5
## How fast it dies while the shells are pressed into the junk.
@export var swing_drag_in_heap: float = 4.0
## Widest the swing may get, radians either side of hanging straight down.
@export var max_swing: float = 0.55
## Swings narrower than this turn round without a creak.
@export var creak_swing: float = 0.07
## The claw never hangs dead still: whenever its swing dies below this
## (radians), a gentle breeze nudges it along with its own motion until it's
## back up to it. Not while the shells are in the junk.
@export var min_swing: float = 0.04
## How hard that nudge is, radians/s².
@export var min_swing_push: float = 0.3

## Heap items with a handle (a `grab_point()`, like the Scrap Dealer's head)
## count as held once the shut ring's centre is within this many claw radii of
## it, pinched or not.
@export var handle_reach: float = 1.6

@export_group("Shell physics")
## Mass of each shell. Heap junk weighs 1-30, so this is what lets the shells
## push through the pile instead of riding up on it — but a floor, or a pile
## packed against it, still stops them.
@export var shell_mass: float = 240.0
## Top speed the servo may drive a shell at. Caps the shove a shell gives junk
## when it's been held back and snaps free.
@export var servo_speed: float = 1400.0
## Top spin rate the servo may turn a shell at, radians per second.
@export var servo_spin: float = 8.0
## How hard a shell holds its angle against junk shoving on its tip, as a
## multiple of a mass hung out at the tip. Too low and the pile pries the open
## claw flat; too high and nothing can ever jam it.
@export var shell_stiffness: float = 3.0
## How far a shell may trail the hinge before it counts as held back.
@export var stall_lag: float = 8.0
## How far, in radians, a shell may be turned off its pose before it counts as
## held back — a claw jammed open on something too big has stopped too.
@export var stall_angle: float = 0.3
## Physics ticks in a row a shell has to be held back for the claw to call it
## the bottom. A few, so one knock off a tumbling chunk doesn't stop the dig.
@export var stall_ticks: int = 5
## How long the haul gets to settle in the shut claw before it's counted.
@export var settle_time: float = 0.3
## Shortest gap between two shove thuds, so a claw ploughing through a pile
## rumbles rather than machine-guns.
@export var shove_gap: float = 0.14

var _digging: bool = false
## Set by the second Space press (or `close_claw()`) while the claw is down:
## stop sinking and shut the jaws.
var _close_requested: bool = false
## True from the moment the claw starts down until the jaws start to shut —
## the window in which Space means "close" rather than "drop".
var _awaiting_close: bool = false
var _heap: TrashHeap = null
## The two clamshell halves, left then right (same order as `SIDES`).
var _shells: Array[RigidBody2D] = []
## Seconds until another shove thud may play.
var _shove_cooldown: float = 0.0
## How deep the winch paid out on the last dig: the hoist length the shells
## stalled at (or `dig_depth`, if nothing stopped them). Zero until the first
## dig.
var last_bite_hoist: float = 0.0
## How fast the claw is swinging, radians per second (`_sway` is the angle).
var _swing_speed: float = 0.0
## The trolley's current speed along the boom (in `trolley` units).
var _trolley_velocity: float = 0.0
## Where the cable's top end was last tick and how fast it was moving, in this
## node's x: the change in that speed is what shoves the claw.
var _last_anchor_x: float = 0.0
var _anchor_velocity: float = 0.0

func _ready() -> void:
	super._ready()
	_heap = _find_heap()
	for side in SIDES:
		_shells.append(_build_shell(side))
	_set_shells_solid(false)
	_last_anchor_x = -trolley

## The base class's idle sway is a sine for a parked crane; this one swings for
## real, in `_swing()`, on the physics tick the shells are driven on.
func _process(_delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	_swing(delta)
	_drive_shells(delta)
	_shove_cooldown = maxf(_shove_cooldown - delta, 0.0)
	# The claw hangs at -trolley, so pressing right has to push the trolley back
	# toward the mast. That's the whole of the player's control: where in the
	# heap the claw goes down. It still steers while the claw is on its way
	# down and hanging open; once the jaws start to shut, or with the controls
	# taken away, the trolley just brakes to a stop.
	var run := 0.0
	if controls_enabled and (not _digging or _awaiting_close):
		run = _axis(KEY_A, KEY_D, &"ui_left", &"ui_right")
	_roll_trolley(run, delta)
	if not controls_enabled:
		return
	if _digging:
		if _awaiting_close and Input.is_action_just_pressed(&"ui_accept"):
			close_claw()
		return
	if Input.is_action_just_pressed(&"ui_accept"):
		dig()

## Speed the trolley up toward `run` (-1..1 of top speed) or brake it, and move
## it. Running into a rail end stops it dead, which the claw feels.
func _roll_trolley(run: float, delta: float) -> void:
	_trolley_velocity = move_toward(_trolley_velocity, -run * trolley_speed, trolley_accel * delta)
	if _trolley_velocity == 0.0:
		return
	var before := trolley
	place_trolley(trolley + _trolley_velocity * delta)
	if trolley == before:
		_trolley_velocity = 0.0

## One tick of the pendulum: gravity pulls the claw back under the trolley, and
## the trolley's change of speed shoves it the other way (a trolley that
## brakes leaves the claw swinging on ahead). Damped a little in the air and a
## lot once the shells are in the junk. Every big swing creaks as it turns.
func _swing(delta: float) -> void:
	if delta <= 0.0:
		return
	var anchor_x := -trolley
	var anchor_velocity := (anchor_x - _last_anchor_x) / delta
	var anchor_accel := (anchor_velocity - _anchor_velocity) / delta
	_last_anchor_x = anchor_x
	_anchor_velocity = anchor_velocity
	var length := maxf(hoist, 1.0)
	var in_heap := _digging and _shells_touching()
	var damping := swing_drag_in_heap if in_heap else swing_damping
	var before := _swing_speed
	_swing_speed += (-swing_gravity / length * sin(_sway) - anchor_accel * swing_kick / length * cos(_sway)
			- damping * _swing_speed + _breeze(length, in_heap)) * delta
	_sway += _swing_speed * delta
	if absf(_sway) > max_swing:
		_sway = signf(_sway) * max_swing
		_swing_speed = 0.0
	if signf(before) != signf(_swing_speed) and absf(_sway) > creak_swing:
		Sfx.play_at(&"cable_creak", to_global(Vector2(anchor_x, -mast_height)),
				lerpf(-16.0, -6.0, clampf(absf(_sway) / max_swing, 0.0, 1.0)))
	_update_claw()
	queue_redraw()

## The push that keeps the claw from ever hanging dead still: along the way
## it's already swinging, and only while the swing (angle and speed together,
## as the amplitude it would reach) is below `min_swing`.
func _breeze(length: float, in_heap: bool) -> float:
	if in_heap or min_swing <= 0.0:
		return 0.0
	var omega := sqrt(swing_gravity / length)
	var amplitude := Vector2(_sway, _swing_speed / omega).length()
	if amplitude >= min_swing:
		return 0.0
	return min_swing_push * (signf(_swing_speed) if _swing_speed != 0.0 else 1.0)

## How far the claw is swinging off straight down right now, radians.
func swing_angle() -> float:
	return _sway

## Shut the claw now, if it's on its way down or hanging open waiting to be
## shut. What Space does mid-dig; a test or a cutscene can call it too.
func close_claw() -> void:
	if _awaiting_close:
		_close_requested = true

## True while the claw is down and open, waiting for Space (or
## `auto_close_delay`) to shut it.
func is_awaiting_close() -> bool:
	return _awaiting_close

## True while the claw is working, so a HUD can grey itself out.
func is_digging() -> bool:
	return _digging

## The heap this crane works, if it can find one.
func heap() -> TrashHeap:
	return _heap

## The two shell bodies, left then right.
func shells() -> Array[RigidBody2D]:
	return _shells.duplicate()

## Work the claw: sink it open until the shells stall, shut them on whatever is
## between them, haul the lot back to the trolley, and bank what stayed inside.
##
## Every dig costs `grab_cost`, taken as the claw sets off, whatever it comes up
## with; being told you can't afford one is free. Await this if you want to know
## when the claw is free again; `dig_finished` reports the same moment to anyone
## who didn't.
func dig() -> void:
	if _digging:
		return
	var heap := _heap
	if heap == null:
		return
	# Check the wallet before the claw moves, not after: finding out you can't
	# afford a dig is worth a line of text, not a whole dive into the heap.
	if not Inventory.can_afford(grab_cost):
		Sfx.play(&"denied", -6.0, 0.0)
		denied.emit()
		return
	# Paid up front, like a coin in an arcade claw: the money is for the go, not
	# for what comes up, so a miss costs the same as a catch.
	Inventory.spend_money(grab_cost)
	Sfx.play(&"cash_register", -10.0, 0.05)
	_digging = true
	_set_shells_solid(true)

	_close_requested = false
	_awaiting_close = true
	await _sink()
	# Settled and open: hang there a beat for the player to say bite, then bite
	# anyway.
	var waited := 0.0
	while not _close_requested and waited < auto_close_delay and is_inside_tree():
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	_awaiting_close = false
	_close_requested = false
	Sfx.play_at(&"crane_clang", jaw_mouth_global(), -2.0)
	var pinched := await _bite(heap)
	# A beat for the shells to finish grinding shut on anything that held them.
	await get_tree().create_timer(0.15).timeout
	var gripped := _grip(heap, pinched)
	await _haul_up(gripped)
	if settle_time > 0.0:
		await get_tree().create_timer(settle_time).timeout

	var caught := trapped(heap)
	for item in gripped:
		if is_instance_valid(item) and not caught.has(item):
			caught.append(item)
	if caught.is_empty():
		Sfx.play_at(&"crane_miss", jaw_mouth_global(), -4.0)
		await _snap_jaws(1.0)
		_set_shells_solid(false)
		_digging = false
		missed.emit()
		dig_finished.emit(0)
		return

	for item in caught:
		var body := item as RigidBody2D
		if body != null:
			body.freeze = true
		var part := heap.part_of(item)
		var scrap := heap.scrap_of(item)
		heap.take(item)
		dug.emit(item, part, scrap)
	await _fade_away_all(caught)
	await _snap_jaws(1.0)
	_set_shells_solid(false)
	_digging = false
	dig_finished.emit(caught.size())

## Every heap piece sitting inside the ring the shut shells make: its centre
## within the ring's hollow. That's the whole test — a piece that's in there
## after the ride up was carried, and one that slid out wasn't.
func trapped(heap: TrashHeap) -> Array[Node2D]:
	var caught: Array[Node2D] = []
	var centre := ring_centre_global()
	var hollow := claw_radius - claw_thickness * 0.5
	for item in heap.items():
		if is_instance_valid(item) and item.global_position.distance_to(centre) < hollow:
			caught.append(item)
	return caught

## Centre of the ring the shut shells make.
func ring_centre_global() -> Vector2:
	return to_global(hinge_local() + Vector2(0.0, claw_radius).rotated(_sway))

## World position of the bottom of the shut claw — where it meets the heap, and
## where its sounds come from.
func jaw_mouth_global() -> Vector2:
	return to_global(hinge_local() + Vector2(0.0, claw_radius * 2.0).rotated(_sway))

## Pay the cable out until the shells touch something, then ease off and stop
## a short `bite_depth` further down — so the claw settles into the top of the
## pile around the first thing it meets instead of ploughing on to the floor.
## A stall (something it can't shove) still stops it on the spot, and so does
## the cable running out. Then take back the slack, so the winch isn't still
## pressing the shells into whatever they landed on while they close.
func _sink() -> void:
	var target := clampf(hoist + dig_depth, hoist_min, hoist_max)
	var held := 0
	var braking := false
	while hoist < target - 0.5 and not _close_requested:
		var speed := dig_speed
		if braking:
			# Slows in proportion to the bite left, down to a crawl, so the stop
			# reads as the claw feeling its way in rather than hitting a wall.
			speed = maxf(dig_speed * (target - hoist) / maxf(bite_depth, 1.0), dig_speed * 0.1)
		place_hoist(minf(hoist + speed * get_physics_process_delta_time(), target))
		await get_tree().physics_frame
		if not braking and _shells_touching():
			braking = true
			target = minf(target, hoist + bite_depth)
		if _shell_lag() > stall_lag or _shell_twist() > stall_angle:
			held += 1
			if held >= stall_ticks:
				break
		else:
			held = 0
	place_hoist(hoist - _shell_lag())
	last_bite_hoist = hoist

## True once either shell is in contact with anything — junk or floor.
func _shells_touching() -> bool:
	for shell in _shells:
		if not shell.get_colliding_bodies().is_empty():
			return true
	return false

## Heap pieces the shut claw has a grip on: pinched between both shells, the
## one way a piece too big for the ring comes up. Touching a single shell, or
## just propping one open, isn't a grip — that piece stays in the heap. Each
## gripped one is locked to the
## claw for the ride up, the way real jaws clamping down would hold it, instead
## of being left to friction and sliding out.
##
## The jaws are parked where they stopped, so the servo stops trying to close
## through the piece, and the shells stop colliding with it, so nothing jitters
## while it's carried.
##
## `also` are pieces already found pinched while the jaws were shutting (see
## `_bite()`), kept even if a contact flickered off since.
func _grip(heap: TrashHeap, also: Array[Node2D] = []) -> Array[Node2D]:
	var gripped := _pinched(heap)
	for item in also:
		if is_instance_valid(item) and not gripped.has(item) and heap.items().has(item):
			gripped.append(item)
	if gripped.is_empty():
		return gripped
	set_jaw_open(_actual_jaw_open())
	for item in gripped:
		var body := item as RigidBody2D
		if body == null:
			continue
		body.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
		body.freeze = true
		for shell in _shells:
			shell.add_collision_exception_with(body)
	return gripped

## Heap pieces both shells are pressed against at once, plus any piece whose
## handle the ring has closed around (see `handle_reach`).
func _pinched(heap: TrashHeap) -> Array[Node2D]:
	var touching: Array = []
	for shell in _shells:
		var mine: Array[Node2D] = []
		for body in shell.get_colliding_bodies():
			var item := heap.item_of(body)
			if item != null and not mine.has(item):
				mine.append(item)
		touching.append(mine)
	var pinched: Array[Node2D] = []
	for item: Node2D in touching[0]:
		if touching[1].has(item):
			pinched.append(item)
	var ring := ring_centre_global()
	for item in heap.items():
		if pinched.has(item) or not item.has_method(&"grab_point"):
			continue
		var handle: Vector2 = item.call(&"grab_point")
		if handle.distance_to(ring) <= claw_radius * handle_reach:
			pinched.append(item)
	return pinched

## Shut the jaws, stopping where they are as soon as both shells have hold of
## the same piece: driving on toward shut from there only squeezes it out from
## between the tips. Returns what they stopped on (empty if they shut all the
## way). They have to be part-way shut first, so a piece the open tips merely
## rest on doesn't count as caught.
func _bite(heap: TrashHeap) -> Array[Node2D]:
	var pinched: Array[Node2D] = []
	if jaw_time <= 0.0:
		set_jaw_open(0.0)
		return pinched
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "jaw_open", 0.0, jaw_time)
	while tween.is_running() and is_inside_tree():
		await get_tree().physics_frame
		if jaw_open > bite_min_close:
			continue
		pinched = _pinched(heap)
		if not pinched.is_empty():
			tween.kill()
			set_jaw_open(_actual_jaw_open())
			break
	return pinched

## How open the shells really are, read off their bodies rather than
## `jaw_open` — the wider of the two, since that's the one holding the jaws
## apart.
func _actual_jaw_open() -> float:
	var widest := 0.0
	for i in _shells.size():
		var shut := global_rotation + shell_rotation(SIDES[i]) + SIDES[i] * JAW_SWING * jaw_open
		widest = maxf(widest, absf(angle_difference(shut, _shells[i].global_rotation)) / JAW_SWING)
	return clampf(widest, 0.0, 1.0)

## How far the most-twisted shell is turned off the pose it's being driven to.
func _shell_twist() -> float:
	var twist := 0.0
	for i in _shells.size():
		var target := global_rotation + shell_rotation(SIDES[i])
		twist = maxf(twist, absf(angle_difference(_shells[i].global_rotation, target)))
	return twist

## How far the furthest-behind shell trails the hinge it's being driven to.
func _shell_lag() -> float:
	var hinge := to_global(hinge_local())
	var lag := 0.0
	for shell in _shells:
		lag = maxf(lag, shell.global_position.distance_to(hinge))
	return lag

## Wind the claw back up to the height the trolley parks it at, carrying
## `gripped` locked to the hinge by the offset each was clamped at. The offsets
## are kept in the claw's own frame, so the load swings with it.
func _haul_up(gripped: Array[Node2D] = []) -> void:
	var offsets: Array[Vector2] = []
	var hinge := to_global(hinge_local())
	for item in gripped:
		offsets.append((item.global_position - hinge).rotated(-_sway))
	var target := rest_hoist()
	if dig_speed <= 0.0:
		place_hoist(target)
		_pin(gripped, offsets)
		return
	while hoist > target:
		place_hoist(maxf(hoist - dig_speed * get_physics_process_delta_time(), target))
		_pin(gripped, offsets)
		await get_tree().physics_frame
	_pin(gripped, offsets)

## Put each gripped piece back at its offset from the hinge. Two writes: the
## physics server's copy (a frozen body's transform belongs to the server, so
## the node alone is undone next step) and the node's, so it draws there now.
func _pin(items: Array[Node2D], offsets: Array[Vector2]) -> void:
	var hinge := to_global(hinge_local())
	for i in items.size():
		var item := items[i]
		if not is_instance_valid(item):
			continue
		var at := hinge + offsets[i].rotated(_sway)
		var body := item as RigidBody2D
		if body != null:
			PhysicsServer2D.body_set_state(body.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM,
					Transform2D(body.rotation, at))
		item.global_position = at

## The cable length the claw hangs at when the trolley parks it — where a dig
## ends as well as starts, so the claw always returns to the same height.
func rest_hoist() -> float:
	return clampf(hoist_length, hoist_min, hoist_max)

## Haul a whole basketful out of the world: freeze each piece so the physics
## server stops arguing, then fade the art out together. Deliberately a fade and
## not a shrink — a simulated body's scale gets rewritten by the physics server
## every tick (see `PartScale.apply_to()`), so the only handle on a grabbing
## body's looks is the CanvasItem side of it.
func _fade_away_all(items: Array[Node2D]) -> void:
	var longest := 0.0
	for item in items:
		if not is_instance_valid(item):
			continue
		var body := item as RigidBody2D
		if body != null:
			body.freeze = true
		if vanish_time <= 0.0:
			item.queue_free()
			continue
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_property(item, "modulate:a", 0.0, vanish_time)
		longest = maxf(longest, vanish_time)
	if longest > 0.0:
		await get_tree().create_timer(longest).timeout
	for item in items:
		if is_instance_valid(item):
			item.queue_free()

## Shut (`open` = 0) or open (`open` = 1) the jaws, and wait for them.
func _snap_jaws(open: float) -> void:
	if jaw_time <= 0.0:
		set_jaw_open(open)
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "jaw_open", open, jaw_time)
	await tween.finished


# --- The shells ----------------------------------------------------------------

## One clamshell half as a real body: the base class's shell outline as both its
## art and its collision, heavy, weightless (the servo holds it up, not the
## cable), and never asleep so the servo always has hold of it.
func _build_shell(side: float) -> RigidBody2D:
	var shell := RigidBody2D.new()
	shell.name = "ShellLeft" if side < 0.0 else "ShellRight"
	shell.mass = shell_mass
	# Turn about the hinge, not the half-ring's own centroid, so the servo's
	# spin and its pull on the hinge are the same motion instead of fighting.
	shell.center_of_mass_mode = RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM
	shell.center_of_mass = Vector2.ZERO
	# The shape's own inertia is a thin arc's — junk shoving on the far tip,
	# a whole ring's height from the hinge, pries it wide open. Hang the mass
	# out at the tips instead so a shell holds its angle like it holds its line.
	shell.inertia = shell_mass * pow(claw_radius * 2.0, 2.0) * shell_stiffness
	shell.gravity_scale = 0.0
	shell.can_sleep = false
	shell.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	shell.contact_monitor = true
	# Enough to see every piece a shell is pressed against when it shuts: the
	# grip (see `_grip()`) is built from this list.
	shell.max_contacts_reported = 8
	var outline := shell_polygon(side)
	var art := Polygon2D.new()
	art.polygon = outline
	art.color = shell_color(side)
	shell.add_child(art)
	var collision := CollisionPolygon2D.new()
	collision.polygon = outline
	shell.add_child(collision)
	add_child(shell)
	shell.global_transform = Transform2D(global_rotation + shell_rotation(side), to_global(hinge_local()))
	for other in _shells:
		shell.add_collision_exception_with(other)
	shell.body_entered.connect(_on_shell_hit)
	return shell

## Drive each shell toward where the rigging says it should be: on the hinge,
## turned by `jaw_open`. Velocity, not position — so the physics server still
## gets to stop a shell that runs into something heavier than it can shove.
func _drive_shells(delta: float) -> void:
	if delta <= 0.0:
		return
	var hinge := to_global(hinge_local())
	for i in _shells.size():
		var shell := _shells[i]
		var target_rotation := global_rotation + shell_rotation(SIDES[i])
		shell.linear_velocity = ((hinge - shell.global_position) / delta).limit_length(servo_speed)
		shell.angular_velocity = clampf(angle_difference(shell.global_rotation, target_rotation) / delta,
				-servo_spin, servo_spin)

## The shells are bodies with their own art, so the base class's drawn pair
## would only be a ghost lagging behind them.
func _draw_shells() -> void:
	pass

## Shells only touch the world during a dig. Parked, the junk being tipped in
## falls straight through them instead of piling up in an open claw.
func _set_shells_solid(solid: bool) -> void:
	for shell in _shells:
		shell.collision_layer = 1 if solid else 0
		shell.collision_mask = 1 if solid else 0

## A shell ran into something: a dull shove thud, rate-limited.
func _on_shell_hit(_body: Node) -> void:
	if not _digging or _shove_cooldown > 0.0:
		return
	_shove_cooldown = shove_gap
	Sfx.play_at(&"crane_shove", jaw_mouth_global(), -8.0)

## -1 while the negative key or action is held, +1 for the positive one, 0 for
## neither or both. Both keyboard routes work because the arrow keys ship as
## `ui_*` actions while WASD is read as raw physical keys — reading either one
## alone would leave somebody out.
func _axis(negative_key: Key, positive_key: Key, negative_action: StringName, positive_action: StringName) -> float:
	var value := Input.get_axis(negative_action, positive_action)
	if Input.is_physical_key_pressed(negative_key):
		value -= 1.0
	if Input.is_physical_key_pressed(positive_key):
		value += 1.0
	return clampf(value, -1.0, 1.0)

## The heap, by the exported path and then by a scene-wide search, so moving the
## heap around the pen doesn't silently disconnect the crane from it.
func _find_heap() -> TrashHeap:
	var node := get_node_or_null(heap_path)
	if node is TrashHeap:
		return node
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var stack: Array[Node] = [scene]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is TrashHeap:
			return current as TrashHeap
		for child in current.get_children():
			stack.append(child)
	return null
