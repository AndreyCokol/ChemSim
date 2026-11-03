"""A3-local, JSON-safe scientific observation projection for seven fixtures.

The result is NOT an integrator-approved EquilibriumResult, a versioned
interchange payload, a stable SpeciesRef representation, or a license/source
admission decision. Consumers must not expose it as a production chemistry
result. It preserves the distinction between a measured zero, unknown,
unassessed, and inapplicable checks before a reviewed cross-agent mapping.
"""

from __future__ import annotations

from math import isclose, log10
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
