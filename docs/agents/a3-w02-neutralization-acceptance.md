# A3-09 — W02 strong-neutralization scientific acceptance and minimal integration slice

**Date:** 2026-11-03  
**Owner:** Agent A3 — Aqueous Chemistry & Equilibrium  
**Tracking:** A3 Issue #8 / Draft PR #4 / branch `agent/a3-equilibrium-implementation`  
**Status:** A3-owned P1 **SPECIFICATION FOR REVIEW**; scientific interface and production adapter **BLOCKED** by OpenSpec owner approval and shared contract decisions. This document does **not** authorize code changes, approve a source constant, define wire DTOs, or reassign A1/A2/A5/integrator work.

## 1. Why W02 first

A1 selected AQ-02 / A3 W02 as a narrow candidate for the first source-backed, offline chemistry calculation. The implementation is `solve_strong_neutralization(hcl_mol_l, naoh_mol_l, kw)` in `src/chemsim/equilibrium.py`. It has fewer chemical-model requirements than a general reaction network, but **it still needs Kw**, typed source applicability and shared result semantics. A1's [P1 field matrix](https://github.com/AndreyCokol/ChemSim/blob/openspec/review-round-1/openspec/reviews/round-1/a1-mvp-assertion-field-matrix.md) and [admission manifest](https://github.com/AndreyCokol/ChemSim/blob/openspec/review-round-1/openspec/reviews/round-1/a1-seven-benchmark-admission-manifest.md) mark AQ-02 **NOT ADMITTED**. The `1.0e-14` used in existing tests is an illustrative algorithm input, **not** a validated, temperature-matched catalog record.

This slice demonstrates **one equilibrium state after fully dissociated feed concentrations have been supplied**, not a reaction time history, finite mixing model, heat balance, or general chemistry API. If the UI starts from raw reaction text, A2 parsing/balancing and integrator reaction/identity mapping are separate upstream steps. A3 must not implement its own parser.

## 2. Exact W02 mathematical problem (model-specific, not universal)

Assumptions:

1. Ideal-dilute aqueous mixture: activity coefficients `gamma_i = 1`; concentration standard `c° = 1 mol/L`; liquid water activity treated as 1.
2. Both feed arguments are **analytical concentrations in the final, already mixed solution** (mol/L). They are **not** incoming stream rates, initial separate vessel concentrations, mole amounts, or inferred from visual positions. If given source vessel amounts `n`, computing final `C = n/V_final` requires explicit valid positive final volume and an approved instantaneous-mixing/volume policy outside this fixture.
3. HCl and NaOH are assumed completely dissociated to aqueous H+/Cl− and Na+/OH−; dissolved species considered are H+, OH−, Na+, Cl−. No activity corrections, buffers, other counterions or secondary complexes.
4. `Kw > 0` is **dimensionless** for the declared reaction H2O(l) ⇌ H+(aq) + OH−(aq) under the selected model and matching standard-state, medium and temperature convention. It is **not** a kinetic rate constant and never implies a neutralization timescale.
5. The model must be scientifically eligible at the actual solution T/pressure/medium. Current Python W02 accepts **no temperature argument**, no provenance and no explicit applicability metadata. A future approved adapter must validate these conditions before extracting the scalar Kw; do not assume 25 °C or the broad proposed water temperature range as guaranteed validity.

Set `A=C_HCl`, `B=C_NaOH`, `d=A-B` (all mol/L), `h=[H+]`, `o=[OH−]`, and `kappa=Kw*(c°)^2` (mol/L)^2. Then:

- Strong electrolyte spectators: `[Cl−]=A`, `[Na+]=B`.
- Charge neutrality: `h + B = o + A`; equivalently `h - o - d = 0`.
- Water equilibrium: `(h/c°)*(o/c°)=Kw`, i.e. `h*o=kappa`.
- Positive solution: `h=(d+sqrt(d^2+4*kappa))/2`; for `d<0` use the algebraically equivalent cancellation-resistant expression `h=2*kappa/(sqrt(d^2+4*kappa)-d)`; `o=kappa/h`.
- `pH_ideal_concentration=-log10(h/c°)` only; **not** thermodynamic `-log10(a_H+)` unless independently validated activity conventions justify that relationship.

