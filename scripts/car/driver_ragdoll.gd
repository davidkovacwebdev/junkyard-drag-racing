class_name DriverRagdoll
extends Node2D
## A driver thrown out of a broken car (DriverSeat.eject()): three floppy
## pieces, head, torso and legs, pinned together at the neck and hips,
## tumbling on with the car's speed. They take no damage; every hard knock
## sprays blood and lands with a wet thud.

const HEAD_PARTS: Array[StringName] = [&"HeadPart", &"HairPart", &"EyesPart", &"AccessoryPart"]
const TORSO_PARTS: Array[StringName] = [&"TorsoPart"]
## In character space (feet at the origin): each piece's middle, and the neck.
const HEAD_CENTER := Vector2(0.0, -205.0)
const TORSO_CENTER := Vector2(0.0, -133.0)
const NECK := Vector2(0.0, -170.0)
const HEAD_SIZE := Vector2(52.0, 60.0)
const TORSO_SIZE := Vector2(60.0, 74.0)
const PIECE_MASS := 1.0
## Out it pops: up, and a little spin.
const POP := Vector2(0.0, -320.0)
const SPIN := 6.0
const BLEED_VELOCITY := 160.0
const BLEED_COOLDOWN := 0.18

var _pieces: Array[RigidBody2D] = []
var _prev_velocity: Dictionary = {}
var _cooldown := 0.0
var _spray_parent: Node

static func from_seat(seat: DriverSeat, parent: Node, velocity: Vector2, layer: int, mask: int) -> DriverRagdoll:
	var ragdoll := DriverRagdoll.new()
	ragdoll.name = "DriverRagdoll"
	parent.add_child(ragdoll)
	ragdoll._spray_parent = parent
	var upper := seat.upper
	var scale_factor := seat.character_scale * absf(seat.global_scale.x)
	var turn := seat.global_rotation
	var head := ragdoll._piece(upper.to_global(HEAD_CENTER), turn, HEAD_SIZE * scale_factor, layer, mask)
	var torso := ragdoll._piece(upper.to_global(TORSO_CENTER), turn, TORSO_SIZE * scale_factor, layer, mask)
	var hip := seat.global_position
	var neck := upper.to_global(NECK)
	var legs := ragdoll._piece((hip + seat.to_global(seat.foot)) * 0.5, turn,
			Vector2(seat.knee.length() + 12.0, seat.thigh_width + 8.0), layer, mask)
	for child in upper.get_children():
		if child.name in HEAD_PARTS:
			child.reparent(head, true)
		elif child.name in TORSO_PARTS:
			child.reparent(torso, true)
	seat.legs.reparent(legs, true)
	upper.queue_free()
	ragdoll._pin(head, torso, neck)
	ragdoll._pin(torso, legs, hip)
	for piece in ragdoll._pieces:
		piece.linear_velocity = velocity + POP + Vector2(randf_range(-80.0, 80.0), randf_range(-60.0, 0.0))
		piece.angular_velocity = randf_range(-SPIN, SPIN)
		ragdoll._prev_velocity[piece] = piece.linear_velocity
	return ragdoll

func _piece(at: Vector2, turn: float, size: Vector2, layer: int, mask: int) -> RigidBody2D:
	var piece := RigidBody2D.new()
	piece.mass = PIECE_MASS
	piece.collision_layer = layer
	piece.collision_mask = mask
	var shape := RectangleShape2D.new()
	shape.size = size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	piece.add_child(collision)
	add_child(piece)
	piece.global_position = at
	piece.global_rotation = turn
	_pieces.append(piece)
	return piece

func _pin(a: RigidBody2D, b: RigidBody2D, at: Vector2) -> void:
	var joint := PinJoint2D.new()
	add_child(joint)
	joint.global_position = at
	joint.node_a = joint.get_path_to(a)
	joint.node_b = joint.get_path_to(b)

func _physics_process(delta: float) -> void:
	_cooldown -= delta
	for piece in _pieces:
		if not is_instance_valid(piece):
			continue
		var velocity := piece.linear_velocity
		var delta_v := (velocity - (_prev_velocity.get(piece, velocity) as Vector2)).length()
		_prev_velocity[piece] = velocity
		if delta_v >= BLEED_VELOCITY and _cooldown <= 0.0:
			_cooldown = BLEED_COOLDOWN
			BloodSpray.spray(_spray_parent, piece.global_position, delta_v)
			RaceCarAudio.play(_spray_parent, &"flesh_splat", piece.global_position,
					linear_to_db(clampf(delta_v / 700.0, 0.3, 1.0)))
