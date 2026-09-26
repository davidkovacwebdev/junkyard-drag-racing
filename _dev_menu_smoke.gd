extends Node
## Throwaway headless check for the dev menu: it stays shut until asked for, it
## lists the whole catalogue, and what it drops on the ground is real loot under
## the normal pickup rules - collectable, copied into the inventory, and two
## spawns of one part stay two separate copies.
##
##   timeout 90 godot --headless res://_dev_menu_smoke.tscn

const CAR_SCENE := "res://scenes/world/player_car.tscn"
const SCRAP_SCENE := "res://scenes/world/scrap_pickup.tscn"
## Where the escape-from-cleanup control orb is parked: far enough from the car
## that it cannot be collected, so it is genuinely the lifetime that frees it.
const FAR_AWAY := Vector2(4000.0, 4000.0)

## Kept as plain ints rather than reaching into `DevMenu.Tab`, so this file still
## parses if the enum is ever reordered or renamed.
const TAB_BODY := 0
const TAB_ENGINE := 1
const TAB_WHEEL := 2
const TAB_SCRAP := 3

var _failures := 0
var _checks := 0
var _car: PlayerCar = null

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	DevMenu.set_enabled(true)
	_check_starts_closed()
	await _check_without_a_world()
	await _check_parts_spawn()
	await _check_spawns_are_copies()
	await _check_spawns_stay_apart()
	await _check_scrap_spawns()
	await _check_persistent_loot()
	await _check_clear_dropped()
	print("---")
	if _failures == 0:
		print("SMOKE OK (%d checks)" % _checks)
	else:
		printerr("SMOKE FAILED: %d of %d checks" % [_failures, _checks])
	get_tree().quit(1 if _failures > 0 else 0)

# --- checks -------------------------------------------------------------------

func _check_starts_closed() -> void:
	print("<hidden until asked for>")
	_ok("starts hidden", not DevMenu.visible)
	DevMenu.toggle()
	_ok("F1 opens it", DevMenu.visible)
	DevMenu.toggle()
	_ok("F1 again closes it", not DevMenu.visible)

## No car: the menu is still worth opening (you can read the catalogue), but it
## has nowhere to put anything and says so instead of failing silently.
func _check_without_a_world() -> void:
	print("<no car, no spawns>")
	Inventory.reset()
	DevMenu.open()
	DevMenu._show_tab(TAB_ENGINE)
	await _settle()
	_eq("the catalogue still lists", DevMenu._list.get_child_count(), PartDatabase.engines.size())
	DevMenu._spawn_part(PartDatabase.engines[0])
	_eq("but nothing was dropped", _pickups().size(), 0)
	_ok("and the status says why",
			DevMenu._status_label.text.contains("open world"),
			DevMenu._status_label.text)
	DevMenu.close()

func _check_parts_spawn() -> void:
	print("<parts land on the ground>")
	Inventory.reset()
	_car = _add_car(Vector2(120.0, -40.0))
	DevMenu.open()
	DevMenu._show_tab(TAB_ENGINE)
	await _settle()
	_eq("one row per engine", DevMenu._list.get_child_count(), PartDatabase.engines.size())

	# Click the first row, the way a mouse would, rather than calling the spawn
	# directly - the click path is half of what this is testing.
	var slot := DevMenu._list.get_child(0) as PartSlot
	_ok("rows are the garage's own part rows", slot != null)
	if slot == null:
		return
	var owned_before := Inventory.owned_count(slot.part)
	var loose_before := _spares_of(String(slot.part.id)).size()
	DevMenu._on_row_input(_left_click(), slot)
	_eq("one pickup on the ground", _live_pickups().size(), 1)
	var orb := _live_pickups()[0] as PartPickup
	_ok("and it is a part orb", orb != null)
	if orb == null:
		return
	_eq("carrying the part that was clicked", String(orb.part.id), String(slot.part.id))
	_eq("parented into the car's own layer", String(orb.get_parent().name), "DevSpawns")
	_ok("which sits beside the car", orb.get_parent().get_parent() == _car.get_parent())
	await _settle()
	_ok("and it did not land inside the car", is_instance_valid(orb))

	orb.collect()
	_eq("collecting it banks a copy", Inventory.owned_count(slot.part), owned_before + 1)
	_eq("as a loose one", _spares_of(String(slot.part.id)).size(), loose_before + 1)
	_ok("that is not the catalogue's own Resource", not _spare_is_catalogue(slot.part))

## Two spawns of one part are two parts: collect both and the player owns two
## independent copies, exactly as if they had dug the same wheel up twice.
func _check_spawns_are_copies() -> void:
	print("<two spawns are two parts>")
	await _reset_spawns()
	var wheel: PartData = PartDatabase.wheels[0]
	var owned_before := Inventory.owned_count(wheel)
	var loose_before := _spares_of(String(wheel.id)).size()
	DevMenu._spawn_part(wheel)
	DevMenu._spawn_part(wheel)
	await _settle()
	_eq("two orbs on the ground", _live_pickups().size(), 2)
	for orb in _live_pickups():
		orb.collect()
	_eq("both are owned", Inventory.owned_count(wheel), owned_before + 2)
	var copies := _spares_of(String(wheel.id))
	_eq("as separate loose copies", copies.size(), loose_before + 2)
	if copies.size() >= 2:
		_ok("neither one shared with the other", not is_same(copies[0], copies[1]))
		_ok("nor with the catalogue's own", not is_same(copies[0], wheel))

