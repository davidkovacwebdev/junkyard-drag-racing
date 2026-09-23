class_name PartHome
extends RefCounted
## Where one owned copy of a part came from, as reported by
## `Inventory.detach_part()`. Enough for a caller to put a DIFFERENT part back
## in the exact same place — which is what turns an equip into a swap (see
## `Inventory.fit_part`) instead of a clone plus a quietly deleted old part.

## `slot` values. The negative ones are the car's singleton slots, named rather
## than numbered so they can never collide with a wheel mount index.
const SLOT_SPARE := -1
const SLOT_BODY := -2
const SLOT_ENGINE := -3

## The part that was taken out of this home.
var part: PartData
## The car it was fitted to, or null when it was loose in the spare stash.
var car: CarModelData = null
## Which slot of `car` it occupied: SLOT_BODY, SLOT_ENGINE, or a wheel mount
## index. SLOT_SPARE whenever `car` is null.
var slot: int = SLOT_SPARE
