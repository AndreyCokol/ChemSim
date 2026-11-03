class_name A1PropertyGate
extends RefCounted

## A1-only structural preflight for an explicitly scoped, numeric reference property.
## This is NOT a shared wire DTO, scientific source certification, or license approval.
## Do not infer missing metadata, substitute default temperatures, or convert units.

const REQUIRED_CONTEXT_FIELDS: Array[String] = [
	"property_kind", "unit_id", "basis", "standard_state",
	"phase_context", "medium", "model_id", "model_version"
]

static func validate_numeric_contract(record: Dictionary, required: Dictionary) -> Dictionary:
	var errors: Array[String] = []

	for key in REQUIRED_CONTEXT_FIELDS:
		if not _nonempty(required.get(key)):
			_flag(errors, "A1_REQUIREMENT_INCOMPLETE")

	if not _nonempty(record.get("property_id")) or not _positive_int(record.get("assertion_revision")):
		_flag(errors, "A1_IDENTITY_INCOMPLETE")

	if record.get("value_state") != "present":
		_flag(errors, "A1_VALUE_UNAVAILABLE")
	var value: Variant = record.get("value")
	if not _finite_number(value):
		_flag(errors, "A1_VALUE_NOT_FINITE_NUMBER")
	elif required.get("require_positive", false) == true and float(value) <= 0.0:
		_flag(errors, "A1_VALUE_NOT_POSITIVE")

	for key in ["property_kind", "unit_id", "basis", "standard_state", "phase_context", "medium"]:
		if not _nonempty(record.get(key)) or record.get(key) != required.get(key):
			_flag(errors, "A1_CONTEXT_MISMATCH")

	# The first implementation slice accepts only an EXACT fixed-T assertion.
	# Any interpolation or temperature conversion needs a separate reviewed model.
	var requested_t: Variant = required.get("temperature_k")
	var record_t: Variant = record.get("temperature_k")
	if not _finite_number(requested_t) or float(requested_t) <= 0.0:
		_flag(errors, "A1_REQUIREMENT_INCOMPLETE")
	if not _finite_number(record_t) or float(record_t) <= 0.0:
		_flag(errors, "A1_TEMPERATURE_MISSING")
	elif _finite_number(requested_t) and float(record_t) != float(requested_t):
		_flag(errors, "A1_TEMPERATURE_MISMATCH")

	if record.get("uncertainty_status") == "reported":
		if not _finite_number(record.get("uncertainty")) or float(record["uncertainty"]) < 0.0:
			_flag(errors, "A1_UNCERTAINTY_INVALID")
	elif record.get("uncertainty_status") != "not_reported":
		_flag(errors, "A1_UNCERTAINTY_UNDECLARED")
	elif record.has("uncertainty") and record["uncertainty"] != null:
		_flag(errors, "A1_UNCERTAINTY_CONTRADICTION")

	# Explicit first-slice reference policy. Broader origins/qualities require an
	# owner-reviewed model policy and must never be silently admitted.
	if record.get("origin") != "curated_reference":
		_flag(errors, "A1_REFERENCE_ORIGIN_UNSUPPORTED")
	if record.get("quality") != "verified" or record.get("review") != "accepted":
		_flag(errors, "A1_EVIDENCE_NOT_ACCEPTED")

	var eligibility: Variant = record.get("model_eligibility")
	if not eligibility is Dictionary:
		_flag(errors, "A1_MODEL_ELIGIBILITY_MISSING")
	elif eligibility.get("model_id") != required.get("model_id") \
			or eligibility.get("model_version") != required.get("model_version") \
			or eligibility.get("status") != "accepted":
		_flag(errors, "A1_MODEL_ELIGIBILITY_MISMATCH")

	var source: Variant = record.get("source")
	if not source is Dictionary:
		_flag(errors, "A1_PROVENANCE_INCOMPLETE")
	else:
		for key in ["source_id", "source_version", "field_locator", "retrieved_at_utc"]:
			if not _nonempty(source.get(key)):
				_flag(errors, "A1_PROVENANCE_INCOMPLETE")

	# Deliberately do not check redistribution here: model contract and release
	# authorization are separate decisions, neither implies the other.
	return {"ok": errors.is_empty(), "errors": errors, "scope": "metadata_preflight_only"}


static func validate_distribution_declaration(record: Dictionary, requested_channel: String) -> Dictionary:
	var errors: Array[String] = []
	if requested_channel.strip_edges().is_empty():
		_flag(errors, "A1_RIGHTS_CHANNEL_MISSING")

	var source: Variant = record.get("source")
	var rights: Variant = record.get("redistribution")
	if not source is Dictionary or not _nonempty(source.get("field_locator")):
		_flag(errors, "A1_RIGHTS_SOURCE_FIELD_MISSING")
	if not rights is Dictionary:
		_flag(errors, "A1_RIGHTS_NOT_APPROVED")
	else:
		if rights.get("disposition") != "approved_for_redistribution":
			_flag(errors, "A1_RIGHTS_NOT_APPROVED")
		if not _nonempty(rights.get("channel")) or rights.get("channel") != requested_channel:
			_flag(errors, "A1_RIGHTS_CHANNEL_MISMATCH")
		if not source is Dictionary or rights.get("field_locator") != source.get("field_locator"):
			_flag(errors, "A1_RIGHTS_FIELD_MISMATCH")
		for key in ["evidence_ref", "reviewed_by", "reviewed_at_utc"]:
			if not _nonempty(rights.get(key)):
				_flag(errors, "A1_RIGHTS_EVIDENCE_INCOMPLETE")

	# Structural declaration verification only: a claimed approval MUST be
	# checked against real source rights by the release reviewer.
	return {"ok": errors.is_empty(), "errors": errors, "scope": "rights_declaration_preflight_only"}


static func _nonempty(value: Variant) -> bool:
	return value is String and not (value as String).strip_edges().is_empty()


static func _finite_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))


static func _positive_int(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and value > 0


static func _flag(errors: Array[String], code: String) -> void:
	if not errors.has(code):
		errors.append(code)
