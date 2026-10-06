class_name OilDrumProp
extends StaticBody2D
## A single oil drum standing on the ground, solid: the stock FlatProps drum
## with a box to bump into. Origin at its foot, so it Y-sorts like any prop.
## The crane pen stands one behind the Scrap Dealer so the claw can't shove him
## off past the end of its rail.

@export var color: Color = UiPalette.RUST.darkened(0.1)
@export var radius: float = 26.0
@export var height: float = 64.0

func _ready() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(radius * 2.0, height)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0.0, -height * 0.5)
	add_child(collision)

func _draw() -> void:
	FlatProps.draw_drum(self, Vector2.ZERO, color, radius, height)
