# A1 — Source and redistribution evidence register (research snapshot 2026-11-03)

> Status: research evidence / proposed import policy, not legal advice and not final allowlist approval.
> Scope: offline redistribution inside the ChemSim application. Website/API access is not treated as redistribution permission.
> A1 has not imported data or selected numerical benchmark fixtures.

## Executive disposition

| Candidate | What the primary source establishes | A1 disposition for ChemSim bundle | What remains to verify |
|---|---|---|---|
| PubChem as an aggregate | PubChem integrates hundreds of contributors; individual assertions may have different source/license provenance. PubChem explicitly warns that some contributors restrict bulk downloads and instructs users to check the contributor's current license. | **NOT blanket-approved.** Use only a specifically traced source/record/field after checking the underlying source terms and relevant PubChem restrictions. | Per-field origin, current license, redistribution/bulk-download permission, attribution and any restrictions. |
| NIST Chemistry WebBook, SRD 69 | It is a Standard Reference Database. NIST's SRD policy says copyright protection may be secured for SRD compilations; SRD data products should carry a copyright notice. The general NIST public-information rule has an exception for copyrighted material. | **HOLD for bundled data.** Do not infer public-domain status from NIST being a US federal agency or from free web access. Seek/verify SRD 69-specific license/permission before copying data into the redistributable bundle. | Whether SRD 69 currently has a specific license or additional use terms; whether each desired component is SRD compilation, extramural, or third-party material. |
| IUPAC Gold Book individual terms | The current Gold Book site states CC BY-SA 4.0 for individual terms and asks parties interested in licensing the Gold Book for commercial use to contact IUPAC. | **CONDITIONAL / TERM-LEVEL REVIEW.** A specific term may be considered under its stated CC BY-SA 4.0 terms with attribution and share-alike compliance. Do not treat the whole collection/API/export as automatically cleared for commercial redistribution. | Whether ChemSim's exact extraction/use is an individual-term reuse or collection reuse; how share-alike applies to the intended packaged format; obtain IUPAC clarification for bulk/whole-collection commercial use. |
| CAS Registry Numbers | NIST Chemistry WebBook explicitly states CAS Registry Numbers are copyrighted by the American Chemical Society and redistribution rights are reserved. | **EXCLUDE from redistributed catalog unless separately licensed.** Do not use CAS RN as a freely redistributable canonical identifier. | Whether ACS grants permission for the intended use; otherwise use ChemSim internal IDs and other identifiers whose terms are verified. |

## Evidence details

### 1. PubChem

Primary evidence:
- PubChem Data Sources documentation says PubChem integrates data from hundreds of organizations and that different sources can provide different data and licensing/reuse conditions. Record sections identify contributing sources and link to source/license information.
- PubChem Downloads documentation says most data are downloadable, but exceptions exist where licensing agreements prevent contributors from allowing bulk downloads. It directs users to check the source's current license and says provenance information varies by source.
- The live Data Sources directory exposes source-level license information, but the search results themselves show many sources with unspecified license metadata as well as sources with distinct licenses/restrictions.

Consequences for ChemSim:
- PubChem Compound/CID or a PubChem API response is not, by itself, a sufficient license record for every displayed property.
- Store at least PubChem source identifier, contributor/source name, source record identifier, exact field/assertion, original source URL, license text/URL/version/date, and extraction timestamp.
- If a Compound summary mixes computed/aggregated properties and contributed annotations, assess each field separately.
- A source marked unspecified, missing, or ambiguous must be blocked_unknown_license for bundle redistribution.
- A source with a non-commercial, no-derivatives, research-only, or explicit bulk-download restriction is not eligible for the default redistributable bundle without a separate permission/compatibility review.
- PubChem's API rate policy and bulk-download documentation are operational access constraints, not copyright licenses.

Examples visible in PubChem's source directory (illustrative, not an approved ChemSim allowlist):
- BindingDB: directory lists CC BY 3.0 for data curated by BindingDB staff.
- DTP/NCI: directory links to NCI reuse policy, which states that unless otherwise indicated NCI product text is free of copyright and may be reused with source credit.
- KEGG: directory says academic users may freely use the website and non-academic use generally requires a commercial license.
- FooDB: directory says commercial use and redistribution require explicit permission.
- Encyclopedia of Life: directory warns that different data elements on a page may have different licenses.
These examples demonstrate why the aggregate itself cannot receive one global allowlist flag. Each example still requires verification against the current source terms and the exact field being imported.

