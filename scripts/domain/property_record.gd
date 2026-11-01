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

func is_usable() -> bool:
	return not property_id.is_empty() and value != null and not unit.is_empty() and not source_reference.is_empty() and not license_identifier.is_empty() and quality_status == "verified"

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
