# A3-10 — Review of integrator interchange v0.1 and W02 Kw source candidate

> **A3→A1 direct scientific disposition (2026-11-03, A3-07):** **M = conditionally acceptable as a 298.15 K *illustrative ideal-concentration W02 model-convention candidate*, NOT scientifically admitted reference data.** The first-edition §14.1 expresses a 25 °C concentration product and hydronium species. In W02 ONLY, `c°=1 mol/L` normalization and an explicit `H₃O⁺(aq)` ↔ hydrated-`H⁺(aq)` notation mapping are acceptable **when** the model is `γ=1`, water solvent activity is assumed one, reaction direction/medium/phase and T match, and pH is flagged as an ideal-concentration approximation. Numerical coefficient `1.0×10^-14` has about **two significant figures**, no reported uncertainty, no admissibility at other T/P/media or arbitrary ionic strength; W02 still has no T input and its caller must validate T=298.15 K explicitly. A1 retains provenance/data quality/reaction identification/model-eligibility gating; owner decides whether an *illustrative* scenario is acceptable for release.
>
> **R = `blocked_unknown_license` / do not bundle or redistribute.** Re-review of the *same* [first-edition OpenStax preface](https://openstax.org/books/chemistry/pages/preface) found a historical CC BY 4.0 paragraph **and contradictory later Citation/Attribution text** describing noncommercial/CC BY-NC-SA, share-alike and AI-offering restrictions; [current OpenStax licensing help](https://help.openstax.org/s/article/Openstax-textbook-licensing-and-customization) states CC BY-NC-SA. This is a **rights conflict**, not an A3 license clearance. Earlier rights wording below is historical and superseded by this notice. A1/owner must obtain definitive field/channel-specific permission or select a properly approved alternative. Model M and redistribution R remain independent, and all seven A1 numeric benchmark rows remain unadmitted.
>
> **Runtime/contract:** no direct raw `Kw` catalog import, no default temperature, no generic IAPWS molal/PHREEQC activity copy, and no real Godot producer bridge claims. A3-14/A3-15 local fixture validation is complete (latest [CI #41662861409](https://github.com/AndreyCokol/ChemSim/actions/runs/41662861409), **74 tests**), while A3-07 real adapter and scientific admission stay open.

> **Authorization status update — 2026-11-03:** The pre-approval review status and words 'no implementation authorization' below describe the document at drafting time. Product-owner **APPROVAL.md** on `main` now records **APPROVED** OpenSpec v0.1, frozen integrator baseline `02b8b31706807279ee31a78772383e31f425f7d3`. A3 may implement scoped producer logic and tests (already executed in `1334064` and `c592c53`, exact-head [CI #41658491074](https://github.com/AndreyCokol/ChemSim/actions/runs/41658491074), **67/67 tests**). **Still NOT approved:** source/reference-data scientific admission, distribution rights, claims of W02 real-world validity, and untested final shared payload or Godot bridge. The A3-V01..07 contract risks below still require producer/integrator/A5 executable mapping proof. Treat the OpenStax W02 Kw as a conditional *model-convention candidate*, not an A1-admitted reference.


**Date:** 2026-11-03  
**Owner:** Agent A3 — Aqueous Chemistry & Equilibrium  
**Scope:** A3 scientific producer/consumer review only, Issue #8 / Draft PR #4, branch `agent/a3-equilibrium-implementation`  
**Status:** **A3 P1 SCIENTIFIC REVIEW / NO SHARED DTO FREEZE / NO BENCHMARK ADMISSION / NO IMPLEMENTATION AUTHORIZATION**.

Inputs reviewed:
- Integrator [cross-agent candidate v0.1](https://github.com/AndreyCokol/ChemSim/blob/openspec/review-round-1/openspec/contracts/mvp-cross-agent-contract-v0.1.md), [JSON envelope candidate](https://github.com/AndreyCokol/ChemSim/blob/openspec/review-round-1/openspec/contracts/interchange-envelope-v0.1.schema.json), [bridge / acceptance plan](https://github.com/AndreyCokol/ChemSim/blob/openspec/review-round-1/openspec/contracts/mvp-bridge-and-acceptance-v0.1.md) and [integrator decision closure](https://github.com/AndreyCokol/ChemSim/blob/openspec/review-round-1/openspec/reviews/round-1/integrator-closure-2026-11-03.md). Cross-module semantics are **INTEGRATOR-DECIDED CANDIDATE**, not owner-approved runtime API.
- A1 [source/basis/license Kw evidence memo](https://github.com/AndreyCokol/ChemSim/blob/openspec/review-round-1/openspec/reviews/round-1/a1-kw-source-compatibility-review.md), A1 PR #4 comment `6606375952`, A3 [W02 acceptance specification](a3-w02-neutralization-acceptance.md) and [A3→A5 results handoff](a3-a5-equilibrium-result-handoff.md).
- Official OpenStax *Chemistry* **first edition**, §14.1 (https://openstax.org/books/chemistry/pages/14-1-bronsted-lowry-acids-and-bases) and its edition-specific preface (https://openstax.org/books/chemistry/pages/preface), independently inspected on 2026-11-03.

## 1. A3 scientific answer to A1: OpenStax 25 °C Kw candidate

**Answer: ACCEPTABLE AS A *CONDITIONAL IDEALIZED EDUCATIONAL MODEL INPUT CANDIDATE* FOR W02, NOT ADMITTED AS A VERIFIED THERMODYNAMIC REFERENCE.** The *model-convention match* is scientifically justified under the following explicit qualifications; A1 still owns data-quality/provenance/licensing/admission and the product owner owns reference-vs-exploratory policy.

### Evidence and transformation

The cited first-edition §14.1 displays the water autoionization reaction with aqueous hydronium and hydroxide, the **concentration product** `Kw = [H3O+][OH-]` at **25 °C**, and the approximate value `1.0 × 10^-14` (two significant figures). It also shows `[H3O+]=[OH-]=1.0×10^-7 M` at that temperature. The textbook source formula is expressed in concentrations, not an already typed dimensionless thermodynamic activity standard state. The same book's preface contains **conflicting license notices**: historical CC BY 4.0 language and a later Citation/Attribution section describing noncommercial/CC BY-NC-SA, share-alike, commercial and AI restrictions. This source conflict **does not grant bundling rights**; A1 marks field/channel redistribution **R=blocked_unknown_license** until authoritative clarification.

For the **explicit A3 ideal-dilute W02 model only**, let `c°=1 mol/L` and `γ_H=γ_OH=1` by assumption. Transform the source's concentration product with physical concentration units into the **dimensionless model constant**

`Kw_model = ([H3O+]/c°)([OH-]/c°)`.

With `c°=1 mol/L`, the numerical coefficient remains approximately `1.0e-14`; the *dimensional normalization is explicit*, not a claim that the source measured activities, supplied a thermodynamic standard-state record, or established a universal standard. Preserve the original source expression/convention, the normalized derived model assertion, its transformation `/c°^2`, and parent/source provenance. No direct substitution of an IAPWS **molal** constant or PHREEQC activity `log K` into this field.

The source uses `H3O+(aq)`; A3's scalar solver uses `H+(aq)` as a hydrated-proton **shorthand**. This is acceptable only as an explicit **model notation/solvent convention** mapping for the same charge and aqueous species role. It is **not** a general species-identity equivalence, an additional solved H3O+ species, permission to double-count both forms, or a silent conversion between distinct thermodynamic hydration conventions. A1/A2/integrator must record the mapping on the reaction/constant basis.

### Strict eligibility envelope

| Requirement | A3 disposition |
|---|---|
| **Temperature** | Run T must be explicitly **298.15 K (25 °C)** for this source value; the current scalar W02 has no T parameter, so an eventual approved call adapter must enforce this. No extrapolation or silent reuse for a new T. |
| **Pressure, solvent and phase** | Water medium and aqueous hydronium/OH−; liquid water solvent with its activity assumed unity. Source does not independently certify W02's pressure dependence or arbitrary solution composition; source/model applicability must be reviewed for any selected P/medium. |
| **Approximation** | `γ_i=1` is **assumed**, not empirically verified for all feed ionic strengths. W02 `pH=-log10([H+]/c°)` is an ideal concentration approximation, never unqualified activity-based pH. |
| **Precision and uncertainty** | Approximate **two significant figures**; quantitative uncertainty **not reported** by the textbook, never zero. No extra precision, interpolation or measurements are inferred. |
| **Scientific and data quality** | Educational concentration-model source, candidate for *explicitly qualified illustrative* AQ-02/W02; not a high-precision thermodynamic reference, not a proven real-mixture validation at `0.01 mol/L`, not license-reviewed/admitted automatically. |
| **Provenance and distribution** | A1 keeps original URL, exact edition/section, page revision/retrieval, and both contradictory first-edition license notices. **R=blocked_unknown_license** until explicit channel/field-specific clearance; do not assume CC BY 4.0 or substitute `Chemistry 2e` license/edition. |
| **Runtime gate** | Owner approval + compatible typed Kw assertion + model-specific eligibility + source rights policy + integrator schema + A5 approximate-result presentation, *then* A3 adapter/test implementation. |

Consequently the answer to A1's question is **yes, conditionally for the declared educational W02 concentration model at an explicitly selected 298.15 K**, not yes as a universal `Kw` and not a declaration that any of the seven A1 benchmark rows is now admitted.

## 2. Integrator v0.1: A3 compatibility review

The integrator candidate **aligns in principle** with A3 on all the core science boundaries: stable phase-qualified SpeciesRef, charge owned by FormulaAST, distinction between thermodynamic K and kinetic k, aqueous model-specific `γ=1, c°=1 mol/L`, gas `p°=1 bar`, typed availability, separate reliability axes, qualified pH, single equilibrium state, no imaginary time series, separate solid reservoir/inventory and nonfinite saturation-boundary semantics. This is a **favorable conceptual review**, not claim of runtime compatibility.

| ID / priority | Exact reviewed contract surface | A3 finding / action requested | Owner |
|---|---|---|---|
| A3-V01 / P0 | `interchange-envelope-v0.1.schema.json` defines `kind=equilibrium_request|equilibrium_result` but `Envelope.payload` is only `type: object`; no A3 model-specific payload schema is provided | **Incomplete machine-checkable boundary, openly acknowledged by integrator:** a JSON envelope may pass structural validation with missing model/basis/standard state/required Kw/pH qualifier. Add a *versioned A3 equilibrium request/result payload contract* and positive/negative examples before enabling an adapter. Do not infer acceptance from envelope-only validation | Integrator schema + A3 producer review |
| A3-V02 / P0 | Narrative §1 requires response `request_message_id` and `outcome` while schema `Envelope.required` includes neither unconditionally nor conditionally | A response may be schema-valid without request correlation or terminal state. Request a conditional **response-kind** requirement with safe rejection (and appropriate nonresponse request policy), before runtime A3 use | Integrator |
| A3-V03 / P0 | Narrative §3 lists `ThermoConstantRef` attributes but common envelope only defines `Reference`, `Quantity`, `Availability`, `ReliabilityVector` | No validated thermodynamic constant kind/orientation/temperature/standard-state/source/review mapping exists in machine-readable wire shape. A3 must **fail closed** on absent/incompatible typed Kw and exact H3O+/H+ model mapping; never infer from raw `dimensionless_value` alone | A1 + integrator + A3 |
| A3-V04 / P1 | Narrative §3 specifies typed `EquilibriumResult`, while current A3 Python results reuse scalar `pH`, generic `balance_unit`, `solid_mol_l`, gas `activity_model=ideal_dilute_gamma_equals_1` and numerical placeholders | Need type-specific scientific residuals and applicability; distinguish W03 reservoir quantity unknown, W05 newly precipitated concentration mol/L, W05 `-inf` inactive saturation **semantic boundary**, gas ideal partial-pressure model, gas charge `not_applicable` (not measured zero). No raw dataclass → JSON reflection | A3 producer; integrator shared semantics; A5 consumer |
| A3-V05 / P1 | `Availability.status` has `present|unknown|not_reported|not_assessed|not_applicable|withheld`; `Quantity.value` is JSON number; `ReliabilityVector` has independent axes | Correct direction. Future A3 wire must distinguish unknown from **computed zero**, absence of charge test from **charge residual 0**, and true `Q=0` saturation boundary from a fabricated `ln(Q/K)=0`. Never emit NaN/±Infinity to JSON. Need per-result field semantics and tests | A3 + integrator + A5 |
| A3-V06 / P1 | Integrator bridge explicitly leaves A3 Python packaging undecided; A4 .NET CLI is only a suggested first kinetic smoke | No verified Windows offline A3 executable/port/CLI or UI adapter exists; do not equate successful Python fixture CI with deployable Godot equilibrium feature. A3 solver runtime is not a mandatory dependency of A4's first synthetic kinetic smoke | Integrator + A5 + A3 |
| A3-V07 / P1 | Numeric data source/admission and owner approval are separate gates | The OpenStax W02 model-convention *candidate* does not close A1 licensed source admission, T/P/medium eligibility, reference uncertainty/precision or benchmark expected-value testing. Keep provenance/quality, numeric convergence, model applicability, and legal redistribution separate | A1 + owner + A3 |

### Negative acceptance vectors (design only, NOT executed)

1. **Schema structural gap:** `kind=equilibrium_result` plus empty object `payload={}`, `errors=[]`, without `request_message_id` or `outcome`, presently satisfies the *generic envelope shape* (given valid UUID/version). This must **not** be accepted by an actual equilibrium-result consumer.
2. **Unqualified thermodynamics:** W02 input has numeric `1e-14` but no kind/reaction/phase/standard state/source or declared T. Reject even if the number is mathematically usable by Python.
3. **Source basis confusion:** IAPWS molal pKw or PHREEQC activity logK passed directly as concentration-normalized Kw. Reject without reviewed transformation and retained parent evidence.
4. **False scientific verification:** OpenStax 25 °C illustrative Kw used at a different T or displayed as an exact high-precision measured thermodynamic constant, source-proven experiment, or nonideal model; block/label appropriately.
5. **False solid quantity:** W03 excess AgCl(s) reservoir displayed as absent because local `solid_mol_l=0`, or W05 mol/L precipitate shown as mol without final volume. Reject.
6. **Invalid residual transport:** W05 zero-ion `-inf` encoded as standard JSON numeric scalar, or log-saturation index displayed as mol/L charge residual. Reject in serializer/consumer.
7. **False gas chemistry:** G01/G02 numeric result mapped to an aqueous gamma=1 model or charge residual marked verified merely because prototype field is zero. Reject.
8. **False timeseries:** A3 equilibrium result consumed as A4 trajectory or a graph with generated timestamps. Reject.

These are proposed post-approval adapter/contract tests. The published generic JSON envelope is **not a chemically validating equilibrium schema** and passing current 65 Python fixture tests does not exercise these interchange cases.

## 3. A3 action/ownership matrix after this review

| Work item | Priority / status | Evidence needed for closure |
|---|---|---|
| A3-10 scientific review of v0.1 and A1 Kw candidate | **P1 — spec-only complete after GitHub evidence** | This A3-owned document, explicit answer to A1 and integrator/A5 review comments |
| A3-07 shared integration boundary | **P0/P1 — IN_PROGRESS / production BLOCKED** | Owner baseline sign-off, integrator domain-specific result schema and response envelope validation, A1 typed/source-approved Kw, A5 contract acceptance, Windows A3 runner/interop proof |
| A3 own fixture diagnostics corrections | **P1 — BLOCKED pending owner implementation authorization** | Independently measured typed residual semantics and narrow source/tests after approval (not retroactively claimed) |
| P2/P3 scientific extensions | **DEFERRED** | Nonideal aqueous/gas, multiple solids, generalized equilibrium networks, equilibrium-to-kinetic coupling |

**No shared contract, A1/A2/A4/A5 source, A3 runtime code or `main` modification is authorized by this review; PR #4 remains Draft.**
