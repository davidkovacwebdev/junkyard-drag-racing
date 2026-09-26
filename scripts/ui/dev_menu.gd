extends CanvasLayer
## Developer popup: every part in the catalogue, plus scrap, as a click-to-spawn
## pickup - so the loot path (spawn, drive over it, Inventory, garage) can be
## tested without digging up half the map first.
##
## F1 toggles it, from any scene. The rows are the very same `PartSlot` the
## garage uses, so a part looks and reads identically in both places; clicking
## one drops that part on the ground as a real `PartPickup` beside the car. A dev
## spawn is not special-cased anywhere downstream - it is collected, copied and
## fitted by exactly the same rules as loot out of a bin.
##
## Spawning needs a car and some ground to land on, so it only works in the open
## world. In a menu or a building interior the list still browses; it just cannot
## drop anything, and says so.
##
## Registered as the `DevMenu` autoload, and switched off outside debug builds -
## see `set_enabled()`.

## The four things the menu hands out. Scrap is not a part, so it gets a tab of
## its own rather than a fake PartData.
enum Tab { BODY, ENGINE, WHEEL, SCRAP }

## Cells across the spawn grid, and how far apart they sit. The step is a pickup
## radius plus a margin on each axis, so two spawns can never merge into one
## blob: a grid of separate orbs reads as "I spawned eight", one fat orb reads as
## something being wrong.
const _GRID_COLUMNS := 4
const _GRID_STEP := Pickup.COLLECT_RADIUS * 2.0 + 16.0
## How far below the car the grid starts, in grid steps. A single step would put
## the first row's collection circle inside the car - the dev would spawn a part
## and collect it on the same frame - so this is the closest row that is actually
## clear of the bodywork.
const _GRID_ORIGIN_ROWS := 1.5
## How high a spawn is dropped from, so it arcs in and lands like a bin's loot
## instead of blinking into place.
const _DROP_HEIGHT := 260.0
const _DROP_ARC := 48.0
const _DROP_TIME := 0.5
## Scrap amounts offered, smallest first. There is no single "right" amount to
## hand a developer, so these are the orders of magnitude the economy spans.
const _SCRAP_AMOUNTS := [1, 5, 25, 100, 1000]

const _PART_PICKUP_SCENE := preload("res://scenes/world/part_pickup.tscn")
const _SCRAP_PICKUP_SCENE := preload("res://scenes/world/scrap_pickup.tscn")
const _PART_SLOT_SCENE := preload("res://scenes/garage/part_slot.tscn")


@onready var _backdrop: ColorRect = $Backdrop
@onready var _parts_scroll: ScrollContainer = $Backdrop/Panel/PartsScroll
@onready var _list: GridContainer = $Backdrop/Panel/PartsScroll/PartsList
@onready var _scrap_box: VBoxContainer = $Backdrop/Panel/ScrapBox
@onready var _scrap_buttons: HBoxContainer = $Backdrop/Panel/ScrapBox/Buttons
@onready var _owned_label: Label = $Backdrop/Panel/ScrapBox/OwnedLabel
@onready var _status_label: Label = $Backdrop/Panel/StatusLabel
@onready var _clear_button: ScrapButton = $Backdrop/Panel/ClearButton
@onready var _body_tab: ScrapButton = $Backdrop/Panel/BodyTab
@onready var _engine_tab: ScrapButton = $Backdrop/Panel/EngineTab
@onready var _wheel_tab: ScrapButton = $Backdrop/Panel/WheelTab
@onready var _scrap_tab: ScrapButton = $Backdrop/Panel/ScrapTab

## Off unless this is a debug build (see `set_enabled`).
var _enabled := false
## Which tab is open. Kept across opens: coming back to the tab you were last
## using is one less click for the thing you do most.
var _tab: int = Tab.BODY
## Where the next spawn lands, and where the grid it belongs to started.
var _spawn_index := 0
var _grid_origin := Vector2.ZERO
var _has_grid := false
## Everything this menu has dropped that is not collected or cleared yet, so
## "Clear dropped" can tidy up after a testing session.
var _spawned: Array[Pickup] = []
## The car spawns land beside, and the container they are parented to. Both are
## re-resolved rather than trusted: a scene change frees them, and neither may be
## held on to after that.
var _car: PlayerCar = null
var _spawn_root: Node2D = null

func _ready() -> void:
	# This has to keep answering while the tree is paused, or the menu would be
	# unreachable from a paused game.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_wire_buttons()
	# WASD still drives the car while the menu is open, and a focused Button
	# would eat those keys, so nothing in here takes keyboard focus.
	for button in [_body_tab, _engine_tab, _wheel_tab, _scrap_tab, _clear_button]:
		button.focus_mode = Control.FOCUS_NONE
	_build_scrap_buttons()
	set_enabled(OS.is_debug_build())

