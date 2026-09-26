class_name PlayerCar
extends CharacterBody2D
## Side-view movement, not top-down: A/D (or Left/Right) move the car
## horizontally and flip it to face that direction; W/S (or Up/Down) move
## it vertically, leaning the car nose-up climbing and nose-down descending
## (see `tilt_max_angle`) so it reads as driving up/down a slope instead of
## the sprite sliding straight up the screen. Two independent axes, no
## steering/turning-radius physics — there's no "reverse steers backwards"
## case here, since the lean is cosmetic and the car's heading is still
## only ever left or right.

## Group the player's car belongs to. It's how something with no path to the
## world scene — the `DevMenu` autoload, say — finds the car to put things next
## to, without guessing at node names or tree shape.
const GROUP := &"player"

@export var max_speed: float = 420.0
@export var acceleration: float = 1800.0
@export var friction: float = 1800.0
## Top speed multipliers depending on whether the car's current position
## is on a road (see RoadNetwork.is_on_road()) — pavement is faster,
## sand is a drag.
@export var on_road_speed_multiplier: float = 1.2
@export var off_road_speed_multiplier: float = 0.9
## How quickly velocity can actually change — both speeding up and
## changing direction — as a multiplier on acceleration/friction. Off
## the road this is cut down, so the car feels loose and slow to turn on
## sand instead of the crisp, immediate response pavement gives.
@export var on_road_handling_multiplier: float = 1.0
@export var off_road_handling_multiplier: float = 0.5
## Top speed multiplier while Shift is held, stacking on top of the
## on/off-road multiplier above.
@export var sprint_speed_multiplier: float = 3.0
## Same convention as TrashSpawner.roads_path: the exported path first,
## falling back to searching the scene for any RoadNetwork if it doesn't
## resolve (e.g. this scene got reparented).
@export var roads_path: NodePath = ^"../Roads"
## Same resolution again, for the ground-decal layer skid marks are
## drawn into (see SkidMarksLayer).
@export var skid_marks_path: NodePath = ^"../SkidMarks"

## A skid mark starts stamping once the car's current heading and the
## player's new input direction diverge past this angle — "the car goes
## one way, the player suddenly wants another" — and keeps stamping
## until they realign. Speed-gated too, so crawling out of a three-point
## turn doesn't leave rubber.
@export var skid_angle_threshold: float = deg_to_rad(35.0)
@export var skid_min_speed: float = 120.0
@export var skid_mark_color: Color = Color(0.05, 0.05, 0.05, 0.55)
@export var skid_mark_width: float = 6.0
## World pixels a wheel has to travel since its last stamp before a new
## segment is laid down — caps how many mark nodes a long skid spawns
## without leaving visible gaps in the trail.
@export var skid_mark_min_gap: float = 14.0
## A stamped segment sits fully opaque this long, then eases out over
## fade_time — hold + fade is the mark's total 5-second lifetime.
@export var skid_mark_hold_time: float = 2.0
@export var skid_mark_fade_time: float = 3.0

## Multiplier on handling while the car is standing in a puddle — how much
## grip the water takes away. This scales the same rate that governs both
## accelerating and changing direction, so a low value doesn't stop the car,
## it makes it keep the momentum it already had and slide through a turn
## instead of carving it. The puddles only appear once `Weather` has soaked
## the road, so a dry map still grips normally.
@export var puddle_slip_multiplier: float = 0.3
## The heading change that starts a skid, on a wet patch. Much smaller than
## the dry threshold, so the same input that grips on tarmac peels out here.
@export var puddle_skid_angle_threshold: float = deg_to_rad(20.0)
## Same resolution again, for the puddle layer the slip test reads. See
## PuddleField.is_on_puddle().
@export var puddles_path: NodePath = ^"../Puddles"