### 2. NIST Chemistry WebBook (SRD 69)

Primary evidence:
- The WebBook identifies itself as NIST Standard Reference Database Number 69 and describes thermochemical, thermophysical, ion energetics, spectra and related data coverage.
- NIST's SRD licensing statement explains that the Standard Reference Data Act empowers the Secretary of Commerce to secure copyright in SRD prepared by NIST, and says SRD data products should include an SRD copyright notice. It distinguishes SRD from other NIST employee-created works.
- NIST's general copyright page says NIST web information is generally public information except material marked copyrighted; it points users to the SRD-specific licensing statements.
- The WebBook credits include external contributors and compiled datasets, so the origin of a particular table/component should not be assumed solely from the host domain.
- NIST's WebBook search page explicitly notes CAS Registry Numbers are copyrighted by ACS and redistribution rights are reserved.

Consequences for ChemSim:
- SRD 69 should not be put on an automatic public-domain allowlist.
- Before redistributing extracted SRD 69 values, identify the current SRD 69-specific terms/license and check whether a given component includes third-party/extramural material.
- Preserve NIST's recommended dataset citation and all notices required by the applicable SRD terms.
- Do not redistribute CAS RN merely because it appears on a NIST page.
- NIST WebBook is a useful candidate for locating/evaluating thermochemical and thermophysical values; it is not, based on the reviewed coverage page, a blanket source for all aqueous Ka/Kb/Ksp benchmark constants.

### 3. IUPAC Gold Book

Primary evidence:
- The current Gold Book website states CC BY-SA 4.0 applies to individual terms.
- The same site says parties interested in licensing the Gold Book for commercial use should contact the IUPAC Executive Director.
- Individual term pages expose a stable term code/DOI, source references and license metadata. The site encourages users to retain the version of the term and check for updates.

Consequences for ChemSim:
- If using a small number of individual definitions, capture the term code/DOI, version, term-level CC BY-SA 4.0 notice, attribution and access date.
- Do not copy a whole vocabulary/export or build a bundled mirror without clarifying collection-level commercial permission and share-alike obligations with IUPAC.
- Gold Book is a terminology source, not a source for numerical equilibrium constants or substance property tables.

## Proposed source-policy fields

Each imported datum or field should have:
- provider_id, dataset_id, source_record_id, source_field_id;
- source_url, retrieved_at, source_version_or_release_date;
- license_spdx_or_text, license_url, license_version_or_review_date;
- redistribution_status: approved_for_redistribution / local_review_only / blocked_unknown_license / blocked_restricted;
- permission_evidence: stable URL or stored review reference and reviewer/date;
- attribution_text and required notices;
- third_party_origin flag and underlying provider;
- transformation_description if normalized, converted, curated or derived.

The license decision must attach to the exact field/assertion (or a demonstrably homogeneous dataset), not merely the top-level website or API.

## Data-quality and scientific suitability are separate

A permissive license does not establish scientific fitness. A scientific authority does not establish redistribution permission. For each numerical property, separately review:
- scientific provenance and evaluation status;
- method, uncertainty/significant digits and original conditions;
- units/dimensions, phase, medium and basis;
- applicability to ChemSim's declared model and temperature/pressure range;
- license and redistribution rights.

No values are promoted to calculation-ready merely because they originate from PubChem, NIST or IUPAC.

## Immediate A1 recommendation

1. Keep PubChem as a discovery/provenance interface, not a global data license.
2. Keep NIST SRD 69 on hold for bundle redistribution until SRD 69-specific permission/terms and component provenance are checked.
3. Permit review of individual IUPAC Gold Book terms under the term-level CC BY-SA 4.0 notice, but seek clarification before any whole-collection/commercial bulk extraction.
4. Exclude CAS Registry Numbers from the redistributable catalog unless ACS permission is obtained.
5. Prefer a small hand-curated set of individual records with explicit per-field evidence over a large unfiltered bulk import.

## Primary references reviewed

