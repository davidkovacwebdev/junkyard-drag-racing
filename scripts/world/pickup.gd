class_name Pickup
extends Area2D
## Master class for everything the player runs over and collects: the scrap and
## car parts a looted bin coughs up onto the road.
##
## A pickup is a floating orb — a flat circle with a dark edge that hovers over
## a small ground shadow, rising and falling on the spot. It's an `Area2D`, not
## something solid: the car drives *straight through* it and collection happens
## on contact. That's the whole reason this exists separately from `TrashProp` —
## the bin is the thing you stop at and open, the orbs are the thing you scoop up
## on the way past.
##
## Art style is flat: plain fills, no outlines, no gloss. Colours carry the
## meaning — the ball's tint is what tells you whether it's scrap or which kind
## of part — so nothing is layered on top to compete with it.
##
## Subclasses only have to answer two questions — `grant()` (what am I worth?)
## and `label_text()` (what should the "+N" line say?) — plus optionally
## `_draw_icon()` for art inside the orb. The orb itself, the arc out of the bin,
## the bob, collect-on-contact, and the text that rises when you grab it all
## live here, so every material that drops out of a bin behaves identically.
##
## **Art space** deliberately matches `TrashProp`: this node's origin is the
## ground contact point and the orb is drawn above it (negative Y). Bobbing the
## *drawing* instead of the node keeps the Y-sort position pinned to the ground,
## so an orb can't flicker in front of and behind the car as it floats — which
## is exactly what moving this node up and down would do under a Y-sorted parent.

## Emitted once, as the orb is being collected.
signal collected(by: Node)

## Resting clearance of the orb's centre above the ground contact point.
const HOVER := 44.0
## How big the glowing ball is drawn.
const ORB_RADIUS := 21.0
## How far the (invisible) collection circle reaches. Generous on purpose — the
## point is that driving over the loot picks it up, not that you have to stop on
## top of it.
const COLLECT_RADIUS := 40.0
## How far the orb rises and falls, and how fast. Readable rather than subtle:
## the float is the pickup's whole silhouette, and it's what says "worth driving
## over" from across the road. The ball hangs `HOVER` above the ground at the
## bottom of the swing and `HOVER + BOB_HEIGHT` at the top.
const BOB_HEIGHT := 9.0
const BOB_SPEED := 1.9
## How long a dropped pickup waits before it gives up and fades, so a bin you
## emptied and drove away from doesn't litter the street forever.
const LIFETIME := 50.0
const FADE_TIME := 4.0
const POPUP_RISE := 42.0
const POPUP_LIFETIME := 1.05
const POPUP_WIDTH := 260.0

@export_group("Colors")
## Body of the ball. `PartPickup` retints this per part category, so the rare
## drops announce what they are at a glance.
@export var orb_color: Color = Color(0.55, 0.82, 0.9, 1.0)
## The soft circle behind the ball. Faint on purpose — see `_draw()`.
@export var glow_color: Color = Color(0.5, 0.85, 0.95, 1.0)
@export var shadow_color: Color = Color(0.0, 0.0, 0.0, 0.18)
@export var text_color: Color = Color(1.0, 0.97, 0.85, 1.0)
@export var text_outline_color: Color = Color(0.08, 0.07, 0.05, 1.0)

## Where the orb's centre sits relative to the origin. Animated: it starts at the
## bin's mouth and arcs down to `_rest_offset`.
var _orb_offset: Vector2 = Vector2(0.0, -HOVER)
var _rest_offset: Vector2 = Vector2(0.0, -HOVER)
## Flight out of the bin that dropped this: local start offset, arc height,
## how long it takes, and how long it waits before it starts.
var _flight_from: Vector2 = Vector2.ZERO
var _flight_arc: float = 0.0
var _flight_time: float = 0.0
var _flight_duration: float = 0.0
var _flying: bool = false
var _bob_phase: float = 0.0
var _age: float = 0.0
var _collected: bool = false

var _shape: CollisionShape2D = null
## Optional child holding real part art to draw inside the orb — only
## `PartPickup` uses it, but the base keeps it in step with the bob.
var _icon: Node2D = null
## Centering offset applied to `_icon` so the art sits on the orb's centre.
var _icon_center: Vector2 = Vector2.ZERO

func _ready() -> void:
	# No z_index override on purpose: the orb takes part in the Y-sort of
	# whatever holds it, exactly like the props and the car do. Forcing a Z here
	# would make it float in front of the car even when the car is nearer the
	# camera, which looks worse than the rare case of a nearby bin clipping it.
	collision_layer = 0
	_build_collision()
	_bob_phase = randf() * TAU

## A single circle at the resting spot. Deliberately not moved during the flight
## out of the bin: the trigger waits where the orb is going to land, so a lob
## can't be grabbed out of the air by a car that happens to be driving past the
## bin at that moment.
func _build_collision() -> void:
	_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if _shape == null:
		_shape = CollisionShape2D.new()
		_shape.name = "CollisionShape2D"
		add_child(_shape)
	var circle := CircleShape2D.new()
	circle.radius = COLLECT_RADIUS
	_shape.shape = circle
	_shape.position = _rest_offset

# --- Dropping in ---------------------------------------------------------------

## Fling the orb out of `from_orb_global` (where it leaves the bin) and let it
## settle on the ground at `to_ground_global`, bowing `arc` pixels upward on the
## way. `delay` staggers a whole handful so they spill rather than all leave at
## once.
func launch(from_orb_global: Vector2, to_ground_global: Vector2, arc: float,
		duration: float, delay: float = 0.0) -> void:
	global_position = to_ground_global
	_flight_from = from_orb_global - to_ground_global
	_orb_offset = _flight_from
	_flight_arc = arc
	_flight_duration = maxf(duration, 0.01)
	_flight_time = -delay
	_flying = true
	_sync_icon()