## How far the car leans at full vertical speed, in radians. Climbing W
## tips the nose up, descending S tips it down; it eases back to level the
## moment the vertical input stops. Deliberately small — it's a hint of a
## slope, not a stunt. 0 leaves the car flat.
@export var tilt_max_angle: float = deg_to_rad(8.0)
## How fast the lean catches up to the current vertical speed. Low is
## floaty and lazy, high snaps to the input the instant W/S is pressed.
@export var tilt_response: float = 9.0

## Hitting something harder than this (px/s of speed lost in one step) knocks.
@export var bump_min_impact_speed: float = 150.0
## Extra deceleration (px/s^2, on top of normal friction) applied while
## touching an obstacle but below bump_min_impact_speed — a glancing slide
## along its edge rather than a square hit. See the collision handling in
## _physics_process for why this exists alongside the hard-hit zeroing.
@export var collision_contact_friction: float = 2400.0
@export var engine_volume_db: float = -12.0
@export var horn_volume_db: float = -6.0
@export var tire_screech_volume_db: float = -12.0

## The ignition only clicks the first time the car shows up this session.
## Coming back out of a building, the engine was never switched off.
static var _engine_started_this_session: bool = false

var _facing_right: bool = true
## Current lean in radians; eased toward the target each frame so the car
## rocks into a climb/dive instead of snapping between angles.
var _tilt: float = 0.0
var _interact_pressed_last: bool = false
var _test_pressed_last: bool = false
## Which target the current hold is building up against, and how far
## along it is (seconds held). Resets to null/0 the instant E is
## released or the player looks away from that target.
var _holding_target: Object = null
var _hold_progress: float = 0.0

@onready var _visual: CarView = $Visual as CarView
@onready var _interaction_zone: Area2D = $InteractionZone
@onready var _tooltip_label: Label = $UI/TooltipLabel
@onready var _hold_bar_bg: Control = $UI/HoldBarBg
@onready var _hold_bar_fill: Control = $UI/HoldBarBg/HoldBarFill
@onready var _scrap_label: Label = $UI/ScrapLabel
@onready var _day_label: Label = $UI/DayLabel

var _road_network: RoadNetwork = null
var _skid_marks: SkidMarksLayer = null
## Standing water the car can lose grip on (see PuddleField). Null on a map
## without a puddle layer — the drag strip races, say — which just means
## nothing is ever wet.
var _puddles: PuddleField = null
## Last stamped world position per wheel mount index; null means that
## wheel isn't mid-skid (either never started, or realigned and got
## cleared) so the next stamp starts fresh instead of drawing a long
## connector line back to wherever the last skid happened to end.
var _skid_last_stamp: Array = []

## Null when the car has no engine — then it rolls around in silence.
var _engine_sound: EngineSound = null
var _horn: SustainedSound
var _tire_screech: SustainedSound
var _bump_cooldown: float = 0.0
var _sprint_pressed_last: bool = false

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group(GROUP)
	_road_network = _resolve_roads()
	_skid_marks = _resolve_skid_marks()
	_puddles = _resolve_puddles()
	var car := Inventory.get_selected_car()
	if car != null:
		_visual.build_from(car)
	_setup_sounds(car)
	# Coming back from a place (garage, drag strip race): reappear where we
	# left the map instead of at the scene's default spawn.
	if WorldState.has_player_position:
		global_position = WorldState.player_position
	# If E was still held when the previous scene ended, don't let it count
	# as a fresh press here — that would instantly re-enter the place we
	# just exited.
	_interact_pressed_last = Input.is_physical_key_pressed(KEY_E)
	_test_pressed_last = Input.is_physical_key_pressed(KEY_T)

# KEY_SPACE stays in here even though nothing reads it for movement yet —
# it's earmarked for braking (see player_car.gd's own history/notes), and
# this list's whole job is releasing every drive-relevant key on focus
# loss, brake included, the moment it starts doing something.
const _DRIVE_KEYS := [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_SPACE, KEY_E, KEY_T, KEY_H, KEY_SHIFT]