## Live feedback, so a dev can watch scrap tick up as the car sweeps a pile and
## can see how much litter is still standing.
func _process(_delta: float) -> void:
	if not visible:
		return
	if _tab == Tab.SCRAP:
		_owned_label.text = "You are carrying %d scrap." % Inventory.scrap
	_clear_button.text = "Clear dropped (%d)" % _live_count()

# --- Opening and closing -------------------------------------------------------

## Master switch. Debug builds default to on, which is what makes F1 available in
## the editor and free in an export; the headless smoke test calls this with
## `true`, since a bare `godot --headless` run is not guaranteed to report the
## same debug/export split an editor session does.
func set_enabled(value: bool) -> void:
	_enabled = value
	if not _enabled:
		close()

func toggle() -> void:
	if visible:
		close()
	else:
		open()

## Show the menu and rebuild what it is offering. The list is rebuilt on every
## open rather than kept around: a part is a live catalogue Resource, and this is
## the cheapest way to be sure the menu agrees with the game about what exists.
func open() -> void:
	if not _enabled:
		return
	visible = true
	_show_tab(_tab)

func close() -> void:
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not _enabled:
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_F1:
		toggle()
		get_viewport().set_input_as_handled()

## Clicking the dimmed area behind the panel closes, the same as F1.
func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		close()

# --- The list ------------------------------------------------------------------

## Every signal is connected here rather than in the scene, partly so the binds
## live in one place, and partly because two of these have to
## pass an argument, which a scene connection cannot do readably.
func _wire_buttons() -> void:
	_body_tab.pressed.connect(_show_tab.bind(Tab.BODY))
	_engine_tab.pressed.connect(_show_tab.bind(Tab.ENGINE))
	_wheel_tab.pressed.connect(_show_tab.bind(Tab.WHEEL))
	_scrap_tab.pressed.connect(_show_tab.bind(Tab.SCRAP))
	_clear_button.pressed.connect(_clear_spawned)
	_backdrop.gui_input.connect(_on_backdrop_input)

## One button per amount, straight from `_SCRAP_AMOUNTS`, so that list is the
## only place an amount is written down.
func _build_scrap_buttons() -> void:
	for amount in _SCRAP_AMOUNTS:
		var button := ScrapButton.new()
		button.text = "x%d" % amount
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(128, 50)
		button.font_size = 20
		button.jitter_seed = amount
		button.tilt_degrees = 1.5 if _scrap_buttons.get_child_count() % 2 == 0 else -1.5
		button.pressed.connect(_spawn_scrap.bind(amount))
		_scrap_buttons.add_child(button)

func _show_tab(tab: int) -> void:
	_tab = tab
	for child in _list.get_children():
		child.queue_free()
	_parts_scroll.visible = tab != Tab.SCRAP
	_scrap_box.visible = tab == Tab.SCRAP
	_refresh_tabs()
	if tab == Tab.SCRAP:
		_set_status("Pick an amount. The scrap lands on the ground next to the car.")
		return
	for part in _parts_for(tab):
		_add_row(part)
	_set_status("Click a part to drop it on the ground next to the car.")

func _refresh_tabs() -> void:
	_body_tab.selected = _tab == Tab.BODY
	_engine_tab.selected = _tab == Tab.ENGINE
	_wheel_tab.selected = _tab == Tab.WHEEL
	_scrap_tab.selected = _tab == Tab.SCRAP

## The catalogue a tab shows, in the garage's own order (by name), so the dev
## menu and the parts list agree on where a part lives.
func _parts_for(tab: int) -> Array[PartData]:
	var parts: Array[PartData] = []
	match tab:
		Tab.BODY:
			for part in PartDatabase.bodies:
				parts.append(part)
		Tab.ENGINE:
			for part in PartDatabase.engines:
				parts.append(part)
		Tab.WHEEL:
			for part in PartDatabase.wheels:
				parts.append(part)
	parts.sort_custom(func(a: PartData, b: PartData) -> bool:
		return a.display_name < b.display_name)
	return parts

