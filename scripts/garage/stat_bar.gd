class_name StatBar
extends HBoxContainer
## Simple 5-cell rating bar — cells up to the rating are filled yellow,
## the rest stay dim. Used to show a part's Durability/Speed/Mass at a
## glance in the garage's parts list.

const FILLED_COLOR := Color(1, 0.85, 0.15, 1)
const EMPTY_COLOR := Color(0.35, 0.33, 0.25, 1)

func set_rating(rating: int) -> void:
	var clamped := clampi(rating, 0, get_child_count())
	for i in get_child_count():
		var cell: ColorRect = get_child(i)
		cell.color = FILLED_COLOR if i < clamped else EMPTY_COLOR
