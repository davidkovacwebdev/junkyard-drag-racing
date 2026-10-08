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
## The shop item that swaps in the Super Horn (items/super_horn.tres).
const SUPER_HORN := &"super_horn"

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
## How hard Space bites, as a fraction of current speed shed per second
## (exponential decay, not a fixed px/s^2) — a hard stop from a sprint
## bleeds off far more speed per frame than easing off a crawl, and the
## last stretch down to a stop tapers off instead of snapping there.
## Overrides any movement input and still scales with road/puddle
## handling, so braking on wet ground slides.
@export var brake_response: float = 1.5
## Same convention as TrashSpawner.roads_path: the exported path first,
## falling back to searching the scene for any RoadNetwork if it doesn't
## resolve (e.g. this scene got reparented).
@export var roads_path: NodePath = ^"../Roads"
## Same resolution again, for the ground-decal layer skid marks are
## drawn into (see SkidMarksLayer).
@export var skid_marks_path: NodePath = ^"../SkidMarks"
## And for the island terrain, which says where the sea starts (see Wading).
@export var terrain_path: NodePath = ^"../../Terrain"

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

## Off for a PlayerCar that lives in its own local space (the junkyard
## yard, say) rather than on the open map — WorldState.player_position is
## a single shared spot on the main map, so a car that isn't on that map
## must neither spawn from it nor overwrite it with its own coordinates.
@export var remember_position: bool = true

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
## Share of the post-hit sliding speed a hard hit leaves the car with, so a
## crash bleeds speed off instead of dead-stopping the car.
@export_range(0.0, 1.0) var hard_hit_speed_kept: float = 0.35
## Extra deceleration (px/s^2, on top of normal friction) applied while
## touching an obstacle but below bump_min_impact_speed — a glancing slide
## along its edge rather than a square hit. See the collision handling in
## _physics_process for why this exists alongside the hard-hit zeroing.
@export var collision_contact_friction: float = 2400.0
@export var engine_volume_db: float = -12.0
@export var horn_volume_db: float = -6.0
## The Super Horn from the shop (owned in the trunk): its blown-out air horn
## replaces whatever horn the car has, at a level way out of proportion.
@export var super_horn_volume_db: float = 6.0
@export var bump_volume_db: float = -6.0
@export var tire_screech_volume_db: float = -12.0

## Traveler mode (debug, F6 via DevMenu): flies over everything at this speed,
## Shift multiplying it, then lands on the nearest clear dry spot.
@export var traveler_speed: float = 5000.0
@export var traveler_sprint_multiplier: float = 4.0
## Ring spacing and reach of the search for a clear spot to land on.
@export var traveler_landing_step: float = 40.0
@export var traveler_landing_reach: float = 3000.0

@export_group("Drunk")
## Drunk (see the `Drunk` autoload), the car wanders off the line it's
## driven along: at full drunkenness by up to this share of its top speed,
## sideways and back and forth, while it's being driven.
@export var drunk_sway_speed: float = 0.55
## And the body rocks from side to side by up to this much, moving or not.
@export var drunk_rock_angle: float = deg_to_rad(7.0)
## A puke stop: the car brakes hard and sits shaking for this long, the
## sick hitting the ground `puke_splat_delay` in.
@export var puke_seconds: float = 3.2
@export var puke_splat_delay: float = 1.3
@export var puke_shake_pixels: float = 3.0
@export var puke_volume_db: float = -2.0
## Chance a stray dog (PukeDog) turns up to lick the puddle up.
@export_range(0.0, 1.0) var puke_dog_chance: float = 0.2

@export_group("Wading")
## Off the sand the car bogs down: top speed is cut to this share, falling to
## nothing as it sinks, and the sea drags the speed it brought in off at
## `water_drag` per second, so even a sprint only makes it a few lengths out.
@export var wade_speed_multiplier: float = 0.4
@export var wade_handling_multiplier: float = 0.4
@export var water_drag: float = 3.0
## Seconds in the water until the car is sunk to its axles and stuck, and how
## fast it drains once it's back on land.
@export var sink_seconds: float = 1.8
@export var drain_seconds: float = 0.6
## How far the body settles into the water when fully sunk.
@export var sink_depth: float = 4.0
@export var splash_volume_db: float = -4.0
@export var glug_volume_db: float = -4.0

