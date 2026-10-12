class_name SixSevenHands
extends Node2D
## The "six seven" hands: both forearms out in front, palms up, bobbing up
## and down out of step like a pair of scales. Put on a CharacterRig with
## `SixSevenHands.play(rig)`; it hides the torso's own arms and hands
## (ArmLeft/ArmRight/HandLeft/HandRight) while it runs, then puts them back.
## Drawn in character space. Used by BeggarNpc's rarest thank-you.
##
## Junk-toy style: per side an upper arm, a forearm and a palm.

const SHOULDERS := [Vector2(-37.0, -168.0), Vector2(37.0, -168.0)]
const DROP := 40.0
const REACH := 12.0
const THICK := 17.0
const BOB := 16.0
const BOB_HZ := 2.6
const OWN_PARTS := [&"ArmLeft", &"ArmRight", &"HandLeft", &"HandRight"]

var sleeve := Color(0.36, 0.31, 0.25, 1)
var skin := Color(0.85, 0.68, 0.55, 1)
var _time := 0.0
var _hidden: Array[CanvasItem] = []

static func play(rig: Node2D, seconds: float = 2.2) -> void:
	if not is_instance_valid(rig):
		return
	var hands := SixSevenHands.new()
	for part_name: StringName in OWN_PARTS:
		var part := rig.find_child(part_name, true, false) as Polygon2D
		if part == null:
			continue
		if part_name.begins_with("Arm"):
			hands.sleeve = part.color
		else:
			hands.skin = part.color
		part.visible = false
		hands._hidden.append(part)
	hands.z_index = 2
	rig.add_child(hands)
	await rig.get_tree().create_timer(seconds).timeout
	if is_instance_valid(hands):
		hands._restore()
		hands.queue_free()

func _restore() -> void:
	for part in _hidden:
		if is_instance_valid(part):
			part.visible = true

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	for i in 2:
		var shoulder: Vector2 = SHOULDERS[i]
		var out := signf(shoulder.x)
		var bob := sin(_time * TAU * BOB_HZ + PI * i) * BOB
		var elbow := shoulder + Vector2(out * 4.0, DROP)
		var hand := elbow + Vector2(out * REACH, -6.0 + bob)
		draw_colored_polygon(FlatProps.sliver(shoulder, elbow, THICK), sleeve)
		draw_colored_polygon(FlatProps.sliver(elbow, hand, THICK), sleeve)
		draw_colored_polygon(FlatProps.octagon(hand + Vector2(out * 2.0, -8.0), 12.0, 7.0), skin)
