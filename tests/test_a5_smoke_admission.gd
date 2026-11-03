extends SceneTree

# QA fixtures are synthetic and explicitly NOT physical NO2 kinetics.
const Contract = preload("res://scripts/a5_smoke_contract.gd")

func _initialize() -> void:
	call_deferred("_run")

func _build_response(request: Dictionary) -> Dictionary:
	var samples: Array = []
	for i in range(21):
		var t := float(i) * 0.25
		var amount_a := exp(-0.1 * t)
		samples.append({
			"time_s": t,
			"amounts_mol": {
				Contract.A_ID: amount_a,
				Contract.B_ID: 2.0 * (1.0 - amount_a)
			}
		})
	return {
		"contract_version": "0.1",
		"message_id": "qa-valid-result-1",
		"request_message_id": str(request.message_id),
		"kind": "simulation_result",
		"outcome": "completed",
		"errors": [],
		"payload": {
			"termination": "completed",
			"reliability": {
				"data_quality": "hypothetical",
				"model_applicability": "not_assessed",
				"numerical_status": "completed",
				"completeness": "complete_for_declared_scope",
				"warnings": []
			},
			"species_ids": [Contract.A_ID, Contract.B_ID],
			"temperature_k": Contract.DEMO_T_K,
			"requested_end_s": Contract.DEMO_END_S,
			"last_valid_time_status": "present",
			"last_valid_time_s": Contract.DEMO_END_S,
			"samples": samples
		}
	}

func _reject(response: Dictionary, request: Dictionary, label: String) -> void:
	var parsed: Dictionary = Contract.validate_response(response, request)
	assert(not bool(parsed.get("ok", false)), label)

func _run() -> void:
	var built: Dictionary = Contract.build_demo_request()
	assert(bool(built.get("ok", false)), "A2 must admit exactly the declared synthetic reaction.")
	var request: Dictionary = built.request
	var good: Dictionary = _build_response(request)
	var admitted: Dictionary = Contract.validate_response(good, request)
	assert(bool(admitted.get("ok", false)), "Complete valid synthetic numerical output must be admitted.")
	assert(int(admitted.history.size()) == 21, "Exactly 21 actual sample states must reach the timeline.")
	assert(int(admitted.concentration_series.samples.size()) == 21, "The graph must retain all validated points.")
	assert(str(admitted.reliability.data_quality) == "hypothetical", "The UI must retain the uncertain data-quality label.")

	var bad: Dictionary = good.duplicate(true)
	bad["request_message_id"] = "different-request"
	_reject(bad, request, "A4 result for another request must be rejected.")

	bad = good.duplicate(true)
	bad["contract_version"] = "99.0"
	_reject(bad, request, "An unsupported protocol version must fail closed.")

	bad = good.duplicate(true)
	bad.payload["species_ids"] = [Contract.A_ID, "unknown-species"]
	_reject(bad, request, "An unknown species identity must be rejected.")

	bad = good.duplicate(true)
	bad.payload.samples[7].time_s = 1.51
	_reject(bad, request, "Completed output must not skip its declared sample grid.")

	bad = good.duplicate(true)
	bad.payload.samples.remove_at(7)
	_reject(bad, request, "Completed output must not silently omit one timestep.")

	bad = good.duplicate(true)
	bad.payload.samples[0].amounts_mol[Contract.A_ID] = 0.5
	bad.payload.samples[0].amounts_mol[Contract.B_ID] = 1.0
	_reject(bad, request, "Atom-conserving but wrong initial amounts must be rejected.")

	bad = good.duplicate(true)
	bad.payload.samples[7].amounts_mol[Contract.A_ID] = -0.1
	bad.payload.samples[7].amounts_mol[Contract.B_ID] = 2.2
	_reject(bad, request, "Negative physical amounts must be rejected.")

	bad = good.duplicate(true)
	bad.payload.samples[3].time_s = bad.payload.samples[2].time_s
	_reject(bad, request, "Repeated sample times must be rejected.")

	bad = good.duplicate(true)
	bad.payload.samples[4].amounts_mol[Contract.A_ID] = INF
	_reject(bad, request, "Nonfinite numerical amounts must be rejected.")

	bad = good.duplicate(true)
	bad.payload["last_valid_time_s"] = 4.75
	_reject(bad, request, "Incorrect last valid time must be rejected.")

	bad = good.duplicate(true)
	bad.payload.reliability["data_quality"] = "verified"
	_reject(bad, request, "A hypothetical test result must not be upgraded to verified.")

	bad = good.duplicate(true)
	bad.payload.reliability["model_applicability"] = "applicable"
	_reject(bad, request, "Unverified model applicability must not be asserted as scientifically established.")

	bad = good.duplicate(true)
	bad.payload.reliability["numerical_status"] = "failed"
	_reject(bad, request, "A numerical failure must not report successful completion.")

	bad = good.duplicate(true)
	bad["errors"] = [{"code": "KINETICS_FAILED"}]
	_reject(bad, request, "A completed computation must not conceal producer errors.")

	bad = good.duplicate(true)
	bad["outcome"] = "blocked"
	bad.payload["termination"] = "blocked"
	_reject(bad, request, "A blocked request must never present a finished trajectory.")

	# A partial valid prefix may be displayed, but it must remain explicitly
	# incomplete and never be extrapolated to the requested final time.
	var prefix := good.duplicate(true)
	prefix["outcome"] = "step_limit"
	prefix.payload["termination"] = "step_limit"
	prefix.payload["samples"] = prefix.payload.samples.slice(0, 5)
	prefix.payload["last_valid_time_s"] = 1.0
	prefix.payload.reliability["numerical_status"] = "failed"
	prefix.payload.reliability["completeness"] = "partial"
	var partial: Dictionary = Contract.validate_response(prefix, request)
	assert(bool(partial.get("ok", false)) and not bool(partial.get("completed", true)), "A valid numeric prefix must be shown only as partial.")
	assert(partial.history.size() == 5, "A partial result must stop at its true last valid sample.")
	print("A5 smoke admission and negative-result QA tests passed")
	quit(0)
