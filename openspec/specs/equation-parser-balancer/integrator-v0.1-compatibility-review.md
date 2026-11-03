# Agent A2 — интеграционный review кандидата v0.1 (2026-11-03)

> **Статус: DRAFT / A2-P1-CONTRACT-REVIEW.** Спецификация и таблица для интегратора; **не** утверждённый публичный DTO, не новые runtime API, не результаты сквозных тестов. Владелец: Agent A2 — Equation Parser & Balancer; закрепление: [Issue #9](https://github.com/AndreyCokol/ChemSim/issues/9); реализация: [Draft PR #5](https://github.com/AndreyCokol/ChemSim/pull/5).

## Проверенная база

- Shared candidate: `openspec/contracts/mvp-cross-agent-contract-v0.1.md`, blob `dc75f017a08cae02d3ff6155c6dcf611d3f1b2e7`, integrator branch `openspec/review-round-1`; **INTEGRATOR-DECIDED / PENDING OWNER APPROVAL**.
- Envelope JSON Schema: `openspec/contracts/interchange-envelope-v0.1.schema.json`, blob `8dfe5c9338596329872430aa775a0b71c20f56b0`. It defines `$defs/Envelope`, `SourceSpan`, `ErrorEnvelope` etc., but its `payload` is an arbitrary object: it **does not yet encode/validate** FormulaAST, Reaction or ReactionTerm wire structures. A2 cannot call interchange payload validation DONE from this schema alone.
- A2 actual source: `src/chemistry/a2/chem_equation_parser.gd` blob `514bddd65fd1b78c381ff4f65dae3090a5a96ff9`; balancer blob `51ac9486139ea064abe82f4d5bad1fa704ccdf71`; tests `7e4e4d34a6f4cb2aecb61dc2ca9ea5f6535f2e71`; README `7be3cc8a6ae74a7b619284793e97db71e7c89edb`.
- Exact A2 previous docs-only HEAD `3ca62f77d01edff6496ed92998f1a9e32d9f413e` passed Godot 4.3 isolated workflow [#41652519847](https://github.com/AndreyCokol/ChemSim/actions/runs/41652519847). The following proposed wire acceptance cases are **not executable tests yet**.

## A2 → shared v0.1 mapping and risks

| A2 actual source | Integrator candidate v0.1 | Mapping/proposal and owner | Status |
|---|---|---|---|
| `parse_formula` returns `formula_ast.schema_version=1`, `source_text`, `nodes`, `element_counts`, `net_charge`; phase returned separately | `FormulaAST` single source of composition/charge, phase in `SpeciesRef` | Preserve formula/charge (never persist second `formal_charge`). Map **local schema version 1** separately from envelope **`contract_version: "0.1"`**; exact FormulaAST wire payload schema needs integrator + A1 agreement. | PARTIAL / owner gate |
| A2 Reaction DTO: `reactants[]`, `products[]`, `arrow_type: "FORWARD"\|"REVERSIBLE"`, `source_text`, `schema_version=1`; positive coefficients | Shared `Reaction` has stable opaque ID/revision, `arrow_type: forward\|equilibrium`, `original_input`, `ReactionTerm` with side and positive coefficient | Explicit boundary mapping `FORWARD→forward`, `REVERSIBLE→equilibrium`, `source_text→original_input`. Stable Reaction ID and revision assigned by **caller/integrator**, not parsed from offset. Never silently default absent local arrow. | PARTIAL / integrator owns public API |
| A2 phase `SOLID,LIQUID,GAS,AQUEOUS,UNSPECIFIED` | `s,l,g,aq,unspecified` | Candidate bijection `SOLID→s`, `LIQUID→l`, `GAS→g`, `AQUEOUS→aq`, `UNSPECIFIED→unspecified`. Preserve unspecified in **draft/parse**, but block a model requiring known phase. Existing bootstrap adapter rejects UNSPECIFIED; its policy cannot be reused as an identity conversion for draft payloads. | BLOCKED — adapter owner and approved semantics |
| A2 generated `term_id="term_<source start offset>"` changes after edits | `SpeciesRef` and `Reaction` require stable ID + `record_revision` | Never reuse `term_id` as `species_id` or `reaction_id`. Caller resolves catalogue or unresolved species to stable identity **only after validated lookup/decision**; source locators remain ephemeral and are retained with every duplicate term. | BLOCKED — adapter |
| A2 balances in separate operations; proposal has `proposed_coefficients` and `source_term_ids` | BalanceResult separate/immutable; accepting proposal creates new Reaction revision | Do not mutate the parsed DTO or invent a coefficient split among duplicates; new revision assigned by caller after user confirmation; map all source locators. Same species on both sides requires downstream model support. | PARTIAL — versioned BalanceResult wire schema missing |
| A2 `serialize_formula` emits short `H+` / `NH4+`, caret `Fe^3+`; `serialize_reaction` outputs `⇌` for reversible | Canonical wire charges `^+`, `^-`, `^2-`, `^3+`; allowed shorthand aliases only `H+`, `OH-`, `Ag+` candidate; canonical arrows `->`, `<->` | **Separate local text serialization from wire canonicalization.** Do not silently reject current accepted `NH4+, Cl-, NO3-` or change A2 round-trip; owner must decide INT-28/29, which text aliases remain input-only, canonical wire spelling and Unicode normalization. | OWNER-GATE |
| A2 diagnostics `code`, `message`, uppercase `severity=ERROR`, `source_span.start_offset/end_offset` in Godot String character indices | `ErrorEnvelope`: stable code, lowercase severity, message_key, context, recoverable, responsible_module; optional UTF-8 byte source span | Adapter maps validated A2 code into agreed module namespacing, `ERROR→error`, typed `message_key`, `context`, recovery and `responsible_module=A2`. Messages are not themselves portable message keys. Only adapter should convert character offsets to byte offsets. | BLOCKED — error namespace and mapping ownership |
| A2 balance/proposal public entry points may accept caller-crafted DTOs missing arrow/version/coefficient/phase; serializer can default arrow | Shared versioned payloads must fail closed | Already specified in A2 DRAFT `Fail-closed validation of externally supplied Reaction DTO`; implement parser/balancer guards and tests only **after owner approves** local API contract. | P1 BLOCKED implementation gate |

## P1: Character span → UTF-8 byte span

**Actual A2 convention:** `[start_offset,end_offset)` counts Godot `String` characters of the **exact original input**, not UTF-8 bytes. It applies both to formula parser and reaction parser; offsets of right-side errors are global, including the original arrow and left side. **Candidate wire convention:** `[utf8_byte_start,utf8_byte_end)` counts bytes of UTF-8 encoding of the **same unchanged original input**.

Suggested **post-approval adapter algorithm**, not code already implemented:

1. Validate `typeof(original_input) == String` and integers `0 ≤ local_start ≤ local_end ≤ original_input.length()`. Do not first normalize, trim, canonicalize Unicode, or replace arrow glyphs.
2. `utf8_byte_start = original_input.substr(0, local_start).to_utf8_buffer().size()`.
3. `utf8_byte_end = original_input.substr(0, local_end).to_utf8_buffer().size()`.
4. Verify `0 ≤ start_byte ≤ end_byte ≤ original_input.to_utf8_buffer().size()`. Consumers must reverse-map **only at verified UTF-8 character boundaries** before caret selection. Byte values must never be sent as Godot character indices.
5. If many diagnostics, build an index-to-byte-boundary map **once per original input**; avoid repeated O(N) UTF-8 prefix allocations.
6. If source text has changed since parsing, invalidate the old span and parse again; `term_id` offsets must not be treated as persistent identities.

**Independent prefix-length calculations (not execution of GDScript):**

| Original input | Expected parser diagnosis | Local char half-open range | Interchange UTF-8 byte range | Why |
|---|---|---|---|---|
| `H2 + O2 → H2Xx` | `PARSE_UNKNOWN_ELEMENT` at `Xx` | `[12,14)` | `[14,16)` | `→` is one char, three UTF-8 bytes |
| `H2 + O2 → H2Ж` | `PARSE_UNEXPECTED_TOKEN` at `Ж` | `[12,13)` | `[14,16)` | Prefix has Unicode arrow (+2 bytes), `Ж` occupies two bytes |
| `H2 + O2` | `PARSE_MISSING_ARROW` after last char | `[7,7)` | `[7,7)` | EOF cursor/insertion position; zero-width valid locally |
| `Fe^3` | `PARSE_INVALID_CHARGE`: missing sign after `3` | `[4,4)` | `[4,4)` | EOF cursor/insertion position; zero-width valid locally |

**Concrete contract conflict:** The schema `SourceSpan` permits `start=end` numerically, but its `description` says consumer checks `end > start`. Local A2 **intentionally emits zero-width EOF diagnostic spans** for missing arrow/sign. A strict `end > start` consumer will reject them or lose highlighting. Integrator/A5 must explicitly choose:
- **Preferred review proposal:** allow `start ≤ end` for diagnostics and designate `start=end` as an **insertion point**, while non-empty spans highlight existing bytes; or
- add a distinct optional `cursor_byte_offset` field and omit `source_span` for insertion-point errors.

Never silently expand a zero-width EOF span to an unrelated character or fabricate an invalid offset. Both schemes require validated range and UTF-8 character boundaries.

## Additional source-aligned acceptance / negative vectors

1. A2 text `2H2 + O2 -> 2H2O`: parsed coefficient, formula atom counts and balanced status unchanged; adapter assigns stable IDs/refs or blocks when identity resolution is unavailable.
2. `NH4+ + Cl- -> NH4Cl`: A2 parses; wire alias/canonicalization policy must be explicitly approved. Do **not** confuse terminal ionic `+` with a separator; current parser requires spaces around the separator.
3. `H2 + I2 <-> 2HI`: local reversible `REVERSIBLE` maps to wire `equilibrium`; never pass to current **irreversible** A4 model or infer k from K.
4. Duplicate `H2 + H2 + O2 -> H2O`: original locator list must be preserved; balance proposal is **aggregated**, not per-original-term coefficients. Caller must not distribute it arbitrarily.
5. A2 text `N2O4(g) -> 2NO2(g)`: valid atoms/charge, `FORWARD`, GAS; synthetic A4 model only after explicit kinetic inputs and applicability, as separately documented in A2 DRAFT.
6. Explicit `UNSPECIFIED` phase: canonical draft SpeciesRef may represent it, but a gas/aqueous model requiring known phase blocks rather than guesses `g` or `aq`.
7. Missing `schema_version`, missing `arrow_type`, missing per-term coefficient or phase in *external* Reaction DTO: fail-closed in each A2 public consumer operation after owner approves the DRAFT validation rule.
8. Unknown envelope `contract_version` or wrong `kind`: integrator transport rejects; do not confuse `contract_version="0.1"` with local A2 AST `schema_version=1`.
9. Source-span with `end < start`, end beyond bytes or start in middle of UTF-8 sequence: block and record typed error; never display wrong highlighting or mutate original text to make range look valid.
10. Zero-length insertion spans: check `[7,7)` and `[4,4)` end-to-end once integrator resolves the schema/consumer contradiction, including Russian UI selection.

## Owner / integrator decisions and stop conditions

| Priority | Owner | Decision / acceptance evidence | Current status |
|---|---|---|---|
| P0 | Product owner | Explicit approval/rejection of OpenSpec baseline SHA/version and phase-1 A2 implementation/adapter scope | **BLOCKED** |
| P1 | Integrator + A5 | Decide UTF-8 SourceSpan zero-width semantics, A2 → ErrorEnvelope code/severity/message mapping and owner of char↔byte conversion; exact Cyrillic+arrow tests | **NEEDS_REVIEW** |
| P1 | Integrator + A1 | Validate species ID/revisions, reaction revision lifecycle, `unspecified` phase mapping, duplicate source-locator retention; add versioned Reaction/BalanceResult schemas | **NEEDS_REVIEW** |
| P1 | Product owner + integrator | INT-28/29 grammar aliases and arrow canonicalization; keep A2 local parse/serialize unaffected until decision | **OWNER-GATE** |
| P1 | A2 | Once authorized, reject malformed caller DTOs and test all public consumer methods; do not write before approval | **SPEC DONE / CODE BLOCKED** |
| P1 | Integrator + A4 + A5 | Implement and run a real Godot ↔ .NET synthetic chemistry-valid E2E, including error spans and failure/partial-result paths | **BLOCKED / NOT EXECUTED** |

**Cross-agent limit:** This document records A2 producer review and actionable examples; it does not change shared contracts, A1 identities, A4 kinetics or A5 UI. A2 branch and PR remain Draft; isolated A2 CI green is not proof of shared v0.1 interoperability.