## One clickable row. `PartSlot` has to be in the tree before `set_part()` - its
## icon resolves its SubViewport in `_ready()` - so it is added first, exactly as
## the garage's list does it.
##
## `garage` is deliberately left unset, so a row dragged out of the dev menu has
## nowhere to land and simply snaps back.
func _add_row(part: PartData) -> void:
	var slot: PartSlot = _PART_SLOT_SCENE.instantiate()
	_list.add_child(slot)
	slot.category = part.category
	slot.set_part(part)
	slot.tooltip_text = "Spawn %s" % part.display_name
	slot.gui_input.connect(_on_row_input.bind(slot))

func _on_row_input(event: InputEvent, slot: PartSlot) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_spawn_part(slot.part)

# --- Spawning ------------------------------------------------------------------

func _spawn_part(part: PartData) -> void:
	if part == null:
		return
	var orb := _PART_PICKUP_SCENE.instantiate() as PartPickup
	if orb == null:
		return
	# The catalogue's own PartData, not a copy: PartPickup only reads it for the
	# icon and the tint, and collecting it is `Inventory.add_part`, which does the
	# copying. So two spawns of one part stay two independent copies.
	orb.configure(part)
	_drop(orb, part.display_name)

func _spawn_scrap(amount: int) -> void:
	var orb := _SCRAP_PICKUP_SCENE.instantiate() as ScrapPickup
	if orb == null:
		return
	orb.amount = amount
	_drop(orb, "%d scrap" % amount)

## Put `orb` on the ground: parented into the spawn container, so it lands in the
## car's own Y-sorted layer and sorts against it, and flung down onto the next
## free grid cell rather than teleported, so a spawn is visibly arriving.
func _drop(orb: Pickup, what: String) -> void:
	var car := _active_car()
	var container := _spawn_container(car)
	if container == null:
		orb.free()
		_set_status("Nothing to drop onto. Spawns need the open world.")
		return
	var landing := _next_slot(car.global_position)
	# Dev loot is there to be tested against, not tidied away mid-session.
	orb.persistent = true
	container.add_child(orb)
	orb.launch(landing + Vector2(0.0, -_DROP_HEIGHT), landing, _DROP_ARC, _DROP_TIME)
	_spawned.append(orb)
	_set_status("Dropped %s." % what)

## The player's car, or null in a scene without one. Looked up by group rather
## than cached forever, so F1 keeps working after a scene change.
func _active_car() -> PlayerCar:
	if is_instance_valid(_car):
		return _car
	_car = get_tree().get_first_node_in_group(PlayerCar.GROUP) as PlayerCar
	return _car

## The node spawns are parented to: one created on demand under whatever holds
## the car, so the orbs share the car's layer and sort against it correctly. It
## is freed along with the scene, which is why it gets re-resolved rather than
## trusted.
func _spawn_container(car: PlayerCar) -> Node2D:
	if car == null or car.get_parent() == null:
		return null
	if is_instance_valid(_spawn_root) and _spawn_root.get_parent() != null:
		return _spawn_root
	_spawn_root = Node2D.new()
	_spawn_root.name = "DevSpawns"
	car.get_parent().add_child(_spawn_root)
	return _spawn_root

## The next free cell of the spawn grid, laid out below the car. The grid resets
## whenever the car has moved on, so eight rapid clicks pile up beside wherever
## the car is now instead of stringing a line back to where it was.
func _next_slot(anchor: Vector2) -> Vector2:
	if not _has_grid or _grid_origin.distance_to(anchor) > _GRID_STEP:
		_grid_origin = anchor
		_spawn_index = 0
		_has_grid = true
	var column := _spawn_index % _GRID_COLUMNS
	var row := floori(float(_spawn_index) / float(_GRID_COLUMNS))
	_spawn_index += 1
	var inset := float(_GRID_COLUMNS - 1) * 0.5
	return anchor + Vector2(0.0, _GRID_STEP * _GRID_ORIGIN_ROWS) + Vector2(
			(float(column) - inset) * _GRID_STEP, float(row) * _GRID_STEP)

## Tidy up: free everything this menu dropped that is still standing, so a test
## session does not leave the map covered in loot that never expires.
func _clear_spawned() -> void:
	var freed := 0
	for orb in _spawned:
		if is_instance_valid(orb) and not orb.is_queued_for_deletion():
			orb.queue_free()
			freed += 1
	_spawned.clear()
	_spawn_index = 0
	_has_grid = false
	_set_status("Cleared %d dropped pickup(s)." % freed)

## How many dropped pickups are still standing, without rebuilding the list. An
## orb frees itself once collected, so it has to be validity-checked every time.
func _live_count() -> int:
	var count := 0
	for orb in _spawned:
		if is_instance_valid(orb) and not orb.is_queued_for_deletion():
			count += 1
	return count

func _set_status(text: String) -> void:
	_status_label.text = text
