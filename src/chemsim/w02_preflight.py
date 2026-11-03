"""A3-owned W02 25 °C scientific compatibility check for *synthetic* fixtures.

This is intentionally NOT an A1 source-admission gate, integrator v0.1 wire
DTO, or application-facing approval for any sourced chemical constant.
It does not verify an asserted reaction ID, provenance, eligibility or rights
against an authoritative store. Only trusted A1/integrator wiring can do that.
"""

from __future__ import annotations

from collections.abc import Mapping
from dataclasses import dataclass
from math import isfinite
from typing import Any


_25C_K = 298.15
_MODEL = "aqueous_ideal_dilute_activity_approximation"
_DIRECTION = "water_to_hydrated_proton_and_hydroxide"
_PROTON_CONVENTION = "H+_aq_alias_for_H3O+_aq"
_STANDARD_STATE = (
    "c0_mol_l", "gamma_h_plus", "gamma_oh_minus", "water_activity",
)


@dataclass(frozen=True)
class W02ModelAssessment:
    """Local model compatibility only; no authority to compute released data."""

    model_compatible: bool
    reasons: tuple[str, ...]
    scope: str = "synthetic_25c_model_preflight_only"
    reference_admitted: bool = False
    redistribution_approved: bool = False


def _finite_number(value: Any) -> bool:
    return isinstance(value, (float, int)) and not isinstance(value, bool) and isfinite(value)


def _nonempty(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _reference(value: Any) -> bool:
    return (
        isinstance(value, Mapping)
        and _nonempty(value.get("id"))
        and isinstance(value.get("record_revision"), int)
        and not isinstance(value.get("record_revision"), bool)
        and value["record_revision"] > 0
    )


def assess_w02_25c_model_candidate(
    *,
    hcl_mol_l: object,
    naoh_mol_l: object,
    final_mixture_basis: object,
    run_temperature_k: object,
    kw_candidate: object,
    expected_water_reaction_ref: object,
) -> W02ModelAssessment:
    """Fail closed on missing/mismatched W02 *model* metadata.

    Even an assessment with model_compatible=True is merely a synthetic
    model-convention check. In particular, fields marked "candidate" or
    "synthetic_test" provide NO scientific/source/rights authenticity.
    The existing scalar solver is intentionally not invoked by this function.
    """
    reasons: list[str] = []

    def reject(code: str) -> None:
        if code not in reasons:
            reasons.append(code)

    if final_mixture_basis != "analytical_concentration_mol_l":
        reject("A3_W02_FINAL_MIXTURE_BASIS")
    for feed in (hcl_mol_l, naoh_mol_l):
        if not _finite_number(feed) or feed < 0.0:
            reject("A3_W02_FEED_INVALID")
            break
    if (
        _finite_number(hcl_mol_l)
        and _finite_number(naoh_mol_l)
        and hcl_mol_l == 0.0
        and naoh_mol_l == 0.0
    ):
        reject("A3_W02_NO_FEED")
    if not _finite_number(run_temperature_k) or run_temperature_k != _25C_K:
        reject("A3_W02_RUN_TEMPERATURE_UNSUPPORTED")

    if not _reference(expected_water_reaction_ref):
        reject("A3_W02_EXPECTED_REACTION_REF")
    if not isinstance(kw_candidate, Mapping):
        reject("A3_W02_KW_RECORD_MISSING")
        return W02ModelAssessment(False, tuple(reasons))

    if not _nonempty(kw_candidate.get("constant_id")) or not (
        isinstance(kw_candidate.get("record_revision"), int)
        and not isinstance(kw_candidate.get("record_revision"), bool)
        and kw_candidate["record_revision"] > 0
    ):
        reject("A3_W02_KW_REVISION")
    if (
        not _reference(kw_candidate.get("reaction_ref"))
        or not _reference(expected_water_reaction_ref)
        or dict(kw_candidate["reaction_ref"]) != dict(expected_water_reaction_ref)
    ):
        reject("A3_W02_KW_REACTION_REF")
    if (
        kw_candidate.get("property_kind") != "water_autoionization_kw"
        or kw_candidate.get("reaction_direction") != _DIRECTION
        or kw_candidate.get("proton_convention") != _PROTON_CONVENTION
    ):
        reject("A3_W02_KW_REACTION_BASIS")

    value = kw_candidate.get("dimensionless_value")
    if not _finite_number(value) or value <= 0.0 or kw_candidate.get("unit_id") != "1":
        reject("A3_W02_KW_VALUE_UNIT")
    if (
        kw_candidate.get("basis") != _MODEL
        or kw_candidate.get("phase_context") != "aq"
        or kw_candidate.get("medium") != "water"
    ):
        reject("A3_W02_KW_MODEL_CONTEXT")

    state = kw_candidate.get("standard_state")
    if (
        not isinstance(state, Mapping)
        or set(state) != set(_STANDARD_STATE)
        or any(
            not _finite_number(state.get(name)) or state[name] != 1.0
            for name in _STANDARD_STATE
        )
    ):
        reject("A3_W02_KW_STANDARD_STATE")

    # A single educational scalar at 25 °C has no automatic K(T) transform.
    # Both T declarations must exist and be exactly equal, never defaulted.
    temperature = kw_candidate.get("temperature_k")
    if (
        not _finite_number(temperature)
        or temperature != _25C_K
        or not _finite_number(run_temperature_k)
        or temperature != run_temperature_k
    ):
        reject("A3_W02_KW_TEMPERATURE_MISMATCH")

    # Keep this slice explicitly synthetic. A valid-looking 'accepted' record
    # or publisher name is not evidence of actual scientific/legal admission.
    if (
        kw_candidate.get("origin") != "synthetic_test"
        or kw_candidate.get("quality") != "unverified"
        or kw_candidate.get("model_eligibility_status") != "candidate"
    ):
        reject("A3_W02_REFERENCE_ADMISSION_NOT_ESTABLISHED")

    if (
        kw_candidate.get("uncertainty_status") != "not_reported"
        or kw_candidate.get("uncertainty") is not None
    ):
        reject("A3_W02_UNCERTAINTY_POLICY")

    source = kw_candidate.get("source")
    if not isinstance(source, Mapping) or any(
        not _nonempty(source.get(field))
        for field in ("source_id", "source_version", "field_locator", "retrieved_at_utc")
    ):
        reject("A3_W02_SOURCE_LOCATOR")

    # No rights-derived conclusion may be inferred even when all checks pass.
    return W02ModelAssessment(not reasons, tuple(reasons))
