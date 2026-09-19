class_name PlayerCar
extends CharacterBody2D
## Side-view movement, not top-down: A/D (or Left/Right) move the car
## horizontally and flip it to face that direction; W/S (or Up/Down) move
## it vertically with no flip and no rotation at all. Two independent
## axes, no steering/turning-radius physics — there's no "reverse
## steers backwards" case here since the car never rotates.

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
## Same convention as TrashSpawner.roads_path: the exported path first,
## falling back to searching the scene for any RoadNetwork if it doesn't
## resolve (e.g. this scene got reparented).
@export var roads_path: NodePath = ^"../Roads"

var _facing_right: bool = true
var _space_pressed_last: bool = false
## Which target the current hold is building up against, and how far
## along it is (seconds held). Resets to null/0 the instant space is
## released or the player looks away from that target.
var _holding_target: Object = null
var _hold_progress: float = 0.0

@onready var _interaction_zone: Area2D = $InteractionZone
@onready var _tooltip_label: Label = $UI/TooltipLabel
@onready var _hold_bar_bg: Control = $UI/HoldBarBg
@onready var _hold_bar_fill: Control = $UI/HoldBarBg/HoldBarFill
@onready var _scrap_label: Label = $UI/ScrapLabel

var _road_network: RoadNetwork = null

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_road_network = _resolve_roads()
	var car := Inventory.get_selected_car()
	if car != null:
		$Visual.build_from(car)
	# Coming back from a place (garage, drag strip race): reappear where we
	# left the map instead of at the scene's default spawn.
	if WorldState.has_player_position:
		global_position = WorldState.player_position
	# If space was still held when the previous scene ended, don't let it
	# count as a fresh press here — that would instantly re-enter the place
	# we just exited.
	_space_pressed_last = Input.is_physical_key_pressed(KEY_SPACE)

const _DRIVE_KEYS := [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_SPACE]

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
		_space_pressed_last = false

## Left-click is how you deal with a person rather than a place (the junkyard's
## scrap dealer). It's a point query into the physics world, not a mouse-over
## test, because the *car* is what has to be in reach: clicking him only counts
## if he's also showing up in the interaction zone, so you can't reach across
## the yard. Anything the click handles is consumed so it can't double up with
## the space path.
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
	$Visual.scale.x = 1.0 if _facing_right else -1.0

	# One on-road check feeds both multipliers, rather than querying the
	# road network twice for the same answer.
	var on_road := _road_network != null and _road_network.is_on_road(global_position)

	var target_velocity := Vector2.ZERO
	if input_dir != Vector2.ZERO:
		var speed_multiplier := on_road_speed_multiplier if on_road else off_road_speed_multiplier
		target_velocity = input_dir.normalized() * max_speed * speed_multiplier
	var handling_multiplier := on_road_handling_multiplier if on_road else off_road_handling_multiplier
	var accel_rate := (acceleration if input_dir != Vector2.ZERO else friction) * handling_multiplier
	velocity = velocity.move_toward(target_velocity, accel_rate * delta)
	move_and_slide()

	# Keep the saved spot current so entering any place (or any other scene
	# change) returns us to exactly here.
	WorldState.remember_player(global_position)

	# The only thing looting actually tracks right now — a plain running
	# total, no distinct item types yet — so this is the whole HUD for now.
	# Money joins it because the scrap dealer at the junkyard pays out.
	_scrap_label.text = "Scrap: %d    $%d" % [Inventory.scrap, Inventory.money]

	_process_interaction(delta)

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

## Nearby buildings are just StaticBody2Ds with a non-empty `display_name`
## property (duck-typed, not a shared base class) that overlap this zone.
## Returns all of them, in physics order: the zone can overlap two things at
## once (parked between the scrap dealer and the crane, say), and the caller
## needs to know about the others to pick one that answers to the space bar.
func _find_interactables() -> Array[Object]:
	var found: Array[Object] = []
	for body in _interaction_zone.get_overlapping_bodies():
		var target_name = body.get("display_name")
		if typeof(target_name) == TYPE_STRING and target_name != "":
			found.append(body)
	return found

func _process_interaction(delta: float) -> void:
	var candidates := _find_interactables()

	# Prefer something the space bar can actually work on. A click-only target
	# (the scrap dealer says so via uses_click_interaction()) is never activated
	# by space, so letting it shadow a normal target nearby would make the space
	# bar stop working for no visible reason — but it still gets the tooltip
	# while nothing else is in reach, otherwise there'd be nothing to tell you
	# the dealer is clickable at all.
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
		_tooltip_label.visible = true
	else:
		_tooltip_label.visible = false

	var hold_duration := _hold_duration_for(target)
	var space_pressed := Input.is_physical_key_pressed(KEY_SPACE)

	if target != null and space_pressed and hold_duration > 0.0:
		if _holding_target != target:
			_holding_target = target
			_hold_progress = 0.0
		_hold_progress += delta
		_set_hold_bar(_hold_progress / hold_duration)
		if _hold_progress >= hold_duration:
			_activate(target)
			_holding_target = null
			_hide_hold_bar()
	elif target != null and space_pressed and not _space_pressed_last:
		_activate(target)
		_holding_target = null
		_hide_hold_bar()
	else:
		_holding_target = null
		_hide_hold_bar()

	_space_pressed_last = space_pressed

## True for a target that only answers to a mouse click. It still advertises
## `display_name` (so the car can find it and click it) but the space prompt
## and the hold bar are skipped for it.
func _is_click_only(target: Object) -> bool:
	if target != null and target.has_method("uses_click_interaction"):
		return bool(target.call("uses_click_interaction"))
	return false

## The tooltip line. The default is about the space key, which is the wrong
## thing to say about a click-only target, so a target can write its own
## (the dealer's doubles as the "how much scrap have I got" readout).
func _interact_prompt(target: Object) -> String:
	if target.has_method("get_interact_prompt"):
		var line: Variant = target.call("get_interact_prompt")
		if typeof(line) == TYPE_STRING and line != "":
			return line
	var verb_prompt := "Hold" if _hold_duration_for(target) > 0.0 else "Press"
	return "%s: %s space to %s" % [target.display_name, verb_prompt, _interact_verb(target)]

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
		get_tree().change_scene_to_packed(interior)
