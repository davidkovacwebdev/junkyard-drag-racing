@tool
class_name FarmProp
extends StaticBody2D
## One piece of the farm landmark: a fence run, a hay bale, a windmill, a water
## trough, a scarecrow, the roadside sign or the dirt yard under it all. Flat polygons only,
## drawn in _draw(), origin on the ground (like trees) so it Y-sorts against the
## car. The collision footprint hugs the ground and is built at runtime.
##
## During Grandpa's "Fenced In" every fence run counts the car's hard rams
## (PlayerCar's `car_rammed()`) toward the quest's `count_goal`, and the last
## one knocks a piece of fence loose (an ItemPickup) for the player to take.

enum Kind { FENCE, HAY_BALE, WINDMILL, TROUGH, SIGN, YARD, SCARECROW }

@export var kind: Kind = Kind.FENCE:
	set(value):
		kind = value
		queue_redraw()
## Fence: run length. Yard: ignored (see `yard_size`).
@export var length: float = 200.0:
	set(value):
		length = value
		queue_redraw()
## Fence only: runs down the screen (into the distance) instead of across it.
@export var vertical: bool = false:
	set(value):
		vertical = value
		queue_redraw()
@export var yard_size: Vector2 = Vector2(900, 400):
	set(value):
		yard_size = value
		queue_redraw()
@export var sign_title: String = "FARM":
	set(value):
		sign_title = value
		queue_redraw()
@export var sign_subtitle: String = "":
	set(value):
		sign_subtitle = value
		queue_redraw()

const WOOD := Color(0.5, 0.36, 0.22)
const WOOD_LIGHT := Color(0.6, 0.44, 0.27)
const WOOD_DARK := Color(0.4, 0.28, 0.17)
const STRAW := Color(0.86, 0.72, 0.36)
const STRAW_SHADE := Color(0.76, 0.62, 0.3)
const STRAW_LIGHT := Color(0.92, 0.8, 0.46)
const WATER := Color(0.35, 0.5, 0.55)
const DIRT := Color(0.62, 0.5, 0.34)
const DIRT_DARK := Color(0.56, 0.44, 0.3)
const VANE_RED := Color(0.62, 0.2, 0.16)
const SHIRT := Color(0.5, 0.26, 0.2)

const FENCE_POST_SPACING := 40.0
const FENCE_DEPTH_POST_SPACING := 30.0
const FENCE_HEIGHT := 34.0
const WINDMILL_HEIGHT := 170.0
const WINDMILL_BLADES := 4
const WINDMILL_BLADE_LENGTH := 44.0
const WINDMILL_SPIN := 1.4

const FENCE_QUEST := preload("res://quests/fence_for_tiger.tres")
const FENCE_PIECE := preload("res://items/fence_piece.tres")
## Rams closer together than this count once, so one crunch isn't three.
const RAM_COOLDOWN_MS := 600
## Where the hit count floats up from, above the car.
const RAM_TEXT_LIFT := 150.0

## The loose piece of fence lying about, shared by every fence run so only
## one is ever out at a time.
static var _fence_orb: ItemPickup = null

var _blade_angle := 0.0
var _last_ram_ms := -100000

func _ready() -> void:
	add_to_group(OffscreenCuller.GROUP)
	set_process(kind == Kind.WINDMILL)
	if not Engine.is_editor_hint():
		_build_collision()

func _process(delta: float) -> void:
	if kind == Kind.WINDMILL:
		_blade_angle = wrapf(_blade_angle + WINDMILL_SPIN * delta, 0.0, TAU)
		queue_redraw()

## The player's car hit this hard (see PlayerCar). Only a fence cares, and
## only while "Fenced In" wants a piece of it.
func car_rammed(car: Node2D, _impact_speed: float) -> void:
	if kind != Kind.FENCE or not _wants_fence():
		return
	var now := Time.get_ticks_msec()
	if now - _last_ram_ms < RAM_COOLDOWN_MS:
		return
	_last_ram_ms = now
	var id := FENCE_QUEST.id
	var goal := FENCE_QUEST.count_goal
	var hits := Quests.add_count(id)
	Sfx.play_at(&"wood_clonk", car.global_position, -2.0, 0.1)
	_shudder()
	var text_at := car.global_position + Vector2(0.0, -RAM_TEXT_LIFT)
	if hits < goal:
		Pickup.spawn_callout(get_parent(), text_at, "%d / %d" % [hits, goal])
		return
	_knock_piece_loose(car)
	Pickup.spawn_callout(get_parent(), text_at, "A piece came loose!")

static func _wants_fence() -> bool:
	var id := FENCE_QUEST.id
	return Quests.has_quest(id) and not Quests.is_ready(id) \
			and not Inventory.has_item(FENCE_PIECE.id) and not is_instance_valid(_fence_orb)

