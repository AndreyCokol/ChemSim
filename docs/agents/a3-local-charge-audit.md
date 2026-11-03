# A3-19 — Independent local aqueous ionic charge diagnostic audit

**Date:** 2026-11-03. **Owner:** Agent A3 / Issue #8 / Draft PR #4. **Priority:** P1.  
**Code/tests:** `298ec20e43d3639259ac99d633a237c68d82ce2f`; [CI #41671442572](https://github.com/AndreyCokol/ChemSim/actions/runs/41671442572) completed **success — 90 tests / OK**.

## Defect and correction

A3-18 validates exact scientific fixture rosters and diagnostic kinds, but its prior local observation projection could still accept an `AqueousResult` whose ion concentrations were changed after the solver returned, while the old `charge_balance_residual` remained unchanged. This could export contradictory charge-balance claims despite finite numbers, a valid pH and correct units.

The A3-owned `src/chemsim/equilibrium_observations.py` now independently recalculates the total signed ionic charge concentration for W01–W05 from **fixed A3 fixture-local charge assumptions**. It compares the absolute calculated residual with `diagnostics.charge_balance_residual` and rejects disagreements **before** creating a local JSON-safe observation.

## Exact mathematical and numerical policy

For each modeled local ion `i`, form `z_i * c_i` with charge number `z_i` and concentration `c_i` (mol/L). Neutral HA and NH3 are excluded. The charge convention used only for these synthetic fixture rosters is:

- H+, Ag+, Na+, NH4+: +1.
- OH−, A−, Cl−, NO3−: −1.

Set `S = max_i |c_i|` among charged species. Instead of potentially overflowing `sum(z_i c_i)`, compare the **normalized** `|math.fsum(z_i * (c_i/S))|` with `charge_balance_residual/S`. Only the **absolute charge** is compared because the existing local diagnostics report a nonnegative magnitude. The explicit float budget is `max(1e-12, 8*sum(ulp(c_i)/S))` in normalized units, allowing differences introduced by representable rounding but rejecting scientifically meaningful mismatches above that resolution.

The tolerance is a **floating-point reproducibility allowance**, not chemical applicability, analytical measurement uncertainty, an acceptable electroneutrality threshold for arbitrary concentrations, or a proof of charge conservation. When one ion dominates by many orders of magnitude, changes below the representation/ULP budget cannot be independently resolved, and this check must not be presented as a universal conservation certificate.

## Tested acceptance and negative scenarios

Three new regression test methods in `tests/test_equilibrium_observations.py` cover:

1. For each aqueous fixture W01, W02, W03, W04, W05, modify one charged ion while retaining its old charge diagnostic: fail closed with a charge inconsistency. Valid rosters, original pH and finite numeric fields alone must not permit export.
2. Independently forge a W02 charge residual of 0.1 mol/L, or alter H+ and simultaneously adjust pH to the new value to evade the earlier pH gate: fail closed.
3. Preserve existing valid extreme numeric cases: W02 roughly 1e308 mol/L near-adjacent feeds, W01 1e100 mol/L + huge Ka, W04 large nitrogen inventory, and W05 a small permitted spectator-feed mismatch. They must not spuriously fail due to naive catastrophic cancellation/overflow.

**Source-head CI #41671442572:** 90 tests / OK (previous 87 + 3). The existing seven-fixture JSON-safe observation, availability, gas proportionality, pH qualifier and W05 saturation boundary checks remain unchanged in scope.

## External gates still open (A3-07)

These charges are A3 reference-fixture *assumptions*, **not authenticated A2 FormulaAST values** and not a reusable general chemistry charge/atom matrix. No new trusted species references, source Ka/Kw/Ksp/Kp, precise T/P validity, source rights, shared `EquilibriumResult` payload, released `ReliabilityVector`, Godot consumer, Windows execution, or scientific benchmark admission is established. A1 still owns source data/rights, integrator owns normative v0.1 interfaces and trusted identity wiring, and A5 owns app UX/bridge. No source-authenticated numerical invariant or production release certification is claimed.

**Conclusion:** A3-19 DONE only for independent local output-vs-diagnostic charge consistency. A3-07 remains IN_PROGRESS/blocked on cross-agent approvals.
