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
##     for WASD),
##   - Space drops the claw: the jaws sink until they land on something, close
##     on the piece they landed on (and anything jammed against it), and the
##     winch hauls the lot back to the trolley.
##
## The winch is deliberately not on a key of its own. Aiming is the game and
## depth is not a decision the player should have to make — so the claw takes
## itself down, and what comes up is decided by where the player parked it. One
## press is one dig, and one dig is one grab: `items_at()` is a shape query
## against the real bodies in the heap (see `TrashHeap`), so what comes up is
## whatever the jaws actually closed around — normally the single piece they
## landed on, and a neighbour too when the two were lying in a tight clump.
##
## It stops where it lands rather than at the bottom of the cable's travel. A
## claw driven all the way down ploughs clean through the pile and comes up with
## a column of junk whether or not it touched anything, which reads as the crane
## ignoring its own jaws — and it makes every dig the same dig. Landing on the
## nearest thing under the teeth is what a grab looks like, and it makes aim
## matter: the piece the jaws stop on is the piece you walk away with.
##
## A dig is charged for when the jaws close on something, not when they go down:
## coming up empty-handed is free, and so is being told you can't afford the
## dig. The claw doesn't pick a target — a body in the heap *is* the part you
## walk away with, not a roll on a loot table.
##
## The machine reports, it doesn't bank: `dug` fires once per piece with the
## item and what it was worth, `dig_finished` when the claw is back at the
## trolley, and the pen (or whoever else owns the crane) decides what to do with
## the haul.
##
## Sway stays on while driving, because a claw that hangs still is a claw that
## aims itself. The jaws read their position *as drawn*, sway and all, so the
## pendulum is a thing to time rather than a thing to fight.

## One piece grabbed off the heap: `part` is the car part it was (null for plain
## junk), `scrap` what the junk is worth. Exactly one of them is set.
##
## Fires once per piece in a haul, *before* the piece is freed, so a handler can
## still read it.
signal dug(item: Node2D, part: PartData, scrap: int)
## The jaws came up empty.
signal missed()
## Something was down there, and the wallet couldn't cover the dig.
signal denied()
## The claw is back at the trolley and the dig is over. `caught` is how many
## pieces came up — 0 for a miss. The crane is idle again by the time this
## lands.
signal dig_finished(caught: int)

## The heap this crane works. Its `items_at()` is the jaws' eyes.
@export var heap_path: NodePath = ^"../Heap"
## What one dig costs, taken off the wallet only when the jaws close on
## something. Expensive on purpose: the junk in a basketful is worth a fraction
## of this, so the money is in what else comes up with it.
@export var grab_cost: int = 100
## Trolley speed along the boom.
@export var trolley_speed: float = 190.0
## How far below its parked height the winch will pay the cable out at most.
## A limit, not a destination: the claw bites in wherever it lands (see
## `bite_depth`) and only comes down this far when there's nothing down there to
## land on. Wants to be a little more than the heap's own depth, so a dig over a
## gap reaches the floor instead of hanging in mid-air.
@export var dig_depth: float = 260.0
## How fast the winch pays out and hauls back.
@export var dig_speed: float = 300.0
## How far past the first touch the claw drives on before it shuts. Stopping on
## contact alone leaves the teeth balanced on top of the piece, which looks like
## the claw gave up a jaw's length short of it, so it bites in by about half a
## jaw. Keep it below `jaw_reach` — bite deeper than the jaws can reach and they
## can close with the thing they landed on already behind them.
@export var bite_depth: float = 30.0
## The nose probe that decides a dig has landed: a small circle at the teeth.
## Small on purpose — "touching" is the teeth, not the jaws' whole reach, and
## probing at the hinge would have the claw stop a blade's length above the heap.
@export var contact_radius: float = 10.0
## How wide the jaws open: the radius a body has to be within of the teeth for
## the jaws to be around it. Roughly the claw's own width, and the hard limit on
## what a dig can come up with.
@export var jaw_reach: float = 38.0
## What counts as a clump: a piece this close to the one the jaws landed on is
## treated as jammed against it and comes up too. Small on purpose, so a dig is
## normally one piece — the junk has to be genuinely nested for the jaws to close
## on two at once. Raise it and digs start scooping.
@export var clump_radius: float = 28.0
## How long the jaws take to shut or open.
@export var jaw_time: float = 0.16
## How long a grabbed piece takes to disappear once the haul is up.
@export var vanish_time: float = 0.45
## Cleared by whatever owns the pen once the dig is over and the player is on
## their way out, so a Space press in the last moment of a scene change can't
## start a second dig.
@export var controls_enabled: bool = true

