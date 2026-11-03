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
