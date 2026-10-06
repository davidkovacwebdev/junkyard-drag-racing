@tool
class_name BaconSmoker
extends StaticBody2D
## Grandpa's homemade bacon smoker by his garage: two oil drums with a yellow
## warning sign laid across them for a grill, bacon sizzling on it, and a
## frame of two sign posts (one still wearing its STOP sign) with a bar
## across the top. Once the player brings him the chains, bacon hangs off
## them from the bar. A couple of big smoke puffs roll up off the grill and
## it sizzles now and then.
##
## Origin on the ground between the drums so it Y-sorts against the car.
## StoryDirector parks it next to Grandpa; it only shows up once he's
## started on "Chains" (see `QUEST_ID`), and the chains go up when that's
## done.

const QUEST_ID := &"chain_gang"
## For cutscenes to find it.
const GROUP := &"bacon_smoker"

const DRUM := Color(0.36, 0.42, 0.5)
const DRUM_SHADE := Color(0.28, 0.33, 0.4)
const SIGN_YELLOW := Color(0.85, 0.66, 0.12)
const STOP_RED := UiPalette.DANGER_RED
const POST := UiPalette.POST_GREY
const BACON := Color(0.82, 0.45, 0.42)
const CHAIN := UiPalette.STEEL_SHADE
const SMOKE := Color(0.72, 0.72, 0.7, 0.55)

const DRUM_RADIUS := 24.0
const DRUM_HEIGHT := 52.0
const DRUM_X := 28.0
const POST_X := 84.0
const BAR_Y := -132.0
const CHAIN_XS: Array[float] = [-34.0, 22.0]
const CHAIN_LENGTH := 30.0
const SMOKE_PUFFS := 2
## How long one puff takes to rise and fade, and how far it goes.
const SMOKE_SECONDS := 2.4
const SMOKE_RISE := 90.0

## Bacon hangs off chains from the top bar.
@export var chains_hung: bool = false:
	set(value):
		chains_hung = value
		queue_redraw()

var _time: float = 0.0
var _collision: CollisionShape2D
var _sizzle: AmbientCall

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group(GROUP)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(POST_X * 2.0 + 16.0, 16.0)
	_collision = CollisionShape2D.new()
	_collision.shape = shape
	_collision.position = Vector2(0.0, -6.0)
	add_child(_collision)
	_sizzle = AmbientCall.new()
	_sizzle.sound_name = &"bacon_sizzle"
	_sizzle.interval_range = Vector2(3.0, 6.0)
	_sizzle.volume_db = -10.0
	_sizzle.max_distance = 900.0
	_sizzle.position = Vector2(0.0, -DRUM_HEIGHT)
	add_child(_sizzle)
	_sync_to_quest()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_sync_to_quest()
	if visible:
		_time += delta
		queue_redraw()

## Shows up while "Chains" is on (and after), with the chains up once it's
## done.
func _sync_to_quest() -> void:
	var shown := Quests.has_quest(QUEST_ID) or Quests.is_complete(QUEST_ID)
	if shown != visible:
		visible = shown
		_collision.disabled = not shown
		_sizzle.process_mode = Node.PROCESS_MODE_INHERIT if shown else Node.PROCESS_MODE_DISABLED
	if Quests.is_complete(QUEST_ID) and not chains_hung:
		chains_hung = true

## Where the chains hang, in the world: what a cutscene looks at.
func bar_center() -> Vector2:
	return global_position + Vector2(0.0, BAR_Y + 30.0)

func _draw() -> void:
	draw_colored_polygon(FlatProps.octagon(Vector2(8.0, 2.0), POST_X + 10.0, 12.0), UiPalette.SHADOW)
	# The frame: two posts, the STOP sign on the right one, a bar across.
	for x: float in [-POST_X, POST_X]:
		draw_colored_polygon(FlatProps.sliver(Vector2(x, 0.0), Vector2(x, BAR_Y - 6.0), 7.0), POST)
	draw_colored_polygon(FlatProps.sliver(Vector2(-POST_X - 4.0, BAR_Y), Vector2(POST_X + 4.0, BAR_Y), 7.0), POST)
	draw_colored_polygon(FlatProps.octagon(Vector2(POST_X, BAR_Y - 24.0), 20.0, 20.0), STOP_RED)
	if chains_hung:
		for i in CHAIN_XS.size():
			var x: float = CHAIN_XS[i]
			var sway := sin(_time * 1.6 + i) * 3.0
			var end := Vector2(x + sway, BAR_Y + CHAIN_LENGTH)
			draw_colored_polygon(FlatProps.sliver(Vector2(x, BAR_Y), end, 5.0), CHAIN)
			draw_colored_polygon(PackedVector2Array([
				end + Vector2(-8.0, 0.0), end + Vector2(8.0, 0.0), end + Vector2(10.0, 18.0),
				end + Vector2(6.0, 38.0), end + Vector2(-8.0, 36.0), end + Vector2(-6.0, 18.0),
			]), BACON)
	# The drums.
	for x: float in [-DRUM_X, DRUM_X]:
		draw_rect(Rect2(x - DRUM_RADIUS, -DRUM_HEIGHT, DRUM_RADIUS * 2.0, DRUM_HEIGHT), DRUM)
		draw_rect(Rect2(x + DRUM_RADIUS - 9.0, -DRUM_HEIGHT, 9.0, DRUM_HEIGHT), DRUM_SHADE)
	# A warning sign laid flat across them for a grill, bacon on top.
	var top := -DRUM_HEIGHT
	draw_colored_polygon(PackedVector2Array([
		Vector2(-62.0, top), Vector2(0.0, top - 12.0), Vector2(62.0, top), Vector2(0.0, top + 10.0),
	]), SIGN_YELLOW)
	for strip: Vector2 in [Vector2(-22.0, top - 2.0), Vector2(14.0, top)]:
		draw_colored_polygon(PackedVector2Array([
			strip + Vector2(-14.0, -3.0), strip + Vector2(14.0, -5.0),
			strip + Vector2(15.0, 2.0), strip + Vector2(-13.0, 4.0),
		]), BACON)
	if Engine.is_editor_hint():
		return
	# Smoke rolling up off the grill: a couple of big puffs, staggered.
	for i in SMOKE_PUFFS:
		var t := fmod(_time / SMOKE_SECONDS + float(i) / SMOKE_PUFFS, 1.0)
		var at := Vector2(-6.0 + sin(t * 4.0 + i) * 10.0, top - 14.0 - t * SMOKE_RISE)
		var radius := 12.0 + t * 14.0
		var smoke := SMOKE
		smoke.a *= 1.0 - t
		draw_colored_polygon(FlatProps.octagon(at, radius, radius * 0.8), smoke)