var _digging: bool = false
var _heap: TrashHeap = null
## The piece the jaws landed on last dig: what the dig was aimed at, and what
## they closed on. Null on a dig that found nothing. Reset at the start of every
## sink, so it always describes the dig just gone rather than an old one.
var _landed_on: Node2D = null
## How deep the winch paid out on the last dig: the hoist length the jaws
## actually stopped at, which is wherever they landed — not `dig_depth`. Zero
## until the first dig. Read-only for anyone outside; the pen doesn't need it,
## but it's the one number that says where the claw bit, and it's otherwise
## thrown away as soon as the claw winds back up.
var last_bite_hoist: float = 0.0

## The piece the last dig landed on, if it found one. The single most useful
## thing to know about a dig: it's what the haul is built around.
func landed_on() -> Node2D:
	return _landed_on

func _ready() -> void:
	super._ready()
	_heap = _find_heap()

func _physics_process(delta: float) -> void:
	if _digging or not controls_enabled:
		return
	# The claw hangs at -trolley, so pressing right has to push the trolley back
	# toward the mast. That's the whole of the player's control: where in the
	# heap the claw goes down.
	var run := _axis(KEY_A, KEY_D, &"ui_left", &"ui_right")
	if run != 0.0:
		place_trolley(trolley - run * trolley_speed * delta)
	if Input.is_action_just_pressed(&"ui_accept"):
		dig()

## True while the jaws are working, so a HUD can grey itself out.
func is_digging() -> bool:
	return _digging

## The heap this crane works, if it can find one.
func heap() -> TrashHeap:
	return _heap

## Work the claw: sink the open jaws until they land on something, shut them on
## whatever is between them, and haul the lot back to the trolley.
##
## Free to miss, free to be broke — the wallet is only touched once the jaws have
## closed on something. Await this if you want to know when the claw is free
## again; `dig_finished` reports the same moment to anyone who didn't.
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
	_digging = true

	# Down with the jaws open until they hit something, or the cable runs out.
	# Nothing is charged yet — we don't know what's in the basket.
	var caught := await _sink(heap)
	if caught.is_empty():
		Sfx.play_at(&"crane_miss", jaw_mouth_global(), -4.0)
		await _haul_up()
		_digging = false
		missed.emit()
		dig_finished.emit(0)
		return

	# Shut on the haul, lift it, and pay for it on the way up. The pieces ride
	# with the jaws — carried out of the heap, not left to fade where they lay.
	Sfx.play_at(&"crane_clang", jaw_mouth_global(), -2.0)
	await _snap_jaws(0.0)
	await _carry_up(caught)
	Inventory.spend_money(grab_cost)
	for item in caught:
		if not is_instance_valid(item):
			continue
		var part := heap.part_of(item)
		var scrap := heap.scrap_of(item)
		heap.take(item)
		dug.emit(item, part, scrap)
	await _fade_away_all(caught)
	await _snap_jaws(1.0)
	_digging = false
	dig_finished.emit(caught.size())

## World position of the jaw teeth — where the claw actually meets the heap.
##
## `claw_tip_global()` is the *hinge* the blades hang from; the teeth are a
## whole jaw below it. A grab aimed at the hinge closes on a patch of air above
## the piece the player was looking at, and a landing probe up there stops the
## claw in mid-air with the heap still a blade's length under it.
func jaw_mouth_global() -> Vector2:
	return to_global(claw_local() + Vector2(0.0, JAW_DROP))

## Pay the cable out from wherever the trolley has the claw, down until the jaws
## touch something, and report what they close on there.
##
## Both the landing probe and the grab read the teeth (see `jaw_mouth_global()`),
## and the descent stops a bite past the first touch rather than at `dig_depth`:
## so a dig over open floor runs the full travel and comes up empty, and a dig
## that lands comes back up with the piece under the jaws.
func _sink(heap: TrashHeap) -> Array[Node2D]:
	_landed_on = null
	var target := clampf(hoist + dig_depth, hoist_min, hoist_max)
	if dig_speed <= 0.0:
		# Instant sink: there's no descent to feel a landing on, so the jaws
		# simply take what they came down around.
		place_hoist(target)
		last_bite_hoist = hoist
		_landed_on = _nearest(heap, jaw_reach)
		return _bite(heap, jaw_reach)
	# -1 until the teeth meet something, then the hoist length they met it at.
	var landed := -1.0
	while hoist < target:
		place_hoist(minf(hoist + dig_speed * get_physics_process_delta_time(), target))
		if landed < 0.0:
			_landed_on = _nearest(heap, contact_radius)
			if _landed_on != null:
				# Teeth are on something. Note where, and keep going: the jaws
				# want to close around the piece, not balance on top of it.
				landed = hoist
		elif hoist >= landed + bite_depth:
			break
		await get_tree().physics_frame
	last_bite_hoist = hoist
	return _bite(heap, jaw_reach)

