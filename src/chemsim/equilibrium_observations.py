"""A3-local, JSON-safe scientific observation projection for seven fixtures.

The result is NOT an integrator-approved EquilibriumResult, a versioned
interchange payload, a stable SpeciesRef representation, or a license/source
admission decision. Consumers must not expose it as a production chemistry
result. It preserves the distinction between a measured zero, unknown,
unassessed, and inapplicable checks before a reviewed cross-agent mapping.
"""

from __future__ import annotations

from math import fsum, isclose, log, log10, ulp
from typing import Any

from chemsim.equilibrium import (
    AqueousResult,
    EquilibriumConvergenceError,
    GasResult,
    SolverDiagnostics,
    STANDARD_CONCENTRATION_MOL_L,
    _aqueous_result,
    _finite_number,
    _gas_result,
)

_SCOPE = "a3_local_scientific_observations_only"


# These are local reference-fixture species rosters, *not* durable A1 SpeciesRef IDs.
# The signature only rejects inconsistent A3 result structures; it cannot
# authenticate chemistry identity, provenance or a general speciation network.
_AQUEOUS_FIXTURES = {
    frozenset(("HA", "A-", "H+", "OH-")): (
        "W01", ("not_modelled",), "aqueous_charge_equation",
        "aqueous_component_balance", "log-space bisection",
    ),
    frozenset(("H+", "OH-", "Na+", "Cl-")): (
        "W02", ("not_modelled",), "aqueous_charge_equation",
        "spectator_feed_identity", "log-space bisection",
    ),
    frozenset(("Ag+", "Cl-", "H+", "OH-")): (
        "W03", ("reservoir_inventory_unknown",), "not_assessed",
        "not_assessed", "closed-form ideal solubility",
    ),
    frozenset(("NH3", "NH4+", "H+", "OH-", "Cl-")): (
        "W04", ("not_modelled",), "aqueous_charge_equation",
        "aqueous_component_balance", "log-space bisection",
    ),
    frozenset(("Ag+", "Cl-", "Na+", "NO3-", "H+", "OH-")): (
        "W05", ("no_precipitate", "new_precipitate"),
        "log_saturation_index", "aqueous_component_balance", None,
    ),
}
_GAS_FIXTURE_ROSTERS = (
    frozenset(("NO2", "N2O4")),
    frozenset(("H2", "I2(g)", "HI")),
)


def _validate_local_aqueous_signature(result: AqueousResult) -> None:
    """Reject cross-fixture species/diagnostic/solid-method combinations."""
    signature = _AQUEOUS_FIXTURES.get(frozenset(result.species_mol_l))
    if signature is None:
        raise EquilibriumConvergenceError(
            "Unsupported or incomplete local aqueous fixture species roster"
        )
    fixture, allowed_solid_states, residual_kind, component_kind, method = signature
    diag = result.diagnostics
    if (
        result.solid_phase_state not in allowed_solid_states
        or diag.residual_kind != residual_kind
        or diag.component_balance_kind != component_kind
        or diag.charge_balance_kind != "aqueous_charge_balance"
        or diag.charge_balance_unit != "mol/L"
        or (
            method is not None and diag.method != method
        )
        or (
            fixture == "W03" and diag.residual_status != "not_assessed"
        )
        or (
            fixture != "W03"
            and fixture != "W05"
            and diag.residual_status != "finite"
        )
        or (
            fixture == "W05"
            and (
                diag.method != (
                    "active-set + bisection"
                    if result.solid_phase_state == "new_precipitate"
                    else "inactive-solid check"
                )
                or (
                    result.solid_phase_state == "new_precipitate"
                    and diag.residual_status != "finite"
                )
            )
        )
    ):
        raise EquilibriumConvergenceError(
            "Local aqueous fixture diagnostics contradict its species/solid model"
        )



# Fixed *local fixture* charges for an independent numeric audit.
# This is deliberately NOT a canonical, A2-authenticated FormulaAST charge
# source, nor a claim that the scientific species/source records are admitted.
_AQUEOUS_LOCAL_CHARGES = {
    "HA": 0, "A-": -1, "H+": 1, "OH-": -1,
    "Na+": 1, "Cl-": -1, "Ag+": 1,
    "NH3": 0, "NH4+": 1, "NO3-": -1,
}