The formulas define an **independent analytical oracle** for moderate representable test inputs. The numerical test oracle must avoid avoidable cancellation and overflow (e.g. scaled hypotenuse or appropriate precision) and not use A3's internal solver output to define its own expected values. The current log-bracketed solver can remain a separate numerical method. Extreme `1e±100` style tests demonstrate numerical behavior, **not** physically applicable ideal-dilute concentrations.

## 3. Required A3 scientific output semantics

| Output | Scientific meaning | Present fixture field | Prohibited inference |
|---|---|---|---|
| H+, OH−, Na+, Cl− | Nonnegative aqueous concentrations (mol/L) at a single equilibrium state | `species_mol_l` | Phase/species identity from strings as permanent DTO keys |
| pH | Dimensionless **ideal concentration approximation** at gamma=1 | scalar `pH` | Thermodynamic activity pH, universal accuracy, or physically valid pH outside chosen model domain |
| Charge residual | Charge-equation residual in mol/L, scaled to feed/ionic concentration | `charge_balance_residual`, `residual` | Universal solver tolerance or certificate of thermodynamic/model validity |
| Spectator balances | `[Cl−]≈A`, `[Na+]≈B`, independently checked | `component_balance_residual=0.0` is currently **hard-coded** | The zero field alone proves an independently executed mass-balance audit |
| Equilibrium residual | Relative/log water quotient `ln((h/c°)(o/c°)/Kw)` for positive values | Not returned as a separate typed diagnostic | `charge_balance_residual=0` also proves water equilibrium |
| Numerical/model status | Solver convergence vs source/model applicability vs completeness | local `idealized_approximation` flag | Source-admitted, production-ready or experimentally validated |

The current `SolverDiagnostics.component_balance_residual=0.0` in W02 is a **placeholder** because the function copies spectator concentrations from the input. A future typed scientific result must not advertise that field as an independent invariant check unless the check is actually performed. Source and result qualifiers cannot be reconstructed solely from W02's return dataclass.

## 4. Proposed minimal W02 contract admission gate (A3 consumer requirements)

Before invoking the fixture from an application workflow, the eventual approved A3 adapter must verify all items below or return an explicit *blocked* result with owner-approved ErrorEnvelope semantics:

1. **A1:** stable species/reaction identity; aqueous phases and charges (+1 H+/Na+, −1 OH−/Cl−); complete-dissociation approximation declared. If species were parsed through A2, consume the validated A2/identity contract and preserve source diagnostics.
2. **A1:** exact **Kw** reaction identity and direction; positive finite dimensionless value; compatible basis/standard-state reference, ideal-dilute gamma=1 model, solvent/medium, source/revision/method/uncertainty-or-not-reported, origin/quality/review/model eligibility and redistribution disposition separately.
3. **A1/integrator:** chosen calculation T (and P if required by the source/model) is **explicit**, within the source and model applicability envelopes; no guessed 298.15 K, thermodynamic extrapolation or unstated K(T) correction.
4. **A5/integrator:** input concentrations are typed **mol/L final-mixture analytical totals**, finite/nonnegative and **not both zero** for this specific fixture; any amount→concentration conversion requires approved units and final-volume data.
5. **A3:** constants and feeds are model-compatible; reject unknown phase, missing Kw, wrong basis, nonideal activity request, outside-validity condition or an unsupported extra solute; do not silently solve a different model.
6. **A3/A5:** result carries separately the pH approximation qualifier, quantities/units, exact model identity/version, numerical termination, scientific applicability, provenance/completeness and actionable warnings. No invented precision/“accuracy percentage”.
7. **Integrator/A5:** Python-to-Godot runtime bridge, serializer, version, Unit Registry and ErrorEnvelope are approved and tested; this document does not choose bridge technology or schema tokens.

A1's *local scientific eligibility* and *redistribution rights* are separate decisions: successful W02 numerical math does not authorize bundling a constant in an offline release.

## 5. A3-owned acceptance cases (design only — not executed tests)

