class_name SubstanceRecord
extends RefCounted

## Catalog identity is independent of phase; phase belongs to SpeciesRef.
const FormulaParserScript = preload("res://scripts/domain/formula_parser.gd")
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

func get_property_record(property_id: String) -> PropertyRecord:
	# Molar mass is a convenience field but follows the same provenance contract.
	if property_id == "molar_mass" and molar_mass != null:
		if molar_mass.property_id == property_id:
			return molar_mass
		return null
	if not properties.has(property_id):
		return null
	var record = properties[property_id]
	if not record is PropertyRecord or record.property_id != property_id:
		return null
	return record

func has_verified_property(property_id: String) -> bool:
	var record := get_property_record(property_id)
	return record != null and record.is_usable()

func can_be_used_for(property_ids: Array[String]) -> bool:
	if not _has_valid_identity():
		return false
	for property_id in property_ids:
		if not has_verified_property(property_id):
			return false
	return true

func _has_valid_identity() -> bool:
	if substance_id.strip_edges().is_empty() or formula.strip_edges().is_empty():
		return false
	var parsed = FormulaParserScript.new().parse(formula)
	if not parsed.ok:
		return false
	# Stored composition and charge are denormalized identity data. Never let
	# a stale or hand-edited record contradict its canonical formula string.
	return parsed.element_counts == element_counts and parsed.net_charge == net_charge

func to_dictionary() -> Dictionary:
	var serialized_properties: Dictionary = {}
	for key in properties:
		var record = properties[key]
		if record is PropertyRecord and record.property_id == str(key):
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
