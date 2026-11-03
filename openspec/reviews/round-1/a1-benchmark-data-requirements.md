# A1 — Benchmark species and data requirements matrix

Status: **RESEARCH / PROPOSAL — NOT A NUMERICAL FIXTURE, NOT AN IMPORT ALLOWLIST**  
Branch: `openspec/review-round-1`  
Scope: A1 data/domain requirements only. Parser semantics remain A2-owned; equilibrium-model semantics and activity treatment remain A3-owned; gas-model semantics remain with the responsible model owner.

## 1. Method and guardrails

This matrix derives candidate entities from the owner-approved seven benchmark scenarios in `openspec/reviews/round-1/benchmark-matrix.md`. It separates:
1. identity/stoichiometric facts (formula, elemental composition, charge, phase);
2. optional encyclopedia properties (e.g. molar mass);
3. calculation-critical model data (equilibrium constants and model conditions);
4. provenance and redistribution evidence.

No numerical property or equilibrium constant is asserted here. A scenario's equation does not by itself establish a complete, calculation-ready fixture. The exact species representation, especially aqueous proton/water conventions, must be confirmed with A2/A3 before fixture authoring.

## 2. Species inventory by benchmark

| Benchmark | Candidate species/entities | Identity and phase requirements | Candidate model data needed | A1 status / coordination |
|---|---|---|---|---|
| AQ-01: CH3COOH ⇌ H+ + CH3COO− | CH3COOH(aq), H+(aq) or agreed aqueous proton convention, CH3COO−(aq), H2O(l) as solvent/context | Formula, composition, charge, phase; distinguish neutral acid from acetate ion; solvent/context must not be confused with a stoichiometric solute | Ka with explicit activity/concentration basis, standard state, T, medium, uncertainty; initial analytical concentration and volume are fixture inputs, not catalog constants | Ka and proton convention require A3 decision. No value/source/license approved. |
| AQ-02: HCl + NaOH → NaCl + H2O | HCl(aq), NaOH(aq), Na+(aq), Cl−(aq), OH−(aq), H2O(l); NaCl may be represented as dissolved ions for the aqueous model | Preserve neutral formula identities separately from ionic species; phase and charge are explicit; clarify whether molecular HCl/NaOH are inputs or dissociated model species | Strong-electrolyte/dissociation assumptions; initial amounts or concentrations, volume, T; no weak-electrolyte Ka/Kb should be invented for this strong-acid/base benchmark | A3 must specify species/reaction representation and assumptions. Property constants may not be required if model treats dissociation as complete. |
| AQ-03: AgCl(s) ⇌ Ag+(aq) + Cl−(aq) | AgCl(s), Ag+(aq), Cl−(aq), H2O(l) | Solid AgCl distinct from dissolved ions; formula, charge, phase | Ksp with explicit basis/standard state, T, aqueous medium/activity model, uncertainty; initial totals/conditions supplied by fixture | Ksp source and A3 activity convention unresolved. No value/source/license approved. |
| AQ-04: NH3 + H2O ⇌ NH4+ + OH− | NH3(aq), NH4+(aq), OH−(aq), H2O(l) | Neutral ammonia distinct from ammonium and hydroxide ions; explicit phase and charge | Kb (or explicitly approved equivalent Ka/conjugate-acid route), basis/standard state, T, medium, uncertainty; initial analytical concentration and volume | A3 to choose Kb vs transformed Ka route and define water convention. No value/source/license approved. |
| AQ-05: AgNO3 + NaCl → AgCl↓ + NaNO3 | AgNO3(aq), NaCl(aq), Ag+(aq), NO3−(aq), Na+(aq), Cl−(aq), AgCl(s), H2O(l) | Molecular salt inputs versus dissociated ions must be unambiguous; spectator ions retained for totals/charge balance; precipitate is solid phase | Ksp compatible with AQ-03, initial amounts/volume/T, activity assumption; limiting reagent and precipitation extent derive from balances/model | A2/A3 coordination needed for reaction and spectator-ion representation. Reuse same AgCl Ksp record as AQ-03 only if conditions/basis match. |
| GAS-01: 2 NO2(g) ⇌ N2O4(g) | NO2(g), N2O4(g) | Formula, elemental composition, neutral charge, gas phase | Kp(T) with pressure standard state/convention, T, uncertainty, source/version; Δn and ideal-gas model context; P or V/n fixture inputs | Gas-model owner must define exact Kp convention and ideal-gas applicability. NIST SRD 69 is a discovery candidate, not an approved redistributable source. |
| GAS-02: H2(g) + I2(g) ⇌ 2 HI(g) | H2(g), I2(g), HI(g) | Molecular identity and gas phase; check whether iodine gas is the intended benchmark state at selected T (do not silently use solid iodine) | Equilibrium K with explicit pressure/concentration/activity basis and standard state, T, uncertainty, source/version; ideal-gas conditions | Temperature/phase consistency is a hard gate. Gas-model owner must confirm basis and intended iodine phase before sourcing or fixture creation. |