@export_group("Fishing")
## The fishing rod casts to the nearest water between these distances (world
## px), searched in rings `cast_ring_step` apart. The minimum keeps the bobber
## clear of the surf, out where it reads as sea.
@export var cast_min_distance: float = 340.0
@export var cast_reach: float = 620.0
@export var cast_ring_step: float = 40.0
## What comes up on the hook: a part this often, an old boot this often, scrap
## (`catch_scrap` of it) the rest of the time.
@export_range(0.0, 1.0) var catch_part_chance: float = 0.15
@export_range(0.0, 1.0) var catch_boot_chance: float = 0.2
@export var catch_scrap := Vector2i(2, 5)

@export_group("Bleeding")
## Beaten up after the ramp (CharacterInjuries.current_level()), the car
## drips blood as it goes: a drop every this many px driven, at level 1 and
## level 2 (index 0 and 1).
@export var blood_drop_spacing := Vector2(85.0, 32.0)
@export var blood_drop_radius := Vector2(7.0, 11.0)
## Level 2 only: now and then a drop drags out into a smear, and parked, it
## still drips every this many seconds.
@export_range(0.0, 1.0) var blood_smear_chance: float = 0.2
@export var blood_idle_drip_seconds: float = 0.9

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

## The tooltip's and hold bar's authored bottom offsets (player_car.tscn),
## and how far both rise when a scene hint holds the bottom line.
const TOOLTIP_TOP := -60.0
const TOOLTIP_BOTTOM := -20.0
const HOLD_BAR_TOP := -78.0
const HOLD_BAR_BOTTOM := -64.0
const SCENE_HINT_LIFT := 44.0

@onready var _visual: CarView = $Visual as CarView
@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _walker_collision: CollisionShape2D = $WalkerCollisionShape2D
@onready var _interaction_zone: Area2D = $InteractionZone
@onready var _tooltip_label: Label = $UI/TooltipLabel
@onready var _hold_bar_bg: Control = $UI/HoldBarBg
@onready var _hold_bar_fill: Control = $UI/HoldBarBg/HoldBarFill
@onready var _scrap_label: Label = $UI/Resources/ScrapLabel
@onready var _money_label: Label = $UI/Resources/MoneyLabel
@onready var _day_label: Label = $UI/DayCounter/DayLabel

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
## Whether `_horn` is the Super Horn, so buying or losing it swaps it live.
var _super_horn_on: bool = false
var _tire_screech: SustainedSound
var _bump_cooldown: float = 0.0
var _bump_sound: StringName = &"bump"
var _boost_sound: StringName = &"backfire"
## Rough total mass of the equipped body + wheels + engine, fed to a
## GarbageTruck every frame the car touches it so how much it can push (or
## get pushed off course by) scales with what's actually bolted on (see
## GarbageTruck.set_contact_push()) rather than being a fixed shove.
var _car_mass: float = 12.0
var _sprint_pressed_last: bool = false
## Seconds left of a puke stop (0: not puking), and whether this one's
## puddle is down yet.
var _puke_left: float = 0.0
var _puked: bool = false
## Created on the first drop; null while the driver isn't bleeding.
var _blood_trail: BloodTrail = null
var _blood_distance: float = 0.0
var _blood_idle: float = 0.0
## Null on a map without islands (the junkyard yard), where there's no sea.
var _terrain: TerrainNetwork = null
var _water_line: CarWaterLine
## 0 dry, 1 sunk to the axles. Stuck latches at 1 and lets go back on land.
var _sink: float = 0.0
var _stuck: bool = false
var _tow_called: bool = false
## The puke shake, kept apart so the sink offset can sit on top of it.
var _visual_shake: Vector2 = Vector2.ZERO
var _default_collision_mask: int = 1
var _default_collision_layer: int = 1
var _traveling: bool = false

const TOW_RESCUE := preload("res://cutscenes/tow_truck_rescue.tres")
const SCRAP_PICKUP := preload("res://scenes/world/scrap_pickup.tscn")
const PART_PICKUP := preload("res://scenes/world/part_pickup.tscn")
## Null unless a line is in the water.
var _fishing: FishingCast = null