func _notification(what: int) -> void:
	# If the window loses OS focus while a key is held, no key-up event
	# ever arrives — Input keeps reporting that key pressed forever after.
	# Force every drive key released whenever focus drops.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		for keycode in _DRIVE_KEYS:
			var ev := InputEventKey.new()
			ev.keycode = keycode
			ev.physical_keycode = keycode
			ev.pressed = false
			Input.parse_input_event(ev)
		velocity = Vector2.ZERO
		_interact_pressed_last = false
		_test_pressed_last = false

## Left-click is how you deal with a person rather than a place (the junkyard's
## scrap dealer). It's a point query into the physics world, not a mouse-over
## test, because the *car* is what has to be in reach: clicking him only counts
## if he's also showing up in the interaction zone, so you can't reach across
## the yard. Anything the click handles is consumed so it can't double up with
## the E path.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index == MOUSE_BUTTON_LEFT and click.pressed:
			var target := _clicked_interactable(get_global_mouse_position())
			if target != null:
				_activate(target)
				get_viewport().set_input_as_handled()

## The thing under the cursor, but only if the car is close enough to it to be
## showing it in the interaction zone. Hit colliders are walked back up to the
## node that owns the interaction protocol, so clicking a character's click box
## or a child collision shape resolves to the same target the zone knows.
func _clicked_interactable(point: Vector2) -> Object:
	var reachable := _find_interactables()
	if reachable.is_empty():
		return null
	var params := PhysicsPointQueryParameters2D.new()
	params.position = point
	params.collide_with_bodies = true
	params.collide_with_areas = true
	for hit in get_world_2d().direct_space_state.intersect_point(params):
		var node := hit.get("collider") as Node
		while node != null:
			if reachable.has(node):
				return node
			node = node.get_parent()
	return null

func _physics_process(delta: float) -> void:
	var input_dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		input_dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		input_dir.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		input_dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		input_dir.y += 1.0

	if input_dir.x > 0.0:
		_facing_right = true
	elif input_dir.x < 0.0:
		_facing_right = false
	_visual.scale.x = 1.0 if _facing_right else -1.0

	# One on-road check feeds both multipliers, rather than querying the
	# road network twice for the same answer. The puddle check sits beside it
	# and feeds the skid test too — standing water lets the tires go with far
	# less provocation than dry tarmac.
	var on_road := _road_network != null and _road_network.is_on_road(global_position)
	var on_puddle := _puddles != null and _puddles.is_on_puddle(global_position)

	# Compared against velocity as it stood BEFORE this frame's move_toward
	# touches it — "the car was already heading this way" — against the
	# input direction just read above, "now the player wants that way".
	var skidding := _is_skidding(input_dir, on_puddle)

	var target_velocity := Vector2.ZERO
	if input_dir != Vector2.ZERO:
		var speed_multiplier := on_road_speed_multiplier if on_road else off_road_speed_multiplier
		if Input.is_physical_key_pressed(KEY_SHIFT):
			speed_multiplier *= sprint_speed_multiplier
		target_velocity = input_dir.normalized() * max_speed * speed_multiplier
	var handling_multiplier := on_road_handling_multiplier if on_road else off_road_handling_multiplier
	if on_puddle:
		# Grip, not speed: the car can still carry its momentum, it just
		# can't change what it's doing anything like as quickly.
		handling_multiplier *= puddle_slip_multiplier
	var accel_rate := (acceleration if input_dir != Vector2.ZERO else friction) * handling_multiplier
	velocity = velocity.move_toward(target_velocity, accel_rate * delta)
	var velocity_before_move := velocity
	move_and_slide()

	# move_and_slide() only strips the component of velocity that's directly
	# into whatever it hit — a glancing or diagonal hit leaves a tangential
	# "slide" component alive, and move_toward keeps re-feeding that while
	# input is held, so it can discharge as a sudden shove once we clear the
	# obstacle's edge. A hard enough hit (same threshold the bump sound uses)
	# kills velocity outright instead, so a real collision actually stops the
	# car rather than storing up momentum for later.
	var impact_speed := (velocity_before_move - velocity).length()
	if impact_speed > bump_min_impact_speed:
		velocity = Vector2.ZERO
	elif get_slide_collision_count() > 0 and input_dir != Vector2.ZERO:
		# A softer, glancing touch never crosses the hard-stop threshold above
		# in any single frame, but it's still in contact — sliding along an
		# obstacle's edge builds the same leftover tangential velocity a hard
		# hit would, just gradually. Only bleed off the part of velocity NOT
		# pointing where the player's currently steering (the actual leftover
		# from the collision) — damping the whole vector here would fight the
		# player's own forward speed the instant they so much as brush a
		# corner, which is what made every touch feel like hitting molasses.
		var desired_dir := input_dir.normalized()
		var forward_component := velocity.dot(desired_dir) * desired_dir
		var residual := (velocity - forward_component).move_toward(Vector2.ZERO, collision_contact_friction * delta)
		velocity = forward_component + residual

	# The map car has no physics at all, so its wheels are animated by hand
	# from the ground it just covered. Each wheel decides what that means — a
	# plain one rolls, a paddle swings (see CarWheel.animate_visual).
	# move_and_slide() has already trimmed velocity for anything we slid
	# against, so the wheels stop turning against a wall. Signed for facing
	# because the facing flip is a scale.x mirror, which would otherwise make
	# a rolling wheel look like it's spinning backwards.
	var facing_sign := 1.0 if _facing_right else -1.0
	_update_tilt(delta, facing_sign)
	_visual.animate_wheels(_roll_distance(delta, facing_sign), delta)

	_update_skid_marks(skidding)
	_update_sounds(delta, input_dir, skidding, impact_speed)

	# Keep the saved spot current so entering any place (or any other scene
	# change) returns us to exactly here.
	WorldState.remember_player(global_position)

	# The only thing looting actually tracks right now — a plain running
	# total, no distinct item types yet — so this is the whole HUD for now.
	# Money joins it because the scrap dealer at the junkyard pays out.
	_scrap_label.text = "Scrap: %d    $%d" % [Inventory.scrap, Inventory.money]
	_day_label.text = "Day %d" % DayNightCycle.day

	_process_interaction(delta)

