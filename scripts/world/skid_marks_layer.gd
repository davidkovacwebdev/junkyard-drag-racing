class_name SkidMarksLayer
extends Node2D
## Flat ground-decal layer for tire skid marks. Sits between Roads and
## Sortables in the scene tree (see main.tscn) — drawn after the road
## surface but before every Y-sorted car/building, so a mark always
## reads as painted onto the ground rather than fighting Y-sort against
## whatever's currently driving over it. A decal has no height, so it
## should never draw "in front of" anything; tree order (not Y-sort)
## is what guarantees that here.
##
## No logic of its own — PlayerCar finds this by type (same resolution
## pattern as RoadNetwork) and adds mark nodes directly under it.