## Rebuilds the car's look and weight from the selected car, after something
## out in the world swapped one of its parts (Grandpa taking his helmet back).
func refresh_parts() -> void:
	var car := Inventory.get_selected_car()
	if car == null:
		return
	_visual.build_from(car)
	_car_mass = _compute_car_mass(car)
	_visual.fit_collision(_collision, _walker_collision)

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group(GROUP)
	Cutscenes.started.connect(_set_hud_visible.bind(false))
	Cutscenes.finished.connect(_set_hud_visible.bind(true))
	_road_network = _resolve_in_scene(roads_path, RoadNetwork) as RoadNetwork
	_skid_marks = _resolve_in_scene(skid_marks_path, SkidMarksLayer) as SkidMarksLayer
	_puddles = _resolve_in_scene(puddles_path, PuddleField) as PuddleField
	_terrain = _resolve_in_scene(terrain_path, TerrainNetwork) as TerrainNetwork
	_water_line = CarWaterLine.new()
	add_child(_water_line)
	move_child(_water_line, _visual.get_index())
	_water_line.hold(_visual)
	_default_collision_mask = collision_mask
	_default_collision_layer = collision_layer
	Inventory.set_use_check(&"fish", _fishing_blocked_reason)
	Inventory.item_used.connect(_on_item_used)
	var car := Inventory.get_selected_car()
	if car != null:
		_visual.audible_accessories = true
		_visual.build_from(car)
		_car_mass = _compute_car_mass(car)
	_visual.fit_collision(_collision, _walker_collision)
	_setup_sounds(car)
	# Coming back from a place (garage, drag strip race): reappear where we
	# left the map instead of at the scene's default spawn.
	if remember_position and WorldState.has_player_position:
		global_position = WorldState.player_position
	# If E was still held when the previous scene ended, don't let it count
	# as a fresh press here — that would instantly re-enter the place we
	# just exited.
	_interact_pressed_last = _is_key_held(KEY_E)
	_test_pressed_last = _is_key_held(KEY_T)

func _exit_tree() -> void:
	Inventory.set_use_check(&"fish", Callable())
	if Inventory.item_used.is_connected(_on_item_used):
		Inventory.item_used.disconnect(_on_item_used)

func get_road_network() -> RoadNetwork:
	return _road_network

func get_terrain() -> TerrainNetwork:
	return _terrain

## Hauled out by the tow truck, the car is dragged straight through the sea
## wall, so it stops colliding with anything until it's set down.
func set_towed(towed: bool) -> void:
	collision_mask = 0 if towed else _default_collision_mask

## Every drive/interact key goes through here, so a cutscene can take the
## wheel just by being active.
## Whether the horn is blaring right now (H held).
func is_honking() -> bool:
	return _horn != null and _is_key_held(KEY_H)

func _is_key_held(keycode: Key) -> bool:
	return not Cutscenes.is_active() and Input.is_physical_key_pressed(keycode)

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
	if Cutscenes.is_active():
		return
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index == MOUSE_BUTTON_LEFT and click.pressed:
			var target := _clicked_interactable(get_global_mouse_position())
			if target != null:
				# Before activating: entering a building swaps the scene, which
				# takes the car out of the tree and leaves no viewport to call.
				get_viewport().set_input_as_handled()
				_activate(target)

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

func is_traveling() -> bool:
	return _traveling

func set_traveling(traveling: bool) -> void:
	if traveling == _traveling:
		return
	_traveling = traveling
	velocity = Vector2.ZERO
	var camera := get_node_or_null(^"Camera2D") as WorldCamera
	if camera != null:
		camera.set_traveler(traveling)
	if traveling:
		collision_layer = 0
		collision_mask = 0
		Sfx.play(&"cutscene_whoosh", -4.0, 0.03).pitch_scale *= 0.7
		return
	global_position = _find_landing_spot(global_position)
	collision_layer = _default_collision_layer
	collision_mask = _default_collision_mask
	Sfx.play(&"gravel_crunch", -2.0, 0.05)

func _read_input_dir() -> Vector2:
	var input_dir := Vector2.ZERO
	if _is_key_held(KEY_A) or _is_key_held(KEY_LEFT):
		input_dir.x -= 1.0
	if _is_key_held(KEY_D) or _is_key_held(KEY_RIGHT):
		input_dir.x += 1.0
	if _is_key_held(KEY_W) or _is_key_held(KEY_UP):
		input_dir.y -= 1.0
	if _is_key_held(KEY_S) or _is_key_held(KEY_DOWN):
		input_dir.y += 1.0
	return input_dir

func _travel(delta: float) -> void:
	var input_dir := _read_input_dir()
	if input_dir.x != 0.0 and _facing_right != (input_dir.x > 0.0):
		_facing_right = input_dir.x > 0.0
		_visual.scale.x = 1.0 if _facing_right else -1.0
		_visual.mirror_collision(_collision, _walker_collision)
	var speed := traveler_speed * (traveler_sprint_multiplier if _is_key_held(KEY_SHIFT) else 1.0)
	velocity = input_dir.normalized() * speed
	global_position += velocity * delta
	if remember_position:
		WorldState.remember_player(global_position)