## Engine, horn and tyres ride on the car, so they sit dead centre of the
## camera. The engine voice comes from whatever engine is bolted on.
func _setup_sounds(car: CarModelData) -> void:
	var profile := EngineSoundProfile.for_engine(car.engine if car != null else null)
	if profile != null:
		_engine_sound = EngineSound.new()
		_engine_sound.profile = profile
		_engine_sound.volume_db = engine_volume_db
		add_child(_engine_sound)
		if not _engine_started_this_session:
			Sfx.play(&"ignition_click", -6.0, 0.0)
			_engine_sound.start_up(0.35)
	_engine_started_this_session = true
	_horn = _add_sustained_sound(&"horn_loop", horn_volume_db)
	_horn.min_on_time = 0.18
	_horn.restart_on_start = true
	_tire_screech = _add_sustained_sound(&"tire_screech_loop", tire_screech_volume_db)

func _add_sustained_sound(sound_name: StringName, volume_db: float) -> SustainedSound:
	var sound := SustainedSound.new()
	sound.sound_name = sound_name
	sound.base_volume_db = volume_db
	add_child(sound)
	return sound

## Speed maps onto rpm on a soft curve: normal top speed sits around three
## quarters of the rev range and sprinting pushes it into the limiter. H honks.
## Shift kicks the sprint in with a backfire.
func _update_sounds(delta: float, input_dir: Vector2, skidding: bool, impact_speed: float) -> void:
	if _engine_sound != null:
		_engine_sound.rpm = 1.0 - exp(-velocity.length() / max_speed * 1.2)
		_engine_sound.throttle = 1.0 if input_dir != Vector2.ZERO else 0.0
	_horn.set_active(Input.is_physical_key_pressed(KEY_H))
	_tire_screech.set_active(skidding)

	_bump_cooldown -= delta
	if impact_speed > bump_min_impact_speed and _bump_cooldown <= 0.0:
		Sfx.play(&"bump", linear_to_db(clampf(impact_speed / max_speed, 0.3, 1.0)))
		_bump_cooldown = 0.3

	var sprint_pressed := Input.is_physical_key_pressed(KEY_SHIFT)
	if sprint_pressed and not _sprint_pressed_last and input_dir != Vector2.ZERO and _engine_sound != null:
		Sfx.play(&"backfire", -6.0)
	_sprint_pressed_last = sprint_pressed

