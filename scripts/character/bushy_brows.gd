class_name BushyBrows
## A gag for any assembled character (a CharacterRig, a CutsceneActor, a
## dialog portrait): two big, bushy black eyebrows pop out over their eyes
## for a moment, then pop off again. The shopkeeper gets them when the player
## tells him "screw you and your eyebrows" during "Juice" (Shop).

const COLOR := Color(0.07, 0.06, 0.06, 1)
## Where the brows sit, in character space (just over the eyes at y ~ -215).
const CENTER := Vector2(0.0, -227.0)
## The left brow around CENTER: chunky, a bumpy top, slanting down inward.
const LEFT := [Vector2(-25.0, 2.0), Vector2(-21.0, -6.0), Vector2(-14.0, -9.0),
		Vector2(-8.0, -6.0), Vector2(-2.0, -3.0), Vector2(-1.0, 4.0), Vector2(-13.0, 1.0)]
const POP_TIME := 0.35

## Sprouts the brows on `who` for `seconds`, with a `brow_sprout`.
static func sprout(who: Node, seconds: float = 2.0) -> void:
	if who == null:
		return
	var eyes := who.find_child("EyesPart", true, false) as Node2D
	if eyes == null:
		return
	var brows := Node2D.new()
	brows.position = CENTER
	brows.scale = Vector2(0.2, 0.2)
	var right: Array[Vector2] = []
	for point: Vector2 in LEFT:
		right.append(Vector2(-point.x, point.y))
	for shape: Array in [LEFT, right]:
		var brow := Polygon2D.new()
		brow.polygon = PackedVector2Array(shape)
		brow.color = COLOR
		brows.add_child(brow)
	eyes.add_child(brows)
	Sfx.play(&"brow_sprout", -6.0, 0.0)
	var tween := brows.create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(brows, "scale", Vector2.ONE, POP_TIME * 2.0)
	tween.tween_interval(seconds)
	tween.tween_property(brows, "scale", Vector2.ZERO, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(brows.queue_free)