## Nearest spot, in widening rings around `origin`, where the car's shapes
## overlap nothing they would collide with and it isn't out at sea.
func _find_landing_spot(origin: Vector2) -> Vector2:
	var radius := 0.0
	while radius <= traveler_landing_reach:
		var samples := 1 if radius == 0.0 else maxi(8, int(TAU * radius / traveler_landing_step))
		for i in samples:
			var candidate := origin + Vector2.RIGHT.rotated(TAU * i / samples) * radius
			if _terrain != null and _terrain.is_in_water(_terrain.to_local(candidate)):
				continue
			if _is_spot_clear(candidate):
				return candidate
		radius += traveler_landing_step
	return origin

func _is_spot_clear(spot: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	for shape_node in [_collision, _walker_collision]:
		if shape_node.disabled or shape_node.shape == null:
			continue
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = shape_node.shape
		query.collision_mask = _default_collision_mask
		query.exclude = [get_rid()]
		var shape_offset: Transform2D = shape_node.global_transform
		shape_offset.origin += spot - global_position
		query.transform = shape_offset
		if not space.intersect_shape(query, 1).is_empty():
			return false
	return true

func _physics_process(delta: float) -> void:
	if _traveling:
		_travel(delta)
		return
	var input_dir := _read_input_dir()

	_update_puke(delta)
	if _puke_left > 0.0:
		input_dir = Vector2.ZERO

	# One on-road check feeds both multipliers, rather than querying the
	# road network twice for the same answer. The puddle check sits beside it
	# and feeds the skid test too — standing water lets the tires go with far
	# less provocation than dry tarmac. A road (a bridge deck, say) is never sea.
	var on_road := (_road_network != null and _road_network.is_on_road(global_position)) \
			or BlockedBridge.any_deck_under(get_tree(), global_position)
	var on_puddle := _puddles != null and _puddles.is_on_puddle(global_position)
	var in_water := not on_road and _terrain != null and _terrain.is_in_water(_terrain.to_local(global_position))
	_update_wading(delta, in_water)
	if _stuck:
		input_dir = Vector2.ZERO
	if is_instance_valid(_fishing):
		# Driving off reels the line in; the car holds still while it does.
		if input_dir != Vector2.ZERO:
			_fishing.cancel()
		input_dir = Vector2.ZERO

	if input_dir.x > 0.0:
		_facing_right = true
	elif input_dir.x < 0.0:
		_facing_right = false
	var facing_scale := 1.0 if _facing_right else -1.0
	if _visual.scale.x != facing_scale:
		_visual.scale.x = facing_scale
		_visual.mirror_collision(_collision, _walker_collision)

	# Compared against velocity as it stood BEFORE this frame's move_toward
	# touches it — "the car was already heading this way" — against the
	# input direction just read above, "now the player wants that way".
	var braking := _is_key_held(KEY_SPACE) or _puke_left > 0.0
	var skidding := not in_water and (_is_skidding(input_dir, on_puddle) or (braking and velocity.length() > skid_min_speed))

	var target_velocity := Vector2.ZERO
	if input_dir != Vector2.ZERO and not braking:
		var speed_multiplier := on_road_speed_multiplier if on_road else off_road_speed_multiplier
		if _is_key_held(KEY_SHIFT):
			speed_multiplier *= sprint_speed_multiplier
		if in_water:
			speed_multiplier *= wade_speed_multiplier * (1.0 - _sink)
		target_velocity = input_dir.normalized() * max_speed * speed_multiplier
		target_velocity += Drunk.sway() * max_speed * drunk_sway_speed * speed_multiplier
	var handling_multiplier := on_road_handling_multiplier if on_road else off_road_handling_multiplier
	if in_water:
		handling_multiplier *= wade_handling_multiplier
	if on_puddle:
		# Grip, not speed: the car can still carry its momentum, it just
		# can't change what it's doing anything like as quickly.
		handling_multiplier *= puddle_slip_multiplier

	if braking:
		var braked_speed := velocity.length() * exp(-brake_response * handling_multiplier * delta)
		if input_dir != Vector2.ZERO:
			var steered_velocity := input_dir.normalized() * velocity.length()
			velocity = velocity.move_toward(steered_velocity, acceleration * handling_multiplier * delta)
		velocity = velocity.limit_length(braked_speed) if braked_speed >= 1.0 else Vector2.ZERO
	else:
		var base_rate := friction if input_dir == Vector2.ZERO else acceleration
		velocity = velocity.move_toward(target_velocity, base_rate * handling_multiplier * delta)
	if in_water:
		velocity *= exp(-water_drag * delta)
	var velocity_before_move := velocity
	move_and_slide()
	_strip_velocity_into_collisions()
	# target_velocity, not velocity_before_move: pinned against something,
	# _strip_velocity_into_collisions() zeroes velocity into it every frame,
	# so velocity_before_move never gets past one frame's worth of
	# acceleration before being stripped again — target_velocity is what the
	# player is actually trying to do this frame, straight from input,
	# unaffected by that ratchet.
	_notify_garbage_truck_contact(target_velocity)

	# The strip above only removes the component of velocity that's directly
	# into whatever it hit — a glancing or diagonal hit leaves a tangential
	# "slide" component alive, and move_toward keeps re-feeding that while
	# input is held, so it can discharge as a sudden shove once we clear the
	# obstacle's edge. A hard enough hit (same threshold the bump sound uses)
	# kills velocity outright instead, so a real collision actually stops the
	# car rather than storing up momentum for later.
	# The sea's edge just blocks the car: no crash stop, no bump.
	var impact_speed := 0.0 if _is_touching_shore() else (velocity_before_move - velocity).length()
	if impact_speed > bump_min_impact_speed:
		velocity *= hard_hit_speed_kept
		_notify_rammed(impact_speed)
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
	_update_blood(delta)
	_update_sounds(delta, Vector2.ZERO if braking else input_dir, skidding, impact_speed)

	# Keep the saved spot current so entering any place (or any other scene
	# change) returns us to exactly here.
	if remember_position:
		WorldState.remember_player(global_position)

	# The only thing looting actually tracks right now — a plain running
	# total, no distinct item types yet — so this is the whole HUD for now.
	# Money joins it because the scrap dealer at the junkyard pays out.
	_scrap_label.text = str(Inventory.scrap)
	_money_label.text = str(Inventory.money)
	_day_label.text = str(DayNightCycle.day)

	_process_interaction(delta)

## In floating motion mode move_and_slide() moves the body but never touches
## `velocity`, so pushing into a wall would keep full speed forever.
func _strip_velocity_into_collisions() -> void:
	for i in get_slide_collision_count():
		var normal := get_slide_collision(i).get_normal()
		if velocity.dot(normal) < 0.0:
			velocity = velocity.slide(normal)

## Called every physics frame, hit or not — if the car happens to be
## touching a GarbageTruck right now, this tells it how hard the player is
## currently *trying* to press into it (see GarbageTruck.set_contact_push()),
## every single frame contact lasts. Takes the car's desired velocity
## (straight from input), not its actual one — pinned against the truck,
## the actual velocity gets zeroed into it every frame by
## _strip_velocity_into_collisions(), so it would never read as more than
## one frame's worth of acceleration. The desired velocity has no such
## ceiling: holding the stick down reports the same full push every frame
## for as long as it's held, which is what lets a slow, sustained lean
## actually walk the truck along instead of only a hard ram doing anything.
## Every other obstacle (buildings, props) just takes the existing
## bump/slow-down above; only the truck reacts back, since it's the only
## thing on the map that isn't nailed down.
func _notify_garbage_truck_contact(pressing_velocity: Vector2) -> void:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var truck := _as_garbage_truck(collision.get_collider())
		if truck != null:
			truck.set_contact_push(pressing_velocity, collision.get_normal(), _car_mass)
			return

## A hard hit: anything the car hit that has a duck-typed
## `car_rammed(car, impact_speed)` hears about it (a farm fence counting the
## hits for "Fenced In"), once per thing per hit.
func _notify_rammed(impact_speed: float) -> void:
	var told: Array[Object] = []
	for i in get_slide_collision_count():
		var collider := get_slide_collision(i).get_collider()
		if collider != null and collider.has_method(&"car_rammed") and not told.has(collider):
			told.append(collider)
			collider.call(&"car_rammed", self, impact_speed)

func _as_garbage_truck(collider: Object) -> GarbageTruck:
	var node := collider as Node
	while node != null:
		if node is GarbageTruck:
			return node
		node = node.get_parent()
	return null

## Rough total mass to represent the car in a collision (see
## _notify_garbage_truck_contact()) — just the sum of what's actually
## bolted on, the same stat numbers the garage shows.
func _compute_car_mass(car: CarModelData) -> float:
	var total := 0.0
	if car.body != null:
		total += car.body.mass
	if car.engine != null:
		total += car.engine.mass
	for wheel in car.wheels:
		if wheel != null:
			total += wheel.mass
	total += car.accessory_mass()
	return maxf(total, 1.0)

func _is_touching_shore() -> bool:
	for i in get_slide_collision_count():
		var collider := get_slide_collision(i).get_collider() as Node
		if collider != null and collider.is_in_group(TerrainNetwork.SHORE_GROUP):
			return true
	return false

## Engine, horn and tyres ride on the car, so they sit dead centre of the
## camera. The engine voice comes from whatever engine is bolted on.
func _setup_sounds(car: CarModelData) -> void:
	if car != null and car.body != null:
		_bump_sound = car.accessory_sound(&"body_impact_sound", car.body.impact_sound)
	if car != null and car.engine != null:
		_boost_sound = car.engine.boost_sound
	var profile := EngineSoundProfile.for_engine(car.engine if car != null else null)
	if profile != null:
		_engine_sound = EngineSound.new()
		_engine_sound.profile = profile
		_engine_sound.volume_db = engine_volume_db
		add_child(_engine_sound)
		if not _engine_started_this_session:
			Sfx.play(car.engine.start_sound, -6.0, 0.0)
			_engine_sound.start_up(0.35)
	_engine_started_this_session = true
	_build_horn(car)
	_tire_screech = _add_sustained_sound(&"tire_screech_loop", tire_screech_volume_db)

## The car's horn: the Super Horn when the player owns it, otherwise an
## accessory's (the siren) or the plain one.
func _build_horn(car: CarModelData) -> void:
	if _horn != null:
		_horn.queue_free()
	_super_horn_on = Inventory.has_item(SUPER_HORN)
	if _super_horn_on:
		_horn = _add_sustained_sound(&"super_horn_loop", super_horn_volume_db)
	else:
		var horn_sound := car.accessory_sound(&"horn_sound", &"horn_loop") if car != null else &"horn_loop"
		_horn = _add_sustained_sound(horn_sound, horn_volume_db)
	_horn.min_on_time = 0.18
	_horn.restart_on_start = true

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
	if Inventory.has_item(SUPER_HORN) != _super_horn_on:
		_build_horn(Inventory.get_selected_car())
	_horn.set_active(_is_key_held(KEY_H))
	_tire_screech.set_level(clampf(velocity.length() / max_speed, 0.4, 1.0) if skidding else 0.0)

	_bump_cooldown -= delta
	if impact_speed > bump_min_impact_speed and _bump_cooldown <= 0.0:
		Sfx.play(_bump_sound, bump_volume_db + linear_to_db(clampf(impact_speed / max_speed, 0.3, 1.0)))
		_bump_cooldown = 0.3

	var sprint_pressed := _is_key_held(KEY_SHIFT)
	if sprint_pressed and not _sprint_pressed_last and input_dir != Vector2.ZERO and _engine_sound != null:
		Sfx.play(_boost_sound, -6.0)
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
	_visual.rotation = _tilt * facing_sign + Drunk.sway().x * drunk_rock_angle

## Too many beers (see Drunk.puke_due()): the car pulls up, shakes as the
## driver heaves out of the window, and leaves a puddle of sick behind
## (on the ground decal layer, under the car, so it shows as the car drives
## off). Not in a cutscene, and never twice at once.
func _update_puke(delta: float) -> void:
	if _puke_left <= 0.0:
		if Cutscenes.is_active() or not Drunk.puke_due():
			return
		_puke_left = puke_seconds
		_puked = false
		Sfx.play(&"puke", puke_volume_db, 0.05)
	_puke_left -= delta
	if not _puked and _puke_left <= puke_seconds - puke_splat_delay:
		_puked = true
		_spawn_puke_puddle()
	if _puke_left > 0.0 and _puke_left < puke_seconds - 0.3:
		_visual_shake = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 0.5)) * puke_shake_pixels
	else:
		_visual_shake = Vector2.ZERO
		if _puke_left <= 0.0:
			_puke_left = 0.0

