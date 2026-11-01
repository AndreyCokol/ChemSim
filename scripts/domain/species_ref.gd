class_name SpeciesRef
extends RefCounted

## A species is a catalog substance in a particular phase/context.
var species_id: String = ""
var substance_id: String = ""
var phase: String = ""
var context_id: String = ""

func is_valid() -> bool:
	return not species_id.is_empty() and not substance_id.is_empty() and phase in ["aq", "s", "l", "g"]
