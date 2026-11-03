# A2 parser and balancer (initial implementation)

This folder contains the first executable A2 domain slice in GDScript 4.x. It has no dependency on Godot scene nodes or UI.

## Files

- `chem_equation_parser.gd` — formula/reaction parsing, FormulaAST construction, phase and charge parsing, atom/charge balance validation.
- `chem_reaction_balancer.gd` — bounded positive-integer search for a minimum-sum coefficient vector.
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

The smoke-test script is executed by the GitHub Actions workflow `A2 parser and balancer tests` in a Godot 4.3 headless container. The latest completed validation before this README refresh is A2 documentation HEAD `5ba054b97280f1da8041d6ad5ad9c1ea96c69b0c`, passed in workflow run [41612841149](https://github.com/AndreyCokol/ChemSim/actions/runs/41612841149): temporary project setup, import/script parsing, and A2 parser/balancer tests all succeeded. This evidence applies to that exact commit; this README refresh will require its own CI run. Local execution was not performed in the current environment.