## Off the sand (see the Wading exports) the car sinks a little more every
## moment, splashing on the way in; sunk to its axles it's stuck for good and
## the tow truck gets called (TowTruckRescueCutscene). Back on land it drains
## and lets go. Called every frame, so the water line and sink offset follow.
func _update_wading(delta: float, in_water: bool) -> void:
	if in_water and _sink <= 0.0:
		Sfx.play(&"car_splash", splash_volume_db, 0.05)
	if in_water:
		_sink = minf(_sink + delta / sink_seconds, 1.0)
	else:
		_sink = maxf(_sink - delta / drain_seconds, 0.0)
		_stuck = false
		_tow_called = false
	if in_water and _sink >= 1.0 and not _stuck:
		_stuck = true
		velocity = Vector2.ZERO
		Sfx.play(&"car_sink_glug", glug_volume_db)
	if _stuck and not _tow_called and not Cutscenes.is_active():
		_tow_called = true
		var rescue := TOW_RESCUE as TowTruckRescueCutscene
		rescue.car = self
		Cutscenes.play(rescue)
	_water_line.level = _sink if in_water else 0.0
	_visual.position = _visual_shake + Vector2(0.0, _sink * sink_depth)

## The rod's use check (see Inventory.use_blocked_reason()): "" when there's
## water to cast into and nothing in the way.
func _fishing_blocked_reason(_item: ItemData) -> String:
	if is_instance_valid(_fishing):
		return "You've already got a line in."
	if _stuck or Cutscenes.is_active():
		return "Not now."
	if _find_cast_spot() == null:
		return "No water close enough to cast into. Park by the sea."
	return ""