## Lean the whole car into its vertical movement: climbing (W/Up) tips the
## nose up, descending (S/Down) tips it down, easing back to level the moment
## the vertical input stops. The angle is capped at `tilt_max_angle` and
## scaled by how close to full speed the climb/dive is, so a gentle nudge
## only rocks the car a little.
##
## Multiplied by `facing_sign` because the facing flip is a `scale.x` mirror
## on this same node: without it, a car facing left would tip the wrong way.
func _update_tilt(delta: float, facing_sign: float) -> void:
	var target := clampf(velocity.y / max_speed, -1.0, 1.0) * tilt_max_angle
	_tilt = lerpf(_tilt, target, 1.0 - exp(-tilt_response * delta))
	_visual.rotation = _tilt * facing_sign

## How far the wheels turn this frame, in world pixels. The wheels roll on the
## car's total travel — the vertical component included — so driving up or
## down spins them instead of the car skating sideways on static wheels.
## Signed so they still roll forwards along the facing direction and, when the
## player actually reverses, backwards (the roll is fed through the wheel's
## mirrored frame, so an always-positive distance would look reversed one way).
func _roll_distance(delta: float, facing_sign: float) -> float:
	var speed := velocity.length()
	if speed <= 0.01:
		return 0.0
	var direction := 1.0 if velocity.x * facing_sign >= 0.0 else -1.0
	return speed * direction * delta

## Same resolution TrashSpawner uses: the exported path first, falling back
## to searching the current scene for any RoadNetwork.
func _resolve_roads() -> RoadNetwork:
	var node := get_node_or_null(roads_path)
	if node is RoadNetwork:
		return node
	var scene := get_tree().current_scene
	if scene == null:
		scene = get_parent()
	var stack: Array[Node] = [scene]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is RoadNetwork:
			return current
		for child in current.get_children():
			stack.append(child)
	return null

## Same resolution again, for the ground-decal layer skid marks are drawn
## into — a plain type search rather than a name lookup, matching
## _resolve_roads().
func _resolve_skid_marks() -> SkidMarksLayer:
	var node := get_node_or_null(skid_marks_path)
	if node is SkidMarksLayer:
		return node
	var scene := get_tree().current_scene
	if scene == null:
		scene = get_parent()
	var stack: Array[Node] = [scene]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is SkidMarksLayer:
			return current
		for child in current.get_children():
			stack.append(child)
	return null

## And once more for the puddle layer the wet-road grip test reads. Null is a
## valid answer (a scene with no puddles in it), which just means the car is
## never on one.
func _resolve_puddles() -> PuddleField:
	var node := get_node_or_null(puddles_path)
	if node is PuddleField:
		return node
	var scene := get_tree().current_scene
	if scene == null:
		scene = get_parent()
	var stack: Array[Node] = [scene]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is PuddleField:
			return current
		for child in current.get_children():
			stack.append(child)
	return null

## True when the car is moving at a real clip but the player just asked
## for a meaningfully different direction — the tires are still carrying
## the old momentum while the wheels have already turned toward the new
## one, which is exactly what leaves rubber on the road. Standing water
## drops the bar sharply, so a puddle peels out under an input that dry
## tarmac would have gripped through.
func _is_skidding(input_dir: Vector2, on_puddle: bool = false) -> bool:
	if input_dir == Vector2.ZERO or velocity.length() < skid_min_speed:
		return false
	var threshold := puddle_skid_angle_threshold if on_puddle else skid_angle_threshold
	return absf(velocity.normalized().angle_to(input_dir.normalized())) > threshold

