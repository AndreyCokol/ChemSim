class_name SubstanceRecord
extends RefCounted

## Catalog identity is independent of phase; phase belongs to SpeciesRef.
var substance_id: String = ""
var display_name: String = ""
var formula: String = ""
var element_counts: Dictionary = {}
var net_charge: int = 0
var molar_mass: PropertyRecord
var properties: Dictionary = {}
var hazard_status: String = "unknown"
var hazard_sources: Array[String] = []
var record_version: String = "1"
var completeness: String = "incomplete"

func has_verified_property(property_id: String) -> bool:
	if not properties.has(property_id):
		return false
	var record = properties[property_id]
	return record is PropertyRecord and record.is_usable()

func can_be_used_for(property_ids: Array[String]) -> bool:
	if substance_id.is_empty() or formula.is_empty():
		return false
	for property_id in property_ids:
		if not has_verified_property(property_id):
			return false
	return true

func to_dictionary() -> Dictionary:
	var serialized_properties: Dictionary = {}
	for key in properties:
		var record = properties[key]
		if record is PropertyRecord:
			serialized_properties[key] = record.to_dictionary()
	return {
		"substance_id": substance_id,
		"display_name": display_name,
		"formula": formula,
		"element_counts": element_counts.duplicate(true),
		"net_charge": net_charge,
		"molar_mass": molar_mass.to_dictionary() if molar_mass != null else null,
		"properties": serialized_properties,
		"hazard_status": hazard_status,
		"hazard_sources": hazard_sources.duplicate(),
		"record_version": record_version,
		"completeness": completeness
	}