def _validate_local_aqueous_charge(result: AqueousResult) -> None:
    """Reconcile ionic concentrations with claimed absolute charge residual.

    Scale before summation to avoid overflow in very large but locally
    representable states. Neutrals do not set the ionic scale. The comparison
    includes float rounding allowance; tiny physical mismatches below that
    scale are *not* independently resolved by this audit.
    """
    charged = [
        (charge, result.species_mol_l[name])
        for name, charge in _AQUEOUS_LOCAL_CHARGES.items()
        if charge and name in result.species_mol_l
    ]
    if not charged:
        raise EquilibriumConvergenceError(
            "No charged species for local aqueous charge audit"
        )
    ionic_scale = max(abs(concentration) for _, concentration in charged)
    if ionic_scale == 0.0:
        raise EquilibriumConvergenceError(
            "All charged species are zero; local aqueous pH is undefined"
        )
    charge_sum = abs(fsum(
        charge * (concentration / ionic_scale)
        for charge, concentration in charged
    ))
    reported = result.diagnostics.charge_balance_residual / ionic_scale
    # The solver's finite output cannot expose differences smaller than the
    # ulps of rounded individual species inventories. Avoid falsely claiming
    # exact independent charge balance in that regime.
    quantization = fsum(
        ulp(concentration) / ionic_scale for _, concentration in charged
    )
    if abs(charge_sum - reported) > max(1.0e-12, 8.0 * quantization):
        raise EquilibriumConvergenceError(
            "Local aqueous ionic charge disagrees with reported balance residual"
        )


def _validate_local_gas_proportionality(result: GasResult) -> None:
    """Check p_i / n_i equality under ONE ideal-gas T, V, without needing T/V.

    Uses log differences to avoid intermediate pressure/amount ratio overflow.
    A pressure near the subnormal float boundary has coarse relative rounding;
    a local numerical ULP allowance avoids asserting false failure there.
    """
    if frozenset(result.species_mol) not in _GAS_FIXTURE_ROSTERS:
        raise EquilibriumConvergenceError(
            "Unsupported local gas fixture species roster"
        )
    ratios = []
    for species, amount in result.species_mol.items():
        if amount > 0.0:
            pressure = result.partial_pressures_pa[species]
            # Positive amount & pressure correspondence was already checked
            # in _gas_result; this is a distinct chemical ideal-gas invariant.
            ratios.append((
                log(pressure) - log(amount),
                ulp(pressure) / pressure,
            ))
    if not ratios:
        raise EquilibriumConvergenceError("No positive gaseous species")
    reference_log, reference_rounding = ratios[0]
    for log_ratio, rounding in ratios[1:]:
        if abs(log_ratio - reference_log) > max(
            2.0e-12, 4.0 * (reference_rounding + rounding)
        ):
            raise EquilibriumConvergenceError(
                "Local gas partial pressures violate common ideal-gas p/n ratio"
            )



def _present(value: int | float, unit_id: str) -> dict[str, Any]:
    """Local shape mirrors the *semantics* of Quantity/Availability only."""
    if not _finite_number(value) or unit_id not in ("mol/L", "mol", "Pa", "1"):
        raise EquilibriumConvergenceError("Invalid local observation quantity")
    return {"status": "present", "quantity": {"value": value, "unit_id": unit_id}}


def _absent(status: str) -> dict[str, str]:
    if status not in ("unknown", "not_assessed", "not_applicable"):
        raise EquilibriumConvergenceError("Unsupported local observation availability")
    return {"status": status}


def _diagnostic(
    value: float | None,
    kind: str,
    unit_id: str | None,
    *,
    availability_status: str,
    domain_status: str,
) -> dict[str, Any]:
    if availability_status == "present":
        if unit_id is None or value is None:
            raise EquilibriumConvergenceError("Present diagnostic requires quantity/unit")
        availability = _present(value, unit_id)
    else:
        # A defined *dimensionless* mathematical check can have no finite
        # value at a domain boundary while still retaining its unit.
        # Unit metadata is not a measured Quantity.
        if value is not None or (
            unit_id is not None and unit_id not in ("mol/L", "mol", "Pa", "1")
        ):
            raise EquilibriumConvergenceError("Unavailable diagnostic cannot carry quantity")
        availability = _absent(availability_status)
    diagnostic = {
        "kind": kind,
        "domain_status": domain_status,
        "availability": availability,
    }
    if unit_id is not None:
        diagnostic["declared_unit_id"] = unit_id
    return diagnostic


