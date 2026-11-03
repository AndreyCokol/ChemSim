# A4 gas-formula-compatible synthetic kinetics smoke: N2O4(g) -> 2NO2(g)

**Task:** A4-E2E-CHEM-FIXTURE-01 (P1). **Owner:** A4 Kinetics & Numerical Solver. **Date:** 2026-11-03.  
**Source of fixture suggestion:** A2 handoff in [A4 PR #6](https://github.com/AndreyCokol/ChemSim/pull/6#issuecomment-6606227420). **Authorization:** [owner-approved OpenSpec v0.1](https://github.com/AndreyCokol/ChemSim/blob/main/openspec/changes/define-chemsim-mvp/APPROVAL.md). This document is the **A4 consumer fixture and tests**, NOT a passed A2 parser, verified physical kinetics, A1 source-backed experimental parameter or Godot E2E.

## 1. A2-compatible formula and A4-only engine inputs

The A2-proposed **chemically parseable** formula is `N2O4(g) -> 2NO2(g)` (forward arrow; both phases gas). The species are atom/charge balanced, regardless of whether the real chemical reaction is reversible or has more complex kinetic behavior. This is an intentionally defined **hypothetical irreversible power law solely to test software interfaces**, not an assertion about real nitrogen dioxide/dinitrogen tetroxide kinetics.

The checked-in [A4 request](../../tests/ChemSim.Kinetics.Tests/Fixtures/a4-n2o4-no2-hypothetical-request.json) is a narrow, synthetic-only v0.1 request payload for the existing CLI:
- **Identity:** opaque test-only refs `hypothetical:N2O4:g`, `hypothetical:NO2:g` (record revisions 1). These are **not** canonical IDs produced by A1 nor a `term_id` from A2; a future integration adapter must resolve A2 FormulaAST/phase/revisions to A1-authoritative references and A4 ID membership without using display strings as identity.
- **Signed stoichiometry:** `nu_N2O4=-1`, `nu_NO2=+2`. A2 owns parsing/positive coefficients and exact balance admission; the application adapter owns signed conversion and mapping.
- **Independent rate law:** `r=k c_N2O4` where k is an explicitly hypothetical `0.1 s^-1`, kinetic order for N2O4 explicitly `1`, order for NO2 not specified (equivalent zero for this declared power-law term). k has typed `derived` canonical SI dimensions `mol^0 m^0 s^-1`; **not inferred** from stoichiometry, reverse arrow or thermodynamic K.
- **State:** n_N2O4(0) = 1 mol; n_NO2(0) = 0 mol; V = 1 m3; fixed T = 298.15 K declared identically for the synthetic parameter and model (not source-backed T applicability). Sample times 0, 0.5, 1 s. No inflows/events, temperature dynamics or finite mixing.
- **Two separate supplied sparse element rows:** N counts (`w_N2O4=2`, `w_NO2=1`); O counts (`w_N2O4=4`, `w_NO2=2`). Both are dimensionless atom counts multiplying species amounts (mol). Charge is known zero for the written neutral formulas; **no nonzero charge law** is needed. The A4 CLI accepts these as user-provided laws; it cannot prove that A1/A2 actually generated them or that all formulas are supported.

## 2. Independently derived exact solution and conservation checks

For this **chosen synthetic** first-order model in a fixed volume,

```text
n_N2O4(t) = 1 mol * exp(-0.1 s^-1 * t)
n_NO2(t)  = 2 mol * (1 - exp(-0.1 s^-1 * t))
I_N(t)    = 2*n_N2O4(t) + n_NO2(t)   = 2 mol of N atoms
I_O(t)    = 4*n_N2O4(t) + 2*n_NO2(t) = 4 mol of O atoms
```

This derives from the A4 mathematical power law and initial state, not from a kinetics publication. Model/kinetics provenance stays **`hypothetical`** and `model_applicability=not_assessed`. Do **not** call the experimental rate constant or real gas chemistry verified. Synthetic atom balance is necessary but not sufficient for real-world reaction applicability or verified kinetic time evolution.

Reference values (illustrative, calculated by the analytic solution):

| Time s | n_N2O4 mol | n_NO2 mol | N atom total mol | O atom total mol |
| ---: | ---: | ---: | ---: | ---: |
| 0 | 1.000000000 | 0.000000000 | 2 | 4 |
| 0.5 | 0.951229425 | 0.097541150 | 2 | 4 |
| 1 | 0.904837418 | 0.190325164 | 2 | 4 |

**Proposed executable tolerance gates:** for each published output sample, `abs(n_N2O4 - analytical) <= 5e-8 mol`, `abs(n_NO2 - analytical) <= 1e-7 mol`, `abs(I_N-2) <= 1e-9 mol`, `abs(I_O-4) <= 2e-9 mol`. These are **software-specific test tolerances**, not validated experimental uncertainty or universal chemical tolerances. Failure/partial status and species/time correlation must remain separately checked.

## 3. Concrete A4 evidence and negative tests

- [JSON fixture](../../tests/ChemSim.Kinetics.Tests/Fixtures/a4-n2o4-no2-hypothetical-request.json) explicitly defines all fields and quantity units. Existing [A4 mathematical A -> B fixture](../../tests/ChemSim.Kinetics.Tests/Fixtures/a4-synthetic-request.json) is retained and labelled **A4-only**, not a chemical parse fixture.
- [A4 xUnit tests](../../tests/ChemSim.Kinetics.Tests/CliChemistryFixtureTests.cs) run the **actual A4 CLI adapter** with this JSON. Positive scenario requires successful correlated v0.1 response, three validated samples, analytic profile, independent N/O invariants, correct hypothetical provenance and no scientific-verification claim.
- Negative scenarios: (1) atom imbalance `N2O4 -> NO2` with original N/O laws => `blocked`; (2) omitted independent kinetic-order array => `blocked`; (3) stale species reference revision => `blocked`; (4) reversible/equilibrium arrow => `blocked`. Each failure produces **zero** samples and a typed A4 input error, rather than pretending a completed time course.
- [CI workflow](../../.github/workflows/a4-dotnet.yml) runs the fixture through a compiled CLI as an independent **Linux process** and through the **published self-contained win-x64 executable** in a Unicode temporary folder on a GitHub-hosted Windows runner, asserting correlated outcome, analytic profile and both element totals.

## 4. Remaining integration responsibility and blockers

| Integration stage | Owner | Required proof; NOT supplied by this fixture |
| --- | --- | --- |
| A2 parser | A2 | Actual GDScript parse/serialize/check_balance for original `N2O4(g) -> 2NO2(g)`, exact element and charge counts, phase and UTF-8 source spans, verified signed stoichiometric adapter. A4 does NOT execute A2 source. |
| Stable canonical identities and provenance | A1 + integrator | Approved `SpeciesRef` IDs/revisions, full formula-AST binding, known-zero versus unknown elemental coverage, unit and kinetic-parameter validity. Hypothetical test IDs do not make this a chemically admitted real experiment. |
| A4 numerical engine | A4 | Correctly validated first-order synthetic trajectory, independent element rows, narrow serializable result status, finite values, partial-run diagnostics, Windows and Linux subprocess proof. |
| Godot process/controller and UI | A5 + integrator | Sandbox nonce/path security, bounded asynchronous child process, request/response correlation, result/sample/GraphSeries adapter, gap/partial presentation, no fabricated rate/replay/T series. A4 cannot mark a complete Godot graph from its own subprocess CI. |
| Distribution | A5 + integrator | Offline clean Windows 10/11 x64 installation/launch without SDK/network, real Godot → CLI → Godot smoke, packaging/license/diagnostic validation and exact artifact evidence. |
| Full ChemSim science MVP | All / owner | Source-backed aqueous/gas equilibrium and kinetic models, open flows/events and rewind scope, model-specific validation and release acceptance; **not replaced by this engineering staging fixture**. |

**Handoff request:** integrator/A1/A2/A5 should use this exact fixture as a transparent *A4-side* consumer candidate and report any necessary mapping revisions before declaring integrated acceptance. Changes to common DTOs, parser or UI remain owned by their agents.

**Status rule:** this task can be marked DONE only when the exact A4 source/test head has passing GitHub Actions .NET tests and Linux/Windows process fixture checks. Even then, A4-E2E-MVP remains **PARTIAL** until actual A2/A5 integration.
