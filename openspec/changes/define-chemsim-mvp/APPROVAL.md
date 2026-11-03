# OpenSpec owner approval — ChemSim MVP architecture baseline v0.1

**Status: APPROVED — 2026-11-03.**

## Authority and exact immutable baseline

On **2026-11-03**, in the project's ChatGPT conversation, the project owner explicitly instructed: **«Можешь отмечать спеку утвержденной, и продолжать работу в рамках агента A5»**. This is direct product-owner approval to mark the OpenSpec specification approved and resume A5 work. It is not a claim that the owner personally submitted a GitHub review.

- Change ID: `define-chemsim-mvp`.
- Approved specification/architecture baseline version: `v0.1` (staged implementation baseline).
- **Immutable source revision being approved:** `02b8b31706807279ee31a78772383e31f425f7d3` from `openspec/review-round-1` (PR #1), including the integrator v0.1 documents and A1/A2 charge reconciliation.
- Normative project context: owner product constraints recorded in OpenSpec `proposal.md`, `design.md`, `questions.md` and scoped `specs/` at this revision. Contract guidance: `openspec/contracts/mvp-cross-agent-contract-v0.1.md`, `interchange-envelope-v0.1.schema.json`, `mvp-bridge-and-acceptance-v0.1.md`.
- Source URL: https://github.com/AndreyCokol/ChemSim/tree/02b8b31706807279ee31a78772383e31f425f7d3/openspec
- This record may be mirrored into `main` independently of the eventual PR #1 merge. **Do not conflate owner authorization with merge status.**

## Authorization and remaining scientific gates

**Authorized:** A1–A5 may continue subsystem implementation, tests and integrations under the approved v0.1 architecture, each in its claimed branch and scope. Specifically A5 is authorized to continue Godot UX, A5-owned adapters, visualization, local draft persistence, tests and offline integration preparation. Integrator can continue contract clarification and E2E planning. This approval removes the previous blanket prohibition on implementation after owner sign-off.

**Not authorized by this approval alone:** invented scientific constants, unstated k/K conversions, silent approximations, publishing unlicensed data, claiming numerical/scientific correctness without source-backed fixtures, claiming working Windows offline packaging without test evidence, or treating producer-specific candidate DTO/CLI transport details as already tested and compatible.

Outstanding items retain independent acceptance gates:
1. A1–A5 map actual local modules to v0.1, review exact semantic/unit/version mismatches and implement adapters with tests.
2. A1/A3/A4 obtain source-backed benchmark inputs, independently derived expected values, model-specific tolerances and redistribution evidence before scientifically validated/catalog-supported release.
3. A2 short-charge aliases / equilibrium arrow tokens require explicit A2 test/lexical confirmation against owner examples; ambiguous input is rejected.
4. Local Godot↔A4 .NET 10 CLI is the **approved architecture direction**, but executable bridge, nonblocking process lifecycle and Windows x64 offline smoke are **not yet implemented or validated**.
5. Unsupported kinetics/equilibrium features remain disabled with explicit `blocked/out_of_domain/unsupported` status rather than fake results.
6. The original scope remains intact (aqueous chemistry, ideal gases, parser, kinetics, open systems, replay, hazards); optional **synthetic** A2→A4→A5 engineering smoke is a staging milestone, not a substitute for feature-complete MVP.

## Approval boundary

This approval means **SPECIFICATION BASELINE APPROVED / IMPLEMENTATION UNBLOCKED**, *not* “all feature tasks DONE”, “scientific data admitted”, “all 48 INT decisions tested”, “PR #1 merged”, or “MVP ready to ship”.

Any incompatible public-schema change requires a new versioned proposal and cross-agent review rather than silent unilateral edits.

**GitHub tracking:** OpenSpec PR #1; integrator Issue #14; agent issues A1 #10, A2 #9, A3 #8, A4 #12, A5 #11.
