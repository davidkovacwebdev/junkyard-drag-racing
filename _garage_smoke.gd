extends Node
## Throwaway headless check for the garage's ownership rules: a part is owned
## in exactly ONE place, fitting MOVES a copy instead of cloning one, and
## nothing the player owns is ever quietly eaten. Drives Inventory directly —
## no Garage UI, so this is the rules under test, not the drag and drop.
##
##   timeout 90 godot --headless res://_garage_smoke.tscn

const BODY_PLANK := "res://scenes/parts/bodies/body_plank.tscn"
const WHEEL_STANDARD := "res://scenes/parts/wheels/wheel_standard.tscn"
const GARAGE_SCENE := "res://scenes/garage/garage.tscn"

var _failures := 0
var _checks := 0

func _ready() -> void:
	# Deferred so the autoloads (Inventory/PartDatabase) have finished _ready
	# before anything asks them for a part.
	_run.call_deferred()

func _run() -> void:
	_check_starter_car()
	_check_pickups_are_copies()
	_check_one_wheel_fills_one_mount()
	_check_body_move_is_a_swap()
	_check_body_swap_keeps_every_wheel()
	_check_unowned_parts_are_refused()
	_check_new_game_list()
	_check_garage_rows_count()
	await _check_garage_screen()
	print("---")
	if _failures == 0:
		print("SMOKE OK (%d checks)" % _checks)
	else:
		printerr("SMOKE FAILED: %d of %d checks" % [_failures, _checks])
	get_tree().quit(1 if _failures > 0 else 0)

# --- checks -------------------------------------------------------------------

## A fresh game: one drivable car, no loose parts.
func _check_starter_car() -> void:
	print("<starter car>")
	Inventory.reset()
	_eq("one car", Inventory.owned_cars.size(), 1)
	var car: CarModelData = Inventory.owned_cars[0]
	_ok("has a body and an engine", car.body != null and car.engine != null)
	var mounts := PartDatabase.wheel_mount_count(car.body)
	_ok("the body declares at least two mounts", mounts >= 2, "got %d" % mounts)
	_eq("wheels match the body's mounts", car.wheels.size(), mounts)
	print("        starter car: %s + %s + %s x%d" % [
			car.body.id, car.engine.id, car.wheels[0].id, car.wheels.size()])
	_ok("no empty mount", not _has_null_wheel(car))
	_ok("nothing in the stash", Inventory.spare_parts.is_empty())

## Two digs of the same wheel are two parts, not one Resource listed twice.
func _check_pickups_are_copies() -> void:
	print("<pickups are copies>")
	Inventory.reset()
	var wheel := _wheel_at(WHEEL_STANDARD)
	_ok("catalog has " + WHEEL_STANDARD, wheel != null)
	if wheel == null:
		return
	var before := Inventory.owned_count(wheel)
	Inventory.add_part(wheel)
	Inventory.add_part(wheel)
	_eq("two digs bank two parts", Inventory.spare_parts.size(), 2)
	_eq("two digs count as two owned", Inventory.owned_count(wheel), before + 2)
	if Inventory.spare_parts.size() == 2:
		_ok("each is its own Resource",
				not is_same(Inventory.spare_parts[0], Inventory.spare_parts[1]))
		_ok("neither is the shared catalog entry",
				not is_same(Inventory.spare_parts[0], wheel)
				and not is_same(Inventory.spare_parts[1], wheel))

## The named bug: one tire bolted onto every corner. One drop fits one mount,
## and with one owned tire a second drop has to MOVE it, not copy it.
func _check_one_wheel_fills_one_mount() -> void:
	print("<one wheel, one mount>")
	Inventory.reset()
	var car: CarModelData = Inventory.owned_cars[0]
	# A wheel the car is NOT already sitting on, so "how many mounts wear it"
	# starts at zero and every mounting below is this test's own doing.
	var wheel := _wheel_other_than(String(car.wheels[0].id))
	var before := Inventory.owned_count(wheel)
	Inventory.add_part(wheel)
	_eq("picked up exactly one", Inventory.owned_count(wheel), before + 1)
	_eq("no mount wears it yet", _mounted(car, wheel), 0)

	_ok("drop on mount 0", Inventory.fit_part(car, PartData.Category.WHEEL, wheel, 0))
	_eq("wearing it on one mount", _mounted(car, wheel), 1)
	_ok("drop on mount 1", Inventory.fit_part(car, PartData.Category.WHEEL, wheel, 1))
	_eq("still wearing it on one mount", _mounted(car, wheel), 1)
	_eq("moved to the mount it was dropped on", String(car.wheels[1].id), String(wheel.id))
	_ok("the mount it left is no longer this wheel",
			String(car.wheels[0].id) != String(wheel.id))

	_ok("whole-car drop", Inventory.fit_part(car, PartData.Category.WHEEL, wheel, -1))
	_eq("whole-car drop still fits one mount", _mounted(car, wheel), 1)
	_eq("one tire is still one tire", Inventory.owned_count(wheel), before + 1)

