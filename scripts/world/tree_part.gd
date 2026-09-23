@tool
class_name TreePart
extends Node2D
## Visual-only tree part (trunk, canopy, decoration). A part is just its
## Polygon2D children plus a data resource, authored in tree space (origin
## at the ground, +y down), so stacking slots needs no runtime anchor math
## — same idea as BuildingPart.
##
## @tool so the Tree Creator dock can instantiate these to read their
## part_data while the editor is running (see tree_data.gd).

@export var part_data: TreePartData

## Only meaningful on a TRUNK part: how much solid collision the tree has at
## its base, in tree space, (width, height-above-ground). ComposedTree reads
## this off the chosen trunk to size its collision shape, so a thin sapling
## and a fat oak each own their own footprint instead of every tree needing
## a separately-tuned size. Ignored on every other slot.
@export var footprint_size: Vector2 = Vector2.ZERO