func _on_item_used(item: ItemData) -> void:
	if item.use_effect != &"fish":
		return
	var spot: Variant = _find_cast_spot()
	if spot == null:
		return
	velocity = Vector2.ZERO
	_fishing = FishingCast.new()
	_fishing.spot = spot
	_fishing.finished.connect(_on_fishing_finished)
	add_child(_fishing)

## The nearest open water around the car, searched outward in rings, or null.
## A spot only counts with more sea past it (so the bobber lands out in the
## blue, not in the surf), and roads (a bridge deck) don't count as water.
func _find_cast_spot() -> Variant:
	if _terrain == null:
		return null
	var distance := cast_min_distance
	while distance <= cast_reach:
		for i in 16:
			var direction := Vector2.from_angle(TAU * i / 16.0)
			var point := global_position + direction * distance
			if _is_open_water(point) and _is_open_water(point + direction * cast_ring_step * 3.0):
				return point
		distance += cast_ring_step
	return null

func _is_open_water(point: Vector2) -> bool:
	return _terrain.is_in_water(_terrain.to_local(point)) \
			and not (_road_network != null and _road_network.is_on_road(point)) \
			and not BlockedBridge.any_deck_under(get_tree(), point)

## Whatever was on the hook flies out of the sea into the car: an old boot, a
## car part, or (most of the time) a handful of scrap.
func _on_fishing_finished(caught: bool, spot: Vector2) -> void:
	_fishing = null
	if not caught:
		return
	var roll := randf()
	if roll < catch_boot_chance:
		Sfx.play_at(&"boot_squelch", spot, -4.0)
		Pickup.spawn_float_text(get_parent(), spot + Vector2(0.0, -60.0), "Just an old boot.")
		return
	var orb: Pickup
	var pools := [PartDatabase.junk_wheels, PartDatabase.junk_bodies, PartDatabase.junk_engines].filter(
			func(pool: Array) -> bool: return not pool.is_empty())
	if roll < catch_boot_chance + catch_part_chance and not pools.is_empty():
		var pool: Array = pools.pick_random()
		var part_orb := PART_PICKUP.instantiate() as PartPickup
		part_orb.configure(pool.pick_random())
		orb = part_orb
	else:
		var scrap_orb := SCRAP_PICKUP.instantiate() as ScrapPickup
		scrap_orb.amount = randi_range(catch_scrap.x, catch_scrap.y)
		orb = scrap_orb
	get_parent().add_child(orb)
	orb.launch(spot, global_position, 120.0, 0.8)