## What the jaws close on, given where they stopped: the piece they landed on,
## plus anything wedged tight enough against it to come up in the same bite.
##
## "Wedged" is measured centre to centre. A shape query would be the obvious
## way to ask, but in a tipped pile almost every piece touches its neighbours,
## so overlap alone turns most digs into a two-piece haul — the opposite of the
## feel we're after. Two centres inside `clump_radius` of each other means the
## pieces are sitting on top of one another, which is a genuine clump.
##
## A dig that never landed on anything comes up empty, whatever is down there.
func _bite(heap: TrashHeap, reach: float) -> Array[Node2D]:
	var caught: Array[Node2D] = []
	if _landed_on == null or not is_instance_valid(_landed_on):
		return caught
	caught.append(_landed_on)
	var anchor := _landed_on.global_position
	var mouth := jaw_mouth_global()
	for item in heap.items():
		if item == _landed_on:
			continue
		if item.global_position.distance_to(anchor) > clump_radius:
			continue
		# Still has to be between the jaws: a neighbour of a piece the teeth
		# caught at the very edge of their reach would otherwise be hauled up
		# from outside the closed jaws.
		if item.global_position.distance_to(mouth) > reach:
			continue
		caught.append(item)
	return caught

## The heap piece nearest `point`, within `radius` of it, or null if the query
## came up empty. Nearest rather than first: the teeth reach into a pile, so the
## thing they actually met is the one closest to them.
func _nearest(heap: TrashHeap, radius: float) -> Node2D:
	var mouth := jaw_mouth_global()
	var best: Node2D = null
	var best_distance := INF
	for item in heap.items_at(mouth, radius):
		var distance := item.global_position.distance_to(mouth)
		if distance < best_distance:
			best_distance = distance
			best = item
	return best

## Wind the claw back up to the height the trolley parks it at.
func _haul_up() -> void:
	if dig_speed <= 0.0:
		place_hoist(rest_hoist())
		return
	var target := rest_hoist()
	while hoist > target:
		place_hoist(maxf(hoist - dig_speed * get_physics_process_delta_time(), target))
		await get_tree().physics_frame

## Ride the caught pieces up with the jaws, so the claw visibly brings the haul
## out of the heap instead of leaving it to fade where it lay.
##
## Each piece is frozen and pinned to the teeth by the offset it was grabbed at,
## so the pieces climb with the claw and settle in the closed jaws. The pin has
## to go through the physics server: a frozen body's transform is owned by the
## server, so writing `global_position` alone gets silently undone on the next
## step — the same reason a parked piece has to be set with `body_set_state`.
func _carry_up(items: Array[Node2D]) -> void:
	var offsets: Array[Vector2] = []
	var mouth := jaw_mouth_global()
	for item in items:
		if not is_instance_valid(item):
			offsets.append(Vector2.ZERO)
			continue
		var body := item as RigidBody2D
		if body != null:
			body.freeze = true
			body.linear_velocity = Vector2.ZERO
			body.angular_velocity = 0.0
		offsets.append(item.global_position - mouth)
	# The hoist loop from `_haul_up`, but every step pins the haul to the teeth
	# first so the pieces climb with the claw.
	if dig_speed <= 0.0:
		place_hoist(rest_hoist())
	else:
		var target := rest_hoist()
		while hoist > target:
			place_hoist(maxf(hoist - dig_speed * get_physics_process_delta_time(), target))
			_pin_haul(items, offsets)
			await get_tree().physics_frame
	_pin_haul(items, offsets)

## Put each grabbed piece back on the teeth, keeping the offset it was caught at.
##
## Two writes, in this order: `body_set_state` tells the physics server where the
## body now is (so the next sync doesn't snap it back), and `global_position`
## moves the node itself (so it reads and renders there this very frame). A
## frozen body's node transform is owned by the server, so either write alone is
## quietly undone on the next step.
func _pin_haul(items: Array[Node2D], offsets: Array[Vector2]) -> void:
	var mouth := jaw_mouth_global()
	for i in items.size():
		var item := items[i]
		if not is_instance_valid(item):
			continue
		var target := mouth + offsets[i]
		var body := item as RigidBody2D
		if body != null:
			PhysicsServer2D.body_set_state(body.get_rid(),
					PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(body.rotation, target))
			body.global_position = target
		else:
			item.global_position = target

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