- PubChem, Data Sources: https://pubchem.ncbi.nlm.nih.gov/docs/data-sources
- PubChem, Data Sources directory: https://pubchem.ncbi.nlm.nih.gov/sources/
- PubChem, Downloads: https://pubchem.ncbi.nlm.nih.gov/docs/downloads
- PubChem, Programmatic Access: https://pubchem.ncbi.nlm.nih.gov/docs/programmatic-access
- NIST, Chemistry WebBook SRD 69: https://webbook.nist.gov/chemistry/
- NIST, Copyrights & Disclaimers: https://www.nist.gov/copyrights-disclaimers
- NIST, Copyright, Fair Use, and Licensing Statements for SRD, Data, Software, and Technical Series Publications: https://www.nist.gov/open/copyright-fair-use-and-licensing-statements-srd-data-software-and-technical-series-publications
- IUPAC, Gold Book: https://goldbook.iupac.org/
- IUPAC, individual term example (reference data): https://goldbook.iupac.org/terms/view/15353
- NIST WebBook CAS identifier notice: https://webbook.nist.gov/chemistry/cas-ser/

## Limitations

This is a source-policy research memo, not a legal opinion. It does not establish the license of every PubChem contributor, every NIST WebBook component, or every IUPAC term export. Current terms must be checked again at the time of each import/release. No source is marked approved_for_redistribution by this memo alone.


## Import gate procedure — operational proposal (2026-11-03)

The source examples above are evidence of why review is necessary; they are not an allowlist. Apply the following gate to every candidate field before it enters an offline catalog.

### Gate 0 — identify the exact material

Record the provider, dataset/collection, source record, exact field or table, source URL, retrieval timestamp, source release/version, and whether the field is original, third-party supplied, transformed, or derived. If a source page combines multiple contributors or licenses and the field-level origin cannot be established, stop at `blocked_unknown_license`.

### Gate 1 — establish rights for the intended use

Review the terms that apply to the exact field and the intended distribution mode (local-only user import, internal organization distribution, public bundled catalog, or hosted service). Capture license identifier and version where available, canonical terms URL, attribution/notices, share-alike obligations, commercial-use restrictions, database rights or additional permissions, and reviewer/date.

A license allowing access or API retrieval is not automatically permission to redistribute a copy. A source's general copyright notice does not override a dataset- or contributor-specific restriction. If terms are ambiguous, conflicting, missing, or silent on the intended use, do not infer permission.

### Gate 2 — assign a narrow disposition

| Disposition | Meaning | Permitted handling |
|---|---|---|
| `approved_for_redistribution` | Evidence supports the exact intended redistribution mode and required notices are captured | May be included only in the approved scope/version |
| `local_review_only` | A user may inspect/use a locally obtained record under separately reviewed terms, but the project has not approved bundling or redistribution | Never package, sync, publish or upload the record as part of the default catalog |
| `blocked_unknown_license` | Exact rights or origin cannot be established | Do not import into a distributable catalog; retain only a non-substantive review note |
| `blocked_restricted` | Terms prohibit the intended use or require permission not obtained | Exclude from that use; do not attempt to bypass source restrictions |

Disposition is purpose-specific. Approval for one deployment mode must not be generalized to another. A future permission grant must identify the covered records/fields, territory, duration, use, redistribution channel and any conditions.

### Gate 3 — scientific and technical validation (independent of license)

Even when redistribution is approved, separately validate identity, property semantics, units/dimensions, basis/standard state, phase/medium, temperature/pressure applicability, method, uncertainty/precision, source evaluation and model eligibility. A license decision must not set `quality_status`, and scientific acceptance must not set `redistribution_status`.

For derived or converted values, retain parent source assertions and a reproducible transformation description (formula/software/version/inputs/conditions). The derived value inherits no broader rights than its inputs; mixed-source derivations require review of all contributing fields and applicable license compatibility.

### Gate 4 — fail-closed import and release checks

- Reject a distributable import if any included field lacks an approved disposition for that exact release mode.
- Reject records with unresolved third-party origin or unknown field-level license.
- Ensure required attribution, notices and share-alike/source-offer obligations are included with the artifact where applicable.
- Keep restricted/local-only records out of generated bundles, exports, telemetry, fixtures, test snapshots and CI artifacts that are published externally.
- Re-run the review when source terms, dataset version, field origin, transformation, packaging, commercial context or distribution channel changes.
- Preserve the historical review decision; do not silently rewrite old provenance when a source changes its terms.

### A1 acceptance cases

**Positive:** a field with traceable source-record/field identity, version, exact applicable license, documented permission for the intended distribution mode, complete notices, and independently validated scientific metadata may pass the corresponding import gate.

**Negative:** a PubChem record with unresolved contributor origin; an SRD 69 value without SRD-specific/component rights review; a CAS RN without ACS permission; a whole Gold Book export justified only by the individual-term license; an API-accessible field with no redistribution grant; or a mixed-source derived value with an unreviewed input must not enter a public bundle.

