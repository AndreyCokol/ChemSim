# A1 P1 — Kw source evidence, scientific basis and redistribution gate

**Owner:** Agent A1 — Chemistry Data & Domain  
**Snapshot:** 2026-11-03  
**Issue:** #10 / A1-P1-KW-SOURCE-01  
**Status:** RESEARCH / SOURCE CANDIDATES ONLY — **NO Kw RECORD ADMITTED**  
**Branch:** `openspec/review-round-1`

This memo checks precise candidate source fields against A3's current AQ-02/W02 consumer contract. It is **not** a ready-to-import constant, calculated dataset, release authorization, executable fixture, approved shared schema, or legal opinion. The OpenSpec baseline is still DRAFT; implementation requires owner approval. Source URLs and revision evidence are listed for independent re-review, with scientific applicability and redistribution rights intentionally separate.

## 1. Exact consumer: what A3 W02 requires

Current A3 Python contract, `src/chemsim/equilibrium.py` on `agent/a3-equilibrium-implementation` (previous verified head `1c3fedb0cd156ba6b4ea63cb4ce30182f3691994`):

```python
solve_strong_neutralization(hcl_mol_l, naoh_mol_l, kw)
```

- `hcl_mol_l`, `naoh_mol_l` are finite nonnegative **analytical concentrations in the already-mixed final solution**, not both zero. They are **not** individual source-vessel concentrations, separate flows, raw amounts or instantaneous mixing assumptions. Mapping source amounts `n` to A3 totals requires an explicitly agreed **final solution volume and mixing/volume policy** in the application/integrator layer. A3 assumes complete dissociation of HCl and NaOH and solves H⁺, OH⁻ plus Na⁺/Cl⁻ spectators.
- `kw` is **finite positive, dimensionless** water-ionization constant for the A3 ideal-dilute convention: `gamma_i = 1`, `c° = 1 mol/L`, water activity treated as 1; A3 shorthand H⁺ is hydrated proton, with no separate H₃O⁺ species.
- In that **specific model**, `Kw_model = ([H+]/c°) × ([OH-]/c°)` and concentration-based `pH = -log10([H+]/c°)`. This is neither a claim of measured activities nor a universal thermodynamic convention.
- A3's newly published `docs/agents/a3-w02-neutralization-acceptance.md` (A3-09, commit `8800569688bb08427d26093b679eb5ff29545296`) additionally requires independent spectator balances and water quotient; its current `component_balance_residual=0.0` is **hard-coded**, not evidence of an independently computed mass balance. A1 must not infer data/model validity from that zero. A3 W02 has no temperature input and makes **no automatic temperature correction**. A1/integrator must therefore pair each prospective Kw with an explicitly declared run/reference T and P applicability without assuming 25 °C or extending a single datum to the entire 273.15–373.15 K product proposal.
- `Ka` or `Kb` is *not* an input to W02, but `Kw` **is**. Example numbers in A3 unit tests are algorithmic inputs, **not** verified catalog constant sources.

## 2. Candidate evidence register — source-specific, not a bundle allowlist