## A splintering crack, and a chunk of fence lands on the car's side of the
## run, where it waits however long the player takes.
func _knock_piece_loose(car: Node2D) -> void:
	var on_fence := _closest_point(car.global_position)
	var away := (car.global_position - on_fence)
	away = away.normalized() if away.length() > 1.0 else Vector2.DOWN
	var orb := ItemPickup.new()
	orb.configure(FENCE_PIECE)
	orb.persistent = true
	get_parent().add_child(orb)
	orb.launch(on_fence + Vector2(0.0, -40.0), car.global_position + away * 110.0, 60.0, 0.5)
	_fence_orb = orb
	Sfx.play_at(&"fence_crack", on_fence, -2.0, 0.05)

## The nearest point of this fence run to `world_point`, in world space.
func _closest_point(world_point: Vector2) -> Vector2:
	var local := to_local(world_point)
	var along := Vector2(0.0, clampf(local.y, 0.0, length)) if vertical \
			else Vector2(clampf(local.x, 0.0, length), 0.0)
	return to_global(along)

## The whole run rattles for a moment from the hit.
func _shudder() -> void:
	var home := position
	var tween := create_tween()
	for offset: Vector2 in [Vector2(3.0, -2.0), Vector2(-3.0, 1.0), Vector2(2.0, 0.0)]:
		tween.tween_property(self, "position", home + offset, 0.04)
	tween.tween_property(self, "position", home, 0.05)

func _build_collision() -> void:
	var footprint := Rect2()
	match kind:
		Kind.FENCE:
			footprint = Rect2(-4.0, -8.0, 8.0, length + 8.0) if vertical else Rect2(0.0, -8.0, length, 10.0)
		Kind.HAY_BALE:
			footprint = Rect2(-22.0, -12.0, 44.0, 12.0)
		Kind.WINDMILL:
			footprint = Rect2(-26.0, -14.0, 52.0, 14.0)
		Kind.TROUGH:
			footprint = Rect2(-32.0, -12.0, 64.0, 12.0)
		Kind.SCARECROW:
			footprint = Rect2(-8.0, -8.0, 16.0, 8.0)
		Kind.SIGN:
			footprint = Rect2(-56.0, -12.0, 112.0, 12.0)
		_:
			return
	var shape := RectangleShape2D.new()
	shape.size = footprint.size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = footprint.get_center()
	add_child(collision)

func _draw() -> void:
	match kind:
		Kind.FENCE:
			if vertical:
				_draw_depth_fence()
			else:
				_draw_fence()
		Kind.HAY_BALE:
			_draw_hay_bale()
		Kind.WINDMILL:
			_draw_windmill()
		Kind.TROUGH:
			_draw_trough()
		Kind.SIGN:
			_draw_sign()
		Kind.YARD:
			_draw_yard()
		Kind.SCARECROW:
			_draw_scarecrow()

## Deterministic wobble so posts aren't all the same height.
func _jitter(index: int, amount: float) -> float:
	return (float(hash(index * 7919 + int(length)) % 1000) / 1000.0 - 0.5) * 2.0 * amount

func _draw_post(base: Vector2, index: int) -> void:
	var height := FENCE_HEIGHT + _jitter(index, 3.0)
	draw_rect(Rect2(base.x - 3.0, base.y - height, 6.0, height), WOOD)

func _draw_fence() -> void:
	draw_rect(Rect2(0.0, -2.0, length, 4.0), UiPalette.SHADOW)
	for rail_y: float in [-28.0, -16.0]:
		draw_colored_polygon(PackedVector2Array([
			Vector2(0.0, rail_y), Vector2(length, rail_y + _jitter(int(rail_y), 1.5)),
			Vector2(length, rail_y + 5.0 + _jitter(int(rail_y), 1.5)), Vector2(0.0, rail_y + 5.0),
		]), WOOD_LIGHT)
	var posts := maxi(1, roundi(length / FENCE_POST_SPACING))
	for i in posts + 1:
		_draw_post(Vector2(length * i / posts, 0.0), i)

func _draw_depth_fence() -> void:
	var posts := maxi(1, roundi(length / FENCE_DEPTH_POST_SPACING))
	for rail_y: float in [-28.0, -16.0]:
		draw_rect(Rect2(-2.0, rail_y, 4.0, length), WOOD_LIGHT)
	for i in posts + 1:
		_draw_post(Vector2(0.0, length * i / posts), i)

func _draw_hay_bale() -> void:
	draw_colored_polygon(FlatProps.octagon(Vector2(4.0, 0.0), 28.0, 5.0), UiPalette.SHADOW)
	draw_rect(Rect2(-22.0, -26.0, 44.0, 26.0), STRAW)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-22.0, -26.0), Vector2(-16.0, -32.0), Vector2(28.0, -32.0), Vector2(22.0, -26.0),
	]), STRAW_LIGHT)
	draw_colored_polygon(PackedVector2Array([
		Vector2(22.0, -26.0), Vector2(28.0, -32.0), Vector2(28.0, -6.0), Vector2(22.0, 0.0),
	]), STRAW_SHADE)

func _draw_trough() -> void:
	draw_colored_polygon(FlatProps.octagon(Vector2(3.0, 0.0), 36.0, 5.0), UiPalette.SHADOW)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-32.0, -20.0), Vector2(32.0, -20.0), Vector2(28.0, 0.0), Vector2(-28.0, 0.0),
	]), WOOD)
	draw_rect(Rect2(-30.0, -20.0, 60.0, 5.0), WATER)

