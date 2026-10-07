class_name PartFactory
extends RefCounted
## The one way to turn a PartData into a live node. Everything that shows or
## drives a part (garage icons, the world car, race rigs, pickups) goes through
## here, so a forged part (PartData.forge) looks and behaves the same everywhere
## without any caller knowing forging exists.

## A fresh instance of `part`'s scene, or null when it has none. For a forged
## part the instance also carries that part's own PartData (its stats, not the
## base scene's) and its mashed art.
static func instantiate(part: PartData) -> Node2D:
	if part == null or part.scene_path.is_empty():
		return null
	var scene := load(part.scene_path) as PackedScene
	if scene == null:
		push_warning("PartFactory: part scene '%s' won't load." % part.scene_path)
		return null
	var instance := scene.instantiate()
	if not (instance is Node2D):
		instance.free()
		return null
	# A forged part and a runner engine both carry their own look on the data.
	if (part.forge != null or part is RunnerEnginePartData) and "part_data" in instance:
		instance.set("part_data", part)
	if part.forge != null:
		part.forge.apply_to(instance)
	return instance as Node2D