## Drips the beaten-up driver's blood behind the car (see the Bleeding
## exports). Checked every frame, so it stops the moment the quests say
## they're patched up.
func _update_blood(delta: float) -> void:
	var level := CharacterInjuries.current_level()
	if level <= 0 or Cutscenes.is_active():
		return
	var heavy := level >= 2
	var moved := velocity.length() * delta
	_blood_distance += moved
	_blood_idle += delta
	var spacing := blood_drop_spacing.y if heavy else blood_drop_spacing.x
	var drip := _blood_distance >= spacing
	if heavy and moved < 0.5 and _blood_idle >= blood_idle_drip_seconds:
		drip = true
	if not drip:
		return
	_blood_distance = 0.0
	_blood_idle = 0.0
	var trail := _get_blood_trail()
	var at := global_position + Vector2(randf_range(-10.0, 10.0), randf_range(-4.0, 4.0))
	var radius := (blood_drop_radius.y if heavy else blood_drop_radius.x) * randf_range(0.8, 1.2)
	if heavy and moved > 0.5 and randf() < blood_smear_chance:
		trail.add_smear(at, at - velocity.normalized() * randf_range(18.0, 30.0), radius * 1.2)
	else:
		trail.add_drop(at, radius)

func _get_blood_trail() -> BloodTrail:
	if is_instance_valid(_blood_trail):
		return _blood_trail
	_blood_trail = BloodTrail.new()
	if _skid_marks != null:
		_skid_marks.add_child(_blood_trail)
	else:
		_blood_trail.z_index = -1
		get_parent().add_child(_blood_trail)
	return _blood_trail

