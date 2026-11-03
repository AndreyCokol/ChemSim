# A4 → A5 concentration GraphSeries projection (P1)

**Task:** A4-GRAPH-PROJECTION-01. **Agent:** A4 — Kinetics & Numerical Solver. **Date:** 2026-11-03. **Scope:** A4-owned validated *in-process* projection, not yet an agreed CLI response payload or Godot E2E.

**Baseline:** owner-approved OpenSpec v0.1 (`02b8b31706807279ee31a78772383e31f425f7d3`); [shared GraphSeries and reliability contract](https://github.com/AndreyCokol/ChemSim/blob/openspec/review-round-1/openspec/contracts/mvp-cross-agent-contract-v0.1.md). **Current A5 consumer:** [`scripts/graph_series_view.gd`](https://github.com/AndreyCokol/ChemSim/blob/feat/godot-workspace-scaffold/scripts/graph_series_view.gd) accepts `quantity_key=concentration`, `unit_id=mol/m3` and rows `{time_s, value_status, value?}`, where missing/invalid values produce gaps.

## Current A4 implementation

- [Source](../../src/ChemSim.Kinetics/Simulation/SolverGraphProjection.cs): `SolverGraphProjection.ProjectConcentrations(request, result, resultReference, speciesReferences, seriesIds)`. The integrator supplies **all** stable result/species references and version numbers and unique per-species series IDs. The A4 mathematical solver never invents canonical identity, serializations, A1 formula metadata or source provenance.
- The projector receives genuine A4 `SimulationResult` with `StateSample.AmountsMol` (mol) and the associated **fixed volume** `SimulationRequest.VolumeM3` (m³). For every species and every *validated* solver output sample, it outputs `c_i=n_i/V` in mol/m³, with explicit `value_status=valid`. Numeric zero is a valid measured/modelled zero and is never changed to missing.
- A4 result prefix semantics are preserved. If `Status != Success` and samples exist before requested end, the adapter appends **one** `{time_s: requested_end, value_status: missing}` per series, with **no numeric value**. This is a display *gap annotation*, not a computed point. The original cause-specific `SimulationResult.Status` must still be transported independently to Godot: GraphSeries alone does **not** describe step_limit, invariant_violation, cancellation or science validity.
- If the solver publishes no samples (e.g., prevalidation failure), the projection produces **no** graph. A claimed successful result without a valid final sample is rejected.
- All emitted points require finite strictly ascending timestamps in the request bounds, a published initial model-time sample, exactly the canonical network species set, finite nonnegative amounts and finite concentrations. Wrong/missing/duplicate IDs/revisions, duplicate series IDs or invalid volume are rejected. It never creates rate, thermal, pH, equilibrium, event or rewind graphs.
- Typed record serialization uses the exact existing JSON property names `series_id`, `result_ref`, `species_ref`, `quantity_key`, `unit_id`, `samples`, `time_s`, `value_status`, `value`. The value property is absent (not null, not zero) when status is `missing`.

## Example: partial numerical result (illustrative mathematics only)

```json
{
  "series_id": "supplied-by-integrator-A",
  "result_ref": {"id": "integrator-run", "record_revision": 1},
  "quantity_key": "concentration",
  "species_ref": {"id": "A", "record_revision": 1},
  "unit_id": "mol/m3",
  "samples": [
    {"time_s": 0, "value_status": "valid", "value": 1},
    {"time_s": 1, "value_status": "valid", "value": 0.5},
    {"time_s": 2, "value_status": "missing"}
  ]
}
```

The final row is the **requested** endpoint, not a successful solve at t=2. The corresponding transport envelope must preserve `outcome=step_limit` (or its actual termination) and independent `reliability.completeness=partial`; A5 must not show an overall completed status merely because the plot can display valid prefix values.

## Automated acceptance in A4

[Unit/serialization tests](../../tests/ChemSim.Kinetics.Tests/SolverGraphProjectionTests.cs) verify a real numerical solve, canonical ids and revisions, proper mol/m³ conversion, valid zero, typed JSON keys, two species sharing one result ref, no-rate/no-temp creation, incomplete-prefix gap with absent value, initial-only stop, empty invalid result, invalid volume, missing/NaN/negative samples, duplicate/decreasing timestamps, overflow and mismatched/duplicate references.

**CI:** A4 `.github/workflows/a4-dotnet.yml` runs the entire A4 xUnit suite on Linux and publishes the self-contained CLI on Windows. These graph-projection tests execute on .NET; **they do not invoke the A5 Godot GraphSeries validator or a Windows Godot child-process bridge**. The existing CLI `simulation_result.payload` still contains `samples[].amounts_mol` as before: this opt-in converter has **not** modified the shared envelope/payload or version.

## Decision requests / further P1 integration

1. **Integrator:** approve the canonical derivation and lifetime of `result_ref`, `species_ref`, `series_id` and `request_message_id` correlation (source revision vs result revision), plus where the projector runs in the A4 CLI adapter and whether GraphSeries is nested in `simulation_result.payload` or a separate consumer message. Do not implicitly use a parse-local A2 `term_id` or fabricate revision `1`.
2. **A5:** confirm consumer acceptance of an explicit final `missing` marker on a non-success prefix, and that GraphSeries presentation does not erase the solver's non-success termination, requested end, input source quality, or applicability. Actual A5 `submit_series` must run against serialized values in an E2E test once the integrator chooses the wire placement.
3. **A1/A2:** provide authoritative stable species identities, their record revisions and exact chemical balance/provenance before a real reaction can be called chemically verified. Numeric success alone is not scientific admission.
4. **A4:** after identity/placement agreement, wire the already-tested projection into the A4-owned CLI result mapping and add real A5 consumer fixtures. The separate A4-GRAPH-PROJECTION-01 is complete only after exact-head CI proves this source/test code. **A4-E2E-MVP remains PARTIAL until actual A2 parser → admitted A4 CLI → A5 Godot roundtrip is demonstrated.**

## P1 cross-runtime finding: Godot JSON numeric revision ingress defect

On 2026-11-03, A4 added a **real cross-branch transport diagnostic**: the xUnit test [`A5JsonConsumerFixtureTests.cs`](../../tests/ChemSim.Kinetics.Tests/A5JsonConsumerFixtureTests.cs) runs the actual `KineticsSimulator` plus `SolverGraphProjection` on the explicitly hypothetical N2O4→2NO2 fixture, writes full/step-limit JSON to a **test-only** GitHub Actions artifact, and the A4-owned [Godot contract script](../../tests/a4_cross_agent/validate_a4_graph_json_in_a5.gd) loads those raw bytes in a detached, pinned checkout of **unchanged A5** revision `90f24ea71923dbbd044e56fa8ade72ff55849e6a`. This is NOT a deployed A2→A4→A5 UI integration.

**Real failure captured:** [CI #41668074731](https://github.com/AndreyCokol/ChemSim/actions/runs/41668074731) passed A4 .NET tests and Windows CLI but the Godot 4.3 cross-consumer job returned **exit code 1**, exactly: `A5 rejected actual JSON from A4 full run: Отсутствует версия или идентификатор результата. (JSON record_revision type=3)`. Godot `JSON.parse_string` reads JSON `record_revision: 1` as `TYPE_FLOAT` (type 3), whereas pinned A5 `graph_series_view.gd::_is_ref` requires `TYPE_INT`. The A4 JSON numeric value is **valid** against the proposed JSON Schema's integer reference revision; changing it to a JSON string would break the contract, not fix the problem.

**A5/integrator fix required:** Accept or normalize JSON numeric revision `v` only if finite, `v >= 1`, exactly integral, within safe precision/representability and within the consumer's integer domain; canonicalize to `TYPE_INT` *before* result identity comparisons. Reject fractions, nonfinite, zero, negatives and overflow. A5 owns GDScript serializer/validator admission; integrator ratifies the cross-runtime DTO. A4 notified [A5 PR #3](https://github.com/AndreyCokol/ChemSim/pull/3), [A5 Issue #11](https://github.com/AndreyCokol/ChemSim/issues/11) and [integrator PR #1](https://github.com/AndreyCokol/ChemSim/pull/1) with exact logs.

**Diagnostic isolation, NOT an implementation workaround:** To see whether further fields fail, the A4 test-only Godot script now *first asserts* that unmodified A5 rejects the genuine JSON, then makes a deep **test-only** copy and strictly converts solely exact, positive, finite safe-integer `record_revision` values from floating JSON to Godot `int`. It must reject fractional/zero revisions, and then exercises the untouched A5 validator and presentation model against both full and step-limit graph samples. A green diagnostic run would show only the **post-normalization** path works: **raw A4 JSON remains blocked for real Godot UI** until A5 owns and ships the ingress fix. Never cite this diagnostic as successful end-to-end A4→A5 wire compatibility.

**Additional UI integration constraint:** The current A5 `GraphViewScript.series_by_quantity` stores one series per `quantity_key`; presenting two different concentration species simultaneously requires an A5-owned UI decision (series grouping/legend or explicit selection). A4's producer emits one valid `GraphSeries` per species; the test checks each independently, but a single A5 quantity tab currently replaces its prior concentration species on submission. Do not label the viewer a full multi-species graph yet.

**Next exact acceptance:** After A5 implements and validates JSON-aware revisions in its own branch, bump the pinned A5 source SHA in the A4 cross-consumer CI, remove the test-only normalization and the expected-failure assertion, and demand a **green raw** JSON→Godot validator process run. The existing `simulation_result` CLI wire placement is still a separate integrator decision. No A5 source change is made in this A4 work.
