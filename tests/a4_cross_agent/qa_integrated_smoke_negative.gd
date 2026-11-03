extends SceneTree

# Independent A4 QA only: copied into a pinned, temporary PR #17 checkout.
# This test uses a real Godot-generated request and a real A4 CLI response,
# then deliberately corrupts response fields to check A5's admission gate.
# It never edits the integration/A5/A2 branches or claims physical kinetics.
const Contract = preload("res://scripts/a5_smoke_contract.gd")
const CHECKOUT_SHA := "96008906b0d0063b146a9882831e42ac2a863b1f"
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var prepared: Dictionary = Contract.build_demo_request()
    if not _expect(bool(prepared.get("ok", false)), "The original A2 parse and synthetic request must succeed"):
        quit(1)
        return
    var request: Dictionary = prepared.request
    var directory := ProjectSettings.globalize_path("user://")
    var base := "a4-qa-" + str(Time.get_ticks_usec()) + "-" + str(randi())
    var request_path := directory.path_join(base + "-request.json")
    var response_path := directory.path_join(base + "-response.json")
    var file := FileAccess.open(request_path, FileAccess.WRITE)
    if not _expect(file != null, "Cannot create QA request in Godot user data directory"):
        quit(1)
        return
    file.store_string(JSON.stringify(request))
    file.close()
    var executable := ProjectSettings.globalize_path("res://bin/chemsim-solver")
    var command_log: Array = []
    var exit_code := OS.execute(executable,
        PackedStringArray(["--request", request_path, "--response", response_path]),
        command_log, true)
    if not _expect(exit_code == 0, "Actual .NET CLI invocation failed: " + str(command_log)):
        _cleanup(request_path, response_path)
        quit(1)
        return
    if not _expect(FileAccess.file_exists(response_path), "A4 did not create a JSON result"):
        _cleanup(request_path, response_path)
        quit(1)
        return
    var result: Variant = JSON.parse_string(FileAccess.get_file_as_string(response_path))
    _cleanup(request_path, response_path)
    if not _expect(result is Dictionary, "Actual A4 output is not a JSON object"):
        quit(1)
        return
    var baseline: Dictionary = Contract.validate_response(result, request)
    if not _expect(bool(baseline.get("ok", false)) and bool(baseline.get("completed", false)),
        "Untampered A2-A4-A5 synthetic request/response must pass: " + str(baseline.get("error", ""))):
        quit(1)
        return
    if not _expect(baseline.history.size() == 21,
        "A4 must provide exactly 21 real numerical samples"):
        quit(1)
        return
    print("BASELINE_OK: real Godot A2 request + A4 CLI response + A5 admission; " +
        "integration checkout " + CHECKOUT_SHA)

    var corruption: Dictionary
    corruption = result.duplicate(true)
    corruption["request_message_id"] = "1ecc7e14-a7ab-465e-b2cb-734b0294084a"
    _must_reject("request correlation", corruption, request)

    corruption = result.duplicate(true)
    corruption.payload.reliability.data_quality = "verified"
    _must_reject("fabricated scientific provenance", corruption, request)

    corruption = result.duplicate(true)
    corruption.payload.samples[5].time_s = corruption.payload.samples[4].time_s
    _must_reject("duplicate numerical time", corruption, request)

    corruption = result.duplicate(true)
    corruption.payload.samples[6].amounts_mol["demo:NO2:g"] = -0.5
    _must_reject("negative/nonphysical amount", corruption, request)

    corruption = result.duplicate(true)
    corruption.payload.samples[6].amounts_mol["demo:NO2:g"] = 10.0
    _must_reject("violated atomic conservation law", corruption, request)

    corruption = result.duplicate(true)
    corruption.payload.samples.pop_back()
    _must_reject("completed without target time", corruption, request)

    corruption = result.duplicate(true)
    corruption.payload.last_valid_time_s = 0.0
    _must_reject("lying last_valid_time_s metadata", corruption, request)

    corruption = result.duplicate(true)
    corruption.payload.reliability.numerical_status = "failed"
    _must_reject("completed with failed numerical status", corruption, request)

    corruption = result.duplicate(true)
    corruption.payload.reliability.completeness = "partial"
    _must_reject("completed falsely declared partial", corruption, request)

    corruption = result.duplicate(true)
    corruption.errors = [{
        "code": "KINETICS_DIAGNOSTIC_ERROR",
        "severity": "error",
        "message_key": "kinetics.error",
        "responsible_module": "A4",
        "recoverable": false,
        "context": {"reason": "Synthetic corruption probe"}
    }]
    _must_reject("completed with an error envelope", corruption, request)

    corruption = result.duplicate(true)
    corruption.outcome = "step_limit"
    corruption.payload.termination = "step_limit"
    corruption.payload.reliability.numerical_status = "failed"
    corruption.payload.reliability.completeness = "partial"
    corruption.payload.samples.pop_back()
    corruption.payload.last_valid_time_s = corruption.payload.samples[-1].time_s
    var accepted_prefix: Dictionary = Contract.validate_response(corruption, request)
    if not _expect(bool(accepted_prefix.get("ok", false)) and
        not bool(accepted_prefix.get("completed", true)),
        "Genuine bounded numerical step-limit prefix must remain incomplete"):
        failures.append("valid step-limit prefix was not accepted as incomplete")

    if failures.is_empty():
        print("QA_NEGATIVE_OK: all 10 corrupted A4 JSON cases rejected; " +
            "non-success bounded prefix accepted as incomplete")
        quit(0)
    else:
        for defect in failures:
            push_error("A4_QA_P1: " + defect)
        print("QA_NEGATIVE_FAILED: " + str(failures.size()) + " admitted or mishandled cases")
        quit(1)

func _must_reject(name: String, corrupted: Dictionary, request: Dictionary) -> void:
    var verdict: Dictionary = Contract.validate_response(corrupted, request)
    if bool(verdict.get("ok", false)):
        failures.append("A5 admitted " + name + " from real A4 result")

func _expect(condition: bool, message: String) -> bool:
    if not condition:
        push_error("A4_QA_BLOCKER: " + message)
    return condition

func _cleanup(request_path: String, response_path: String) -> void:
    if FileAccess.file_exists(request_path):
        DirAccess.remove_absolute(request_path)
    if FileAccess.file_exists(response_path):
        DirAccess.remove_absolute(response_path)