## The named bug: the same body on two cars. Taking another car's body swaps
## the two over rather than cloning one and stripping the other.
func _check_body_move_is_a_swap() -> void:
	print("<a body moves between cars>")
	Inventory.reset()
	var a: CarModelData = Inventory.owned_cars[0]
	var b := Inventory._build_starter_car()
	Inventory.owned_cars.append(b)
	var worn := String(a.body.id)
	_eq("both cars start on the same body", String(b.body.id), worn)

	var other := _body_at(BODY_PLANK)
	var borrowed := a.body
	Inventory.add_part(other)
	_ok("fit the picked-up body on B", Inventory.fit_part(b, PartData.Category.BODY, other))
	_eq("B wears it", String(b.body.id), String(other.id))
	_ok("B's copy is its own Resource", not is_same(b.body, other))
	_eq("A is untouched", String(a.body.id), worn)

	# The bug: B is wearing the only other body the player owns, and it gets
	# dragged onto A.
	_ok("take B's body for A", Inventory.fit_part(a, PartData.Category.BODY, b.body))
	_ok("neither car is left bodiless", a.body != null and b.body != null)
	_eq("A wears it", String(a.body.id), String(other.id))
	_eq("B got A's old body", String(b.body.id), worn)
	_ok("and got the very same copy, not a clone", is_same(b.body, borrowed))
	_ok("the two cars wear two different parts", not is_same(a.body, b.body))
	_eq("still exactly one of that body owned", Inventory.owned_count(other), 1)
	_eq("both copies of the starter body still owned",
			Inventory.owned_count(borrowed), 2)
	_eq("A's wheels re-cut to its body's mounts",
			a.wheels.size(), PartDatabase.wheel_mount_count(a.body))
	_eq("B's wheels re-cut to its body's mounts",
			b.wheels.size(), PartDatabase.wheel_mount_count(b.body))
	_ok("no empty mount on A", not _has_null_wheel(a))
	_ok("no empty mount on B", not _has_null_wheel(b))

## The named bug: parts disappearing. Swapping onto a body with fewer mounts
## has to return the surplus wheels to the player, not drop them.
func _check_body_swap_keeps_every_wheel() -> void:
	print("<a body swap keeps every wheel>")
	Inventory.reset()
	var car: CarModelData = Inventory.owned_cars[0]
	var three := _body_with_mounts(3)
	var two := _body_with_mounts(2)
	if three == null or two == null:
		_fail("catalog has both a 3-mount and a 2-mount body")
		return
	Inventory.add_part(three)
	_ok("fit the 3-mount body", Inventory.fit_part(car, PartData.Category.BODY, three))
	_eq("wheels grew to 3", car.wheels.size(), 3)
	_ok("every new mount is filled", not _has_null_wheel(car))

	var wheels_before := _wheel_instances()
	var stash_before := _stashed_wheels()
	Inventory.add_part(two)
	_ok("fit the 2-mount body", Inventory.fit_part(car, PartData.Category.BODY, two))
	_eq("wheels shrank to 2", car.wheels.size(), 2)
	_ok("both mounts are filled", not _has_null_wheel(car))
	_eq("no wheel was destroyed", _wheel_instances(), wheels_before)
	_eq("the surplus wheel went back to the stash", _stashed_wheels(), stash_before + 1)

