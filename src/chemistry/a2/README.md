# A2 parser and balancer (initial implementation)

This folder contains the first executable A2 domain slice in GDScript 4.x. It has no dependency on Godot scene nodes or UI.

## Files

- `chem_equation_parser.gd` — formula/reaction parsing, FormulaAST construction, phase and charge parsing, atom/charge balance validation.
- `chem_reaction_balancer.gd` — bounded positive-integer search for a minimum-sum coefficient vector.
- `chem_source_span.gd` — validated A2-only conversions between Godot character spans and original UTF-8 byte spans; no shared ErrorEnvelope construction.
- `chem_stoichiometry_handoff.gd` — A2-local, trusted original-source-to-exact-atom/charge conservation facts with a separate signed coefficient per source occurrence; not a shared v0.1 payload or a durable identity adapter.
- `tests/a2/test_a2_parser_balancer.gd` — headless smoke tests.

## Current supported syntax

- Element symbols from the periodic table.
- Positive integer subscripts and nested round groups.
- Phases `(s)`, `(l)`, `(g)`, `(aq)`.
- Explicit charge notation such as `Fe^3+`, `SO4^2−`, `SO4^-` and `H2^+`; charge magnitude 1 is valid with a caret and is not confused with an atom subscript.
- One-charge aliases in the parser allowlist, including `H+`, `OH-`, `NH4+`, `Ag+`, `Cl-`, `NO3-`.
- Reaction arrows `->`, `→`, `⇌`, `<->`.
- Stoichiometric coefficients are stored separately from formula AST. Fractional, zero, negative, and oversized coefficients are rejected.
- Integer tokens are capped at 1,000,000; expanded per-element formula counts are capped at 1,000,000,000 to keep arithmetic within explicit safe bounds.
- A reaction side uses whitespace around the plus separator: `NH4+ + Cl-`.

Hydrates, square-bracket complexes, redox half-reactions, isotopes, radicals, and advanced organic notation are rejected or not implemented.

**Canonical charge serialization (A2-local):** `serialize_formula()` / `serialize_reaction()` preserve one-unit charge semantics. The serializer uses short `+` or `-` only for explicit entries in `SIMPLE_ION_ALIASES` (e.g. `NH4+`, `OH-`, `Ag+`), otherwise canonical `^+` or `^-` (`SO4^-(aq)`, `H2^+(g)`, `Fe^+`). Previously an unaliased `SO4^-` could become ambiguous `SO4-`; this is now rejected as a serializer regression by round-trip tests. **The original `source_text` is preserved**, while the canonical output may normalize the charge syntax. This local policy is not an integrator decision about the shared v0.1 wire canonicalization or short alias set (INT-28/29).

## Diagnostic source spans

Parser diagnostics expose `source_span.start_offset` and `source_span.end_offset` as zero-based Godot `String` character indices. The end offset is exclusive. Offsets refer to the original formula or reaction input, including leading whitespace and text before the failing token; they are not UTF-8 byte offsets.

The pure A2 `ChemSourceSpan` utility converts **only offsets**, without rewriting or normalizing the source, changing A2 diagnostics, or choosing the shared wire `ErrorEnvelope` policy:

```gdscript
var source := "H2 + O2 → H2Ж"
var parsed := ChemEquationParser.new().parse_reaction(source)
if not parsed.ok:
    var bytes := ChemSourceSpan.to_utf8_byte_span(source, parsed.source_span)
    # For the invalid Cyrillic character: [12,13) -> UTF-8 [14,16).
    if bytes.ok:
        var original_chars := ChemSourceSpan.to_character_span(source, bytes.source_span)
```

Successful results contain `{"ok": true, "source_span": {"utf8_byte_start": ..., "utf8_byte_end": ...}}` or the reverse `{"start_offset": ..., "end_offset": ...}`; invalid values return `{"ok": false, "code": "A2_INVALID_SOURCE_SPAN"}`. Conversion checks missing, wrong-type, negative, reversed and out-of-bounds offsets, and rejects byte ranges ending or starting **inside a UTF-8 multibyte character**. Both functions preserve zero-width character/byte insertion positions, including at EOF. The **integrator/A5 must still decide** whether wire `SourceSpan` accepts zero-width error insertion ranges or encodes a distinct cursor position: this A2 utility does not silently change that policy. Call with the exact unchanged original source; UI offsets from an edited buffer are stale and must be reparsed.

The utility is independently tested with ASCII, UTF-8 Unicode arrows, Cyrillic text and 4-byte emoji and remains part of the A2 scope only; it is **not** an A2→A5 adapter, an approved shared payload or integrated UI validation.

## API sketch

