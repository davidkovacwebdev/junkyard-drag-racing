@tool
class_name BuildingPart
extends Node2D
## Visual-only building part (wall, roof, door, window, decoration).
## A part is just its Polygon2D children plus a data resource, authored in
## building space (origin at the ground, +y down), so stacking slots
## needs no runtime anchor math — same idea as CharacterPart.
##
## @tool so the Building Creator dock can instantiate these to read
## their part_data while the editor is running (see building_data.gd).

@export var part_data: BuildingPartData

## Only meaningful on a WALL part: the building's footprint in building
## space, (width, height-above-ground). ComposedBuilding reads this off
## the chosen wall to size its collision shape, so a "cabin" wall and a
## "warehouse" wall can each own their own footprint instead of every
## building needing a separately-tuned size. Ignored on every other slot.
@export var footprint_size: Vector2 = Vector2.ZERO