## A part the player doesn't own can't be dragged out of thin air — and a
## refused drop must leave the car exactly as it was.
func _check_unowned_parts_are_refused() -> void:
	print("<unowned parts are refused>")
	Inventory.reset()
	var car: CarModelData = Inventory.owned_cars[0]
	var worn := String(car.body.id)
	var body := _body_other_than(worn)
	var wheel := _wheel_other_than(String(car.wheels[0].id))
	if body == null or wheel == null:
		_fail("catalog has spare bodies and wheels to test with")
		return
	_eq("body not owned", Inventory.owned_count(body), 0)
	_eq("wheel not owned", Inventory.owned_count(wheel), 0)
	_ok("detach knows it has none", Inventory.detach_part(body) == null)
	_ok("an unowned body can't be fitted",
			not Inventory.fit_part(car, PartData.Category.BODY, body))
	_eq("the car keeps its own body", String(car.body.id), worn)
	var mounts_before := _wheel_ids(car)
	_ok("an unowned wheel can't be fitted",
			not Inventory.fit_part(car, PartData.Category.WHEEL, wheel, 0))
	_ok("the refused drop left the wheels alone", _wheel_ids(car) == mounts_before)
	_ok("and minted nothing", Inventory.spare_parts.is_empty())

## A brand-new game: the starter parts are ON the car, so every tab is empty.
## Seeing a body/engine/wheel row here would mean a bonus copy was handed out.
func _check_new_game_list() -> void:
	print("<new game list>")
	Inventory.reset()
	var car: CarModelData = Inventory.owned_cars[0]
	var categories := [PartData.Category.BODY, PartData.Category.ENGINE, PartData.Category.WHEEL]
	for category in categories:
		var rows := _rows_for(category)
		for row in rows:
			print("        %-6s %-24s x%d" % [_category_name(category),
					(row["part"] as PartData).display_name, int(row["count"])])
		_eq("%s: nothing loose" % _category_name(category), _loose_instances(category), 0)
		_eq("%s: no spare rows" % _category_name(category), rows.size(), 0)
		# And the parts really are on the car, just not listed.
		_ok("%s: the car is wearing them" % _category_name(category),
				_fitted_instances(car, category) > 0)

## How many of `category` are bolted to `car`.
func _fitted_instances(car: CarModelData, category: PartData.Category) -> int:
	match category:
		PartData.Category.BODY:
			return 1 if car.body != null else 0
		PartData.Category.ENGINE:
			return 1 if car.engine != null else 0
		_:
			var total := 0
			for wheel in car.wheels:
				if wheel != null:
					total += 1
			return total

## How many of `category` are sitting loose in the stash.
func _loose_instances(category: PartData.Category) -> int:
	var total := 0
	for part in Inventory.spare_parts:
		if part != null and part.category == category:
			total += 1
	return total

static func _category_name(category: PartData.Category) -> String:
	match category:
		PartData.Category.BODY:
			return "body"
		PartData.Category.ENGINE:
			return "engine"
		_:
			return "wheel"

## What the garage list shows: the car's own parts are hidden, spares aren't.
func _check_garage_rows_count() -> void:
	print("<garage rows count copies>")
	Inventory.reset()
	var car: CarModelData = Inventory.owned_cars[0]
	_eq("the car's worn wheels aren't spares", _rows_for(PartData.Category.WHEEL).size(), 0)

	var extra := _wheel_other_than(String(car.wheels[0].id))
	if extra == null:
		_fail("catalog has another wheel to test with")
		return
	Inventory.add_part(extra)
	_eq("one spare reads as one", _row_count(_rows_for(PartData.Category.WHEEL), String(extra.id)), 1)
	Inventory.add_part(extra)
	var rows := _rows_for(PartData.Category.WHEEL)
	_eq("two spares read as two", _row_count(rows, String(extra.id)), 2)
	_eq("as one row, not two identical ones", rows.size(), 1)
	# Fitting both still leaves the car's own tire out of the count.
	_ok("a same-id copy on the car doesn't inflate the count",
			_row_count(rows, String(car.wheels[0].id)) == -1, str(rows))

