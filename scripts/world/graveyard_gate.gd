@tool
class_name GraveyardGate
extends StaticBody2D
## The iron gate in the graveyard landmark's front fence. It stays chained
## shut until Grandpa sends the player to pay their respects ("Pay Your
## Respects"). From then on it stands open, and E drives in to the cemetery
## (scenes/cemetery/cemetery.tscn). Origin at the middle of the gap, on the
## ground.

const QUEST_ID := &"pay_respects"
const CEMETERY_SCENE := "res://scenes/cemetery/cemetery.tscn"
const POST_HEIGHT := 70.0
const LEAF_HEIGHT := 50.0
const BAR_SPACING := 20.0
const LOCKED_COLOR := Color(0.75, 0.75, 0.72)

@export var display_name: String = "Graveyard"
## Half the width of the gap in the fence.
@export var half_width: float = 60.0:
	set(value):
		half_width = value
		queue_redraw()

var _drawn_open: bool = false

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var shape := RectangleShape2D.new()
	shape.size = Vector2(half_width * 2.0, 12.0)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0.0, -4.0)
	add_child(collision)

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint() and is_open() != _drawn_open:
		queue_redraw()

func is_open() -> bool:
	if Engine.is_editor_hint():
		return false
	return Quests.has_quest(QUEST_ID) or Quests.is_complete(QUEST_ID)

func get_interact_prompt() -> String:
	if is_open():
		return ""
	return "%s: The gate's chained shut" % display_name

func get_interact_prompt_color() -> Color:
	return Color(1, 1, 1, 1) if is_open() else LOCKED_COLOR

## Called by PlayerCar on E: rattles the chain while locked, swings in
## otherwise.
func interact(_actor: Node = null) -> void:
	if not is_open():
		Sfx.play(&"gate_rattle", -4.0, 0.05)
		return
	Sfx.play(&"cemetery_gate_creak", -4.0, 0.05)
	SaveSystem.save_game()
	get_tree().change_scene_to_file(CEMETERY_SCENE)

func _draw() -> void:
	_drawn_open = is_open()
	var iron := GraveyardProp.IRON
	for x: float in [-half_width, half_width]:
		draw_rect(Rect2(x - 8.0, -POST_HEIGHT, 16.0, POST_HEIGHT), GraveyardProp.STONE)
		draw_rect(Rect2(x + 2.0, -POST_HEIGHT, 6.0, POST_HEIGHT), GraveyardProp.STONE_SHADE)
	if _drawn_open:
		# Swung inward: each leaf is a narrow slab foreshortened up-screen.
		for side: float in [-1.0, 1.0]:
			var hinge := Vector2(side * (half_width - 10.0), 0.0)
			draw_colored_polygon(PackedVector2Array([
				hinge, hinge + Vector2(0.0, -LEAF_HEIGHT), hinge + Vector2(-side * 12.0, -LEAF_HEIGHT - 40.0),
				hinge + Vector2(-side * 12.0, -40.0),
			]), iron)
		return
	# Shut: a rail across, a few spiked bars, and a chain looped round the
	# middle with a fat padlock.
	draw_rect(Rect2(-half_width + 8.0, -LEAF_HEIGHT + 10.0, half_width * 2.0 - 16.0, 6.0), iron)
	draw_rect(Rect2(-half_width + 8.0, -16.0, half_width * 2.0 - 16.0, 6.0), iron)
	var bars := int((half_width * 2.0 - 16.0) / BAR_SPACING)
	for i in bars + 1:
		var x := -half_width + 8.0 + i * (half_width * 2.0 - 16.0) / bars
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - 3.0, 0.0), Vector2(x - 3.0, -LEAF_HEIGHT + 6.0), Vector2(x, -LEAF_HEIGHT - 2.0),
			Vector2(x + 3.0, -LEAF_HEIGHT + 6.0), Vector2(x + 3.0, 0.0),
		]), iron)
	draw_colored_polygon(FlatProps.sliver(Vector2(-14.0, -38.0), Vector2(14.0, -22.0), 5.0), UiPalette.STEEL_SHADE)
	draw_colored_polygon(FlatProps.sliver(Vector2(-14.0, -22.0), Vector2(14.0, -38.0), 5.0), UiPalette.STEEL_SHADE)
	draw_rect(Rect2(-8.0, -26.0, 16.0, 14.0), UiPalette.STEEL_DARK)
