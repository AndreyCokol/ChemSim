# A3-18 — Local equilibrium fixture identity and pressure-law integrity

**Date:** 2026-11-03. **Owner/lease:** Agent A3 — Issue #8, Draft PR #4; branch agent/a3-equilibrium-implementation. **Priority:** P1.  
**Code/test commit:** `19458711c48953b9f59f5c108ada3353bc72ad7f`. **Verified CI:** [GitHub Actions #41669588960](https://github.com/AndreyCokol/ChemSim/actions/runs/41669588960) completed **success, 87/87 tests OK**.

## Narrow scientific risk addressed

Before A3-18, the local observation projection rechecked finite numerical values, pH method, reported units, and generic diagnostics. A forged or cross-mixed AqueousResult could nevertheless claim a valid equilibrium observation while including extraneous, missing or wrong-model species; a forged GasResult could change one par­tial pressure and the total pressure together to preserve the total=sum(partials) invariant but violate ideal-gas partial-pressure proportionality `p_i/n_i = RT/V` for a single well-mixed state.

Because v0.1 cross-agent SpeciesRef identity and source admission remain outside A3 scope, this is **only** a fail-closed *local scientific fixture shape* check, not an authoritative species identity mapper or a general speciation-network validator.

## Implemented invariants

A3-owned `src/chemsim/equilibrium_observations.py` now checks exact local species rosters and fixed fixture semantics before publishing A3 private observations:

| Fixture | Exact local species roster | Local scientific diagnostic and phase requirements |
|---|---|---|
| W01 weak acid | HA, A−, H+, OH− | aqueous charge residual, component balance; no solid modelled; log-space bisection |
| W02 strong neutralization | H+, OH−, Na+, Cl− | aqueous charge residual, *spectator-feed identity* component kind; no solid modelled; log-space bisection |
| W03 AgCl excess solid | Ag+, Cl−, H+, OH− | residual and component *not assessed*; unknown solid-reservoir inventory; closed-form ideal solubility |
| W04 ammonia buffer | NH3, NH4+, H+, OH−, Cl− | aqueous charge residual and nitrogen component balance; no solid modelled; log-space bisection |
| W05 AgCl precipitation | Ag+, Cl−, Na+, NO3−, H+, OH− | **log saturation index** (not an aqueous charge primary residual); no/new precipitate state and matching inactive-solid/active-set method; no finite log for a zero-ion state |
| G01 NO2/N2O4 | NO2, N2O4 | ideal gas, amount mol, partial pressure Pa; one common positive-species `ln(p_i/n_i)` |
| G02 H2/I2(g)/HI | H2, I2(g), HI | explicit gas iodine notation and same positive-species ideal-gas pressure/amount relationship |

The gas validator compares `ln(p_i)-ln(n_i)` for every species with positive amount, with a floating-point tolerance and an ULP-scaled allowance for near-subnormal positive pressures. This avoids overflow of a direct `p_i/n_i` quotient. It does **not** reconstruct the actual temperature or volume, certify the iodine gas phase physically stable, infer source Kp or establish energy balance; those are external science/model gates. Individual zero-amount species are already checked by the prior `_gas_result` amount/pressure zero-consistency rule.

All output remains tagged `scope=a3_local_scientific_observations_only`, `reference_admitted=false`, `redistribution_approved=false` and one equilibrium state; A3-17 JSON-safe, typed availability/units and pH behavior are preserved.

## Executed tests

Three additional regression tests in `tests/test_equilibrium_observations.py` cover:

1. Cross-fixture/malformed aqueous states: extra/missing species, W01 results relabeled with W02 species, false spectator vs component-balance meaning, W03 assessed diagnostics in place of unassessed, W05 charge residual mislabeled as log saturation, and W05 false no-solid status.
2. Gas pressure law: modify G01 NO2 partial pressure and update P_total so generic finite/sum checks pass; the new **common p/n** check must reject it.
3. Gas identity: unknown gas roster rejected; the existing G02 extreme finite large-amount/temperature/volume case still passes the scale-aware law check.

**Source CI #41669588960:** 87 tests / OK (previous 84 + 3), no other agent paths modified.

## External acceptance gates remain open — A3-07

- **A1 / scientific owner:** source-backed Ka/Kw/Ksp/Kp records, exact temperature/phase applicability and distribution rights; seven reference benchmarks still not scientifically admitted.
- **A2/A1/integrator:** canonical trusted SpeciesRef/FormulaAST/Reaction identities and immutable revisions. Local formula-string keys are *not* durable IDs and cannot authenticate origin.
- **Integrator:** reviewed v0.1 `EquilibriumResult` payload with precise conditions/source association, Availability, ReliabilityVector, ErrorEnvelope and concrete consumer test vectors. This local dictionary is NOT the shared schema.
- **A5:** actual Godot consumer and offline Windows x64 integration; a successful Python scientific projection does not prove UI acceptance or Windows packaging.

**Conclusion:** A3-18 DONE only for narrow supported-fixture consistency and tests; A3-07 real end-to-end producer/consumer acceptance remains IN_PROGRESS. No main merge or shared-contract change.
