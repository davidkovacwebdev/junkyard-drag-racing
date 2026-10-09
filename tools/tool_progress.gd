class_name ToolProgress
extends RefCounted
## A progress bar for a headless tool, redrawn in place on the terminal's
## bottom line. Worker processes each report through their own file, holding
## how much they've done, and the bar adds those up. Whatever the workers
## print comes in through their pipes and goes out above the bar, so the bar
## stays on the bottom line.

const BAR_WIDTH := 40
const REDRAW_MSEC := 500
const PIPE_READ_BYTES := 65536

var _label := ""
var _total := 0
var _unit := ""
## Shown after the bar until anything's done (workers still loading).
var _waiting_message := ""
var _last_draw_msec := -REDRAW_MSEC
var _last_done := -1
var _pipes: Array[FileAccess] = []
## Each pipe's text since its last newline.
var _partial_lines: Dictionary = {}

func _init(label: String, total: int, unit: String, waiting_message: String = "") -> void:
	_label = label
	_total = total
	_unit = unit
	_waiting_message = waiting_message
	draw(0)

## A worker's stdout or stderr (from OS.execute_with_pipe), to print above
## the bar.
func add_output_pipe(pipe: FileAccess) -> void:
	_pipes.append(pipe)
	_partial_lines[pipe] = ""

## Prints the workers' output and redraws from their files, at most every
## REDRAW_MSEC.
func update_from_files(paths: PackedStringArray) -> void:
	_print_pipe_output()
	if Time.get_ticks_msec() - _last_draw_msec < REDRAW_MSEC:
		return
	_last_draw_msec = Time.get_ticks_msec()
	var done := 0
	for path in paths:
		done += FileAccess.get_file_as_string(path).to_int()
	if done != _last_done:
		draw(done)

## Carriage return and clear-line, no newline, so the next draw replaces it.
func draw(done: int) -> void:
	_last_done = done
	var filled := BAR_WIDTH * mini(done, _total) / maxi(_total, 1)
	var waiting := "  (%s)" % _waiting_message if done == 0 and not _waiting_message.is_empty() else ""
	printraw("\r\u001b[K%s  [%s%s] %d / %d %s%s" % [_label, "#".repeat(filled), ".".repeat(BAR_WIDTH - filled),
			done, _total, _unit, waiting])

## Clears the bar, prints `line` where it was and draws the bar again below.
func print_above(line: String) -> void:
	printraw("\r\u001b[K%s\n" % line)
	draw(_last_done)

## Draws the bar full and moves on to a fresh line.
func finish() -> void:
	_print_pipe_output()
	draw(_total)
	printraw("\n")

func _print_pipe_output() -> void:
	for pipe in _pipes:
		var text: String = _partial_lines[pipe] + pipe.get_buffer(PIPE_READ_BYTES).get_string_from_utf8()
		var lines := text.split("\n")
		_partial_lines[pipe] = lines[lines.size() - 1]
		for i in lines.size() - 1:
			print_above(lines[i])

static func write_worker_file(path: String, done: int) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(str(done))
	file.close()