```gdscript
var parser := ChemEquationParser.new()
var parsed := parser.parse_reaction("H2 + O2 -> H2O")
if parsed.ok:
    var balance_check := parser.check_balance(parsed.reaction)
    var balancer := ChemReactionBalancer.new()
    var proposal := balancer.propose_balance(parsed.reaction)
```

Parsing never changes coefficients and never balances implicitly. `check_balance` validates entered coefficients. `propose_balance` returns a separate proposal. Canonical serializers reparse and validate FormulaAST data; they return an empty string for malformed or stale DTOs rather than serializing a mutated node tree. Generated `term_id` values currently use the term's source-character offset and are only parse-local locators; they are not stable across whitespace or text edits. Callers that need persistent source-term identity must manage a stable ID outside the current parser API until the shared DTO/API contract is approved.

## Trusted source-text stoichiometry facts (A2-local, P1 integration preparation)

The pure `ChemStoichiometryHandoff.extract_balanced_terms(original_source)` helper **re-invokes the actual A2 parser** and exact `check_balance()`. Its only input is reaction text, not user-supplied or decoded FormulaAST/SpeciesRef dictionaries; it refuses parsing errors, malformed local Reaction DTOs and atom/charge imbalances rather than handing a plausible partial network to A4.

```gdscript
var result := ChemStoichiometryHandoff.extract_balanced_terms("N2O4(g) -> 2NO2(g)")
if result.ok:
    # reactant ν=-1, product ν=+2; explicit N/O counts and GAS phase
    # The integrator must still resolve stable SpeciesRef IDs/revisions.
    var terms: Array = result.terms
```

Successful A2-local output has `schema_version=1`, `arrow_type`, exact `original_input`, `element_residuals` and `charge_residual`, plus one `terms` entry **per original source occurrence**, not per aggregated species. Each entry contains source-local `source_term_id`, Godot-character `source_span`, `side`, positive `stoichiometric_coefficient`, signed `signed_stoichiometric_coefficient` (reactant negative, product positive), `formula_source_text`, copied `element_counts`, `net_charge`, and explicit `phase` including `UNSPECIFIED`. Duplicate terms keep separate offsets and source locators. The signed coefficients follow A4's numeric convention, which is the **negative** of A2's nonzero `check_balance()` residual sign.

**Exact conservation-row derivation (A2-local, not A4 wire):** a successful result also has `conservation_rows`, deterministically sorted by chemical element, followed by an explicit `CHARGE` row. Each `ELEMENT` row contains `element` (e.g. `N`, `O`) and a sparse `coefficients` array of `{source_term_id, coefficient}`; entries are exact positive atom counts for each **original source occurrence**, omitting only known zero counts. The `CHARGE` row contains exact signed formal charges for non-neutral occurrences; an **empty** charge coefficient list means every parsed species is confirmed neutral, not that charge is unknown or unassessed. For `N2O4(g) -> 2NO2(g)`, rows are `N=(2,1)`, `O=(4,2)`, empty known-zero charge; for `Ag+(aq) + Cl-(aq) -> AgCl(s)`, the charge row is `(+1,-1)`. In each row, `Σ(source_row_coefficient × signed_stoichiometric_coefficient) = 0` is validated in A2 tests. Repeated `H2` source terms remain independently referenced rather than being silently collapsed.