## The real screen, exercised through the same call a drop makes, so the count
## actually reaches the row label the player reads.
func _check_garage_screen() -> void:
	print("<garage screen>")
	Inventory.reset()
	var car: CarModelData = Inventory.owned_cars[0]
	var spare := _body_other_than(String(car.body.id))
	var placeholder := String(car.body.display_name)

	var garage := (load(GARAGE_SCENE) as PackedScene).instantiate() as Garage
	add_child(garage)
	await _settle()
	garage._show_category(PartData.Category.BODY)
	await _settle()
	# A fresh game: the car's body is on the car, so the tab is empty and says so.
	_ok("nothing to fit on a fresh car", _row_labels(garage).is_empty())
	_ok("and the empty tab explains itself", garage._parts_empty_label.visible)

	Inventory.add_part(spare)
	Inventory.add_part(spare)
	garage._show_category(PartData.Category.BODY)
	await _settle()
	var labels := _row_labels(garage)
	_eq("only the spare body is offered", labels.size(), 1)
	_ok("two copies of the spare show as two", labels.has("%s x2" % spare.display_name), str(labels))
	_ok("the car's own body is not listed as a spare", not labels.has(placeholder), str(labels))
	_ok("and the hint gets out of the way", not garage._parts_empty_label.visible)

	garage.equip_part(PartData.Category.BODY, Inventory.spare_parts[0])
	_ok("the car wears the spare", String(car.body.id) == String(spare.id))
	_eq("and still owns both copies", Inventory.owned_count(spare), 2)
	await _settle()
	labels = _row_labels(garage)
	_eq("the list rebuilt around the swap", labels.size(), 2)
	_ok("the body it took off is listed as a spare now", labels.has(placeholder), str(labels))
	_ok("neither car part was cloned", not is_same(car.body, spare))
	garage.queue_free()
	await _settle()

## Two frames: one for queue_free()d rows to actually leave, one to spare.
func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

## The visible title of every row currently in the parts list.
func _row_labels(garage: Garage) -> Array:
	var labels := []
	for child in garage.get_node("PartsScroll/PartsList").get_children():
		if child is PartSlot:
			labels.append((child as PartSlot)._title_label.text)
	return labels

# --- inventory helpers --------------------------------------------------------

## Rows exactly as Garage builds them (its method only reads Inventory, so a
## loose Garage node is enough — no scene, no UI, and freed on the way out).
func _rows_for(category: PartData.Category) -> Array[Dictionary]:
	var garage := Garage.new()
	var rows := garage._owned_parts(category)
	garage.free()
	return rows

func _row_count(rows: Array[Dictionary], id: String) -> int:
	for row in rows:
		var part: PartData = row["part"]
		if String(part.id) == id:
			return int(row["count"])
	return -1

## Every wheel instance the player owns, fitted or loose.
func _wheel_instances() -> int:
	var total := _stashed_wheels()
	for car in Inventory.owned_cars:
		for wheel in car.wheels:
			if wheel != null:
				total += 1
	return total

func _stashed_wheels() -> int:
	var total := 0
	for part in Inventory.spare_parts:
		if part != null and part.category == PartData.Category.WHEEL:
			total += 1
	return total

func _mounted(car: CarModelData, part: PartData) -> int:
	var total := 0
	for wheel in car.wheels:
		if wheel != null and wheel.id == part.id:
			total += 1
	return total

func _has_null_wheel(car: CarModelData) -> bool:
	return car.wheels.has(null)

func _wheel_ids(car: CarModelData) -> Array:
	var ids := []
	for wheel in car.wheels:
		ids.append(String(wheel.id) if wheel != null else "-")
	return ids

# --- catalog helpers ----------------------------------------------------------

func _body_at(path: String) -> BodyPartData:
	for body in PartDatabase.bodies:
		if body.scene_path == path:
			return body
	return null

func _wheel_at(path: String) -> WheelPartData:
	for wheel in PartDatabase.wheels:
		if wheel.scene_path == path:
			return wheel
	return null

func _body_with_mounts(count: int) -> BodyPartData:
	for body in PartDatabase.bodies:
		if PartDatabase.wheel_mount_count(body) == count:
			return body
	return null

func _body_other_than(id: String) -> BodyPartData:
	for body in PartDatabase.bodies:
		if String(body.id) != id:
			return body
	return null

func _wheel_other_than(id: String) -> WheelPartData:
	for wheel in PartDatabase.wheels:
		if String(wheel.id) != id:
			return wheel
	return null

# --- assertions ---------------------------------------------------------------

func _ok(what: String, passed: bool, detail: String = "") -> void:
	_checks += 1
	if passed:
		print("  pass  ", what)
		return
	_failures += 1
	print("  FAIL  ", what, "  ", detail)

func _eq(what: String, actual: Variant, expected: Variant) -> void:
	_ok(what, actual == expected, "got %s, expected %s" % [actual, expected])

func _fail(what: String) -> void:
	_ok(what, false)