| Candidate | Exact source/version/field evidence | Scientific compatibility with W02 | Distribution/rights assessment | Disposition |
|---|---|---|---|---|
| **OpenStax *Chemistry* (first edition, 2015), §14.1** | Official chapter `https://openstax.org/books/chemistry/pages/14-1-bronsted-lowry-acids-and-bases`: at explicitly specified **25 °C**, textbook represents `Kw = [H₃O⁺][OH⁻] ≈ 1.0 × 10⁻¹⁴` and derives concentrations in **M (mol/L)**. Book-specific preface `https://openstax.org/books/chemistry/pages/preface` identifies this edition as **CC BY 4.0**. | **Closest direct W02 educational approximation:** normalized concentration product with `c°=1 mol/L` and `gamma=1` fits A3's *declared* ideal-dilute educational model at **one temperature**, provided A3 approves H₃O⁺↔hydrated-H⁺ shorthand and dimensionless normalization. Textbook rounds to **two significant figures** and gives no quantitative uncertainty; do **not** promote into a general temperature-dependent or experimental reference. | Edition-specific license permits reuse/adaptation with attribution to OpenStax/contributors. Must preserve book/section citation, license link, version/date and any notice; check field and downstream release channel before import. This is **not** the license of *Chemistry 2e*: that separate edition is CC BY-NC-SA 4.0 per its own preface. Book media/logos carry additional restrictions. | `priority_candidate_for_25C_educational_fixture`; **scientific M=needs A3 review; rights R=needs per-field release review** — **NOT ADMITTED** |
| **IAPWS R11-24 (June 2024)** | Official *Revised Release on the Ionization Constant of H₂O*; publication `https://iapws.org/documents/release/Ionization.download`, pp. 1 (attribution), 2 (standard state), 3 (reaction/model), 5 (validity/uncertainty), 6 (tabulations). Its pKw is calculated from T and **water density**, with ion **molal** standard state `m°=1 mol/kg` and mole-fraction standard state for molecular water; reaction convention `2 H₂O ⇌ H₃O⁺ + OH⁻`. | **Not directly compatible as a W02 input**: A3 uses ionic concentration standard `c°=1 mol/L` and gamma=1. A validated conversion requires explicit thermodynamic conventions, T/P and density/solution composition and activity assumptions; substituting a published pKw/rounded number is unsafe. Formula also depends on an appropriate water density equation of state. | Cover explicitly permits publication of whole/part with IAPWS attribution. This is **document-publication** permission; do not silently equate it with a reviewed, compatible derivative-property/license decision for this application. Retain attribution/source and review rights for any actual field/formulation/derived output intended for bundling. | `scientific_model_mismatch`; candidate for method/reference research; **M=blocked, R=not approved** |
| **USGS PHREEQC `phreeqc.dat`** | Exact source path `database/phreeqc.dat`, GitHub `phreeqc-dev/phreeqc3`, pinned revision `992c7ec919828ed3edc5ffd2b02a2695e4e0ad4e` (observed 2026-11-03). Entry under `# aqueous species`: `H2O = OH- + H+` / `-log_k -14`, with `-delta_h`, `-analytic`, `-gamma` entries (read as a *record*, not `1e-14` without its context). PHREEQC `SOLUTION_SPECIES` manual documents `log_k` at **25 °C**. | **Not automatically compatible**: PHREEQC's geochemical speciation uses ion *activities*, ion molalities, and potentially nonunit gamma/water activity. A3's concentration idealization needs explicit, scientifically justified mapping/approximation and an agreed policy for its limitations. The database is a literature-derived compendium; USGS manual cautions that data/aqueous models may lack systematic consistency and should be treated as preliminary. | USGS publishes PHREEQC software/downloads; source availability and software/model CC0/public-domain descriptions do **not** by themselves verify the redistribution rights of this **particular literature-derived field**, version, or bundled database. Need source-field/third-party-origin and license evidence. | `basis_and_rights_review_required`; **M=blocked, R=blocked_unknown_license** |
| **NIST publication / CRC 106th edition (2025)** | H. Arcis and A. Harvey, *Ionization Constant of Water*, NIST publication listing 2025-06-10: `https://www.nist.gov/publications/ionization-constant-water`. NIST identifies the tables as an update for CRC Handbook, reflecting the 2024 IAPWS formulation. | Useful independent publication trail, not yet an exact W02-compatible, source-field-proven value. CRC tabular representation, standard-state mapping and exact usage conditions must be inspected. | Publisher is CRC Press; a NIST-hosted summary/PDF does not establish free redistribution of CRC's table as an application dataset. | `secondary_reference_review`; **M=blocked, R=blocked_unknown_license** |
| **A3 unit-test scalar values** | A3 tests call `solve_strong_neutralization(..., kw)` with test numbers. | Useful for software regressions **only**; does not satisfy scientific source, uncertainty, temperature, applicable basis or reference-data quality requirements. | Never treat test literals as external license evidence or approved chemistry catalog fields. | `test_only`; **M(reference)=blocked, R=not applicable/not approved** |

**Sources accessed (2026-11-03):**

