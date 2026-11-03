extends SceneTree

# A4-owned cross-branch acceptance script. CI copies this file into a detached,
# pinned checkout of A5; it never modifies or commits A5-owned sources.
const GraphViewScript = preload("res://scripts/graph_series_view.gd")

func _initialize() -> void:
    var ok := _run()
    if ok:
        print("A4-produced JSON -> unchanged A5 GraphSeries consumer acceptance passed")
        quit(0)
    else:
        quit(1)

func _run() -> bool:
    var full = _load("res://tests/a4-graph-fixtures/complete.json")
    var partial = _load("res://tests/a4-graph-fixtures/partial.json")
    if not _expect(full is Dictionary and partial is Dictionary,
        "Expected complete and partial JSON objects from the real A4 numerical producer"):
        return false
    if not _expect(full.get("test_only") == true and partial.get("test_only") == true,
        "Cross-consumer fixture must be marked test_only"):
        return false
    if not _expect(full.get("data_quality") == "hypothetical" and
        partial.get("data_quality") == "hypothetical",
        "The A4 synthetic kinetics may not be relabelled verified"):
        return false
    if not _expect(full.get("outcome") == "completed" and
        partial.get("outcome") == "step_limit" and
        partial.get("completeness") == "partial",
        "The partial numerical cause and completeness must remain independent"):
        return false
    if not _expect(full.get("series") is Array and full.series.size() == 2 and
        partial.get("series") is Array and partial.series.size() == 2,
        "Expected exactly two concentration species per result"):
        return false

    for series in full.series:
        var result = GraphViewScript.validate_series(series, str(full.contract_version))
        if not _expect(bool(result.get("ok", false)),
            "A5 rejected actual JSON from A4 full run: " + str(result.get("error", "unknown")) +
            " (JSON record_revision type=" + str(typeof(series.result_ref.record_revision)) + ")"):
            return false
        if not _expect(int(result.valid_points) == 3 and int(result.gaps) == 0,
            "A full trajectory must contain three valid points without fake gaps"):
            return false

    for series in partial.series:
        var result = GraphViewScript.validate_series(series, str(partial.contract_version))
        if not _expect(bool(result.get("ok", false)),
            "A5 rejected actual JSON from A4 step_limit: " + str(result.get("error", "unknown"))):
            return false
        if not _expect(int(result.gaps) == 1 and
            int(result.valid_points) == series.samples.size() - 1,
            "A partial trajectory must preserve a separate missing endpoint"):
            return false
        var last: Dictionary = series.samples[-1]
        if not _expect(last.value_status == "missing" and not last.has("value"),
            "Missing endpoint must never contain fabricated zero/null numerical data"):
            return false

    var view = GraphViewScript.new()
    root.add_child(view)
    var no2_series: Dictionary = {}
    for series in full.series:
        if str(series.species_ref.id) == "hypothetical:NO2:g":
            no2_series = series
    if not _expect(not no2_series.is_empty(),
        "The A4 actual-kinetic NO2 species series must be present"):
        view.queue_free()
        return false
    if not _expect(float(no2_series.samples[0].value) == 0.0 and
        no2_series.samples[0].value_status == "valid",
        "Actual simulated zero at t=0 must not be changed to missing"):
        view.queue_free()
        return false
    var admit = view.submit_series(no2_series, str(full.contract_version))
    if not _expect(bool(admit.get("ok", false)),
        "A5 GraphView failed to submit A4 NO2 values to its presentation model"):
        view.queue_free()
        return false
    if not _expect(int(admit.valid_points) == 3 and int(admit.gaps) == 0,
        "A5 presentation must retain all three NO2 points"):
        view.queue_free()
        return false

    var prefix = view.submit_series(partial.series[0], str(partial.contract_version))
    if not _expect(bool(prefix.get("ok", false)) and int(prefix.gaps) == 1,
        "A5 presentation must show the partial-run missing endpoint as a gap"):
        view.queue_free()
        return false
    if not _expect(str(view.active_result_ref.id) == "a4-cross-consumer-step-limit" and
        int(view.active_result_ref.record_revision) == 1,
        "The next run must invalidate previous result identity"):
        view.queue_free()
        return false
    view.queue_free()
    return true

func _load(path: String) -> Variant:
    if not FileAccess.file_exists(path):
        push_error("A4 generated fixture not found: " + path)
        return null
    return JSON.parse_string(FileAccess.get_file_as_string(path))

func _expect(condition: bool, message: String) -> bool:
    if not condition:
        push_error("Cross-agent contract violation: " + message)
        return false
    return true
