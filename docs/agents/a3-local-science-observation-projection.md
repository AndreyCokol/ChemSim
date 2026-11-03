# A3-17 — Local scientific observation projection and Availability semantics

> **A3-18 scientific cross-field check (2026-11-03):** The A3-local observation layer now requires exact W01–W05/G01–G02 fixture species-key sets and matching aqueous method, residual kind, component kind, and solid state, rather than trusting arbitrary finite maps. G01/G02 positive-species par­tial pressures must be proportional to their mole amounts under one ideal-gas T/V; the validator compares `ln(p_i)-ln(n_i)` using scale/ULP-aware tolerances, not an overflowing ratio. These are **synthetic fixture consistency checks, NOT authenticated canonical SpeciesRefs, source-backed model validity or a general equilibrium proof**. [Science and test matrix](a3-local-cross-field-integrity.md). Source/tests commit `19458711c48953b9f59f5c108ada3353bc72ad7f`; [CI #41669588960](https://github.com/AndreyCokol/ChemSim/actions/runs/41669588960) **87 tests / OK**. No A1/A2/A4/A5 or integrator-owned wire changes.

**Date:** 2026-11-03. **Owner/lease:** Agent A3 — Issue #8, Draft PR #4, branch agent/a3-equilibrium-implementation. **Priority:** P1.  
**Scope:** A3 isolated ideal-dilute aqueous and ideal-gas reference fixtures only; NOT an approved cross-agent EquilibriumResult schema, production serializer, source database, Godot bridge, or scientific release gate.

**Test evidence:** source/tests commit `6837754e9b694af8a756de22021b3af764f38571` initially exposed a local W05 unit/domain bug in [CI #41667727732](https://github.com/AndreyCokol/ChemSim/actions/runs/41667727732), **83/84 tests passed, one error**. The issue was fixed at `6535e9abeb8508ad4a3b8f3e10d8fe888533fc42`; [corrective source CI #41667873794](https://github.com/AndreyCokol/ChemSim/actions/runs/41667873794) completed **success; 84/84 tests OK**. The W05 zero-ion log-saturation *unit metadata* is `1` while numerical availability is `not_applicable`; never synthesize a numeric 0, epsilon or -Infinity.

## Implementation and trust boundary

The A3-owned `src/chemsim/equilibrium_observations.py` function `project_local_equilibrium_observations(AqueousResult | GasResult)` revalidates supplied local dataclasses (including forged or modified frozen dataclass instances) and constructs a **JSON-safe scientific observation view**. It does not call the equilibrium solver, interpolate a trajectory, perform source admission, mint stable species refs, evaluate thermodynamic data provenance, or emit the shared envelope.

Return shape explicitly identifies `scope="a3_local_scientific_observations_only"`, `state_kind="single_equilibrium_state"`, local `activity_model`, `scientific_applicability="idealized_approximation"`, `reference_admitted=false`, `redistribution_approved=false`. **Do not treat those two false flags as independent A1 admission/rights evidence**; the function simply never makes such assertions.

Inside A3's private data shape, **availability** has `{"status":"present","quantity":{"value":finite_number,"unit_id":"mol/L|mol|Pa|1"}}` or nonpresent `{"status":"unknown|not_assessed|not_applicable"}`, without `quantity`. That fragment borrows the *semantics* of approved v0.1 Availability but is not the integrator's normative EquilibriumResult/error envelope. All returned objects can be encoded by strict `json.dumps(...,allow_nan=False)` with **no null, NaN or Infinity**. A3-local diagnostic `kind`, `domain_status` and optional `declared_unit_id` do not establish shared wire enums.

## Fixture mapping — executed in the six A3-17 unittest cases

| Fixture / case | Result quantity & unit | Solid state and availability | Diagnostic availability and unit |
|---|---|---|---|
| W01 weak acid | H+, OH-, HA, A- in mol/L; ideal concentration pH unit `1` | `not_modelled` => `not_assessed` (legacy `solid_mol_l=0` is a placeholder) | Charge-equation residual present mol/L; acid mass check present mol/L |
| W02 strong neutralization | H+, OH-, Na+, Cl- in mol/L; approximate pH `1` | `not_modelled` => `not_assessed` | Charge-equation residual present mol/L; spectator output/feed identity **present numeric zero** mol/L but NOT independent scientific validation |
| W03 AgCl(s) excess reservoir | Dissolved species in mol/L; approximate pH `1` | `reservoir_inventory_unknown` => `unknown`, **not** absent solid | Primary and component checks `not_assessed`, no numeric quantities; charge check present mol/L |
| W04 NH3/NH4 buffer | Aqueous species in mol/L; approximate pH `1` | `not_modelled` => `not_assessed` | Charge-equation and nitrogen component checks present mol/L |
| W05 no precipitation | Dissolved ions mol/L; approximate pH `1` | `no_precipitate` => **present computed zero** mol/L | Finite log-saturation index present unit `1` |
| W05 new precipitation | Dissolved ions mol/L; approximate pH `1` | `new_precipitate` => **present positive computed concentration** mol/L (NOT amount mol without volume) | Finite log-saturation index present unit `1`; Ag/Cl component check present mol/L |
| W05 zero-ion boundary | Dissolved ions mol/L; approximate pH `1` | `no_precipitate` => present computed zero mol/L | Log-saturation `not_applicable`; `domain_status="zero_ion_activity"`, `declared_unit_id="1"`, **no numeric quantity** |
| G01 and G02 ideal gases | Species amounts mol; partial/total pressures Pa; extent mol | Solid phase `not_applicable` | Finite gas log quotient present unit `1`; extent update check mol; charge and pH `not_applicable` |

For aqueous results, the projection ensures that the pH interpretation is `ideal_concentration_approximation` and matches `-log10([H+]/c°)` at c°=1 mol/L. It refuses inconsistent gas-vs-aqueous diagnostic model labels, false verified reliability status, nonfinite contents, unavailable-vs-quantity contradictions and physically inconsistent solid phase status. Gas outputs are rechecked via A3's own fail-closed `_gas_result` constructor. The projection maps **one state**, not time-dependent `GraphSeries` samples.

Tests in `tests/test_equilibrium_observations.py` verify seven numeric scenarios plus W05 positive/no/zero-ion variants, strict JSON/no-null output, correct units, preservation of computed zero vs unassessed vs unknown vs not applicable, and rejection of forged malformed AqueousResult/GasResult.

## Blocking integration dependencies — A3-07 remains IN_PROGRESS

- **A1/owner:** scientific source-backed seven-fixture admission (still 0/7), model-quality applicability, K(T)/standard states, source/field redistribution rights and exact match to canonical water-ionization/Ksp/Kp data. No reference constant or third-party text reused/approved by this projection.
- **A2/A1/integrator:** stable phase-qualified SpeciesRef with immutable identity and records, A2 reaction refs/stoichiometry and trusted binding. A3-local species strings are *not* durable identity IDs and must not be serialized as such.
- **Integrator:** approve specific versioned EquilibriumRequest/EquilibriumResult payload, reference association, errors/reliability/availability semantics, phase/solid reservoir status, domain status code mapping, unit registry and serialized test vectors. A3 private observation format is NOT the v0.1 EquilibriumResult payload or final interop API.
- **A5:** use only the approved producer DTO with tested validation. Preserve approximate pH, absence/unknown status, standalone equilibrium state and no fabricated time samples. Windows offline bridge and actual UI source/consumer acceptance still pending.

**Definition of narrow A3-17 DONE:** executable local scientific status/quantity projection + negative tests + exact-head CI. **Product launch is not established**; keep PR #4 Draft, do not merge or modify main/other-agent files.