This procedure is a proposed A1 control, not legal advice or a claim that any current candidate source has passed. The current evidence register continues to approve no numerical property/source pair for redistribution.

## Kw-specific source-license and convention comparison (P1, 2026-11-03)

Follow-up evidence: `openspec/reviews/round-1/a1-kw-source-compatibility-review.md` (candidate evidence only; no numerical record or source/field approved). Compared official IAPWS R11-24, USGS PHREEQC `phreeqc.dat`, NIST/CRC 2025 citation, and **OpenStax *Chemistry* first edition**. Distinguish a scientific source value, its **thermodynamic activity or concentration standard state**, and its **rights to be packaged in the app**.

- **OpenStax *Chemistry* (first edition; chapter 14.1):** chapter URL `https://openstax.org/books/chemistry/pages/14-1-bronsted-lowry-acids-and-bases`; edition-specific preface `https://openstax.org/books/chemistry/pages/preface` explicitly states **CC BY 4.0 International**. The chapter discusses water-ionization concentration product at **25 °C**, displayed to **two significant figures**. Its content is the closest available **educational ideal-dilute concentration approximation** for A3's explicitly scoped `c°=1 mol/L`, `gamma=1` fixture. **Not yet scientific-model-admitted**: the textbook does not provide a typed standard-state identifier, uncertainty interval or all-temperature applicability; A3/owner must approve the exact concentration-normalization and H₃O⁺ shorthand, limited precision, fixed-temperature scope and quality policy before a catalog-backed W02 test.
- **OpenStax *Chemistry 2e*:** **different edition and different license**. Its own preface `https://openstax.org/books/chemistry-2e/pages/preface` states **CC BY-NC-SA 4.0**; do not infer CC BY terms from the first edition. Review actual distribution channel/commercial status and mandatory license/attribution notices for any adopted text/field.
- **IAPWS R11-24 (2024):** official release cover allows publication with attribution, but its ionic Kw standard state is molal (1 mol/kg), and publication permission does not certify direct compatibility with A3's concentration Kw or approve an entire derivative catalog.
- **USGS PHREEQC:** its source file's `-log_k -14` at 25 °C belongs to an activity-model database with literature-sourced fields. Software availability/public-domain labels do not substitute for per-field license and source-model review.

**Disposition:** research evidence improves the shortlist but the source allowlist still has **no approved Kw field** for redistribution, and none of AQ-01..AQ-05/GAS-01..GAS-02 is admitted. `OpenStax Chemistry` first edition is a P1 **candidate for explicit 25 °C model review**, not an implicit default value, a finalized license decision, or an automatic right to repackage all textbook content. This addendum is A1 review only, not legal advice.


## P1 rights-conflict override for OpenStax *Chemistry* first edition (2026-11-03)

**This latest disposition supersedes the earlier simplified first-edition CC BY 4.0 license characterization above; it does not alter the chapter's scientific content.** The [same first-edition preface](https://openstax.org/books/chemistry/pages/preface) states CC BY 4.0 under “Customization” but under “Citation/Attribution” also describes noncommercial use, share-alike, AI/LLM reuse restrictions and commercial-permission requests. [OpenStax's current licensing help](https://help.openstax.org/s/article/Openstax-textbook-licensing-and-customization) describes CC BY-NC-SA/noncommercial terms. These conflicting notices do not supply unambiguous rights for ChemSim's intended offline bundled catalog.

- **Status:** first-edition §14.1 Kw candidate `blocked_unknown_license` for redistribution, pending written source-authoritative clarification for the **specific edition, field and distribution channel**; if restrictions apply incompatibly, set `blocked_restricted`.
- **Scientific gate separately open:** A3 must accept fixed 298.15 K, ideal dilute gamma=1, c°=1 mol/L normalized dimensionless Kw, approximation and quality context; owner/integrator approval is not inferred.
- **Scope:** link/citation and examination as a candidate are distinct from importing a protected compilation or republishing source content. Do not silently treat the bare scientific constant as license-cleared catalog evidence, and do not assert that every use of the underlying numerical fact requires permission.
- **Checks:** A1-KW-N14 conflicting notices prevent automatic redistribution approval; A1-KW-N15 edition/site/version mismatch prevents blanket rights promotion. Record source URLs, check date, written rights decision, permitted use and notices before any R approval.

No source/field has passed the per-field redistribution gate; zero source-backed benchmark rows admitted. A1 documentation-only update; not legal advice.