## 3. Cross-scenario property requirements

| Data field / property | Required when | Dimension / representation | Conditions and metadata | Gate |
|---|---|---|---|---|
| Stable internal substance/species ID | Every catalog entity | Opaque stable ID; not a CAS RN dependency | Identity version; aliases separately sourced | Required for all |
| Formula, elemental composition, charge, phase | Every parsed/catalog species | Structured formula/composition; integer charge; controlled phase enum | Formula grammar and charge syntax owned by A2; domain identity semantics coordinated with A2 | Required for all |
| Molar mass | Only if converting mass ↔ amount, or displaying encyclopedia property | mass·amount⁻¹, canonical unit plus source unit | Isotopic/atomic-weight convention, source, uncertainty/significant digits | Not required when fixture supplies mol directly |
| Initial amount / analytical concentration | All aqueous benchmarks as relevant | mol or amount·volume⁻¹; mol/L only where the model contract permits | Initial totals vs free species must be distinguished; volume and T explicit | Fixture input, not necessarily catalog property |
| Ka | AQ-01 | Dimensionless activity convention or explicitly dimensioned concentration convention | Acid reaction definition, standard state, T, medium, activity model, uncertainty | Required for weak-acid model |
| Kb (or approved equivalent) | AQ-04 | Dimensionless activity convention or explicitly dimensioned concentration convention | Base reaction definition, standard state, T, medium, activity model, uncertainty | Required for weak-base model |
| Ksp | AQ-03 and AQ-05 | Explicit activity product / standard-state convention; never bare number | Solid phase identity, dissolution reaction, T, medium, activity model, uncertainty | Required for precipitation/solubility model |
| Kp | GAS-01 | Explicit dimensionless pressure-standard-state convention or documented legacy dimensional form | Balanced gas reaction, Δn, T, standard pressure, ideal-gas assumptions, uncertainty | Required for equilibrium fixture |
| K for GAS-02 | GAS-02 | Explicit basis; pressure/concentration relation must be documented even when Δn=0 | Balanced reaction, standard state, T, source, uncertainty | Required for equilibrium fixture |
| Density / activity coefficients / activity model parameters | Only if chosen model needs them | Typed dimensioned records / model-specific parameters | Composition, T, P and validated range | Do not require for ideal-dilute approximation unless A3 says otherwise |
| Hazard assertions | Encyclopedia display for every entity where available | Hazard classification/assertion, not a scalar property | Exact source, jurisdiction/version, completeness status, review date | Missing/unknown never means safe |

## 4. Source coverage and license disposition (current evidence)

| Candidate source | Potentially useful coverage | Current A1 disposition |
|---|---|---|
| PubChem and its contributor records | Identity, formula, molecular properties, selected annotations; contributor-dependent coverage | Discovery/provenance route only. No global PubChem license assumption. Every imported field requires contributor/source record, exact field, license, version/date and redistribution review. |
| NIST Chemistry WebBook SRD 69 | Thermochemical/thermophysical data and evaluated references for some gas/substance properties | Scientific discovery candidate. Hold from automatic bundle redistribution until SRD-specific terms and component/third-party provenance are checked. Coverage of all required aqueous Ka/Kb/Ksp values is not established. |
| IUPAC Gold Book | Definitions and terminology | Not a source for numerical equilibrium constants. Individual-term CC BY-SA 4.0 notice is not blanket approval for bulk/collection redistribution. |
| Primary evaluated literature / handbooks | Likely necessary for specific Ka/Kb/Ksp and equilibrium datasets | No individual reference has yet been selected or license-cleared. Citation alone does not grant redistribution rights. |
| CAS Registry Numbers | Cross-reference identifier | Exclude from redistributed catalog absent ACS permission; use ChemSim internal IDs and separately cleared identifiers. |

No source/property pair in this matrix is approved for redistribution. Scientific suitability and licensing are independent gates.

## 5. Explicit blockers before numerical fixtures

