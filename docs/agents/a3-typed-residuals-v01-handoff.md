# A3-14 — Scientific residual and pH metadata mapping for seven equilibrium fixtures

**Date:** 2026-11-03  
**Owner/lease:** Agent A3, Issue #8 / Draft PR #4 / `agent/a3-equilibrium-implementation`  
**Status:** **VERIFIED in isolated Python reference fixtures** at code/test commit `3c2106615017bf5dbe4c4feb1aff89e1aee6318c`; [Actions #41661392329](https://github.com/AndreyCokol/ChemSim/actions/runs/41661392329) job `test` **71 tests / OK**. No producer DTO/Godot integration assertion.

## A3-15 — Fail-closed local gas result validation (2026-11-03)

**Status:** A3 Python-only implementation/tests **verified** at `b40f73646435f74d6ee8e013f1a2587c540f1b03`; [exact-source PR CI #41662629358](https://github.com/AndreyCokol/ChemSim/actions/runs/41662629358) `completed/success`, **74 tests / OK**. This expands numeric-result validation without inventing an external gas-phase domain guarantee.

The new internal `_gas_result` checks G01/G02 output integrity before exposing `GasResult`: nonempty matching nonnegative finite amount/partial-pressure dictionaries, nonzero inventory, presence/zero consistency between amount and pressure, finite positive pressure total consistent with the sum of partial pressures, finite extent, nonnegative finite extent-update diagnostic, valid nonnegative integer iteration count, and declared `SolverDiagnostics` model/kind/unit/status consistency. Gas requirements are exactly `gas_ideal_partial_pressure`, finite dimensionless `ideal_gas_log_quotient`, `extent_update_consistency` measured in `mol`, charge `not_applicable` with `None`, and `idealized_approximation` rather than source verification. Invalid values cause `EquilibriumConvergenceError`; no silent default to aqueous/verified/zero.

The unit tests `test_local_gas_result_rejects_false_scientific_diagnostics`, `test_local_gas_result_rejects_inconsistent_amounts_pressures_and_extent`, and `test_local_gas_result_accepts_valid_fixtures_with_frozen_maps` check both normal fixtures and malformed model/amount/pressure/metadata cases. Input signatures, ideal-gas equilibrium mathematics, scalar data assumptions and read-only output mappings are preserved. These checks **do not** certify atom-matrix conservation from the extent-update residual (existing fixed-reaction benchmark tests check the relevant atoms), source-backed `Kp`, gas fugacities, I₂(g) phase stability, temperature applicability, or transport compatibility.

**Integrator/A5 acceptance still required:** type-map the local residual kinds/units and none/not-applicable states into the approved v0.1 `EquilibriumResult`/`Availability`; reject an A3 result if required phase/source/model evidence is missing; show pressure Pa and quantity mol separately; never infer a kinetic trajectory from one gas equilibrium state. No direct dataclass-to-JSON reflection or automatic claim of trustworthy chemistry. A3-07 remains open, A1 source admission/rights and A5 runtime bridge not complete.

## Purpose and approval boundary

The owner approved OpenSpec architecture baseline v0.1 (frozen integrator source `02b8b31706807279ee31a78772383e31f425f7d3`) in `main/openspec/changes/define-chemsim-mvp/APPROVAL.md`. The approved cross-agent contract requires typed residual **kind, unit and scale**, independently qualified pH, missing-value status and distinct reliability axes. This A3-only implementation provides scientific **local field semantics**, NOT a finalized `EquilibriumResult` payload, JSON wire schema, source-licensed property catalog or measured validation.

The backward-compatible `SolverDiagnostics.balance_unit` field is **legacy and not the unit of all residual fields**. A consumer must read each field's explicit `*_kind` + `*_unit` and its own value/status. A zero numeric result must not be confused with `None`/not assessed. Do not reflect local Python dataclasses directly into a shared DTO. P1 A3-07 remains open.

## Fixture-by-fixture scientific meaning

| Fixture | `residual_kind`, unit, finite status | `component_balance_kind`, unit | Charge residual | pH method |
|---|---|---|---|---|
| W01 weak monoprotic acid | `aqueous_charge_equation`, `mol/L`, finite | `aqueous_component_balance`, `mol/L`; HA/A- conservation | `aqueous_charge_balance`, `mol/L` | `ideal_concentration_approximation` |
| W02 HCl/NaOH | `aqueous_charge_equation`, `mol/L`, finite | `spectator_feed_identity`, `mol/L`; Na/Cl direct output-to-input comparison, **not independent experimental conservation evidence** | `aqueous_charge_balance`, `mol/L` | Same ideal approximation |
| W03 AgCl reservoir | `not_assessed`, unit `None`, value `None`, status `not_assessed`; no fabricated numerical-equilibrium residual | `not_assessed`, unit `None`, value `None`; reservoir remaining inventory unknown | `aqueous_charge_balance`, `mol/L` | Same ideal approximation |
| W04 NH3/NH4+ buffer | `aqueous_charge_equation`, `mol/L`, finite | `aqueous_component_balance`, `mol/L`; nitrogen conservation | `aqueous_charge_balance`, `mol/L` | Same ideal approximation |
| W05 AgCl precipitation | `log_saturation_index`, `1`; finite for positive ion activities; when either ion is zero, **value `None`** plus `residual_status=zero_ion_activity` (no `-Infinity` wire number) | `aqueous_component_balance`, `mol/L`; Ag/Cl with precipitated concentration | `aqueous_charge_balance`, `mol/L` | Same ideal approximation |
| G01 NO2/N2O4 | `ideal_gas_log_quotient`, `1`, finite; `ln(Qp/Kp)` | `extent_update_consistency`, `mol`; **not an independent atom-matrix audit** | `not_applicable`, unit `None`, value `None` | Not applicable (gas, no pH) |
| G02 H2/I2(g)/HI | `ideal_gas_log_quotient`, `1`, finite; `ln(Qp/Kp)` | `extent_update_consistency`, `mol`; **not an independent atom-matrix audit** | `not_applicable`, unit `None`, value `None` | Not applicable (gas, no pH) |

All aqueous species concentrations are in mol/L, aqueous ideal activity uses c°=1 mol/L and assumes gamma=1; gas amounts are in mol, pressures in Pa, and the ideal pressure standard is p°=100000 Pa. `residual_kind` describes a *computed check/equation*; it does not establish that the overall thermodynamic model is physically applicable. Do not present pH as thermodynamic activity pH. W05 `solid_mol_l` measures newly precipitated concentration; W03 `solid_mol_l=None` means solid *reservoir quantity unknown*, never zero or phase absent.

## Local validation guarantees (implemented)

1. Aqueous constructors refuse unregistered diagnostic kind/unit pairings, unsupported residual state combinations and gas-only types attached to an aqueous result.
2. A missing W03 numerical residual and mass balance must be explicitly marked `not_assessed`; an unsupported numeric zero is not a substitute.
3. A W05 zero-ion saturation boundary carries `residual=None`, `residual_status=zero_ion_activity` with `residual_kind=log_saturation_index`, unit `1` and compatible no-precipitate phase.
4. W02 spectator audit is named `spectator_feed_identity`; no UI may rename it to an independent component-conservation certificate.
5. Gas results explicitly denote `ideal_gas_log_quotient` and `extent_update_consistency`, not aqueous charge, and mark charge as not applicable.

The test suite `tests/test_equilibrium.py` includes `test_all_seven_fixtures_have_explicit_scientific_residual_units` and `test_rejects_mismatched_residual_kind_units_and_missing_status`, in addition to existing conservation/solver coverage. These are mathematical **synthetic fixtures**, not A1-admitted independently sourced benchmark measurements.

## Proposed producer-v0.1 / A5 handoff acceptance — NOT yet executed

- **A3-DIAG-01:** for each present diagnostic, wire `Quantity.value` finite and `unit_id` an approved registry token (`mol/L`, `mol`, or `1`), with the corresponding scientific kind carried and known to the consumer. No global `balance_unit` inheritance.
- **A3-DIAG-02:** W03 residual and component check exported as typed *not_assessed* or equivalent explicitly reviewed absence; solid reservoir inventory exported as *unknown*, distinct from present zero and from absent solid.
- **A3-DIAG-03:** W05 zero-ion activity status exported as a typed domain boundary, not `NaN`, `Infinity`, `-Infinity`, bare null-as-zero or a fabricated finite saturation index.
- **A3-DIAG-04:** W05 precipitated mol/L must not be presented as mol without actual final volume. pH must preserve `ideal_concentration_approximation` and model applicability.
- **A3-DIAG-05:** G01/G02 lack an evaluated charge constraint; gas quotient is dimensionless, gas component check is extent consistency (mol), and the one equilibrium state does not become a time series.
- **A3-DIAG-06:** missing/incompatible source-backed typed K, reaction/phase/temperature or model applicability must block production computation before calling A3's scalar fixture, independent from local numerical convergence.

**External owners:** integrator owns versioned `EquilibriumResult` payload, contract version, `Availability`, `ErrorEnvelope`, `ReliabilityVector`, bridge and wire compatibility. A1 owns verified thermodynamic constants, source/license and model-domain data. A5 owns typed UI consumption and disabled/unsupported display. A3 owns validating the scientific mapping and later A3-specific adapter tests once the shared payload is reviewed. A4 kinetics is separate (equilibrium K must not be interpreted as reaction rate k).

**Release gate:** Existing 71 Python tests establish local fixture behavior, not scientific-source admission, general nonideal speciation, a complete equilibrium API, serialized v0.1 payload or a working Godot↔chemistry bridge. Keep PR #4 Draft and do not merge to `main` until cross-agent tests and release gates pass.
