# A1 Chemistry Data & Domain — first implementation slice

**Owner:** A1 (Issue #10; Draft PR #15)  
**Approved architecture:** owner sign-off `main:openspec/changes/define-chemsim-mvp/APPROVAL.md`, OpenSpec v0.1 source `02b8b31706807279ee31a78772383e31f425f7d3`.  
**Scope:** A1-local strict *structural preflight* — not a shared wire DTO, not source validation, not formula parsing, not a complete offline catalog.

## Components

- `a1_property_gate.gd`: numeric reference-assertion metadata and separate per-field/per-channel release-declaration structural checks. Missing values are not zero; unregistered units, mismatched basis, unqualified temperatures, unsigned quality/review or missing provenance do not pass the calculation metadata preflight. A syntactically complete `approved_for_redistribution` declaration remains an **unverified claim** until a rights reviewer checks the source.
- `a1_identity_gate.gd`: validates the binding of caller-selected stable Substance, Species and FormulaAST **IDs plus record revisions** against the shape of a *trusted result produced by A2*. FormulaAST owns composition and net charge. Phase is occurrence-scoped; an A2 `UNSPECIFIED` phase is not automatically aqueous. It accepts `user_defined` and `hypothetical` identity without making a reference-quality claim.

These methods return `{ok,errors,scope,...}` for A1-local preflight; error strings are not the approved shared `ErrorEnvelope` wire schema. The integrator owns their mapping into v0.1 envelopes.

## Integrator / producer boundary

The **integrator** must: (1) call the A2 parser on actual input, (2) authenticate/trust the resulting A2 `ok/formula_ast/phase` data (the helper cannot tell fabricated dictionaries from real parser calls), (3) resolve and lock immutable `{id,record_revision}` for Substance, Species and FormulaAST from its persistent identity store, (4) pass the selected refs and actual A2 result to A1, and (5) enforce that changed formula or phase creates a fresh identity ID and historical revisions remain immutable. The helper cannot prove revision monotonicity or historical identity from one snapshot.

A2 currently returns an AST with `schema_version: 1`, `element_counts`, `net_charge`, `nodes`, `source_text`, and a separate phase token such as `AQUEOUS` or `UNSPECIFIED`. **A2's parser does not currently issue durable FormulaAST record IDs or revisions.** The selection/binding must be supplied by an approved integrator adapter; an A2 local term index or formula text must never be silently used as catalog identity.

For the A1 local identity preflight, the caller passes:

| Parameter | Contract subset |
|---|---|
| `substance` | `substance_id`, positive `record_revision`, `formula_ast_ref`, declared `origin`; **no** independently serialized `formal_charge`, `net_charge`, `element_counts`, `phase` |
| `species` | `species_id`, positive `record_revision`, same `formula_ast_ref`, phase `s/l/g/aq/unspecified` |
| `a2_parse_result` | `ok: true`; AST `schema_version: 1`, nonempty `nodes`, exact positive-integer sparse element counts, integer charge, `source_text`; A2 phase |
| `selection` | explicit three ref pairs `substance_ref`, `species_ref`, `formula_ast_ref`, each with `id` and positive `record_revision` |
| `model` | `required_phase` (`unspecified` for descriptive-only) and `explicit_occurrence_phase_confirmed` when A2 source phase is unspecified and a phase-specific model is requested |

**Important:** parser output must be supplied by a trusted A2 invocation, not accepted as raw user assertions. Presence of element counts is only a **shape/coverage** check: a missing element in an independently complete A2 AST is a known zero; a missing or unsupported AST is *unknown* and cannot be treated as a zero row. A1 does not derive element or charge balancing, mass, isotope corrections or equilibrium constants.

## Current implementation gaps / integration stop conditions

- Existing `implementation/bootstrap:scripts/domain/substance_record.gd` contains denormalized `element_counts`, `net_charge` and a local formula-parse routine. It does **not** map as-is to the v0.1 canonical record. The A1 helper intentionally rejects a second independent persisted chemistry truth; **no bootstrap/A2 file has been altered**. Integration requires an owner-reviewed migration/adapter and corresponding tests.
- A2 parser's ephemeral AST still needs durable identity binding, identity-change handling and trustworthy call-site semantics from the integrator. Static reference equality is **not** a cryptographic/content verification of a claimed AST.
- A1 origin preservation is separate from quality, review, model eligibility and redistribution. A1 `ok` is not a permission to label a trajectory `chemically_verified`; A4 needs independently proved full element/charge coverage, exact balance and applicable kinetics before using generated invariant rows.
- No numeric chemical constants, source-proven values, licensed catalog bundle or scientific benchmark have been admitted (**0/7**). A3 W02 requires source-backed, basis-qualified Kw, final-mixture concentration inputs and independent A3 adapter evidence.
- Overall bootstrap Godot editor import still reports existing parser/balancer script errors on the independent A1 job; passing isolated A1 tests is not a clean full-app build.

## Tests

```sh
godot --headless --editor --path . --quit
godot --headless --path . --script res://tests/a1/test_a1_property_gate.gd
godot --headless --path . --script res://tests/a1/test_a1_identity_gate.gd
```

These are **synthetic contract tests**, not scientific validation fixtures or an end-to-end A2→A1→A4 run. Exact-head GitHub Actions evidence must be recorded in PR #15 / Issue #10 after each meaningful change.


## A1 local user/hypothetical substance draft catalog (P1)

`a1_user_catalog.gd` is an A1 **private offline draft store**, not the v0.1 interchange envelope, A5 experiment persistence, a verified built-in catalog or a migration of `scripts/domain/substance_record.gd`.

- Only `user_defined` and `hypothetical` origins are accepted. Every draft is explicitly `identity_status: incomplete`, and its hazard coverage is `not_assessed`. Presence of a selected `formula_ast_ref` is **not** an A2 authenticity proof; historical scientific identity binding remains an integrator/A2 task.
- Caller supplies a stable opaque `substance_id` and `record_revision`. First revision is `1`; append requires the caller's `expected_previous_revision` and a consecutive revision. Every old revision is stored unchanged. Under one ID, `origin`, `formula_ast_ref`, and provenance creation timestamp are immutable; changing formula identity requires **a new catalog ID**, not an overwrite.
- `properties[]` are explicitly `quality: unverified` with matching local origin. `value_state: unknown/not_reported/not_applicable/withheld` carries no numeric `value`; `value_state: present` permits a finite numeric value (including **0**) only with explicit `unit_id` and `basis`. Neither structure nor numeric presence confers calculation eligibility.
- Arbitrary `quality: verified`, `redistribution`, `model_eligibility`, serialized `phase`, `net_charge` or `element_counts` are rejected in the local draft format. Do **not** use this store to ingest licensed reference fields, hazards or A2 formula/charge snapshots.
- Versioned `schema_version: 1` JSON, bounded record/property/file sizes, strict field allowlist, refusal of corrupt JSON and unknown versions. No silent migration. A fixed local file `user://a1_substance_drafts_v1.json` is written through a validated `.tmp` stage, with previous snapshot retained at `.bak`. A failed write attempts rollback; a corrupt primary does **not** silently import the older backup. Restore requires explicit user/integrator review.
- Test writes use **only** `user://a1_substance_drafts_test_v1.json` (plus test tmp/bak). It is never the production catalog. The store is not yet wired into UI, an authenticated A2 adapter or the shared Save/Replay document. No real chemical value/benchmark is imported.

Exact tests:

```sh
godot --headless --path . --script res://tests/a1/test_a1_user_catalog.gd
```

**Known limitations:** this is a local implementation slice. It does not validate literal UTC timestamps beyond structural presence, independently prove provenance truth, enforce scientific unit dimensions, guarantee atomicity under power loss, or resolve concurrent processes on Windows. A5/integrator must specify migration/export/backup UX and cross-module locking before shipping persistent data. No full-app E2E or scientific benchmark admission is implied.