1. IAPWS R11-24 official download, `https://iapws.org/documents/release/Ionization.download`; release landing page `https://iapws.org/documents/release/Ionization`. Cover explicitly states permission for publication with attribution. §1 explicitly labels `Kw` dimensionless at `m°=1 mol kg⁻¹`; §3 defines `2H₂O ⇌ H₃O⁺ + OH⁻` and **ionic molal standard state**; §4 requires T and density/pressure applicability. §5 gives uncertainty characterizations; reported benchmark-table digits do not equal measurement precision.
2. USGS PHREEQC source field at `https://github.com/phreeqc-dev/phreeqc3/blob/992c7ec919828ed3edc5ffd2b02a2695e4e0ad4e/database/phreeqc.dat`. Verified via GitHub text retrieval, not just a search snippet.
3. Official USGS PHREEQC manual: `https://water.usgs.gov/water-resources/software/PHREEQC/documentation/phreeqc3-html/phreeqc3-50.htm`, `SOLUTION_SPECIES` defines `log_k` at 25 °C and `-gamma` coefficient fields.
4. Official USGS limitations note: `https://water.usgs.gov/water-resources/software/PHREEQC/documentation/phreeqc3-html/phreeqc3-2.htm`, *Program Limitations / Aqueous Model*: data compendia have not systematically aligned all source activity models.
5. USGS software landing `https://www.usgs.gov/software/phreeqc-version-3`. Downloaded software availability / image public-domain notice is **not** field-specific license proof.
6. NIST publication citation `https://www.nist.gov/publications/ionization-constant-water`, June 2025, credits CRC Press.
7. OpenStax *Chemistry* **first edition**, §14.1 `https://openstax.org/books/chemistry/pages/14-1-bronsted-lowry-acids-and-bases` and book-specific CC BY 4.0 preface `https://openstax.org/books/chemistry/pages/preface` (published 2015; web page checked 2026-11-03). The chapter defines a **molar concentration** product at 25 °C; re-expressing it as `([H₃O⁺]/c°)([OH⁻]/c°)`, `c°=1 mol/L` is the proposed **dimensionless A3 adapter interpretation**, not a literal typed standard-state record supplied by the textbook. It provides no uncertainty interval or all-temperature guarantee.
8. OpenStax *Chemistry 2e* preface `https://openstax.org/books/chemistry-2e/pages/preface` explicitly identifies **CC BY-NC-SA 4.0**, distinct from the first edition. Do not transfer the older CC BY permission to the 2e edition or vice versa; the site-wide default is not a substitute for edition-specific text.

## 3. Do not collapse thermodynamic, model and rights decisions

**Shortest P1 path:** the first-edition OpenStax concentration expression at exactly 25 °C is a better scientific *model-convention candidate* than adapting IAPWS molality or PHREEQC geochemical activity constants. This still requires A3 review of normalized, dimensionless `Kw` and H₃O⁺/H⁺ shorthand, an owner-approved quality policy for an approximate **two-significant-figure educational assertion** without reported uncertainty, and a record-specific attribution/redistribution gate. Do not silently assume 25 °C for W02; select it explicitly if owner approves that smoke-test case.

A source may be authoritative in its **own** basis without being directly eligible for A3. Conversely a model-compatible, explicitly user-provided *exploratory* constant may be usable under a future owner-approved exploratory policy without automatically becoming a curated reference or redistributable field.

The separate review gates are:

1. **Origin:** exact field, source version/record locator, original measured/calculated/compiled method and all parents. Identify any original third-party contribution.
2. **Scientific convention:** exact reaction orientation, liquid water activity, proton/H₃O⁺ mapping, dimensionless definition, molal vs molar standard state, gamma/activity convention and T/P/phase/solvent applicability.
3. **Derivation (if required):** explicit density, solution composition, water mass per solution volume, activity coefficients and transformation method; preserve all parent records and uncertainty. No symbol-only conversion `mol/kg → mol/L` or `pKw → Kw` without preserving mathematical method and precision.
4. **Quality:** uncertainty or explicit not-reported, accepted evidence method, scientific review and a version-bound model/conditions eligibility decision. `accepted` workflow is separate from `verified` quality.
5. **Redistribution:** source-field rights for exact intended use and attribution/notice/version, independently of model eligibility. Status must remain `blocked_unknown_license` until documented rights review or `blocked_restricted` if incompatible terms are established.
6. **Runtime (future, gated):** A3 W02 adapter refuses missing T association, unsupported basis, unknown/zero/negative/NaN Kw, missing source review for reference mode, and inconsistent ion/phase mapping. Inputs are final-mixture mol/L analytical totals, not raw streams or moles; no amount-to-concentration conversion without explicit final volume and approved mixing policy. Independently audit `[Na+]=B` and `[Cl-]=A`; the current W02 `component_balance_residual=0.0` is a placeholder, not a scientific proof. A3 itself has no built-in T correction; adapter cannot pretend otherwise.

**Important:** IAPWS table values are *verification/reference data in the source's own thermodynamic convention*, not an automatic license or confirmation of A3 ideal-dilute concentration constants. PHREEQC `-log_k -14` is not silently a `Kw_model` field merely because both are written as `K_w`.

## 4. Acceptance tests to implement **after** OpenSpec owner approval

