class_name BloodSpray
extends Node2D
## A burst of blood off a driver taking a knock in a race (DriverSeat,
## DriverRagdoll): a few chunky drops flung out and arcing down, then fading.
## One node draws the whole burst and frees itself when it's done.
##
## Junk Toy: each drop is one lumpy hexagon, never thinner than 4 px, and a
## burst is a handful of them, not a mist.

const BLOOD := BloodTrail.BLOOD
const GRAVITY := 900.0
const LIFETIME := 1.1
const FADE_TIME := 0.4
const DROPS_MIN := 3
const DROPS_MAX := 7
const SPEED := Vector2(120.0, 320.0)

## Each: {at: Vector2, velocity: Vector2, radius: float}, in this node's space.
var _drops: Array[Dictionary] = []
var _age := 0.0

## Blood off whatever was hit at `at` (world space); a harder knock (`delta_v`)
## throws more of it, faster.
static func spray(parent: Node, at: Vector2, delta_v: float) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var burst := BloodSpray.new()
	burst.z_index = 5
	parent.add_child(burst)
	burst.global_position = at
	var hardness := clampf(delta_v / 800.0, 0.0, 1.0)
	var count := int(lerpf(DROPS_MIN, DROPS_MAX, hardness))
	for i in count:
		var direction := Vector2.from_angle(randf_range(-PI * 0.95, -PI * 0.05))
		burst._drops.append({
			at = Vector2.ZERO,
			velocity = direction * randf_range(SPEED.x, SPEED.y) * (0.6 + hardness * 0.6),
			radius = randf_range(3.0, 6.0),
		})

func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	for drop in _drops:
		drop.velocity += Vector2(0.0, GRAVITY * delta)
		drop.at += drop.velocity * delta
	queue_redraw()

func _draw() -> void:
	var alpha := clampf((LIFETIME - _age) / FADE_TIME, 0.0, 1.0)
	var color := Color(BLOOD, alpha)
	for drop in _drops:
		draw_colored_polygon(FlatProps.octagon(drop.at, drop.radius, drop.radius * 0.85), color)
