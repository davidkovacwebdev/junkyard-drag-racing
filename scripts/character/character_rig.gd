class_name CharacterRig
extends Node2D
## Thin wrapper: assembles a character from a saved CharacterData as soon
## as it enters the tree, so a scene can just place a CharacterRig node
## and assign a .tres character instead of assembling one by hand. This is
## the same CharacterAssembler path the Character Creator preview and any
## later crowd/pit-crew spawning will use.

@export var character_data: CharacterData

var assembled: Node2D

func _ready() -> void:
	assembled = CharacterAssembler.assemble(character_data, self, Vector2.ZERO)