All row identifiers are **parse-local source-term IDs**, not immutable `SpeciesRef` IDs; the integrator must resolve A1 species revisions, map and aggregate occurrences by authenticated species identity, validate complete chemical element/charge coverage, and convert nonempty rows to A4 numeric sparse laws. Do **not** send a zero-valued empty charge row to A4 as a nontrivial conservation law, claim a verified numerical kinetics model, infer electroneutrality from reaction charge conservation, or interpret `conservation_rows` as an approved shared v0.1 JSON payload. Invalid/unbalanced input returns neither `terms` nor `conservation_rows`. Exact A2 row regressions: [CI #41667608709](https://github.com/AndreyCokol/ChemSim/actions/runs/41667608709) at code/test commit `98cbea9fbdaea3bbe687ea5f5fd2f5820507e9e6`.

Failures have `ok=false` and one of `A2_REACTION_PARSE_FAILED` (includes original parser code/span), `A2_REACTION_VALIDATION_FAILED`, or `A2_REACTION_UNBALANCED` (exact A2 atom/charge residuals), **without** exposing consumable `terms`. This helper does not balance an equation, choose kinetic reaction order, rate constant k, equilibrium K, gas/aqueous model, model units, source provenance, durable SpeciesRef/ReactionRef IDs, cross-agent `ErrorEnvelope`, or a CLI request. The integrator must perform trusted revision/identity/phase admission, signed-stoichiometry aggregation and complete sparse law-row construction before A4. In particular, `UNSPECIFIED` must not become `GAS` by assumption and `REVERSIBLE` must not be sent to the current irreversible A4 kinetics model.

The local helper/test source commits are `c6ffffd1922e8ed7e4254b2134cc0f99bbf4eb8f` and `48e6131900fbd55354645c6b744d52da26193b4a`. This is an **A2-only preparatory handoff**, not integrated A2→A4→A5 E2E.

## External Reaction DTO validation (local A2 v1)

The product owner approved staged A1–A5 implementation under OpenSpec architecture baseline v0.1: [approval record](https://github.com/AndreyCokol/ChemSim/blob/main/openspec/changes/define-chemsim-mvp/APPROVAL.md). This does not make the A2-local dictionaries the approved public interchange schema.

All three A2 entry points that consume a caller-supplied reaction — `check_balance()`, `propose_balance()`, and `serialize_reaction()` — now **fail closed** unless the reaction carries:
- an explicit **integer** `schema_version = 1` and recognized `arrow_type` (`FORWARD` / `REVERSIBLE`);
- nonempty typed `reactants` and `products`, each with an explicit positive integer `stoichiometric_coefficient` and an explicit `species.phase` (`UNSPECIFIED` is valid and distinct from omitted);
- internally consistent `FormulaAST` data, as verified by reparsing `formula_ast.source_text` and comparing nodes, element counts, phase, charge, and local AST version.

Local invalid-input responses remain `BALANCE_INVALID_REACTION`, `BALANCE_INVALID_TERM`, balancer `INVALID_INPUT`, or empty serialized string. `parse_reaction()` still accepts omitted **textual** unit coefficients and phases, materializing explicit coefficient 1 and phase `UNSPECIFIED` in its successful DTO. No legacy/unversioned external DTO defaults or migration are assumed. This local shape/version is **not** the shared wire `contract_version = "0.1"`; stable SpeciesRef/Reaction identity and phases require the integrator-owned adapter.

Nine mutated reaction inputs are covered across all three operations (missing/unsupported/wrong-type version, missing/invalid arrow, missing coefficient, missing/invalid phase), with valid-v1 and input-preservation checks. Exact A2 source/test head `dd3de4b396e9a38fe0fccb0f043159ac396fadc6` passed [Godot 4.3 CI #41657267795](https://github.com/AndreyCokol/ChemSim/actions/runs/41657267795), including import/script parsing and A2 tests. This is not an integrated Godot→.NET E2E claim.

## Balancer guarantees and limits

The current solver enumerates positive integer coefficient vectors in increasing total-sum order. It can prove a unique or ambiguous optimum when it finishes a complete minimum-sum layer. It uses integer arithmetic only and rejects malformed/out-of-contract species DTOs before search.

- Default maximum coefficient sum: 64; caller-supplied coefficient-sum bounds are capped at 1,000,000 and candidate limits at 2,000,000.
- `check_balance` accepts at most 4,096 total species terms per reaction; this bounds aggregate arithmetic under the parser's formula/charge limits. The solver applies a stricter 128-term cap to bound recursive search depth.
- Source coefficients must be positive integers no greater than 1,000,000. `propose_balance` validates them but computes a fresh coefficient proposal independently of the entered values.
- Each species DTO is reparsed from `formula_ast.source_text`; schema version, AST node tree, phase, net charge, and elemental composition must match the parsed source formula.
- Default candidate limit: 500,000. Recursive search is also capped at 2,000,000 visited nodes so internal composition-tree work cannot grow without bound even when few complete candidates are reached.
- A structurally impossible element balance returns `NO_POSITIVE_SOLUTION`.
- If the configured bound is exhausted, the result is `SEARCH_LIMIT_EXCEEDED`, never a false claim of no solution.
- Terms with identical source formula notation and the same phase are aggregated per reaction side into one solver variable. The proposal returns the aggregate coefficient and all contributing `source_term_ids`; it deliberately does not invent a distribution across duplicate source terms. Different phases and differently written formulas remain distinct; this avoids merging possible isomers that share an elemental composition. The objective is the sum of coefficients over distinct species terms.

This is an initial bounded solver, not a general-purpose ILP implementation. Limits and duplicate-term semantics need benchmark-driven refinement before production use.

## Test status

The smoke-test script is executed by the GitHub Actions workflow `A2 parser and balancer tests` in a Godot 4.3 headless container. The latest **source/test validation** is commit `1a0f175d0f3148e49250ed332a922bbdc6220b4e`, passed in workflow run [41662285747](https://github.com/AndreyCokol/ChemSim/actions/runs/41662285747): temporary Godot project setup, import/script parsing, and all A2 parser/balancer tests succeeded, including canonical one-unit-charge round trips, exact chemistry-balance vectors and UTF-8 source-span cases. This evidence applies to that exact source/test commit, not to any later documentation HEAD. Local Godot execution and full integrated-project validation have not been performed in this environment.