1. A3 must confirm aqueous species conventions (especially H+ vs hydrated-proton representation), activity/standard-state convention, and model-required constant basis.
2. The gas-model owner must confirm Kp/K basis, standard pressure, iodine phase at the chosen temperature, and ideal-gas assumptions.
3. A2 must confirm formula/phase/charge identity handoff and avoid duplicate domain/parser DTOs.
4. For every selected numerical datum: record exact source record/table, value, unit, reaction definition, T/P, medium/phase, basis, uncertainty, source version/access date, license and redistribution status.
5. If source license is unknown/restricted, retain the datum only as a research lead; do not package it in the offline catalog or test fixture.
6. A numerical fixture also needs derivation of expected output and per-test absolute/relative/residual tolerances. This matrix does not assign those tolerances.

## 6. A1 acceptance checks derived from this matrix

- Every benchmark species has an explicit identity (formula, charge, phase) or a documented unresolved convention.
- Every calculation-critical constant is typed by reaction, basis, standard state, conditions and uncertainty; a bare K/Ka/Kb/Ksp/Kp is rejected as calculation-ready.
- AQ-03 and AQ-05 cannot silently use different AgCl Ksp records or incompatible conditions.
- AQ-04 cannot silently substitute Ka for Kb without a documented thermodynamic conversion and compatible standard states.
- GAS-02 cannot silently substitute I2(s) data for I2(g).
- Missing molar mass blocks only mass↔amount conversion, not a calculation already expressed in mol.
- Missing/unknown license blocks redistribution, not local research documentation.
- Missing hazard data is rendered as unknown/incomplete, never safe.
- No molarity↔molality conversion occurs without the solvent mass/density and composition inputs required by the chosen conversion.
- User-defined/hypothetical values remain visibly distinct and their provenance status propagates to dependent results.

## 7. Open coordination questions

- **A2:** What exact identity key and phase/charge representation is accepted at the parser/domain boundary? Does parser output already contain a canonical formula composition, or should the domain normalize it?
- **A3:** Confirm aqueous proton/water convention, strong-electrolyte treatment, Ka/Kb/Ksp basis, standard state, and the activity model supported by the MVP.
- **Gas model owner:** Confirm Kp/K convention and I2 phase for GAS-02.
- **Integrator/owner:** Confirm shared schema version, canonical units/Unit Registry and error envelope. A1 does not freeze these shared contracts.

This document is a requirements map, not an implementation specification approval, source allowlist, legal opinion, or numerical benchmark dataset.


## 8. A3 consumer clarification (2026-11-03)

A3 ответил на aqueous consumer-contract вопросы A1 в PR #4 comment `6600097355`. Уточнение ограничено текущими семью reference fixtures:

- Aqueous Ka/Kw/Ksp сейчас трактуются как конечные положительные безразмерные константы при ideal-dilute convention, \(c^\circ=1\,\mathrm{mol/L}\), \(\gamma_i=1\). Для AQ-01 это Ka(HA); для AQ-04 — Ka(NH4+) (не Kb(NH3)); для AQ-03/AQ-05 — Ksp AgCl(s) с активностью твёрдого тела 1.
- A3 не принимает температуру и не рассчитывает температурные поправки. Константы должны быть заранее приведены к одной явно объявленной совместимой температуре; 25 °C не является default.
- В текущей модели H+ — shorthand hydrated proton; H2O(l) — solvent с unit activity, не отдельная solved species; H3O+ отдельно не представлена. Любое H3O+/H+ преобразование требует явного стехиометрически/термодинамически согласованного правила.
- Поддерживается только gamma=1. Ionic strength, dielectric/solvent properties, ion-size/interaction parameters и complexation data не потребляются; неидеальные модели требуют отдельного контракта.
- G01/G02 используют dimensionless Kp при \(p^\circ=1\,\mathrm{bar}\), идеальные partial pressures и не используют fugacity coefficients.

Следствие: первоначальные пункты «A3 должен подтвердить...» в разделах выше теперь частично разрешены для текущей fixture-конвенции. Однако численные значения, точные source records, uncertainty, provenance, quality policy на уровне адаптера, GAS-02 фаза I2, общий DTO и typed ErrorEnvelope остаются неразрешёнными. Ни один numerical fixture или источник для redistribution не утверждён этим уточнением.

Источник: PR #4 comment `6600097355`, 2026-11-03; подробная запись consumer implications — раздел 17 `openspec/specs/chemistry-domain/a1-data-contracts.md`.
