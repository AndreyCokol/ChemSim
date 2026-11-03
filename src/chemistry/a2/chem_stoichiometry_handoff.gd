extends RefCounted
class_name ChemStoichiometryHandoff

## A2-only chemical admission facts for an integrator's model adapter.
## Input is ORIGINAL reaction text, never an untrusted caller-supplied AST.
## Output is NOT a shared v0.1 DTO, a stable SpeciesRef or an A4 request.
## No reaction order, k, equilibrium K, phase assumption or provenance is made.

const Parser = preload("res://src/chemistry/a2/chem_equation_parser.gd")
const SourceSpan = preload("res://src/chemistry/a2/chem_source_span.gd")


static func extract_balanced_terms(source: String) -> Dictionary:
	var parser = Parser.new()
	var parsed: Dictionary = parser.parse_reaction(source)
	if not bool(parsed.get("ok", false)):
		# Preserve original Godot character offsets and provide the byte
		# boundaries that an integrator/A5 wire consumer will eventually
		# need. Never change the source or highlight an invented character.
		var parser_span: Dictionary = parsed.get("source_span", {})
		var encoded_error_span: Dictionary = SourceSpan.to_utf8_byte_span(source, parser_span)
		if not bool(encoded_error_span.get("ok", false)):
			return {"ok": false, "code": "A2_SOURCE_SPAN_CONVERSION_FAILED"}
		return {
			"ok": false,
			"code": "A2_REACTION_PARSE_FAILED",
			"parser_code": String(parsed.get("code", "PARSE_UNKNOWN")),
			"source_span": parser_span.duplicate(true),
			"source_span_utf8": encoded_error_span.source_span
		}
	var reaction: Dictionary = parsed.reaction
	var check: Dictionary = parser.check_balance(reaction)
	if not bool(check.get("ok", false)):
		return {
			"ok": false,
			"code": "A2_REACTION_VALIDATION_FAILED",
			"balance_code": String(check.get("code", "BALANCE_UNKNOWN"))
		}
	if not bool(check.balanced):
		return {
			"ok": false,
			"code": "A2_REACTION_UNBALANCED",
			# A2's exact residual orientation is reactants MINUS products.
			"element_residuals": check.element_residuals.duplicate(true),
			"charge_residual": int(check.charge_residual)
		}

	var terms: Array = []
	for term in reaction.reactants:
		var reactant_fact: Dictionary = _term_fact(term, "REACTANT", -1, source)
		if not bool(reactant_fact.get("ok", false)):
			return {"ok": false, "code": "A2_SOURCE_SPAN_CONVERSION_FAILED"}
		terms.append(reactant_fact.term)
	for term in reaction.products:
		var product_fact: Dictionary = _term_fact(term, "PRODUCT", 1, source)
		if not bool(product_fact.get("ok", false)):
			return {"ok": false, "code": "A2_SOURCE_SPAN_CONVERSION_FAILED"}
		terms.append(product_fact.term)

	return {
		"ok": true,
		"schema_version": 1,
		"arrow_type": String(reaction.arrow_type),
		"original_input": source,
		# Each original occurrence is kept, including duplicate formulae.
		# IDs are parse-local locators, NOT durable SpeciesRef identity.
		"terms": terms,
		# Local, deterministic exact element and charge rows keyed by original
		# source-term IDs. This is NOT A4 sparse-law or stable SpeciesRef wire.
		"conservation_rows": _exact_conservation_rows(terms),
		"element_residuals": check.element_residuals.duplicate(true),
		"charge_residual": int(check.charge_residual)
	}


static func _term_fact(term: Dictionary, side: String, sign: int, source: String) -> Dictionary:
	var local_span: Dictionary = term.source_span
	var converted_span: Dictionary = SourceSpan.to_utf8_byte_span(source, local_span)
	if not bool(converted_span.get("ok", false)):
		return {"ok": false}
	var ast: Dictionary = term.species.formula_ast
	var coefficient: int = term.stoichiometric_coefficient
	return {"ok": true, "term": {
		"source_term_id": String(term.term_id),
		"source_span": local_span.duplicate(true),
		"source_span_utf8": converted_span.source_span,
		"side": side,
		"stoichiometric_coefficient": coefficient,
		# The numerical A4 reaction convention: product PLUS, reactant MINUS.
		"signed_stoichiometric_coefficient": sign * coefficient,
		"formula_source_text": String(ast.source_text),
		"element_counts": ast.element_counts.duplicate(true),
		"net_charge": int(ast.net_charge),
		"phase": String(term.species.phase)
	}}


static func _exact_conservation_rows(terms: Array) -> Array:
	# All values came from A2's reparsed/validated FormulaAST, not an
	# untrusted identity catalog or caller-authored numeric model.
	var elements: Dictionary = {}
	for term in terms:
		for element in term.element_counts:
			elements[element] = true
	var sorted_elements: Array = elements.keys()
	sorted_elements.sort()

	var rows: Array = []
	for element in sorted_elements:
		var coefficients: Array = []
		for term in terms:
			var count: int = int(term.element_counts.get(element, 0))
			if count != 0:
				coefficients.append({
					"source_term_id": String(term.source_term_id),
					"coefficient": count
				})
		rows.append({
			"kind": "ELEMENT",
			"element": String(element),
			"coefficients": coefficients
		})

	# Charge is assessed for EVERY parsed formula. An empty sparse charge
	# row means all participants are KNOWN neutral, NOT "not assessed".
	# The integrator must omit an empty row from A4's numerical law list.
	var charge_coefficients: Array = []
	for term in terms:
		var charge: int = int(term.net_charge)
		if charge != 0:
			charge_coefficients.append({
				"source_term_id": String(term.source_term_id),
				"coefficient": charge
			})
	rows.append({
		"kind": "CHARGE",
		"coefficients": charge_coefficients
	})
	return rows