| Test ID | Given | Required independent check / behavior | Status |
|---|---|---|---|
| A3-W02-AC01 | Compatible, **synthetic** `A=B=0.01 mol/L`, `Kw=1e-14` at explicit matching synthetic conditions | `h=o=sqrt(Kw)*c°`, `pH≈7`; charge balance, spectator totals and water quotient pass declared independent tolerances | SPEC ONLY |
| A3-W02-AC02 | Synthetic acid excess `A=0.01`, `B=0`; same synthetic Kw | Independent quadratic oracle; H+ dominates OH−; `[Cl−]=A`, `[Na+]=0` and `h*o/(c°)^2≈Kw` | SPEC ONLY |
| A3-W02-AC03 | Synthetic base excess `A=0`, `B=0.01`; same synthetic Kw | Cancellation-resistant base-side oracle; OH− dominates H+ and independent charge/water equilibrium checks | SPEC ONLY |
| A3-W02-AC04 | Synthetic small nonzero `d` around equivalence and both-sided trace feeds | Continuous nonnegative solution, consistent charge and water quotient; independent absolute + scale-aware relative criteria (not one global epsilon) | SPEC ONLY |
| A3-W02-AC05 | Both input feeds zero; negative feed; NaN/Inf; booleans/strings; `Kw<=0` | Low-level W02 rejects invalid numeric inputs; pure-water case belongs to separately declared problem, not silently normalized to W02 | SPEC ONLY (existing validation tests cover some cases) |
| A3-W02-AC06 | Typed Kw missing/wrong reaction direction/wrong standard state/nonideal basis/T out of range | Application calculation blocked before calling numerical solver; missing fields and applicable cause retained | BLOCKED: shared DTO |
| A3-W02-AC07 | Final volume missing but UI provides moles or separate-vessel concentrations | No arbitrary conversion to W02 mol/L; request defined final volume/approved mixing model or block | BLOCKED: Unit Registry + application |
| A3-W02-AC08 | Numerical solution converges but A1 source has no admission/review rights | Mathematical diagnostic may be local exploratory only if approved policy allows; no verified/catalog/distribution claim | BLOCKED: A1 admission and policy |
| A3-W02-AC09 | W02 result consumed in A5 Godot | pH explicitly qualified, species phase/units preserved, one equilibrium state only, separate numerical/model/data statuses, no time series | BLOCKED: integrator + A5 |
| A3-W02-AC10 | `component_balance_residual=0.0` on W02 output | A3 independent spectator audit must actually check `[Na+]-B` and `[Cl−]-A`; never infer a certificate from a hard-coded zero | SPEC ONLY; A3-owned scientific diagnostics correction requires owner approval |

For computational validation, each admitted test needs exact data/model revision, independent expected value/derivation, individual absolute/relative tolerance appropriate to **charge (mol/L)**, **water log quotient (dimensionless)**, **pH (dimensionless)**, and exact spectator component identities. An acceptance test passing on synthetic inputs is **not** an A1-approved reference benchmark.

## 6. Ownership and readiness

| Task | Priority/status | Owner | Objective release evidence |
|---|---|---|---|
| W02 scientific model/oracle/negative contract | **P1 — A3 SPECIFICATION IN PROGRESS** | A3 | This reviewed document; post-approval A3 scalar/adapter tests with exact-head CI |
| Source-backed, compatible typed Kw and phase/charge/data eligibility | **P1 — BLOCKED** | A1 | Admitted evidence row including conditions, version, uncertainty, rights |
| Formula/species/reaction mapping if user starts with text | **P0 — BLOCKED** | A2 + integrator | Versioned shared species identity, phase and reaction interface |
| Typed quantities, ErrorEnvelope, ReliabilityVector and runtime bridge | **P0 — BLOCKED** | Integrator + owner | Approved OpenSpec/API, tested Godot↔chemistry runtime crossing |
| One-state display and consumer acceptance | **P1 — BLOCKED** | A5 | A5-approved view contract and tests without false zero/model claims |
| Actual W02 adapter and hard-coded-zero correction | **P1 — BLOCKED** | A3 after owner approval | Implemented A3-owned slice + independent invariant tests + exact CI |
| Nonideal models, general reaction networks, multi-solids, kinetics/time history | **P2/P3 — DEFERRED** | Other approved scope | Not required for this narrow W02 vertical slice |

**Decision requested of integrator/owner:** confirm W02 as first supported end-to-end equilibrium state scenario, or name a different first slice; approve the shared domain/result contracts and OpenSpec baseline *before* any production adapter implementation. Keep PR #4 Draft and A3-07 open until those conditions are met.
