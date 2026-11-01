class_name ExperimentComponent
extends RefCounted

var species: SpeciesRef
var amount_value: float = 0.0
var amount_unit: String = "mol"
var initial_concentration_value: Variant = null
var concentration_unit: String = "mol/L"
var initial_temperature_k: Variant = null
var initial_pressure_pa: Variant = null
var container_volume_l: Variant = null
var metadata: Dictionary = {}

func is_valid() -> bool:
	if species == null or not species.is_valid():
		return false
	if amount_value < 0.0 or not is_finite(amount_value):
		return false
	if amount_unit not in ["mol", "mmol", "umol"]:
		return false
	if initial_concentration_value != null and (not is_finite(float(initial_concentration_value)) or float(initial_concentration_value) < 0.0):
		return false
	return true
