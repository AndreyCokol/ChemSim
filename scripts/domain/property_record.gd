class_name PropertyRecord
extends RefCounted

## A measured or sourced property. Unknown values remain absent; never substitute defaults.
var property_id: String = ""
var value: Variant = null
var unit: String = ""
var uncertainty: Variant = null
var source_name: String = ""
var source_reference: String = ""
var source_version: String = ""
var retrieved_at_utc: String = ""
var license_identifier: String = ""
var conditions: Dictionary = {}
var valid_temperature_range_k: Array[float] = []
var valid_pressure_range_pa: Array[float] = []
var quality_status: String = "unknown"
var notes: String = ""

func is_valid() -> bool:
	if property_id.is_empty() or unit.is_empty():
		return false
	if quality_status not in ["unknown", "provisional", "verified", "rejected"]:
		return false
	if value != null and typeof(value) not in [TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_BOOL]:
		return false
	if typeof(value) in [TYPE_INT, TYPE_FLOAT] and not is_finite(float(value)):
		return false
	if uncertainty != null and (typeof(uncertainty) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(uncertainty)) or float(uncertainty) < 0.0):
		return false
	if not _valid_range(valid_temperature_range_k) or not _valid_range(valid_pressure_range_pa):
		return false
	return true

func is_usable() -> bool:
	# Only finite numeric values can enter quantitative calculations. Text and
	# booleans may be retained as descriptive metadata, but must never pass the
	# calculation-readiness gate merely because provenance fields are present.
	return (
		is_valid()
		and typeof(value) in [TYPE_INT, TYPE_FLOAT]
		and not source_reference.is_empty()
		and not license_identifier.is_empty()
		and quality_status == "verified"
	)

func _valid_range(bounds: Array[float]) -> bool:
	if bounds.is_empty():
		return true
	if bounds.size() != 2:
		return false
	return is_finite(bounds[0]) and is_finite(bounds[1]) and bounds[0] >= 0.0 and bounds[1] >= bounds[0]

func to_dictionary() -> Dictionary:
	return {
		"property_id": property_id,
		"value": value,
		"unit": unit,
		"uncertainty": uncertainty,
		"source_name": source_name,
		"source_reference": source_reference,
		"source_version": source_version,
		"retrieved_at_utc": retrieved_at_utc,
		"license_identifier": license_identifier,
		"conditions": conditions.duplicate(true),
		"valid_temperature_range_k": valid_temperature_range_k.duplicate(),
		"valid_pressure_range_pa": valid_pressure_range_pa.duplicate(),
		"quality_status": quality_status,
		"notes": notes
	}