| Test | Input / negative or positive evidence | Expected A1 semantic gate |
|---|---|---|
| A1-KW-P01 | Explicit W02 model/version, Kw with exact A3-compatible `c°`, `gamma`, T, source, finite positive dimensionless value, evidence/review and accepted owner policy | Permit **candidate model eligibility review**, not blanket/redistribution approval |
| A1-KW-P02 | Valid IAPWS field retained with `molal-standard-state` provenance and temperature/density | Permit **descriptive storage** as scientifically scoped source evidence; do not claim W02 eligibility |
| A1-KW-P03 | Valid PHREEQC source-field provenance `H2O = OH- + H+`, `log_k`, declared T/basis | Permit **descriptive storage** as source assertion; M blocked pending matching model-convention review |
| A1-KW-N01 | Convert an IAPWS `m°=1 mol/kg` Kw directly into A3 `c°=1 mol/L` | Reject automatic model eligibility; require documented transformation |
| A1-KW-N02 | Copy PHREEQC `-log_k -14` directly into A3 as verified source-free Kw | Reject; require explicit source/version, convention, T, model quality and transformation/justification |
| A1-KW-N03 | Pass `pKw` numeral as Kw without explicit `10^-pKw` transform and propagation of provenance/precision | Reject incorrect value representation |
| A1-KW-N04 | Treat IAPWS or PHREEQC value as valid across 273.15–373.15 K with no model/temperature metadata | Reject assumed temperature range |
| A1-KW-N05 | Use third-party USGS-compendium field in offline public bundle on a program-level/public-domain banner alone | Reject `R` until field-level rights confirmed |
| A1-KW-N06 | Interpret PHREEQC water activity/gamma as 1 without a declared/validated ideal-dilute assumption | Reject silent approximation |
| A1-KW-N07 | Store a literature source's missing uncertainty as zero, or false precision from verification digits | Reject fabricated uncertainty/precision |
| A1-KW-N08 | Mark an A3 test literal or user-defined hypothetical input `curated_reference` | Reject provenance/status promotion |
| A1-KW-N09 | Attempt W02 with zero, negative, boolean, NaN or infinity for Kw | Reject numerical admission |
| A1-KW-N10 | Convert a mixed-source/derived Kw but omit one parent or the activity/basis transform | Reject nontraceable derivation |
| A1-KW-P04 | Source: OpenStax *Chemistry* first-edition §14.1, explicitly tagged 25 °C, approx. two sig figs, c° normalization proposed, uncertainty not reported | Permit **descriptive source candidate**; model M requires A3/owner review and R requires per-field rights sign-off |
| A1-KW-N11 | Copy first-edition 25 °C educational Kw to an arbitrary T in 273.15–373.15 K range | Reject unsupported temperature propagation |
| A1-KW-N12 | Label OpenStax *Chemistry 2e* as CC BY 4.0 by confusing it with the original edition | Reject license/edition mismatch; 2e says CC BY-NC-SA 4.0 |
| A1-KW-N13 | Treat rounded OpenStax educational value as a high-precision experimental measurement with zero uncertainty | Reject origin/precision promotion |


These are specification requirements, **not passing tests or code changes**.

## 5. Narrow P1 decisions required for first A1/A3 slice

- **Integrator + A3:** confirm exact typed Kw adapter policy (acceptable activity↔concentration approximation, reaction basis, source application, run T/P association and result warnings); there is no approved scientific transformation from IAPWS/PHREEQC to W02 at this time.
- **Product owner:** approve OpenSpec baseline, whether exploratory user-defined constants may participate in a **clearly marked** local validation mode, and whether reference-backed W02 is a mandatory MVP demo. Exploratory mode **must not silently become** reference mode or claim scientific validation.
- **A1:** obtain per-field source rights and numerical provenance/uncertainty for whichever candidate passes scientific checks; record exact version/field and proper attribution; prepare eligibility decision and eventual A1 semantic tests after authorization.
- **A5:** preserve `idealized_approximation`, concentration-based pH, provenance and missing/invalid-data states. No A1 changes to UI.
- **A2:** preserve formula/species identity and `aq` phase without inferring catalog ID; no A1 parser code.
- **A4:** unrelated to W02; do not substitute Kw for a kinetic rate constant or fabricate a trajectory.

## 6. Current outcome

**Source candidates reviewed: IAPWS (thermodynamic molal), PHREEQC (geochemical activity), NIST/CRC (secondary thermodynamic citation), OpenStax first-edition (direct concentration-based educational candidate); W02 model-compatible numeric assertions admitted: 0; rights-approved redistributable Kw fields: 0; seven benchmark rows admitted: 0.** The source review now identifies a relatively direct, **25 °C-only**, two-significant-figure educational candidate under an edition-specific CC BY 4.0 license. The remaining obstacle is explicit A3/owner acceptance of the model approximation and provenance/uncertainty policy, plus A1 per-field rights review and integrator contract approval. All records remain blocked pending those gates. No numeric constant is copied into the ChemSim catalog; no execution/CI has been performed on an implementation.

