class_name A1SourceAdmissionGate
extends RefCounted

## This is the A1-owned, fail-closed boundary between a metadata claim and
## reference data admission. Caller-provided verified/accepted/rights statuses
## are NEVER trusted as proof. No scientific assertion has been admitted.
##
## Approval entries, when independently reviewed, must be committed through
## A1 source review and integrator/owner procedures, with exact record,
## model requirement, evidence and release-channel bindings. Not from user data.
## This is NOT an official shared wire DTO or a chemistry validity proof.

const PropertyGate = preload("res://src/chemistry/a1/a1_property_gate.gd")

const BENCHMARK_IDS: Array[String] = [
	"AQ-01", "AQ-02", "AQ-03", "AQ-04", "AQ-05", "GAS-01", "GAS-02"
]

# Separate allowlists intentionally contain NO entries (scientific 0/7).
# Shape of a future code-reviewed entry:
# benchmark_id -> {
#   "status": "admitted", "review_id": nonempty, "reviewer": nonempty,
#   "approved_record": exact complete assertion dictionary,
#   "model_requirement": exact complete requirement dictionary
# }
# The exact assertion includes source ID/version/field and numerical value,
# and the required model includes context, version and exact conditions.
const REVIEWED_MODEL_ASSERTIONS: Dictionary = {}

# Separate channel-specific legal/rights review must not be inferred from
# the model allowance or from a caller's redistribution declaration.
# Shape of future entry:
# benchmark_id -> {
#   "status": "approved_for_redistribution",
#   "review_id": nonempty, "reviewer": nonempty,
#   "channel": exact intended channel,
#   "approved_record": exact complete assertion dictionary,
#   "model_requirement": exact complete requirement dictionary
# }
const REVIEWED_RELEASE_ASSERTIONS: Dictionary = {}


static func assess_assertion(
		record: Dictionary,
		required: Dictionary,
		benchmark_id: String,
		requested_channel: String
	) -> Dictionary:
	var errors: Array[String] = []
	if not BENCHMARK_IDS.has(benchmark_id):
		_add(errors, "A1_ADMISSION_UNKNOWN_BENCHMARK")
	if requested_channel.strip_edges().is_empty():
		_add(errors, "A1_ADMISSION_CHANNEL_MISSING")

	# These two helpers are syntactic *claim* checks only. A forged source
	# record may pass both, but it still cannot pass either trusted allowlist.
	var structural: Dictionary = PropertyGate.validate_numeric_contract(record, required)
	var rights_declaration: Dictionary = PropertyGate.validate_distribution_declaration(
		record, requested_channel
	)
	if not structural["ok"]:
		_add(errors, "A1_ADMISSION_PROPERTY_METADATA_INVALID")
	if not rights_declaration["ok"]:
		_add(errors, "A1_ADMISSION_RIGHTS_DECLARATION_INVALID")

	var model_admitted: bool = false
	var release_approved: bool = false
	if BENCHMARK_IDS.has(benchmark_id) and structural["ok"]:
		model_admitted = _matches_model_review(
			REVIEWED_MODEL_ASSERTIONS.get(benchmark_id), record, required
		)
	if not model_admitted:
		_add(errors, "A1_ADMISSION_SOURCE_NOT_REVIEWED")

	# Model admission and distribution approval remain independent decisions;
	# the final export/use boundary additionally requires both.
	if BENCHMARK_IDS.has(benchmark_id) and rights_declaration["ok"]:
		release_approved = _matches_release_review(
			REVIEWED_RELEASE_ASSERTIONS.get(benchmark_id),
			record, required, requested_channel
		)
	if not release_approved:
		_add(errors, "A1_ADMISSION_RELEASE_NOT_REVIEWED")

	return {
		"ok": errors.is_empty() and model_admitted and release_approved,
		"errors": errors,
		"benchmark_id": benchmark_id,
		"metadata_preflight_ok": structural["ok"],
		"rights_declaration_preflight_ok": rights_declaration["ok"],
		"reference_admitted": model_admitted,
		"redistribution_approved": release_approved,
		"scientific_data_ready": model_admitted,
		"release_ready": model_admitted and release_approved,
		"scope": "a1_source_field_admission_boundary_only"
	}


static func _matches_model_review(entry: Variant, record: Dictionary, required: Dictionary) -> bool:
	if not entry is Dictionary:
		return false
	return entry.get("status") == "admitted" \
		and _nonempty(entry.get("review_id")) \
		and _nonempty(entry.get("reviewer")) \
		and entry.get("approved_record") == record \
		and entry.get("model_requirement") == required


static func _matches_release_review(
		entry: Variant, record: Dictionary, required: Dictionary, requested_channel: String
	) -> bool:
	if not entry is Dictionary:
		return false
	return entry.get("status") == "approved_for_redistribution" \
		and _nonempty(entry.get("review_id")) \
		and _nonempty(entry.get("reviewer")) \
		and entry.get("channel") == requested_channel \
		and entry.get("approved_record") == record \
		and entry.get("model_requirement") == required


static func _nonempty(value: Variant) -> bool:
	return value is String and not (value as String).strip_edges().is_empty()


static func _add(errors: Array[String], code: String) -> void:
	if not errors.has(code):
		errors.append(code)
