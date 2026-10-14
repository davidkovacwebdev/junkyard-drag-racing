class_name MiniHeli
extends Node2D
## Grandpa's homemade one-man helicopter ("Test Pilot"), built out of the
## crashed helicopter's engine and tail rotor ("Up, Up and Away") and a tin
## bathtub for a cockpit. Side view, nose to the right, origin on the ground
## under the skid; flip it with scale.x.
##
## Back to front: tail boom and tail rotor, the engine block on the back of
## the tub, the mast and the main rotor, then whoever's flying it (a
## CutsceneActor, `seat_pilot()`), then the tub over their legs and the skid.
## `spin` turns the rotors (0 parked, 1 flying flat out); `smoking` puffs
## black smoke out of the engine as it gives up.

const TUB := Color(0.78, 0.46, 0.2)
const TUB_SHADE := Color(0.62, 0.36, 0.16)
const ENGINE := Color(0.52, 0.53, 0.55)
const ENGINE_SHADE := Color(0.42, 0.43, 0.45)
const PIPE := Color(0.3, 0.29, 0.28)
const BLADE := UiPalette.METAL_GREY
const SMOKE := Color(0.22, 0.21, 0.2, 0.75)

const MAST_TOP := Vector2(-6.0, -210.0)
const ROTOR_LENGTH := 175.0
const ROTOR_THICKNESS := 9.0
const TAIL_HUB := Vector2(-200.0, -118.0)
const TAIL_BLADE := 30.0
const ENGINE_EXHAUST := Vector2(-80.0, -150.0)
## Where the pilot's feet go, down inside the tub.
const SEAT := Vector2(14.0, -36.0)
const PILOT_SCALE := 0.55
## Rotor turns per second at full spin.
const ROTOR_SPEED := 5.0
const TAIL_SPEED := 9.0
## Smoke: a big puff this often, drifting up this fast, gone after this long.
const SMOKE_EVERY := 0.18
const SMOKE_RISE := 90.0
const SMOKE_LIFE := 1.4

## 0 parked, 1 flat out.
var spin: float = 0.0
var smoking: bool = false
## Where smoke puffs go (they drift free of the helicopter); its parent by
## default.
var smoke_parent: Node = null

var pilot: CutsceneActor = null
var _rotor: Polygon2D
var _tail: Node2D
var _pilot_slot: Node2D
var _phase := 0.0
var _smoke_timer := 0.0

func _ready() -> void:
	_poly(FlatProps.sliver(Vector2(-60.0, -96.0), TAIL_HUB, 14.0), PIPE)
	_tail = Node2D.new()
	_tail.position = TAIL_HUB
	add_child(_tail)
	for bar in [FlatProps.sliver(Vector2(-TAIL_BLADE, 0.0), Vector2(TAIL_BLADE, 0.0), 9.0),
			FlatProps.sliver(Vector2(0.0, -TAIL_BLADE), Vector2(0.0, TAIL_BLADE), 9.0)]:
		var blade := Polygon2D.new()
		blade.polygon = bar
		blade.color = ENGINE if _tail.get_child_count() == 0 else ENGINE_SHADE
		_tail.add_child(blade)
	_poly(PackedVector2Array([Vector2(-96.0, -150.0), Vector2(-30.0, -154.0), Vector2(-26.0, -70.0),
			Vector2(-96.0, -66.0)]), ENGINE)
	_poly(PackedVector2Array([Vector2(-74.0, -152.0), Vector2(-62.0, -152.0), Vector2(-62.0, -67.0),
			Vector2(-74.0, -67.0)]), TUB)
	_poly(FlatProps.sliver(Vector2(-6.0, -84.0), MAST_TOP, 10.0), PIPE)
	_rotor = _poly(PackedVector2Array(), BLADE)
	_pilot_slot = Node2D.new()
	_pilot_slot.position = SEAT
	add_child(_pilot_slot)
	_poly(PackedVector2Array([Vector2(-50.0, -92.0), Vector2(78.0, -92.0), Vector2(100.0, -60.0),
			Vector2(84.0, -18.0), Vector2(-40.0, -18.0)]), TUB)
	_poly(PackedVector2Array([Vector2(-44.0, -36.0), Vector2(91.0, -36.0), Vector2(84.0, -18.0),
			Vector2(-40.0, -18.0)]), TUB_SHADE)
	_poly(PackedVector2Array([Vector2(-70.0, -8.0), Vector2(110.0, -10.0), Vector2(118.0, -20.0),
			Vector2(124.0, -18.0), Vector2(116.0, 0.0), Vector2(-70.0, 0.0)]), PIPE)
	_update_rotors(0.0)

func _process(delta: float) -> void:
	_update_rotors(delta)
	if smoking:
		_smoke_timer -= delta
		if _smoke_timer <= 0.0:
			_smoke_timer = SMOKE_EVERY
			_puff()

## Sits `character` in the tub, or takes whoever's in it out with null.
func seat_pilot(character: CharacterData) -> CutsceneActor:
	if is_instance_valid(pilot):
		pilot.queue_free()
		pilot = null
	if character == null:
		return null
	pilot = CutsceneActor.new()
	pilot.setup(character, PILOT_SCALE)
	_pilot_slot.add_child(pilot)
	return pilot

## The main blade seen side-on: as it turns its length swings through
## nothing and back. Parked, it hangs at full length.
func _update_rotors(delta: float) -> void:
	_phase += delta * ROTOR_SPEED * TAU * spin
	_tail.rotation += delta * TAIL_SPEED * TAU * spin
	var reach := ROTOR_LENGTH * (1.0 if spin <= 0.0 else maxf(absf(cos(_phase)), 0.12))
	var tip := MAST_TOP + Vector2(0.0, -ROTOR_THICKNESS * 0.5)
	_rotor.polygon = PackedVector2Array([
		tip + Vector2(-reach, 2.0), tip + Vector2(reach, -2.0),
		tip + Vector2(reach, ROTOR_THICKNESS - 2.0), tip + Vector2(-reach, ROTOR_THICKNESS + 2.0),
	])

## One big black puff out of the exhaust, rising and growing as it fades.
func _puff() -> void:
	var parent := smoke_parent if is_instance_valid(smoke_parent) else get_parent()
	if parent == null:
		return
	var puff := Polygon2D.new()
	puff.polygon = FlatProps.octagon(Vector2.ZERO, 26.0, 22.0)
	puff.color = SMOKE
	puff.z_index = z_index + 1
	parent.add_child(puff)
	puff.global_position = to_global(ENGINE_EXHAUST)
	puff.scale = global_scale.abs() * 0.6
	var rise := Vector2(randf_range(-20.0, 20.0), -SMOKE_RISE * SMOKE_LIFE) * global_scale.abs()
	var tween := puff.create_tween().set_parallel()
	tween.tween_property(puff, "global_position", puff.global_position + rise, SMOKE_LIFE)
	tween.tween_property(puff, "scale", puff.scale * 2.2, SMOKE_LIFE)
	tween.tween_property(puff, "modulate:a", 0.0, SMOKE_LIFE)
	tween.chain().tween_callback(puff.queue_free)

func _poly(points: PackedVector2Array, color: Color) -> Polygon2D:
	var polygon := Polygon2D.new()
	polygon.polygon = points
	polygon.color = color
	add_child(polygon)
	return polygon
