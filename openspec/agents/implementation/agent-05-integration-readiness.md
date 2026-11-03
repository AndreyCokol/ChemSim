# A5-09 — Inter-module integration readiness

Date: 2026-11-03  
Owner: Agent A5 — Godot UX, Visualization & Integration  
Branch: `feat/godot-workspace-scaffold`  
Tracking: issue #11; implementation PR #3  
Status: **in progress — consumer-side contract audit; normative adapters remain gated**

## 1. Scope and authority

This document records what the Godot application/presentation layer needs from A1–A4 and the integrator. It is an A5 consumer contract and readiness matrix, not a shared DTO definition, chemistry/solver specification, or OpenSpec baseline approval.

A5 owns:
- Godot application boundary and presentation adapters;
- mapping approved application results into UI view models;
- explicit unavailable, invalid, stale, partial and error states;
- graph/timeline presentation once canonical result contracts exist;
- end-to-end UI integration tests.

A5 does not own:
- chemistry, parser, equilibrium or solver algorithms;
- A1–A4 domain DTOs, identity semantics or normative enums;
- unit definitions/conversions outside an approved shared Unit Registry;
- shared ErrorEnvelope, schema policy or ReliabilityVector decisions;
- merge to `main` or approval of the OpenSpec baseline.

## 2. Readiness matrix

| Producer / boundary | Minimum consumer requirements | Current evidence | Status | Closure owner |
|---|---|---|---|---|
| A1 domain / substance / property | Stable IDs and revisions; FormulaAST reference; property value/status, unit/dimension, basis, conditions, uncertainty and provenance; hazard completeness, declared scope, source/version, covered/missing sections, dates, freshness and conflict state | A1 proposal and A1 coordination requests on PR #3; A5 consumer response posted in PR #3 comment 6602863645 | **Provisional** — consumer requirements stated; normative A1 records/enums still need publication and cross-agent closure | A1 + integrator |
| A2 FormulaAST / Reaction | Stable identity and revision; formula composition and net charge owned once; phase separate from formula identity with explicit unknown semantics; reaction term/coefficient; parser/balancer result and typed diagnostics; source-span coordinate system and range convention | A2 PR #5 and A5 round-2/round-3 reviews; schema-version proposal is draft | **Blocked** — identity/revision, phase, source spans, diagnostics and reaction contract not frozen | A2 + integrator; A1 for shared identity |
| A3 equilibrium result | Typed species quantities; units and thermodynamic basis/standard state; phase and dissolved/solid context; pH convention/activity model; residuals with units/scaling; method/iterations; provenance, quality, applicability, warnings and typed termination | A3 PR #4 and consumer requirements in PR #3 comment 6600133057; current Python dataclasses are explicitly fixtures | **Blocked** — fixtures are not normative Godot DTOs; shared unit/error/reliability/schema decisions remain open | A3 + integrator |
| A4 kinetic / solver result | Versioned kinetic model; rate-law and parameter dimensions; typed SolverResult termination, error estimate, invariant residuals and applicability; valid sample/gap semantics; stable GraphSeries identity, quantity/unit/time basis and source revision | A4 PR #6 and benchmark matrix; round-3 A5 review identifies missing normative API | **Blocked** — normative kinetic/result/GraphSeries contract not published | A4 + integrator |
| A4 timeline / replay | Canonical model time, sample/event ordering, event identity and acknowledgement, snapshots/checkpoints, input/model versions, solver settings and explicit replay determinism guarantee | A5 round-3 dataflow review; no approved event/replay contract identified | **Blocked** — UI must not define ordering, replay or hash semantics | A4 + integrator |
| Integrator cross-cutting | Approved Unit Registry; ErrorEnvelope; schema compatibility/version policy; ReliabilityVector semantics; application boundary and canonical decision register | OpenSpec review PR #1 and A5 round-2/round-3 reviews | **Blocked** — owner decisions and baseline approval outstanding | Integrator / product owner |

## 3. Presentation invariants

1. **Unknown is not zero.** Missing, unavailable, not assessed, invalid and measured zero are distinct states.
2. **Completeness is scoped.** `complete_for_declared_scope` never means universally safe or universally complete.
3. **Numerical convergence is not scientific validity.** Numerical termination, invariant residuals, input data quality, model applicability and result completeness remain separate.
4. **No fabricated time series.** One equilibrium result is one state. A5 will not synthesize graph points, interpolation, history or replay data.
5. **No implicit chemistry.** UI will not infer phase, reaction order, charge, unit, basis, standard state or species identity.
6. **No silent correction.** Original user input remains available; normalization and diagnostics must be explicit and traceable.
7. **Invalid samples create gaps.** Missing, rejected or non-finite samples are not plotted as zero and lines are not joined across invalid gaps.
8. **Preserve qualifiers.** Concentration-based ideal pH, activity-based pH, solid amount/status and model assumptions must be labelled from authoritative result metadata.
9. **No speculative unit conversion.** Display conversion is permitted only through the approved shared Unit Registry and typed quantity metadata.
10. **No unsupported replay claims.** A5 does not promise deterministic or bitwise replay until A4 and the integrator define the guarantee.

## 4. A5 implementation plan

### Can proceed now
- Keep existing Godot draft editor and local UI-draft persistence isolated from scientific DTOs.
- Maintain placeholders and explicit blocked/unavailable/error states.
- Add contract-readiness and missing-capability diagnostics without claiming a calculation ran.
- Add consumer-side acceptance tests for distinctions such as unknown vs zero, stale vs incomplete, numerical status vs applicability, and equilibrium state vs time series.
- Coordinate closure questions with A1–A4 and integrator; update this matrix when owner evidence changes.

### Must remain gated
- Concrete FormulaAST/Reaction serializers and source-span highlighting.
- Substance/property/hazard adapters against unapproved enums or IDs.
- Equilibrium and kinetic result adapters.
- GraphSeries, timeline, event and replay adapters.
- Shared unit formatting/conversion and ErrorEnvelope-to-action mapping.
- Migration to a canonical experiment document or solver-history persistence.

## 5. Immediate closure requests

- **A1:** publish the normative HazardRecord and PropertyRecord fields/statuses and stable identity/revision semantics; confirm the consumer requirements in PR #3.
- **A2:** publish the normative FormulaAST/SpeciesRef/Reaction contracts, phase-unknown policy, stable identity/revision rules, source-span coordinate/range semantics and typed parser diagnostics.
- **A3:** publish the normative equilibrium result contract including typed basis/standard-state, pH convention, residual scaling, applicability and termination.
- **A4:** publish KineticModel, SolverResult, GraphSeries/sample-validity, time/event ordering, history and replay contracts.
- **Integrator / owner:** resolve Unit Registry, ErrorEnvelope, schema compatibility, ReliabilityVector and application boundary; record accepted/rejected/deferred decisions and approve the baseline explicitly.

## 6. Evidence and change policy

- Contract proposals, review notes and isolated fixture dataclasses do not count as approved APIs.
- Every transition to **ready** requires an owner-published normative contract and a consumer review.
- Every adapter implementation must link to the exact contract version/revision it consumes and include tests for missing, invalid, stale and incompatible data.
- Work stays on `feat/godot-workspace-scaffold`; no A1–A4 files or shared DTOs are changed by A5.
- PR #3 remains Draft and unmerged; `main` is not modified.
