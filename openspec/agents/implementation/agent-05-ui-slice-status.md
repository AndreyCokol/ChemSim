# A5 implementation slice — status and boundaries

Date: 2026-11-02  
Branch: feat/godot-workspace-scaffold  
PR: #3 (draft, not merged)

## Implemented in this slice

- Godot 4.x project entry point and Russian-language experiment workspace.
- Add, edit and remove unvalidated component drafts (name, formula text, amount text, display unit and phase label).
- Editable experiment title and explicit confirmation before discarding a dirty draft on New/Open.
- Separate local draft repository restricted to `user://`, with temporary-file write, backup/restore replacement and round-trip/security tests.
- Presentation-only placement and dragging of component markers. Normalized display coordinates are stored separately from chemistry input and are never sent to a solver.
- Raw reaction text and raw pressure/volume fields.
- Explicit isothermal presentation; temperature is fixed and not user-editable in the MVP shell.
- Versioned local UI-draft document (`chemsim_ui_draft`, schema version 1), with codec validation, round-trip tests, and rejection of unsupported schema versions / duplicate IDs.
- Atomic-style replacement using a temporary file and backup/restore path.
- Headless Godot import/startup CI, draft-codec tests and draft-repository round-trip/security tests.

## Explicitly not implemented

- Formula parsing, reaction parsing, balancing, substance identity, property/unit validation, hazard classification, equilibrium, kinetics, integration, numerical diagnostics, or chemistry DTOs.
- Solver-backed graphs, interpolation, graph-series adapters, playback, pause, single-step, rewind, event application, replay, or simulation hashing.
- Final experiment-document persistence, chemistry records, solver history, event logs, migration of the future canonical format, CSV result export, or Windows release packaging.
- Encyclopedia content. A1 must provide canonical substance/property/provenance/hazard records before the encyclopedia can display scientific claims.

## Integration gates

| Dependency | A5 work blocked until contract is available |
|---|---|
| A1 | Canonical substance IDs/revisions, property/unit/provenance and hazard completeness records |
| A2 | FormulaAST/reaction contracts, stable IDs, source-span semantics, parser/balancer diagnostics |
| A3 | Equilibrium result metadata, basis/standard state, activity model, pH convention and diagnostics |
| A4 | Kinetic model, solver result, graph-series/sample validity, event ordering, history and replay semantics |
| Integrator / owner | Shared error envelope, unit registry, schema policy, approved OpenSpec baseline and application boundary |

## Validation status

- GitHub Actions successfully completed the initial scaffold import/startup checks on commit `2c1fc5935d32d7c5e0d12c73dc799c8a2a7ba042`.
- New codec/test commits have their own GitHub Actions runs queued or in progress; do not treat them as passed until the latest head SHA has a successful run.
- No local Godot executable is installed in the authoring environment.

## Approval boundary

This PR is an A5 presentation/application-shell slice. It does not imply that OpenSpec PR #1, A1–A4 contracts, or the final experiment persistence format are approved. PR #3 remains draft and is not merged into `main`.
