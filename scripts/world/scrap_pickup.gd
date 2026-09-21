class_name ScrapPickup
extends Pickup
## A fistful of loose scrap, drawn as a little pile of junk inside the orb.
## The common drop: most orbs a bin coughs up are one of these.

## Scrap it's worth. Rolled by whatever dropped it.
@export var amount: int = 1
## Flavour word shown after the number ("+2 scrap (bent hubcap)"). Optional —
## empty just prints the count.
var noun: String = ""

## Muted on purpose: the orb is already the loud part, and a shiny nut on top of
## it fights the rarity tint that the part orbs use to say what they are.
const METAL_COLOR := Color(0.6, 0.62, 0.58, 1.0)

func grant() -> void:
	Inventory.add_scrap(amount)

func label_text() -> String:
	if noun.is_empty():
		return "+%d scrap" % amount
	return "+%d scrap (%s)" % [amount, noun]

func _draw_icon(center: Vector2, radius: float) -> void:
	# One solid bolt head, sized to nearly fill the ball so the two shapes read as
	# a nut sitting in a circle rather than as one circle inside another.
	# Deliberately no centre hole: a hole is concentric with the orb, and three
	# concentric circles in a row read as an eyeball. The hexagon's own silhouette
	# is what makes it a bolt, and at this size it stays legible from a car doing
	# 200.
	var r := radius * 0.76
	var nut := PackedVector2Array()
	for i in 6:
		var angle := TAU * float(i) / 6.0 + 0.35
		nut.append(center + Vector2(cos(angle), sin(angle)) * r)
	draw_colored_polygon(nut, METAL_COLOR)