func _draw_windmill() -> void:
	var top := Vector2(0.0, -WINDMILL_HEIGHT)
	draw_colored_polygon(FlatProps.octagon(Vector2(6.0, 0.0), 40.0, 7.0), UiPalette.SHADOW)
	for side: float in [-1.0, 1.0]:
		draw_colored_polygon(FlatProps.sliver(Vector2(24.0 * side, 0.0), top + Vector2(5.0 * side, 10.0), 6.0), UiPalette.STEEL_BASE)
	draw_rect(Rect2(-16.0, -64.0, 32.0, 6.0), UiPalette.STEEL_BASE)
	draw_colored_polygon(FlatProps.sliver(top, top + Vector2(40.0, -2.0), 4.0), UiPalette.METAL_GREY)
	draw_colored_polygon(PackedVector2Array([
		top + Vector2(34.0, -14.0), top + Vector2(52.0, -20.0), top + Vector2(52.0, 8.0), top + Vector2(34.0, 6.0),
	]), VANE_RED)
	for i in WINDMILL_BLADES:
		var direction := Vector2.from_angle(_blade_angle + TAU * i / WINDMILL_BLADES)
		var side := direction.orthogonal() * 7.0
		var tip := top + direction * WINDMILL_BLADE_LENGTH
		draw_colored_polygon(PackedVector2Array([top - side * 0.5, tip - side, tip + side, top + side * 0.5]), UiPalette.TRIM_OFF_WHITE)
	draw_colored_polygon(FlatProps.octagon(top, 7.0, 7.0), UiPalette.METAL_GREY)

func _draw_sign() -> void:
	var board := Rect2(-70.0, -92.0, 140.0, 56.0)
	for post_x: float in [board.position.x + 18.0, board.end.x - 24.0]:
		draw_rect(Rect2(post_x, board.end.y - 4.0, 6.0, -board.end.y + 4.0), WOOD_DARK)
	draw_set_transform(board.get_center(), deg_to_rad(-2.0), Vector2.ONE)
	var local := Rect2(-board.size / 2.0, board.size)
	draw_rect(Rect2(local.position + Vector2(4.0, 5.0), local.size), UiPalette.SHADOW)
	draw_rect(local, WOOD_LIGHT)
	draw_rect(Rect2(local.end.x - 8.0, local.position.y, 8.0, local.size.y), WOOD)
	var font := ThemeDB.fallback_font
	draw_string(font, local.position + Vector2(0.0, 23.0), sign_title,
			HORIZONTAL_ALIGNMENT_CENTER, local.size.x - 8.0, 22, UiPalette.TEXT_BROWN)
	draw_string(font, local.position + Vector2(0.0, 45.0), sign_subtitle,
			HORIZONTAL_ALIGNMENT_CENTER, local.size.x - 8.0, 13, VANE_RED)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Trampled dirt under the whole farm. Drawn only below and right of the
## origin, so placing the origin at the yard's top-left corner keeps it under
## everything that Y-sorts against it.
func _draw_yard() -> void:
	var w := yard_size.x
	var h := yard_size.y
	draw_colored_polygon(PackedVector2Array([
		Vector2(w * 0.08, 0.0), Vector2(w * 0.55, h * 0.03), Vector2(w * 0.94, 0.0), Vector2(w, h * 0.3),
		Vector2(w * 0.97, h * 0.82), Vector2(w * 0.7, h), Vector2(w * 0.2, h * 0.96), Vector2(0.0, h * 0.7),
		Vector2(w * 0.02, h * 0.2),
	]), DIRT)
	for patch in [Rect2(w * 0.15, h * 0.55, 60.0, 14.0), Rect2(w * 0.6, h * 0.25, 80.0, 12.0), Rect2(w * 0.42, h * 0.8, 50.0, 10.0)]:
		draw_colored_polygon(FlatProps.octagon(patch.get_center(), patch.size.x / 2.0, patch.size.y / 2.0), DIRT_DARK)

## A scarecrow on its post: a T of an old shirt, a hubcap for a face (its gag)
## and a floppy hat.
func _draw_scarecrow() -> void:
	draw_colored_polygon(FlatProps.octagon(Vector2(4.0, 0.0), 18.0, 5.0), UiPalette.SHADOW)
	draw_rect(Rect2(-4.0, -70.0, 8.0, 70.0), WOOD_DARK)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-40.0, -96.0), Vector2(40.0, -100.0), Vector2(40.0, -86.0), Vector2(16.0, -86.0),
		Vector2(18.0, -54.0), Vector2(-16.0, -52.0), Vector2(-14.0, -84.0), Vector2(-40.0, -82.0),
	]), SHIRT)
	draw_colored_polygon(FlatProps.octagon(Vector2(0.0, -112.0), 14.0, 14.0), UiPalette.STEEL_BASE)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-24.0, -122.0), Vector2(-10.0, -128.0), Vector2(-8.0, -144.0), Vector2(10.0, -142.0),
		Vector2(12.0, -128.0), Vector2(26.0, -120.0),
	]), STRAW_SHADE)
