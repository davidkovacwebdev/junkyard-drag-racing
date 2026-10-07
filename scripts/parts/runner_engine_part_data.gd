class_name RunnerEnginePartData
extends EnginePartData
## An engine that's a person pulling the car on a rope (PunkerEngine), carrying
## who that person is. Saves embed whole part resources, so a crane worker
## generated at runtime keeps their look in the garage across sessions.

## Who runs in front of the car. Null: whoever the part scene's Character has.
@export var runner: CharacterData
## For a generated copy: the catalog part it's a version of, so it shares that
## part's engine sound. Empty for the catalog part itself.
@export var base_part_id: StringName = &""

func catalog_id() -> StringName:
	return base_part_id if forge == null and base_part_id != &"" else super()