def _observed_diagnostics(diag: SolverDiagnostics) -> dict[str, Any]:
    if diag.residual_status == "finite":
        primary = _diagnostic(
            diag.residual, diag.residual_kind, diag.residual_unit,
            availability_status="present", domain_status="finite",
        )
    elif diag.residual_status == "not_assessed":
        primary = _diagnostic(
            diag.residual, diag.residual_kind, diag.residual_unit,
            availability_status="not_assessed", domain_status="not_assessed",
        )
    elif diag.residual_status == "zero_ion_activity":
        # At a zero dissolved-ion activity ln(Q/Ksp) does not have a finite
        # value; its domain is known, but it is NOT a measured numeric zero.
        primary = _diagnostic(
            diag.residual, diag.residual_kind, diag.residual_unit,
            availability_status="not_applicable", domain_status="zero_ion_activity",
        )
    else:
        raise EquilibriumConvergenceError("Unknown primary diagnostic domain status")

    component = _diagnostic(
        diag.component_balance_residual,
        diag.component_balance_kind,
        diag.component_balance_unit,
        availability_status=(
            "not_assessed" if diag.component_balance_residual is None else "present"
        ),
        domain_status=(
            "not_assessed" if diag.component_balance_residual is None else "finite"
        ),
    )
    charge = _diagnostic(
        diag.charge_balance_residual,
        diag.charge_balance_kind,
        diag.charge_balance_unit,
        availability_status=(
            "not_applicable" if diag.charge_balance_residual is None else "present"
        ),
        domain_status=(
            "not_applicable" if diag.charge_balance_residual is None else "finite"
        ),
    )
    return {
        "primary": primary,
        "component_balance": component,
        "charge_balance": charge,
        "iterations": _present(diag.iterations, "1"),
        "method": diag.method,
    }


def project_local_equilibrium_observations(
    result: AqueousResult | GasResult,
) -> dict[str, Any]:
    """Read-only scientific interpretation of an existing *local* result.

    Revalidate even frozen dataclass instances: callers can construct or
    dataclasses.replace them with inconsistent values. No scalar solver is
    run and no v0.1 wire envelope, identity mapping or release flag is made.
    """
    if isinstance(result, AqueousResult):
        diag = result.diagnostics
        _aqueous_result(
            dict(result.species_mol_l), result.pH, diag,
            solid_mol_l=result.solid_mol_l,
            solid_phase_state=result.solid_phase_state,
        )
        _validate_local_aqueous_signature(result)
        _validate_local_aqueous_charge(result)
        h = result.species_mol_l.get("H+")
        if (
            result.pH_method != "ideal_concentration_approximation"
            or diag.activity_model != "ideal_dilute_gamma_equals_1"
            or diag.reliability_status != "idealized_approximation"
            or not _finite_number(h)
            or h <= 0.0
            or not isclose(
                result.pH,
                -log10(h / STANDARD_CONCENTRATION_MOL_L),
                rel_tol=0.0,
                abs_tol=2e-10,
            )
        ):
            raise EquilibriumConvergenceError(
                "Local aqueous scientific model or pH interpretation is inconsistent"
            )

        phase_state = result.solid_phase_state
        if phase_state == "reservoir_inventory_unknown":
            solid = _absent("unknown")
        elif phase_state == "not_modelled":
            # A legacy numeric solid_mol_l=0 is an internal placeholder,
            # not evidence that precipitation was assessed and excluded.
            solid = _absent("not_assessed")
        else:
            solid = _present(result.solid_mol_l, "mol/L")
        return {
            "scope": _SCOPE,
            "state_kind": "single_equilibrium_state",
            "phase": "aqueous",
            "activity_model": diag.activity_model,
            "scientific_applicability": diag.reliability_status,
            "reference_admitted": False,
            "redistribution_approved": False,
            "species": {
                name: _present(value, "mol/L")
                for name, value in result.species_mol_l.items()
            },
            "pH": {
                "method": result.pH_method,
                "availability": _present(result.pH, "1"),
            },
            "solid_phase": {
                "state": phase_state,
                "concentration": solid,
            },
            "diagnostics": _observed_diagnostics(diag),
        }

    if isinstance(result, GasResult):
        diag = result.diagnostics
        _gas_result(
            dict(result.species_mol), dict(result.partial_pressures_pa),
            result.total_pressure_pa, result.extent_mol, diag,
        )
        _validate_local_gas_proportionality(result)
        return {
            "scope": _SCOPE,
            "state_kind": "single_equilibrium_state",
            "phase": "gas",
            "activity_model": diag.activity_model,
            "scientific_applicability": diag.reliability_status,
            "reference_admitted": False,
            "redistribution_approved": False,
            "species": {
                name: _present(value, "mol")
                for name, value in result.species_mol.items()
            },
            "partial_pressures": {
                name: _present(value, "Pa")
                for name, value in result.partial_pressures_pa.items()
            },
            "total_pressure": _present(result.total_pressure_pa, "Pa"),
            "extent": _present(result.extent_mol, "mol"),
            "pH": {
                "method": "unavailable",
                "availability": _absent("not_applicable"),
            },
            "solid_phase": {
                "state": "not_applicable",
                "concentration": _absent("not_applicable"),
            },
            "diagnostics": _observed_diagnostics(diag),
        }
    raise TypeError("Only A3 AqueousResult or GasResult can be projected")
