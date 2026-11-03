extends SceneTree

const Contract = preload("res://scripts/a5_smoke_contract.gd")
const Runner = preload("res://scripts/a5_solver_process.gd")
const Graph = preload("res://scripts/graph_series_view.gd")
const Main = preload("res://scripts/main.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var built: Dictionary = Contract.build_demo_request()
	assert(bool(built.get("ok", false)), "A2 parser must accept N2O4(g) -> 2NO2(g) and validate atom/charge balance")
	var request: Dictionary = built.request
	assert(str(request.kind) == "simulation_request" and str(request.contract_version) == "0.1", "Request must use contract v0.1")
	assert(request.payload.reactions[0].stoichiometry[0].coefficient == -1, "A2 reactant stoichiometry must be negative in A4")
	assert(request.payload.reactions[0].stoichiometry[1].coefficient == 2, "A2 product stoichiometry must preserve the balancing coefficient")
	assert(request.payload.reactions[0].kinetic_orders[0].order == 1.0, "Synthetic order must be explicitly declared")
	assert(str(request.payload.data_quality) == "hypothetical", "Synthetic data can never be labelled verified")

	var absent := Contract.validate_response({}, request)
	assert(not bool(absent.get("ok", true)), "Missing response must fail closed")
	var runner = Runner.new()
	root.add_child(runner)
	assert(not Runner.solver_path().is_empty(), "This E2E test requires a genuine self-contained A4 CLI binary")
	var started: Dictionary = runner.launch(request)
	assert(bool(started.get("ok", false)), "Godot must launch the actual A4 process: " + str(started.get("error", "")))
	assert(runner.is_busy(), "Child process must be active or waiting to be reaped")
	var admitted: Dictionary = await runner.completed
	assert(bool(admitted.get("ok", false)), "A4 real subprocess must return validated scientific-model-labelled data: " + str(admitted.get("error", "")))
	assert(bool(admitted.completed), "The simple synthetic ODE should reach its requested end")
	assert(admitted.history.size() == 21, "The real solver should produce t=0..5 at 0.25s output steps")
	assert(absf(float(admitted.history[-1].time_s) - 5.0) < 1.0e-9, "End time must actually be reached")
	assert(absf(float(admitted.history[-1].n2o4_mol) - exp(-0.5)) < 2.0e-5, "A4 trajectory should match independently derived first-order decay")
	assert(absf(float(admitted.history[-1].no2_mol) - 2.0 * (1.0 - exp(-0.5))) < 2.0e-5, "A4 product amount follows checked stoichiometry")
	var graph = Graph.new()
	root.add_child(graph)
	assert(bool(graph.submit_series(admitted.concentration_series, "0.1").get("ok", false)), "Graph must accept true A4 concentration output")
	assert(bool(graph.submit_series(admitted.temperature_series, "0.1").get("ok", false)), "Graph must accept explicit constant-T metadata for the same run")
	assert(graph.series_by_quantity["concentration"].valid_points == 21, "Graph must show every actual computed output sample")
	assert(not graph.series_by_quantity.has("rate"), "A4 CLI does not return a real rate series; never fabricate it")
	assert(graph.series_by_quantity["concentration"].result_ref == graph.series_by_quantity["temperature"].result_ref, "Both graph tabs belong to one result")

	# The real Godot application applies the same adapter to its three tabs
	# and controls playback over the validated, finite history.
	var main = Main.new()
	root.add_child(main)
	await process_frame
	main._on_demo_result(admitted)
	assert(main.playback_history.size() == 21 and main.playback_slider.editable, "Main workspace must unlock history only after a genuine A4 result")
	assert(main.graph_view.series_by_quantity.has("concentration"), "Main workspace must display the real A4 concentration series")
	main._step_demo()
	assert(main.playback_index == 1 and not main.playback_running, "A step must advance exactly one validated sample")
	main._rewind_demo()
	assert(main.playback_index == 0, "Rewind must return to the first validated history point")
	main._set_playback_speed(2)
	assert(is_equal_approx(main.playback_speed, 4.0), "Speed control must explicitly select 4× playback")
	main._toggle_playback()
	assert(main.playback_running, "Play must start history playback")
	main._toggle_playback()
	assert(not main.playback_running, "Pause must stop history playback")
	main._new_experiment()
	assert(main.playback_history.is_empty(), "Changing experiments must clear stale computed history")
	assert(main.graph_view.series_by_quantity.is_empty(), "Changing experiments must clear stale computed graph series")
	main.queue_free()
	graph.queue_free()
	runner.queue_free()
	print("A2 → A4 real CLI → A5 Godot graph and history E2E passed (synthetic model only)")
	quit(0)
