class_name CarEngine
extends Node2D
## Visual-only decoration for a car's ENGINE part — not a physics body.
## Its `power` stat is read once by CarAssembler and turned into real
## wheel torque; after that this node just rides along as a child of the
## body, purely for looks.

@export var part_data: EnginePartData
