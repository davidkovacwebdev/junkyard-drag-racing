class_name PunkerEngine
extends CarEngine
## A person as an engine (Vern and the crane workers), hauled out of the crane
## pen by the claw. The part's origin is the hitch on the body's EngineMount; he
## runs in front of the car with the tow rope over his shoulder and drags the
## thing along himself.
##
## Built like HorseEngine: `attach_to_body()` stands him on the ground past the
## body's nose, and the run is driven by how far he actually moves, so he pelts
## along in a race, on the map and backs up when the car reverses, and stands
## there catching his breath when parked.
##
## He's a CharacterRig on his character's .tres, not a copy of the art, so he
## can't drift from the NPC version. The run is just his own leg and boot
## polygons stomping up and down in turn, a bob, and a lean into the rope. He
## faces the camera the whole time, like everyone in this game.
##
## The character comes from the Character node's `character_data`, or from the
## part's own `runner` when it's a RunnerEnginePartData.

## How far his art reaches behind his own origin (his arm, at half size).
const REAR_REACH := 18.0
## Wheels hang below their mounts by about a standard wheel's radius, which is
## where the ground is.
const WHEEL_RADIUS_GUESS := 36.0
## Distance covered by one full stride, in runner pixels. Short: little legs.
const STRIDE_LENGTH := 70.0
## Speed (runner pixels/s) at which he's flat out.
const FULL_GAIT_SPEED := 300.0
## How far a leg swings forward and back from the hip, radians.
const LEG_SWING := 0.55
## How high the swinging foot comes up, in character pixels.
const KNEE_LIFT := 16.0
const RUN_BOUNCE := 10.0
## Lean into the rope at full tilt, radians.
const RUN_LEAN := 0.26
## Side-to-side rock onto whichever foot is down, radians.
const RUN_SWAY := 0.09
## How far the arms swing from the shoulder, against the legs, radians.
const ARM_SWING := 0.6
## Squash on each footfall, as a fraction of height.
const STOMP_SQUASH := 0.08
const LEAD_SEGMENTS := 10
const LEAD_WIDTH := 5.0
const LEAD_SAG_IDLE := 16.0
const LEAD_SAG_PULLING := 2.0
## The assembled character's slots that make up his top half: everything bobs
## together except the legs and boots, which stomp on their own.
const UPPER_SLOTS: Array[String] = ["TorsoPart", "HeadPart", "HairPart", "EyesPart", "AccessoryPart"]

## Space between the body's nose and the runner's back, in body pixels.
@export var lead_length := 18.0

## Scales how fast the legs cycle for the distance covered. The map car sets
## this below 1 so the shrunk runner doesn't scurry.
var gait_rate := 1.0

@onready var _harness: Node2D = $Harness
@onready var _lead: Polygon2D = $Harness/Lead
@onready var _runner: Node2D = $Harness/Runner
@onready var _character: CharacterRig = $Harness/Runner/Character
@onready var _lead_point: Marker2D = $Harness/Runner/LeadPoint

## Per side (left, right): [hip pivot, [leg and boot polygons]].
var _legs: Array = [[Vector2.ZERO, []], [Vector2.ZERO, []]]
var _upper: Array[Node2D] = []
## Per side: [shoulder pivot, [arm, hand, cuff polygons]].
var _arms: Array = [[Vector2.ZERO, []], [Vector2.ZERO, []]]
var _character_scale: Vector2
var _previous_position: Vector2
var _has_previous_position := false
var _gait_phase := 0.0
var _gait_blend := 0.0
var _idle_time := 0.0

func _ready() -> void:
	_harness.add_to_group(PartScale.OUTRIGGER_GROUP)
	_idle_time = randf() * 10.0
	var runner_part := part_data as RunnerEnginePartData
	if runner_part != null and runner_part.runner != null:
		_character.set_character(runner_part.runner)
	_character_scale = _character.scale
	if _character.assembled != null:
		CharacterAssembler.layer_by_child_order(_character.assembled)
	_find_limbs()
	_update_lead()

