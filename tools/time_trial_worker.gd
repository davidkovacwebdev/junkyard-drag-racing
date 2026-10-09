extends Node2D
## One TimeTrial worker process, spawned by TimeTrial.run(). Races the specs in
## TimeTrial.worker_specs_path(n) and writes their results next to them.

var _worker := 0

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--worker="):
			_worker = arg.trim_prefix("--worker=").to_int()
	var specs: Array[Dictionary] = []
	specs.assign(JSON.parse_string(FileAccess.get_file_as_string(TimeTrial.worker_specs_path(_worker))))
	var trial := TimeTrial.new()
	trial.on_hill = "--hill" in OS.get_cmdline_user_args()
	trial.progress_path = TimeTrial.worker_progress_path(_worker)
	add_child(trial)
	trial.finished.connect(_save)
	trial.run_in_this_process(specs)

func _save(results: Array[Dictionary]) -> void:
	var file := FileAccess.open(TimeTrial.worker_results_path(_worker), FileAccess.WRITE)
	file.store_string(JSON.stringify(results))
	file.close()
	get_tree().quit()
