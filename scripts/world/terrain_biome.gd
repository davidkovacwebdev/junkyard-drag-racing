class_name TerrainBiome
extends RefCounted
## The palette the terrain paints its land with.
##
## A biome is **only ever a colour** — no props, no gameplay effect, nothing but
## the fill. So adding one here and dropping a `BiomeMarker` on the map is the
## whole feature.
##
## A biome is one colour to pick, not three: the shaded rim along the coast and
## the second inland tone are both derived from `base` (see `rim_color` /
## `inland_color`), which is what keeps every biome's land reading in the same
## flat, stepped, cell-shaded way whatever its hue.

enum Kind {
	PLAINS,   ## Ordinary green.
	SCRUB,    ## Dry yellow-green.
	DESERT,   ## Sand.
	FOREST,   ## Deep green.
	SWAMP,    ## Murky green.
	MOUNTAIN, ## Bare grey rock.
	SNOW,     ## Pale, cold.
}

const _NAMES := {
	Kind.PLAINS: "Plains",
	Kind.SCRUB: "Scrub",
	Kind.DESERT: "Desert",
	Kind.FOREST: "Forest",
	Kind.SWAMP: "Swamp",
	Kind.MOUNTAIN: "Mountain",
	Kind.SNOW: "Snow",
}

## Main land tone per biome. These are the only colours to tune; the rest of the
## three-tone step is derived from them.
const _BASE := {
	Kind.PLAINS: Color("8ea75e"),
	Kind.SCRUB: Color("b3a865"),
	Kind.DESERT: Color("e0cd92"),
	Kind.FOREST: Color("5f8a4e"),
	Kind.SWAMP: Color("6d8a58"),
	Kind.MOUNTAIN: Color("9aa0a2"),
	Kind.SNOW: Color("e2ebee"),
}

## Display label for a biome, e.g. for an editor dot or a HUD readout.
static func display_name(kind: int) -> String:
	return _NAMES.get(kind, "Biome")

## The biome's true colour — what fills the bulk of its land, inland of the
## coast.
static func base_color(kind: int) -> Color:
	return _BASE.get(kind, Color("8ea75e"))

## The same colour pushed toward black by `amount`, for the coastline and the
## band just inside it. Deriving both from `base` is what keeps every biome's
## land reading in the same stepped way whatever its hue — and it means a biome
## is one colour to pick, not three.
static func edge_color(kind: int, amount: float) -> Color:
	return base_color(kind).darkened(amount)