func _process(delta: float) -> void:
	if _collected:
		return
	if _flying:
		_flight_time += delta
		if _flight_time <= 0.0:
			_orb_offset = _flight_from
		else:
			var t := clampf(_flight_time / _flight_duration, 0.0, 1.0)
			# Ease the horizontal travel out so it plops where it lands instead
			# of arriving at full tilt; the arc is a plain sine bow on top.
			var eased := 1.0 - pow(1.0 - t, 2.0)
			_orb_offset = _flight_from.lerp(_rest_offset, eased) \
					+ Vector2(0.0, -_flight_arc * sin(PI * t))
			if t >= 1.0:
				_flying = false
		_sync_icon()
		queue_redraw()
		return

	_bob_phase += delta * BOB_SPEED
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	# Fade out over the last stretch so an ignored orb quietly evaporates
	# instead of vanishing on a frame boundary.
	var remaining := LIFETIME - _age
	modulate.a = clampf(remaining / FADE_TIME, 0.0, 1.0) if remaining < FADE_TIME else 1.0
	_orb_offset = _rest_offset + Vector2(0.0, sin(_bob_phase) * BOB_HEIGHT)
	_sync_icon()
	queue_redraw()

## Walk the collection circle past the car each physics frame rather than
## relying on `body_entered`: a prop dropped on top of a parked car is already
## overlapping the moment it spawns, and an entry event may never fire.
func _physics_process(_delta: float) -> void:
	if _collected:
		return
	for body in get_overlapping_bodies():
		if body is PlayerCar:
			collect(body)
			return

## Keep the child icon (see `PartPickup`) sitting on the ball as it moves. It
## gets a lazy fraction of the bob as a rotation instead of a full swing — a
## wheel tumbling in step with the float looks mechanical.
func _sync_icon() -> void:
	if _icon == null:
		return
	_icon.position = _orb_offset + _icon_center
	_icon.rotation = sin(_bob_phase * 0.5) * 0.09

# --- Collecting ----------------------------------------------------------------

## Grab it. Safe to call more than once — the second call is ignored.
func collect(by: Node = null) -> void:
	if _collected:
		return
	_collected = true
	set_process(false)
	set_physics_process(false)
	monitoring = false
	grant()
	var text := label_text()
	if not text.is_empty():
		_spawn_float_text(text)
	collected.emit(by)
	# A quick pop-and-fade on the orb's way out. The text is a separate node (see
	# `_spawn_float_text`), so it survives this.
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(1.35, 1.35), 0.16)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)

## The line that floats up when this is grabbed. Empty = no text at all.
func label_text() -> String:
	return ""

## Bank whatever this orb is worth. Subclasses override; the base is a no-op.
func grant() -> void:
	pass

## Floating "+N" text, drifting up and fading over where the orb was. Parented
## to the pickup's *parent*, not the pickup — the orb is about to free itself and
## must not take the text down with it.
func _spawn_float_text(text: String) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", text_color)
	label.add_theme_color_override("font_outline_color", text_outline_color)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_font_size_override("font_size", 18)
	label.size = Vector2(POPUP_WIDTH, 28.0)
	label.z_as_relative = false
	label.z_index = 40
	parent.add_child(label)
	label.global_position = global_position \
			+ Vector2(-POPUP_WIDTH * 0.5, -HOVER - ORB_RADIUS - 42.0)
	var tween := label.create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "global_position:y",
			label.global_position.y - POPUP_RISE, POPUP_LIFETIME)
	tween.parallel().tween_property(label, "modulate:a", 0.0, POPUP_LIFETIME * 0.6) \
			.set_delay(POPUP_LIFETIME * 0.4)
	tween.tween_callback(label.queue_free)

# --- Drawing -------------------------------------------------------------------

func _draw() -> void:
	# The shadow sits on the ground and never follows the ball. That gap is the
	# whole read: a circle bobbing over its own shadow looks like it's hovering,
	# and the same circle bobbing on its own just looks like it's twitching. It
	# tightens as the ball rises, which is what makes the float read as height
	# instead of as the whole thing sliding up and down the screen.
	var lift := clampf(1.0 - (_rest_offset.y - _orb_offset.y) * 0.005, 0.72, 1.0)
	draw_colored_polygon(_ellipse(Vector2(0.0, -3.0), ORB_RADIUS * 0.9 * lift,
			ORB_RADIUS * 0.3 * lift), shadow_color)
	# Then a faint circle behind the ball and the flat ball itself. No edge line,
	# no highlight, no gradient: the silhouette has to stay legible from a car
	# doing 200, and linework at this size just reads as grime.
	var glow := glow_color
	glow.a *= 0.13
	draw_circle(_orb_offset, ORB_RADIUS * 1.42, glow)
	draw_circle(_orb_offset, ORB_RADIUS, orb_color)
	_draw_icon(_orb_offset, ORB_RADIUS)

## Ring of points for a squashed circle, used here for the ground shadow.
## `draw_circle` has no way to squash itself, and building the ring by hand beats
## saving and restoring the draw transform around every pickup.
func _ellipse(center: Vector2, rx: float, ry: float, steps: int = 20) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in steps:
		var angle := TAU * float(i) / float(steps)
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	return points

## Art inside the orb, in this node's local space. Base draws nothing; a part
## orb puts the real part art in a child instead (see `PartPickup`), while a
## scrap orb draws its chunks here.
func _draw_icon(_center: Vector2, _radius: float) -> void:
	pass
