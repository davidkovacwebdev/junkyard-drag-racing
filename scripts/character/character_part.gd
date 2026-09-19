@tool
class_name CharacterPart
extends Node2D
## Visual-only character part (torso, legs, boots, head, hair, eyes,
## accessory). Unlike cars there is no physics here — characters are pure
## polygons, so a part is just its Polygon2D children plus a data
## resource. Its placement lives in the scene, authored in character
## space (origin at the feet, +y down), so stacking slots needs no
## runtime anchor math (same idea as the engine scene's authored offset,
## just taken to the whole body).
##
## @tool so the Character Creator dock can instantiate these to read
## their part_data while the editor is running (see character_data.gd).

@export var part_data: CharacterPartData