## A grid of separate orbs, not one merged blob: the whole reason the spawn step
## is a collect radius plus a margin.
func _check_spawns_stay_apart() -> void:
	print("<spawns keep their distance>")
	await _reset_spawns()
	DevMenu._show_tab(TAB_WHEEL)
	await _settle()
	for i in 4:
		DevMenu._spawn_part(PartDatabase.wheels[1])
	var orbs := _live_pickups()
	_eq("four dropped", orbs.size(), 4)
	var closest := INF
	for i in orbs.size():
		for j in range(i + 1, orbs.size()):
			closest = minf(closest, orbs[i].global_position.distance_to(orbs[j].global_position))
	_ok("no two inside a collect radius of each other",
			closest >= Pickup.COLLECT_RADIUS * 2.0, "closest %s" % closest)
	await _reset_spawns()

func _check_scrap_spawns() -> void:
	print("<scrap spawns too>")
	await _reset_spawns()
	DevMenu._show_tab(TAB_SCRAP)
	await _settle()
	var buttons: Array = DevMenu._scrap_buttons.get_children()
	_eq("an amount button per offered amount", buttons.size(), 5)
	_ok("the scrap box is the one on show",
			DevMenu._scrap_box.visible and not DevMenu._parts_scroll.visible)

	var before := Inventory.scrap
	DevMenu._spawn_scrap(25)
	var orb := _live_pickups()[0] as ScrapPickup
	_ok("a scrap orb", orb != null)
	if orb == null:
		return
	_eq("worth what was asked for", orb.amount, 25)
	orb.collect()
	_eq("collecting it banks the scrap", Inventory.scrap, before + 25)

	# The buttons are wired by index into the amount list, so pressing one is the
	# only way to be sure the binding lines up with the label.
	(buttons[3] as BaseButton).pressed.emit()
	var paid := _live_pickups()[0] as ScrapPickup
	var got := "nothing"
	if paid != null:
		got = str(paid.amount)
	_ok("a button spawns its own amount", paid != null and paid.amount == 100,
			"got %s" % got)

func _check_persistent_loot() -> void:
	print("<dropped loot waits to be tested>")
	var orb := _live_pickups()[0]
	_ok("dev drops are marked persistent", orb.persistent)
	# Age it past the point where a bin's loot would give up and fade.
	orb._age = Pickup.LIFETIME + 10.0
	await _settle()
	_ok("so it is still there", is_instance_valid(orb))

	# The control: ordinary loot has to keep cleaning itself up, or a street full
	# of uncollected orbs never goes away.
	var litter := (load(SCRAP_SCENE) as PackedScene).instantiate() as ScrapPickup
	add_child(litter)
	litter.global_position = FAR_AWAY
	litter._age = Pickup.LIFETIME + 10.0
	await _settle()
	_ok("while ordinary loot still expires", not is_instance_valid(litter))

func _check_clear_dropped() -> void:
	print("<clearing up>")
	var dropped: int = DevMenu._live_count()
	_ok("the dropped count sees them", dropped > 0, "got %d" % dropped)
	DevMenu._clear_spawned()
	_eq("clearing forgets them", DevMenu._live_count(), 0)
	await _settle()
	_eq("and frees every one of them", _pickups().size(), 0)
	_ok("the status reports it", DevMenu._status_label.text.contains("Cleared"))

# --- helpers ------------------------------------------------------------------

static func _left_click() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event

func _add_car(at: Vector2) -> PlayerCar:
	var car := (load(CAR_SCENE) as PackedScene).instantiate() as PlayerCar
	add_child(car)
	car.global_position = at
	return car

## Sweep up whatever the last check dropped, so each one counts only its own.
func _reset_spawns() -> void:
	DevMenu._clear_spawned()
	await _settle()

## Two process frames (for queue_free()s to land) and two physics frames (so
## collection actually gets a chance to run).
func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame

## Every pickup in the tree, wherever it is parented. Collected orbs linger for
## a moment while they pop and fade, so counts go through `_live_pickups()`.
func _pickups() -> Array[Pickup]:
	var found: Array[Pickup] = []
	_collect_pickups(get_tree().root, found)
	return found

func _live_pickups() -> Array[Pickup]:
	var found: Array[Pickup] = []
	for orb in _pickups():
		if not orb._collected:
			found.append(orb)
	return found

static func _collect_pickups(node: Node, found: Array[Pickup]) -> void:
	if node is Pickup:
		found.append(node)
	for child in node.get_children():
		_collect_pickups(child, found)

## The player's loose copies of a part, by id.
func _spares_of(id: String) -> Array[PartData]:
	var found: Array[PartData] = []
	for part in Inventory.spare_parts:
		if part != null and String(part.id) == id:
			found.append(part)
	return found

## True when the first loose copy of `part` is literally the catalogue's own
## Resource - the shared-Resource bug the ownership rules exist to prevent.
func _spare_is_catalogue(part: PartData) -> bool:
	var copies := _spares_of(String(part.id))
	return copies.is_empty() or is_same(copies[0], part)

func _ok(what: String, passed: bool, detail: String = "") -> void:
	_checks += 1
	if passed:
		print("  pass  %s" % what)
	else:
		_failures += 1
		printerr("  FAIL  %s%s" % [what, (" (%s)" % detail) if not detail.is_empty() else ""])

func _eq(what: String, actual: Variant, expected: Variant) -> void:
	_ok(what, actual == expected, "got %s, expected %s" % [actual, expected])
