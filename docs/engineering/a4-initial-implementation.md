# A4 Initial Implementation — Scope and Limitations

Status: implementation draft on `feature/a4-kinetics-core`.

## Runtime decision

- Calculation libraries target .NET 10.
- Godot is intentionally not referenced by the calculation library.
- The future Godot .NET project should consume these libraries through project/package references.
- No Python runtime dependency is introduced.

## Implemented vertical slice

- Closed, constant-volume, isothermal systems.
- Species amounts are the integrated state, in mol.
- Concentrations used by rate laws are mol/m^3.
- Volumetric reaction rates are mol/(m^3 s).
- Extent rates are volume multiplied by volumetric rates, in mol/s.
- Stoichiometric coefficients and kinetic orders are separate inputs.
- Irreversible power-law rate laws with non-negative real orders.
- Rate-constant concentration dimensions are validated from total kinetic order.
- Adaptive Dormand-Prince RK 5(4) integration.
- Component-wise amount error scaling using scalar atol/rtol.
- Trial stages that leave the non-negative state domain are rejected; amounts are never silently clipped.
- Optional linear conservation laws are checked against every reaction and monitored at output samples.
- Deterministic species/reaction ordering by stable IDs.
- Cancellation and a simulation-wide internal-step budget.
- Analytical first- and second-order tests.

## CI

- Added `.github/workflows/a4-dotnet.yml` to restore, build, and test the solution with the .NET 10 SDK on pushes to the A4 feature branch and pull requests.
- CI uploads TRX test results when available.
- Verified source/test commit `d62fd5888254537f48b360a8912459b3d618e16f` with GitHub Actions run [41604271064](https://github.com/AndreyCokol/ChemSim/actions/runs/41604271064): .NET 10 Restore, Build and Test all completed successfully.
- CI status is tied to the exact source/test commit above; re-verify after any subsequent source or test change.

## Numerical edge-case hardening

- A final requested integration interval shorter than the configured minimum step is allowed when it is integrated as one final step; the minimum-step limit applies to further subdivision.
- The integrator advances in elapsed-time coordinates while passing absolute simulation time to the RHS, avoiding loss of step resolution at large absolute start times.
- The simulator rejects output intervals that cannot advance the representable time coordinate and rejects non-finite total durations.
- RHS evaluation diagnostics count actual RHS delegate invocations, including the invocation that throws an arithmetic failure; failed trial steps preserve both the count and original failure message.
- The output-time ULP calculation uses the inward representable spacing at `double.MaxValue`, avoiding an infinite spacing result from `Math.BitIncrement(double.MaxValue)`.

## Explicitly not implemented

- Chemical formula parsing or balancing (A2).
- Substance catalog, elemental composition, units catalog or provenance (A1).
- Aqueous/gas equilibrium and activities (A3).
- Reversible kinetics inferred from thermodynamic K.
- Arrhenius temperature dependence.
- Open-system flows and discrete events.
- Analytical-component state and equilibrium coupling.
- BDF, Radau, Jacobian, automatic stiffness switching.
- Godot scenes, UI, charting and persistence (A5).

## Important numerical limitation

This first integrator is explicit RK45. It is not suitable for every stiff chemical system. Stiffness detection and implicit methods are intentionally deferred until a benchmark can compare them against validated reference cases.

## Build and test

Requires the .NET 10 SDK:

```sh
dotnet test ChemSim.sln
```

This repository change is a first vertical slice, not a claim that the full A4 specification or MVP is complete.
