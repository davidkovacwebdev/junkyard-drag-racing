class_name ChestPickup
extends StaticBody2D
## The treasure chest sitting in its hole ("Finders Keepers"): drive up and
## press E to heave it into the trunk, which finishes the quest (its item
## goal). With the trunk full it stays put. The chest itself is drawn by the
## DigHole; this is what the car finds and talks to. Placed by
## TreasureStory.

const CHEST := preload("res://items/treasure_chest.tres")
const BODY_SIZE := Vector2(46.0, 16.0)

@export var display_name: String = "Treasure Chest"

var hole: DigHole

func _ready() -> void:
	var shape := RectangleShape2D.new()
	shape.size = BODY_SIZE
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)

func get_interact_prompt() -> String:
	return "%s: Press E to pick it up" % display_name

## Called by PlayerCar on E or a click.
func interact(_actor: Node = null) -> void:
	if Cutscenes.is_active():
		return
	if Inventory.is_trunk_full():
		Sfx.play(&"denied", -6.0, 0.0)
		Pickup.spawn_float_text(get_parent(), global_position + Vector2(0.0, -50.0), "Trunk's full!")
		return
	Inventory.give_item(CHEST)
	Sfx.play(&"cardboard_crumple", -6.0, 0.05)
	Sfx.play(&"part_pickup", -4.0, 0.0)
	if is_instance_valid(hole):
		hole.has_chest = false
		hole.queue_redraw()
	SaveSystem.save_game()
	queue_free()
