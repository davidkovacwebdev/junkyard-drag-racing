class_name PartData
extends Resource
## Base data shared by every junk part (body/wheel/engine).
## Concrete parts extend this with category-specific fields.

enum Category { BODY, WHEEL, ENGINE }

## Cosmetic label only right now; not read by any gameplay system yet.
## Named MaterialType, not Material, because Material is a native Godot class.
enum MaterialType { METAL, WOOD, PLASTIC, CERAMIC, RUBBER, GLASS, FABRIC }

@export var id: StringName = &""
@export var display_name: String = ""
@export var category: Category = Category.BODY
@export var mass: float = 10.0
@export var durability: float = 100.0
## How much this part contributes to top speed — an engine's is just its
## power; a body/wheel's is a stand-in for drag/rolling efficiency until
## those actually factor into open-world driving.
@export var speed: float = 3.0
@export var material_type: MaterialType = MaterialType.METAL
## Scene this part's actual visual/physics rig lives in — set by whatever
## loads the part (PartDatabase), not authored on the resource itself.
@export var scene_path: String = ""
