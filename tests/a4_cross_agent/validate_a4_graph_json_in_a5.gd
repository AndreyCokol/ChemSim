extends SceneTree

# A4-owned cross-branch acceptance script. CI copies this file into a detached,
# pinned checkout of A5; it never modifies or commits A5-owned sources.
const GraphViewScript = preload("res://scripts/graph_series_view.gd")

func _initialize() -> void:
    var ok := _run()
    if ok:
        print("A4 Godot diagnostic PASSED after TEST-ONLY strict revision normalization; raw wire remains BLOCKED on pinned A5")
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

    # Demonstrate the *real* wire failure; do not hide it by changing A4's
    # schema-valid JSON integer into a string. Godot JSON.parse_string maps
    # number 1 to TYPE_FLOAT, while pinned A5 _is_ref requires TYPE_INT.
    var raw_first: Dictionary = full.series[0]
    if not _expect(typeof(raw_first.result_ref.record_revision) == TYPE_FLOAT,
        "Expected Godot 4.3 JSON parser numeric revision to be TYPE_FLOAT"):
        return false
    var raw_verdict: Dictionary = GraphViewScript.validate_series(
        raw_first, str(full.contract_version))
    if not _expect(not bool(raw_verdict.get("ok", false)),
        "Pinned A5 unexpectedly accepted JSON numeric revision; update test and remove shim"):
        return false
    print("KNOWN P1 A5 BLOCKER: raw JSON integer record_revision rejected by pinned A5 TYPE_INT gate")

    # TEST-ONLY workaround to isolate any *other* A4/A5 interoperability
    # issues. This must not become production transport or a DTO change.
    # A5/integrator own the actual JSON-aware revision normalization.
    var normalized_full: Array = []
    var normalized_partial: Array = []
    for raw_series in full.series:
        var series: Dictionary = _strict_test_only_reference_normalization(raw_series)
        if not _expect(not series.is_empty(),
            "Real A4 JSON reference does not pass strict test-only integer admission"):
            return false
        normalized_full.append(series)
        var result: Dictionary = GraphViewScript.validate_series(
            series, str(full.contract_version))
        if not _expect(bool(result.get("ok", false)),
            "A5 rejected normalized A4 full-run JSON: " + str(result.get("error", "unknown"))):
            return false
        if not _expect(int(result.valid_points) == 3 and int(result.gaps) == 0,
            "A full trajectory must have three valid points without fake gaps"):
            return false

    for raw_series in partial.series:
        var series: Dictionary = _strict_test_only_reference_normalization(raw_series)
        if not _expect(not series.is_empty(),
            "Partial A4 JSON reference failed strict test-only integer admission"):
            return false
        normalized_partial.append(series)
        var result: Dictionary = GraphViewScript.validate_series(
            series, str(partial.contract_version))
        if not _expect(bool(result.get("ok", false)),
            "A5 rejected normalized A4 step_limit: " + str(result.get("error", "unknown"))):
            return false
        if not _expect(int(result.gaps) == 1 and
            int(result.valid_points) == series.samples.size() - 1,
            "Partial trajectory must preserve a separate missing endpoint"):
            return false
        var last: Dictionary = series.samples[-1]
        if not _expect(last.value_status == "missing" and not last.has("value"),
            "Missing endpoint must never contain fabricated zero/null numerical data"):
            return false

    var fractional: Dictionary = raw_first.duplicate(true)
    fractional.result_ref.record_revision = 1.5
    if not _expect(_strict_test_only_reference_normalization(fractional).is_empty(),
        "Fractional revision must not be rounded in test-only normalization"):
        return false
    var zero_revision: Dictionary = raw_first.duplicate(true)
    zero_revision.result_ref.record_revision = 0.0
    if not _expect(_strict_test_only_reference_normalization(zero_revision).is_empty(),
        "Zero revision must not be coerced to a valid record revision"):
        return false

    var view = GraphViewScript.new()
    root.add_child(view)
    var no2_series: Dictionary = {}
    for series in normalized_full:
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

    var prefix = view.submit_series(normalized_partial[0], str(partial.contract_version))
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

func _strict_test_only_reference_normalization(series: Variant) -> Dictionary:
    if not (series is Dictionary):
        return {}
    var copy: Dictionary = series.duplicate(true)
    for field in ["result_ref", "species_ref"]:
        if not copy.has(field) or not (copy[field] is Dictionary):
            return {}
        var reference: Dictionary = copy[field]
        var revision: Variant = reference.get("record_revision")
        if typeof(revision) != TYPE_FLOAT and typeof(revision) != TYPE_INT:
            return {}
        var value := float(revision)
        if not is_finite(value) or value < 1.0 or value > 9007199254740991.0:
            return {}
        if floor(value) != value:
            return {}
        reference["record_revision"] = int(value)
    return copy

func _expect(condition: bool, message: String) -> bool:
    if not condition:
        push_error("Cross-agent contract violation: " + message)
        return false
    return true
