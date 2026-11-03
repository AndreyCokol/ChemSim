# A2 parser and balancer (initial implementation)

This folder contains the first executable A2 domain slice in GDScript 4.x. It has no dependency on Godot scene nodes or UI.

## Files

- `chem_equation_parser.gd` — formula/reaction parsing, FormulaAST construction, phase and charge parsing, atom/charge balance validation.
- `chem_reaction_balancer.gd` — bounded positive-integer search for a minimum-sum coefficient vector.
- `chem_source_span.gd` — validated A2-only conversions between Godot character spans and original UTF-8 byte spans; no shared ErrorEnvelope construction.
- `tests/a2/test_a2_parser_balancer.gd` — headless smoke tests.

## Current supported syntax

- Element symbols from the periodic table.
- Positive integer subscripts and nested round groups.
- Phases `(s)`, `(l)`, `(g)`, `(aq)`.
- Explicit multi-charge notation such as `Fe^3+` and `SO4^2−`.
- One-charge aliases in the parser allowlist, including `H+`, `OH-`, `NH4+`, `Ag+`, `Cl-`, `NO3-`.
- Reaction arrows `->`, `→`, `⇌`, `<->`.
- Stoichiometric coefficients are stored separately from formula AST. Fractional, zero, negative, and oversized coefficients are rejected.
- Integer tokens are capped at 1,000,000; expanded per-element formula counts are capped at 1,000,000,000 to keep arithmetic within explicit safe bounds.
- A reaction side uses whitespace around the plus separator: `NH4+ + Cl-`.

Hydrates, square-bracket complexes, redox half-reactions, isotopes, radicals, and advanced organic notation are rejected or not implemented.

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

The smoke-test script is executed by the GitHub Actions workflow `A2 parser and balancer tests` in a Godot 4.3 headless container. The latest **source/test validation** is commit `5301346f2cab397b6652b45c6961b0e53376a92b`, passed in workflow run [41659813692](https://github.com/AndreyCokol/ChemSim/actions/runs/41659813692): temporary Godot project setup, import/script parsing, and all A2 parser/balancer + UTF-8 source-span tests succeeded. This evidence applies to that exact source/test commit, not to any later documentation HEAD. Local Godot execution and full integrated-project validation have not been performed in this environment.