## Stamps a short mark segment behind each wheel mount while skidding,
## picking up from wherever that wheel's last stamp landed so a fast
## skid still reads as one continuous streak rather than dots. Wheels
## that stop skidding just drop out of _skid_last_stamp (set back to
## null) so the next skid starts its own fresh trail instead of drawing
## one long connector across wherever the car drove in between.
func _update_skid_marks(skidding: bool) -> void:
	if _skid_marks == null:
		return
	var mounts := _visual.get_wheel_mounts()
	if _skid_last_stamp.size() != mounts.size():
		_skid_last_stamp.resize(mounts.size())
	for i in mounts.size():
		if not skidding:
			_skid_last_stamp[i] = null
			continue
		var world_pos: Vector2 = _visual.to_global(mounts[i])
		var last: Variant = _skid_last_stamp[i]
		if last == null:
			_skid_last_stamp[i] = world_pos
			continue
		var last_pos: Vector2 = last
		if last_pos.distance_to(world_pos) >= skid_mark_min_gap:
			_spawn_skid_segment(last_pos, world_pos)
			_skid_last_stamp[i] = world_pos

## One stamped segment: a short dark line from `a` to `b` in world space,
## fully opaque for skid_mark_hold_time, then eased out over
## skid_mark_fade_time and freed — a 5-second lifetime by default,
## matching a real tire mark that lingers before weathering away.
func _spawn_skid_segment(a: Vector2, b: Vector2) -> void:
	var line := Line2D.new()
	line.width = skid_mark_width
	line.default_color = skid_mark_color
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = true
	line.add_point(_skid_marks.to_local(a))
	line.add_point(_skid_marks.to_local(b))
	_skid_marks.add_child(line)
	var tween := line.create_tween()
	tween.tween_interval(skid_mark_hold_time)
	tween.tween_property(line, "modulate:a", 0.0, skid_mark_fade_time)
	tween.tween_callback(line.queue_free)

## Nearby buildings are just StaticBody2Ds with a non-empty `display_name`
## property (duck-typed, not a shared base class) that overlap this zone.
## Returns all of them, in physics order: the zone can overlap two things at
## once (parked between the scrap dealer and the crane, say), and the caller
## needs to know about the others to pick one that answers to E.
func _find_interactables() -> Array[Object]:
	var found: Array[Object] = []
	for body in _interaction_zone.get_overlapping_bodies():
		var target_name = body.get("display_name")
		if typeof(target_name) == TYPE_STRING and target_name != "":
			found.append(body)
	return found

func _process_interaction(delta: float) -> void:
	var candidates := _find_interactables()

	# Prefer something E can actually work on. A click-only target (the scrap
	# dealer says so via uses_click_interaction()) is never activated by E,
	# so letting it shadow a normal target nearby would make E stop working
	# for no visible reason — but it still gets the tooltip while nothing
	# else is in reach, otherwise there'd be nothing to tell you the dealer
	# is clickable at all.
	var target: Object = null
	for candidate in candidates:
		if not _is_click_only(candidate):
			target = candidate
			break
	var prompt_target: Object = target
	if prompt_target == null and not candidates.is_empty():
		prompt_target = candidates[0]

	if prompt_target != null:
		_tooltip_label.text = _interact_prompt(prompt_target)
		_tooltip_label.add_theme_color_override("font_color", _interact_prompt_color(prompt_target))
		_tooltip_label.visible = true
	else:
		_tooltip_label.visible = false

	var hold_duration := _hold_duration_for(target)
	var interact_pressed := Input.is_physical_key_pressed(KEY_E)

	if target != null and interact_pressed and hold_duration > 0.0:
		if _holding_target != target:
			_holding_target = target
			_hold_progress = 0.0
		_hold_progress += delta
		_set_hold_bar(_hold_progress / hold_duration)
		if _hold_progress >= hold_duration:
			_activate(target)
			_holding_target = null
			_hide_hold_bar()
	elif target != null and interact_pressed and not _interact_pressed_last:
		_activate(target)
		_holding_target = null
		_hide_hold_bar()
	else:
		_holding_target = null
		_hide_hold_bar()

	_interact_pressed_last = interact_pressed

	# A second, parallel entry point: T opens a target's test_interior_scene
	# instead of its real interior_scene, if it has one — lets a place like
	# the drag strip offer an in-progress alternate version to try without
	# touching what E drops you into.
	var test_pressed := Input.is_physical_key_pressed(KEY_T)
	if target != null and test_pressed and not _test_pressed_last:
		_activate_test(target)
	_test_pressed_last = test_pressed