func _find_limbs() -> void:
	var body := _character.assembled
	if body == null:
		return
	# Every polygon of the legs and boots/slippers named ...Left or ...Right,
	# whatever the outfit calls them (BootLeft, SoleLeft, SlipperLeft, ...).
	for slot in ["LegsPart", "BootsPart"]:
		var part := body.get_node_or_null(slot)
		if part == null:
			continue
		for node in part.get_children():
			if node is Node2D:
				if node.name.ends_with("Left"):
					_legs[0][1].append(node)
				elif node.name.ends_with("Right"):
					_legs[1][1].append(node)
	for leg in _legs:
		leg[0] = _limb_pivot(leg[1])
	for slot in UPPER_SLOTS:
		var node := body.get_node_or_null(slot) as Node2D
		if node != null:
			_upper.append(node)
	var torso := body.get_node_or_null("TorsoPart")
	if torso != null:
		for i in 2:
			var side := "Left" if i == 0 else "Right"
			for part_name in ["Arm", "Hand", "Cuff"]:
				var node := torso.get_node_or_null(part_name + side) as Node2D
				if node != null:
					_arms[i][1].append(node)
			_arms[i][0] = _limb_pivot(_arms[i][1])

## The joint a limb swings from: the middle of its top edge, a little down.
func _limb_pivot(nodes: Array) -> Vector2:
	var top := INF
	var left := INF
	var right := -INF
	for node in nodes:
		if node is Polygon2D:
			for vertex in node.polygon:
				top = minf(top, vertex.y)
				left = minf(left, vertex.x)
				right = maxf(right, vertex.x)
	if top == INF:
		return Vector2.ZERO
	return Vector2((left + right) * 0.5, top + 6.0)

## Rotate a limb about its pivot and raise it by `lift`.
func _swing_limb(limb: Array, angle: float, lift: float) -> void:
	var pivot: Vector2 = limb[0]
	for node: Node2D in limb[1]:
		node.rotation = angle
		node.position = pivot - pivot.rotated(angle) + Vector2(0.0, -lift)

## The runner on his own, without the rope: CarView gives him his own
## collision shape apart from the car's.
func get_walker() -> Node2D:
	return _runner

## Stand him out in front of `body`, on the ground, upright relative to the
## body. Called by CarBody.place_engine().
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
	var stand_in_body := Vector2(nose + lead_length + REAR_REACH * _runner.scale.x, ground)
	_runner.position = transform.affine_inverse() * stand_in_body
	_runner.rotation = -rotation
	_update_lead()

func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	var travelled := _forward_travel()
	var speed := absf(travelled) / delta
	_gait_blend = lerpf(_gait_blend, clampf(speed / FULL_GAIT_SPEED, 0.0, 1.0), clampf(6.0 * delta, 0.0, 1.0))
	_gait_phase = wrapf(_gait_phase + travelled / STRIDE_LENGTH * TAU * gait_rate, 0.0, TAU)
	_idle_time += delta
	_animate()
	_update_lead()

## Distance moved since last frame along his forward axis, in his own pixels,
## so the stride matches whether the car is shrunk down on the map or full
## size in a race, and goes negative when reversing.
func _forward_travel() -> float:
	var position_now := _runner.global_position
	var travelled := 0.0
	if _has_previous_position:
		var forward := _runner.global_transform.x
		var world_scale := forward.length()
		if world_scale > 0.0:
			travelled = (position_now - _previous_position).dot(forward / world_scale) / world_scale
	_previous_position = position_now
	_has_previous_position = true
	return travelled

## Legs striding forward and back from the hip, the swinging foot lifted,
## arms swinging against them, the top half bouncing and rocking onto the
## planted foot, squashing on every stomp, and leaning into the rope; parked,
## a heavy heave of breath.
func _animate() -> void:
	for i in 2:
		var stride := sin(_gait_phase + PI * i) * _gait_blend
		var lift := maxf(0.0, cos(_gait_phase + PI * i)) * KNEE_LIFT * _gait_blend
		_swing_limb(_legs[i], -stride * LEG_SWING, lift)
		_swing_limb(_arms[i], stride * ARM_SWING, 0.0)
	var panting := sin(_idle_time * 5.0) * 2.0 * (1.0 - _gait_blend)
	var bounce := -absf(sin(_gait_phase)) * RUN_BOUNCE * _gait_blend
	for node in _upper:
		node.position.y = bounce + panting
	var footfall := pow(1.0 - absf(sin(_gait_phase)), 4.0) * _gait_blend
	_character.scale = _character_scale * Vector2(1.0 + STOMP_SQUASH * footfall, 1.0 - STOMP_SQUASH * footfall)
	_character.rotation = RUN_LEAN * _gait_blend + sin(_gait_phase) * RUN_SWAY * _gait_blend

## A rope from the hitch to his shoulder, sagging when slack and pulled
## straight when he's running.
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
