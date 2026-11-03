class_name A2PhaseAdapter
extends RefCounted

## Converts A2 parser phase tokens into the A1 SpeciesRef vocabulary.
## An unspecified or unknown phase is deliberately not guessed; callers must
## obtain an explicit phase before constructing a calculation-ready SpeciesRef.
static func to_species_ref_phase(parser_phase: String) -> String:
	match parser_phase:
		"AQUEOUS":
			return "aq"
		"SOLID":
			return "s"
		"LIQUID":
			return "l"
		"GAS":
			return "g"
		_:
			return ""