## True for a target that only answers to a mouse click. It still advertises
## `display_name` (so the car can find it and click it) but the E prompt
## and the hold bar are skipped for it.
func _is_click_only(target: Object) -> bool:
	if target != null and target.has_method("uses_click_interaction"):
		return bool(target.call("uses_click_interaction"))
	return false

## The tooltip line. The default is about the E key, which is the wrong
## thing to say about a click-only target, so a target can write its own
## (the dealer's doubles as the "how much scrap have I got" readout).
func _interact_prompt(target: Object) -> String:
	if target.has_method("get_interact_prompt"):
		var line: Variant = target.call("get_interact_prompt")
		if typeof(line) == TYPE_STRING and line != "":
			return line
	var verb_prompt := "Hold" if _hold_duration_for(target) > 0.0 else "Press"
	return "%s: %s E to %s" % [target.display_name, verb_prompt, _interact_verb(target)]

## Tooltip color. Defaults to the label's own authored white; a target can
## override via the duck-typed get_interact_prompt_color() (the registration
## booth turns its prompt red while closed overnight).
func _interact_prompt_color(target: Object) -> Color:
	if target != null and target.has_method("get_interact_prompt_color"):
		var color: Variant = target.call("get_interact_prompt_color")
		if typeof(color) == TYPE_COLOR:
			return color
	return Color(1, 1, 1, 1)

## 0 means instant activation (buildings you just walk into); a target can
## opt into a hold-to-activate delay (roadside trash props do, so a
## drive-by tap doesn't loot them by accident) via get_interact_hold_duration().
func _hold_duration_for(target: Object) -> float:
	if target != null and target.has_method("get_interact_hold_duration"):
		var d: Variant = target.call("get_interact_hold_duration")
		if typeof(d) == TYPE_FLOAT or typeof(d) == TYPE_INT:
			return float(d)
	return 0.0

func _set_hold_bar(fraction: float) -> void:
	_hold_bar_bg.visible = true
	_hold_bar_fill.anchor_right = clampf(fraction, 0.0, 1.0)

func _hide_hold_bar() -> void:
	_hold_bar_bg.visible = false
	_hold_bar_fill.anchor_right = 0.0
	_hold_progress = 0.0

## What the prompt offers for a target. Places you walk into are "entered";
## something that acts on the spot (a trash bin being looted) can say otherwise
## by implementing `get_interact_verb()`.
func _interact_verb(target: Object) -> String:
	if target.has_method("get_interact_verb"):
		var verb: Variant = target.call("get_interact_verb")
		if typeof(verb) == TYPE_STRING and verb != "":
			return verb
	return "enter"

## Something in reach was just activated. A target implementing `interact()`
## handles it itself — that's how roadside props do their looting — otherwise
## fall back to the place behaviour: print the name and switch to its interior
## scene, if it has one.
func _activate(target: Object) -> void:
	if target.has_method("interact"):
		target.call("interact", self)
		return
	print(target.display_name)
	var interior = target.get("interior_scene")
	if interior is PackedScene:
		Sfx.play(&"door_close", -4.0)
		get_tree().change_scene_to_packed(interior)

## T's counterpart to _activate(): only ever switches scene, since a
## test entry point has no loot-style interact() of its own to call.
func _activate_test(target: Object) -> void:
	var interior = target.get("test_interior_scene")
	if interior is PackedScene:
		Sfx.play(&"door_close", -4.0)
		get_tree().change_scene_to_packed(interior)
