extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_property_record()
	_test_species_ref()
	_test_experiment_component()
	_test_substance_record()

	if _failures.is_empty():
		print("PASS: domain record validation tests")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)

func _test_property_record() -> void:
	var record := PropertyRecord.new()
	record.property_id = "molar_mass"
	record.value = 18.015
	record.unit = "g/mol"
	record.source_reference = "https://example.invalid/source"
	record.license_identifier = "CC-BY-4.0"
	record.quality_status = "verified"
	_expect(record.is_valid(), "complete property record should be structurally valid")
	_expect(record.is_usable(), "verified sourced property should be usable")

	record.license_identifier = ""
	_expect(record.is_valid(), "missing license does not corrupt record structure")
	_expect(not record.is_usable(), "property without license must not be usable")

	record.license_identifier = "CC-BY-4.0"
	record.uncertainty = -0.1
	_expect(not record.is_valid(), "negative uncertainty must be rejected")
	_expect(not record.is_usable(), "invalid property must not be usable")

	record.uncertainty = null
	record.valid_temperature_range_k = [300.0]
	_expect(not record.is_valid(), "single-bound validity range must be rejected")

	record.valid_temperature_range_k = [400.0, 300.0]
	_expect(not record.is_valid(), "reversed validity range must be rejected")

	record.valid_temperature_range_k = []
	record.quality_status = "unknown"
	_expect(record.is_valid(), "unknown quality is a valid record state")
	_expect(not record.is_usable(), "unknown quality must not be used in calculations")

	record.quality_status = "verified"
	record.value = "18.015"
	_expect(record.is_valid(), "descriptive string values may be structurally retained")
	_expect(not record.is_usable(), "string-valued properties must not enter quantitative calculations")
	record.value = true
	_expect(record.is_valid(), "boolean metadata may be structurally retained")
	_expect(not record.is_usable(), "boolean-valued properties must not enter quantitative calculations")
	record.value = 18.015
	_expect(record.is_usable(), "finite numeric property with provenance should remain usable")

func _test_species_ref() -> void:
	var species := SpeciesRef.new()
	species.species_id = "water_aq"
	species.substance_id = "water"
	species.phase = "aq"
	_expect(species.is_valid(), "aqueous species reference should be valid")
	species.phase = "gas"
	_expect(not species.is_valid(), "unsupported phase must be rejected")

func _test_experiment_component() -> void:
	var species := SpeciesRef.new()
	species.species_id = "water_aq"
	species.substance_id = "water"
	species.phase = "aq"

	var component := ExperimentComponent.new()
	component.species = species
	component.amount_value = 1.0
	component.amount_unit = "mol"
	_expect(component.is_valid(), "minimal component with valid species should be valid")

	component.amount_value = -1.0
	_expect(not component.is_valid(), "negative amount must be rejected")
	component.amount_value = 1.0

	component.initial_temperature_k = 0.0
	_expect(not component.is_valid(), "zero kelvin must be rejected by positive-temperature constraint")
	component.initial_temperature_k = 298.15

	component.initial_pressure_pa = -1.0
	_expect(not component.is_valid(), "negative pressure must be rejected")
	component.initial_pressure_pa = 101325.0

	component.container_volume_l = 0.0
	_expect(not component.is_valid(), "zero container volume must be rejected")
	component.container_volume_l = 1.0

	component.initial_concentration_value = 0.0
	_expect(component.is_valid(), "zero initial concentration is valid")
	component.concentration_unit = "g/L"
	_expect(not component.is_valid(), "unsupported concentration unit must be rejected")

func _test_substance_record() -> void:
	var substance := SubstanceRecord.new()
	substance.substance_id = "water"
	substance.formula = "H2O"
	_expect(substance.can_be_used_for([]), "identity-complete substance can satisfy an empty property requirement")
	_expect(not substance.can_be_used_for(["molar_mass"]), "missing required property must block use")

	var property := PropertyRecord.new()
	property.property_id = "molar_mass"
	property.value = 18.015
	property.unit = "g/mol"
	property.source_reference = "https://example.invalid/source"
	property.license_identifier = "CC-BY-4.0"
	property.quality_status = "verified"
	substance.properties["molar_mass"] = property
	_expect(substance.can_be_used_for(["molar_mass"]), "verified required property should permit use")
	property.quality_status = "provisional"
	_expect(not substance.can_be_used_for(["molar_mass"]), "provisional property must block calculation")

	property.quality_status = "verified"
	property.property_id = "density"
	_expect(not substance.can_be_used_for(["molar_mass"]), "property key and record identity must match")

	property.property_id = "molar_mass"
	substance.properties.clear()
	substance.molar_mass = property
	_expect(substance.can_be_used_for(["molar_mass"]), "molar mass convenience field must participate in verified-property lookup")
	property.property_id = "density"
	_expect(not substance.can_be_used_for(["molar_mass"]), "molar mass field with mismatched identity must be rejected")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
