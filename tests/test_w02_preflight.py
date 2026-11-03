"""Synthetic A3 scientific input checks; not an admitted A1 source dataset."""

import copy
import math
import unittest

from chemsim.equilibrium import solve_strong_neutralization
from chemsim.w02_preflight import assess_w02_25c_model_candidate


def _synthetic_candidate():
    return {
        "constant_id": "synthetic-water-ionization",
        "record_revision": 1,
        "reaction_ref": {"id": "synthetic-water-reaction", "record_revision": 2},
        "property_kind": "water_autoionization_kw",
        "reaction_direction": "water_to_hydrated_proton_and_hydroxide",
        "proton_convention": "H+_aq_alias_for_H3O+_aq",
        "dimensionless_value": 1.2345e-14,  # Arbitrary synthetic test scalar.
        "unit_id": "1",
        "basis": "aqueous_ideal_dilute_activity_approximation",
        "standard_state": {
            "c0_mol_l": 1.0,
            "gamma_h_plus": 1.0,
            "gamma_oh_minus": 1.0,
            "water_activity": 1.0,
        },
        "phase_context": "aq",
        "medium": "water",
        "temperature_k": 298.15,
        "origin": "synthetic_test",
        "quality": "unverified",
        "model_eligibility_status": "candidate",
        "uncertainty_status": "not_reported",
        "source": {
            "source_id": "synthetic-only",
            "source_version": "test-v1",
            "field_locator": "non-physical-fixture",
            "retrieved_at_utc": "synthetic-not-a-date",
        },
    }


def _parameters():
    c = _synthetic_candidate()
    return {
        "hcl_mol_l": 0.01,
        "naoh_mol_l": 0.01,
        "final_mixture_basis": "analytical_concentration_mol_l",
        "run_temperature_k": 298.15,
        "kw_candidate": c,
        "expected_water_reaction_ref": copy.deepcopy(c["reaction_ref"]),
    }


