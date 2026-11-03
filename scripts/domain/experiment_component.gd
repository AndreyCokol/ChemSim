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
	if not is_finite(amount_value) or amount_value < 0.0:
		return false
	if amount_unit not in ["mol", "mmol", "umol"]:
		return false
	if not _is_optional_finite_nonnegative(initial_concentration_value):
		return false
	if initial_concentration_value != null and concentration_unit != "mol/L":
		return false
	if not _is_optional_finite_positive(initial_temperature_k):
		return false
	if not _is_optional_finite_nonnegative(initial_pressure_pa):
		return false
	if not _is_optional_finite_positive(container_volume_l):
		return false
	return true

func _is_optional_finite_nonnegative(value: Variant) -> bool:
	if value == null:
		return true
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	return is_finite(float(value)) and float(value) >= 0.0

func _is_optional_finite_positive(value: Variant) -> bool:
	if value == null:
		return true
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	return is_finite(float(value)) and float(value) > 0.0
