extends SceneTree

# Actual A2 parse → A4 external .NET CLI → A5 Godot result admission.
# Synthetic, *not* physical NO2/N2O4 kinetic parameter validation.
const MainScene = preload("res://scenes/main.tscn")
const DemoContract = preload("res://scripts/a5_smoke_contract.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var prepared: Dictionary = DemoContract.build_demo_request()
	assert(bool(prepared.get("ok", false)), "A2 must parse and atom/charge-check the chemistry-parseable synthetic scenario")
	var input: Dictionary = prepared.request
	assert(str(input.kind) == "simulation_request" and str(input.payload.data_quality) == "hypothetical", "Request must remain explicitly synthetic")
	assert(input.payload.reactions[0].kinetic_orders.size() == 1, "Kinetic orders must be explicitly present")
	assert(float(input.payload.reactions[0].rate_constant.value) == 0.1, "Only the explicitly synthetic kinetic k may be supplied")
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	assert(main.graph_view.series_by_quantity.is_empty(), "No fabricated data may show before actual A4 execution")
	assert(main.demo_run_button != null and not main.demo_run_button.disabled, "Synthetic demo start must be enabled")
	main._run_demo()
	assert(main.solver_process.is_busy(), "CLI must run as a real separate process, not a fake UI fixture")
	var elapsed := 0
	while main.solver_process.is_busy() and elapsed < 900:
		await process_frame
		elapsed += 1
	assert(not main.solver_process.is_busy(), "A4 CLI must finish within the bounded integration test")
	assert(main.playback_history.size() == 21, "The actual A4 result must provide 0..5 s sampled every 0.25 s")
	assert(main.graph_view.series_by_quantity.has("concentration"), "The actual A4 time series must reach the concentration plot")
	assert(main.graph_view.series_by_quantity.has("temperature"), "The explicit fixed-temperature series must reach the graph")
	assert(not main.graph_view.series_by_quantity.has("rate"), "A4 did not produce an independently verified rate series")
	assert(main.diagnostic_label.text.find("Синтетическое") >= 0, "The numerical result must be clearly labelled hypothetical")
	var end_sample: Dictionary = main.playback_history.back()
	assert(absf(float(end_sample.no2_mol) - 2.0 * (1.0 - exp(-0.5))) < 5.0e-6, "Actual A4 kinetics must match independently calculated first-order analytical shape")
	assert(absf(2.0 * float(end_sample.n2o4_mol) + float(end_sample.no2_mol) - 2.0) < 1.0e-6, "Actual A4 result must conserve nitrogen atoms")
	assert(main.playback_index == 0, "Timeline starts at validated t=0")
	main._step_demo()
	assert(main.playback_index == 1, "Step traverses actual computed samples")
	main._rewind_demo()
	assert(main.playback_index == 0, "Rewind traverses actual history, not an invented recalculation")
	main._toggle_playback()
	assert(main.playback_running, "Play should start computed-history playback")
	main._toggle_playback()
	assert(not main.playback_running, "Pause should stop computed-history playback")
	main._set_playback_speed(2)
	assert(main.playback_speed == 4.0, "Speed mode must update playback rate")
	main._seek_demo(8.0)
	assert(main.playback_index == 8, "Seek should select an actual A4 sample index")
	main._on_reaction_changed("user edited raw reaction")
	assert(main.playback_history.is_empty() and main.graph_view.series_by_quantity.is_empty(), "Editing the chemical draft must invalidate prior real samples")
	assert(main.playback_step_button.disabled, "Stale playback controls must be disabled")
	main.queue_free()
	print("A2 → A4 actual process → A5 Godot synthetic integration smoke passed")
	quit(0)