func _spawn_puke_puddle() -> void:
	var puddle := PukePuddle.new()
	puddle.position = global_position
	if _skid_marks != null:
		_skid_marks.add_child(puddle)
	else:
		puddle.z_index = -1
		get_parent().add_child(puddle)
	if randf() < puke_dog_chance:
		PukeDog.send_to(puddle, get_parent())

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

## The exported path first, falling back to searching the current scene for
## the first node of `type` — the same convention TrashSpawner uses — so a
## reparented car still finds its roads, skid-mark layer, puddles and terrain.
## Null is a valid answer (the junkyard has no puddles or sea).
func _resolve_in_scene(path: NodePath, type: Script) -> Node:
	var node := get_node_or_null(path)
	if is_instance_of(node, type):
		return node
	var scene := get_tree().current_scene
	if scene == null:
		scene = get_parent()
	var stack: Array[Node] = [scene]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if is_instance_of(current, type):
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
	# A target can ask to win over its neighbours with a duck-typed
	# get_interact_priority() (a person standing by a building's door returns
	# 1, so E talks to them instead of walking into the building). Everything
	# else is 0 and keeps its physics order.
	var ranked := found.map(func(target: Object) -> Array: return [_interact_priority(target), target])
	for i in ranked.size():
		ranked[i].append(i)
	ranked.sort_custom(func(a: Array, b: Array) -> bool:
		return a[0] > b[0] if a[0] != b[0] else a[2] < b[2])
	found.clear()
	for entry in ranked:
		found.append(entry[1])
	return found

func _interact_priority(target: Object) -> int:
	if target.has_method("get_interact_priority"):
		return int(target.call("get_interact_priority"))
	return 0

## Cutscenes play without the HUD in the way. The night tint lives in the
## same layer but is part of the world's look, so it stays.
func _set_hud_visible(shown: bool) -> void:
	for child in $UI.get_children():
		if child.name != &"NightOverlay" and child != _hold_bar_bg:
			child.visible = shown
	if not shown:
		_hide_hold_bar()

func _process_interaction(delta: float) -> void:
	if Cutscenes.is_active():
		return
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
		_lift_prompt_above_scene_hint()
	else:
		_tooltip_label.visible = false

	var hold_duration := _hold_duration_for(target)
	var interact_pressed := _is_key_held(KEY_E)

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

	# T at a race entrance starts a debug race with random cars (see DebugRace).
	var test_pressed := _is_key_held(KEY_T)
	if target != null and test_pressed and not _test_pressed_last:
		_enter_debug_race(target)
	_test_pressed_last = test_pressed

## True for a target that only answers to a mouse click. It still advertises
## `display_name` (so the car can find it and click it) but the E prompt
## and the hold bar are skipped for it.
func _is_click_only(target: Object) -> bool:
	if target != null and target.has_method("uses_click_interaction"):
		return bool(target.call("uses_click_interaction"))
	return false

## Some scenes (the cemetery, the junkyard) keep their own hint line in the
## same bottom-centre slot as the tooltip. While one of those ("scene_hint"
## group) is showing, the tooltip and its hold bar ride a line above it so
## the two never print over each other.
func _lift_prompt_above_scene_hint() -> void:
	var lift := 0.0
	for hint in get_tree().get_nodes_in_group(&"scene_hint"):
		if hint is Label and hint.is_visible_in_tree() and hint.text != "":
			lift = SCENE_HINT_LIFT
			break
	_tooltip_label.offset_top = TOOLTIP_TOP - lift
	_tooltip_label.offset_bottom = TOOLTIP_BOTTOM - lift
	_hold_bar_bg.offset_top = HOLD_BAR_TOP - lift
	_hold_bar_bg.offset_bottom = HOLD_BAR_BOTTOM - lift

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
		SceneLoader.change_scene_packed(interior)

func _enter_debug_race(target: Object) -> void:
	var race_scene = target.get("debug_race_scene")
	if race_scene is PackedScene:
		Sfx.play(&"door_close", -4.0)
		DebugRace.request()
		SceneLoader.change_scene_packed(race_scene)