class W02PreflightTests(unittest.TestCase):
    def test_explicit_synthetic_model_compatibility_never_grants_science_or_rights(self):
        params = _parameters()
        result = assess_w02_25c_model_candidate(**params)
        self.assertTrue(result.model_compatible, result.reasons)
        self.assertEqual(result.reasons, ())
        self.assertEqual(result.scope, "synthetic_25c_model_preflight_only")
        self.assertFalse(result.reference_admitted)
        self.assertFalse(result.redistribution_approved)
        # The existing numerical fixture remains independent and idealized:
        # no source/rights promotion follows from a mathematical solution.
        solution = solve_strong_neutralization(
            params["hcl_mol_l"], params["naoh_mol_l"],
            params["kw_candidate"]["dimensionless_value"],
        )
        self.assertEqual(solution.pH_method, "ideal_concentration_approximation")
        h = solution.species_mol_l["H+"]
        oh = solution.species_mol_l["OH-"]
        self.assertAlmostEqual(
            h * oh, params["kw_candidate"]["dimensionless_value"], delta=1e-22
        )

    def test_rejects_invalid_or_unqualified_feeds_and_temperature(self):
        cases = (
            ("hcl_mol_l", None, "A3_W02_FEED_INVALID"),
            ("hcl_mol_l", True, "A3_W02_FEED_INVALID"),
            ("hcl_mol_l", -0.01, "A3_W02_FEED_INVALID"),
            ("hcl_mol_l", math.inf, "A3_W02_FEED_INVALID"),
            ("hcl_mol_l", 10 ** 500, "A3_W02_FEED_INVALID"),
            ("naoh_mol_l", math.nan, "A3_W02_FEED_INVALID"),
            ("final_mixture_basis", "source_vessel_mol_l", "A3_W02_FINAL_MIXTURE_BASIS"),
            ("final_mixture_basis", "mol", "A3_W02_FINAL_MIXTURE_BASIS"),
            ("run_temperature_k", None, "A3_W02_RUN_TEMPERATURE_UNSUPPORTED"),
            ("run_temperature_k", True, "A3_W02_RUN_TEMPERATURE_UNSUPPORTED"),
            ("run_temperature_k", 299.15, "A3_W02_RUN_TEMPERATURE_UNSUPPORTED"),
            ("run_temperature_k", 10 ** 500, "A3_W02_RUN_TEMPERATURE_UNSUPPORTED"),
        )
        for field, value, expected in cases:
            with self.subTest(field=field, value=value):
                params = _parameters()
                params[field] = value
                check = assess_w02_25c_model_candidate(**params)
                self.assertFalse(check.model_compatible)
                self.assertIn(expected, check.reasons)
        params = _parameters()
        params["hcl_mol_l"] = params["naoh_mol_l"] = 0.0
        self.assertIn(
            "A3_W02_NO_FEED", assess_w02_25c_model_candidate(**params).reasons
        )

    def test_rejects_wrong_water_reaction_identity_and_basis(self):
        field_cases = (
            ("constant_id", "", "A3_W02_KW_REVISION"),
            ("record_revision", True, "A3_W02_KW_REVISION"),
            ("property_kind", "kinetic_rate_k", "A3_W02_KW_REACTION_BASIS"),
            ("reaction_direction", "reverse", "A3_W02_KW_REACTION_BASIS"),
            ("proton_convention", "treat_H3O_as_extra_species", "A3_W02_KW_REACTION_BASIS"),
            ("dimensionless_value", 0.0, "A3_W02_KW_VALUE_UNIT"),
            ("dimensionless_value", False, "A3_W02_KW_VALUE_UNIT"),
            ("dimensionless_value", math.nan, "A3_W02_KW_VALUE_UNIT"),
            ("dimensionless_value", math.inf, "A3_W02_KW_VALUE_UNIT"),
            ("dimensionless_value", 10 ** 500, "A3_W02_KW_VALUE_UNIT"),
            ("unit_id", "mol/kg", "A3_W02_KW_VALUE_UNIT"),
            ("unit_id", "pKw", "A3_W02_KW_VALUE_UNIT"),
            ("basis", "iapws_molal_standard_state", "A3_W02_KW_MODEL_CONTEXT"),
            ("basis", "phreeqc_activity_log_k", "A3_W02_KW_MODEL_CONTEXT"),
            ("phase_context", "g", "A3_W02_KW_MODEL_CONTEXT"),
            ("medium", "ethanol", "A3_W02_KW_MODEL_CONTEXT"),
            ("temperature_k", 299.15, "A3_W02_KW_TEMPERATURE_MISMATCH"),
            ("temperature_k", None, "A3_W02_KW_TEMPERATURE_MISMATCH"),
            ("origin", "curated_reference", "A3_W02_REFERENCE_ADMISSION_NOT_ESTABLISHED"),
            ("quality", "verified", "A3_W02_REFERENCE_ADMISSION_NOT_ESTABLISHED"),
            ("model_eligibility_status", "accepted", "A3_W02_REFERENCE_ADMISSION_NOT_ESTABLISHED"),
            ("uncertainty_status", "reported", "A3_W02_UNCERTAINTY_POLICY"),
            ("uncertainty", 0.0, "A3_W02_UNCERTAINTY_POLICY"),
        )
        for field, value, reason in field_cases:
            with self.subTest(field=field, value=value):
                params = _parameters()
                params["kw_candidate"][field] = value
                result = assess_w02_25c_model_candidate(**params)
                self.assertFalse(result.model_compatible)
                self.assertIn(reason, result.reasons)

        for reference in (
            {"id": "other-reaction", "record_revision": 2},
            {"id": "synthetic-water-reaction", "record_revision": 3},
            {"id": "synthetic-water-reaction", "record_revision": True},
            {},
        ):
            with self.subTest(reaction_ref=reference):
                params = _parameters()
                params["kw_candidate"]["reaction_ref"] = reference
                self.assertIn(
                    "A3_W02_KW_REACTION_REF",
                    assess_w02_25c_model_candidate(**params).reasons,
                )

    def test_rejects_incomplete_source_standard_state_and_missing_candidate(self):
        params = _parameters()
        params["kw_candidate"] = None
        self.assertIn(
            "A3_W02_KW_RECORD_MISSING",
            assess_w02_25c_model_candidate(**params).reasons,
        )
        for update, reason in (
            (lambda k: k.pop("standard_state"), "A3_W02_KW_STANDARD_STATE"),
            (lambda k: k["standard_state"].update({"gamma_h_plus": 0.95}),
             "A3_W02_KW_STANDARD_STATE"),
            (lambda k: k["standard_state"].update({"c0_mol_l": True}),
             "A3_W02_KW_STANDARD_STATE"),
            (lambda k: k["source"].pop("field_locator"), "A3_W02_SOURCE_LOCATOR"),
            (lambda k: k["source"].update({"source_id": ""}),
             "A3_W02_SOURCE_LOCATOR"),
        ):
            with self.subTest(reason=reason):
                params = _parameters()
                update(params["kw_candidate"])
                self.assertIn(reason, assess_w02_25c_model_candidate(**params).reasons)
        params = _parameters()
        params["expected_water_reaction_ref"] = {
            "id": "synthetic-water-reaction", "record_revision": False,
        }
        check = assess_w02_25c_model_candidate(**params)
        self.assertIn("A3_W02_EXPECTED_REACTION_REF", check.reasons)
        self.assertIn("A3_W02_KW_REACTION_REF", check.reasons)
