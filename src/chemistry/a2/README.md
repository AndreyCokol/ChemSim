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

## API sketch

```gdscript
var parser := ChemEquationParser.new()
var parsed := parser.parse_reaction("H2 + O2 -> H2O")
if parsed.ok:
    var balance_check := parser.check_balance(parsed.reaction)
    var balancer := ChemReactionBalancer.new()
    var proposal := balancer.propose_balance(parsed.reaction)
```

Parsing never changes coefficients and never balances implicitly. `check_balance` validates entered coefficients. `propose_balance` returns a separate proposal.

## Balancer guarantees and limits

The current solver enumerates positive integer coefficient vectors in increasing total-sum order. It can prove a unique or ambiguous optimum when it finishes a complete minimum-sum layer. It uses integer arithmetic only and rejects malformed/out-of-contract species DTOs before search.

- Default maximum coefficient sum: 64; caller-supplied bounds are capped at 1,000,000.
- Maximum input species terms: 4,096 per reaction; this and the coefficient-sum cap keep solver residual arithmetic within signed 64-bit bounds under the validated formula/charge limits.
- Source coefficients must be positive integers no greater than 1,000,000. `propose_balance` validates them but computes a fresh coefficient proposal independently of the entered values.
- Each species DTO is reparsed from `formula_ast.source_text`; phase, net charge, and elemental composition must match the parsed source formula.
- Default candidate limit: 500,000.
- A structurally impossible element balance returns `NO_POSITIVE_SOLUTION`.
- If the configured bound is exhausted, the result is `SEARCH_LIMIT_EXCEEDED`, never a false claim of no solution.
- Terms with identical source formula notation and the same phase are aggregated per reaction side into one solver variable. The proposal returns the aggregate coefficient and all contributing `source_term_ids`; it deliberately does not invent a distribution across duplicate source terms. Different phases and differently written formulas remain distinct; this avoids merging possible isomers that share an elemental composition. The objective is the sum of coefficients over distinct species terms.

This is an initial bounded solver, not a general-purpose ILP implementation. Limits and duplicate-term semantics need benchmark-driven refinement before production use.

## Test status

The smoke-test script is committed, but it has not been executed in this environment because a Godot 4.x executable and a root `project.godot` are not present in the repository/runtime. No test pass is claimed.
