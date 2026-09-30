@tool
class_name ItemData
extends Resource
## A tool or gadget the player can own (the shop's stock). Not a car part:
## items live in `Inventory.owned_items` and are just "have it or not".
##
## Each lives in its own .tres under res://items, so name, price and blurb
## are edited in the inspector. @tool so the editor treats it as a real
## resource rather than a placeholder (see CharacterData).

## What saves and code refer to it by. Never change it once an item shipped.
@export var id: StringName = &""
@export var display_name: String = ""
@export var price: int = 0
## What the shopkeeper says about it when the player asks.
@export_multiline var description: String = ""
## A few flat polygons, authored around (0, 0) in a roughly 64 px box.
@export var icon_scene: PackedScene
