class_name A1IdentityGate
extends RefCounted

## A1-only preflight of references selected by a caller, against a trusted
## A2 parse result. The integrator must invoke A2 and bind immutable refs.
## Never mint catalog IDs from formula text or independently parse chemistry.
## A passing result is NOT scientific provenance or chemical validation.

const PHASE_IDS: Array[String] = ["s", "l", "g", "aq", "unspecified"]
const A2_PHASE_MAP: Dictionary = {
	"SOLID": "s",
	"LIQUID": "l",
	"GAS": "g",
	"AQUEOUS": "aq",
	"UNSPECIFIED": "unspecified"
}
const ORIGINS: Array[String] = [
	"curated_reference", "experimental", "calculated", "estimated",
	"user_defined", "hypothetical", "unknown"
]

static func validate_binding(
		substance: Dictionary,
		species: Dictionary,
		a2_parse_result: Dictionary,
		selection: Dictionary,
		model: Dictionary
	) -> Dictionary:
	var errors: Array[String] = []

	# The three durable IDs and revisions are allocated by the catalog /
	# integrator, not by FormulaAST text or A2 source-span identifiers.
	var selected_substance: Variant = selection.get("substance_ref")
	var selected_species: Variant = selection.get("species_ref")
	var selected_ast: Variant = selection.get("formula_ast_ref")
	if not _valid_ref(selected_substance) or not _valid_ref(selected_species) or not _valid_ref(selected_ast):
		_flag(errors, "A1_SELECTION_UNRESOLVED")

	if not _nonempty(substance.get("substance_id")) or not _positive_int(substance.get("record_revision")):
		_flag(errors, "A1_SUBSTANCE_ID_INVALID")
	elif _valid_ref(selected_substance) and (
			substance["substance_id"] != selected_substance["id"]
			or substance["record_revision"] != selected_substance["record_revision"]
		):
		_flag(errors, "A1_SUBSTANCE_REVISION_MISMATCH")

	if not _nonempty(species.get("species_id")) or not _positive_int(species.get("record_revision")):
		_flag(errors, "A1_SPECIES_ID_INVALID")
	elif _valid_ref(selected_species) and (
			species["species_id"] != selected_species["id"]
			or species["record_revision"] != selected_species["record_revision"]
		):
		_flag(errors, "A1_SPECIES_REVISION_MISMATCH")

	var substance_ast: Variant = substance.get("formula_ast_ref")
	var species_ast: Variant = species.get("formula_ast_ref")
	if not _valid_ref(substance_ast) or not _valid_ref(species_ast):
		_flag(errors, "A1_FORMULA_AST_REF_MISSING")
	elif _valid_ref(selected_ast) and (
			not _same_ref(substance_ast, selected_ast)
			or not _same_ref(species_ast, selected_ast)
		):
		_flag(errors, "A1_FORMULA_AST_REVISION_MISMATCH")

	# No duplicated source of truth for A2 composition/net_charge in A1.
	# Phase is a species occurrence, not SubstanceRecord identity.
	for forbidden_key in ["formal_charge", "net_charge", "element_counts", "phase"]:
		if substance.has(forbidden_key):
			_flag(errors, "A1_SUBSTANCE_DUPLICATE_CHEMISTRY_TRUTH")

	if not ORIGINS.has(substance.get("origin")):
		_flag(errors, "A1_ORIGIN_UNDECLARED")

	var selected_phase: Variant = species.get("phase")
	if not PHASE_IDS.has(selected_phase):
		_flag(errors, "A1_SPECIES_PHASE_INVALID")

	# A2 parser currently returns schema_version=1, and its AST has
	# integer element counts, signed integer charge, and source text.
	# This is only shape verification: the trusted A2 execution and
	# immutable-ref binding must be provided by the integrator.
	var ast: Variant = a2_parse_result.get("formula_ast")
	if typeof(a2_parse_result.get("ok")) != TYPE_BOOL or a2_parse_result.get("ok") != true:
		_flag(errors, "A1_A2_PARSE_NOT_VALIDATED")
	if not ast is Dictionary:
		_flag(errors, "A1_A2_AST_INVALID")
	else:
		if typeof(ast.get("schema_version")) != TYPE_INT or ast.get("schema_version") != 1:
			_flag(errors, "A1_A2_AST_SCHEMA_UNSUPPORTED")
		if typeof(ast.get("net_charge")) != TYPE_INT:
			_flag(errors, "A1_A2_CHARGE_INVALID")
		if not _complete_element_counts(ast.get("element_counts")):
			_flag(errors, "A1_A2_COMPOSITION_INCOMPLETE")
		if not _nonempty(ast.get("source_text")) or typeof(ast.get("nodes")) != TYPE_ARRAY or ast["nodes"].is_empty():
			_flag(errors, "A1_A2_AST_INVALID")

	var parsed_phase: Variant = a2_parse_result.get("phase")
	if not A2_PHASE_MAP.has(parsed_phase):
		_flag(errors, "A1_A2_PHASE_INVALID")
	elif PHASE_IDS.has(selected_phase):
		# Explicit A2 phase cannot be silently overridden at a SpeciesRef.
		# A2 UNSPECIFIED has no implicit aqueous/gas default; species phase
		# requires a separate, explicit integrator selection.
		if parsed_phase != "UNSPECIFIED" and selected_phase != A2_PHASE_MAP[parsed_phase]:
			_flag(errors, "A1_PHASE_BINDING_MISMATCH")

	# Explicit model requirement; "unspecified" means descriptive-only.
	# It must never confer suitability for an aqueous or gas model.
	var required_phase: Variant = model.get("required_phase")
	if not PHASE_IDS.has(required_phase):
		_flag(errors, "A1_MODEL_PHASE_REQUIREMENT_MISSING")
	elif required_phase != "unspecified" and selected_phase != required_phase:
		_flag(errors, "A1_MODEL_PHASE_MISMATCH")
	if required_phase != "unspecified" and parsed_phase == "UNSPECIFIED":
		if model.get("explicit_occurrence_phase_confirmed") != true:
			_flag(errors, "A1_EXPLICIT_PHASE_EVIDENCE_MISSING")

	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"scope": "a1_identity_reference_preflight_only",
		"origin": substance.get("origin", "unknown")
	}


static func _valid_ref(value: Variant) -> bool:
	return value is Dictionary and _nonempty(value.get("id")) and _positive_int(value.get("record_revision"))


static func _same_ref(a: Dictionary, b: Dictionary) -> bool:
	return a["id"] == b["id"] and a["record_revision"] == b["record_revision"]


static func _complete_element_counts(value: Variant) -> bool:
	if not value is Dictionary or value.is_empty():
		return false
	for element in value:
		if not _nonempty(element) or not _positive_int(value[element]):
			return false
	return true


static func _nonempty(value: Variant) -> bool:
	return value is String and not (value as String).strip_edges().is_empty()


static func _positive_int(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and value > 0


static func _flag(errors: Array[String], code: String) -> void:
	if not errors.has(code):
		errors.append(code)
