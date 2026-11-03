"""A3 private scientific observation tests. No shared/wire DTO is defined."""

from dataclasses import replace
import json
import math
import unittest

from chemsim.equilibrium import (
    EquilibriumConvergenceError,
    solve_weak_acid,
    solve_strong_neutralization,
    solve_agcl_solubility,
    solve_ammonia_buffer,
    solve_agcl_precipitation,
    solve_no2_dimerization,
    solve_h2_i2_hi,
)
from chemsim.equilibrium_observations import project_local_equilibrium_observations


def _fixtures():
    kw = 1.0e-14  # Synthetic mathematical test input, NOT an admitted dataset.
    return {
        "W01": solve_weak_acid(0.01, 1.0e-5, kw),
        "W02": solve_strong_neutralization(0.01, 0.01, kw),
        "W03": solve_agcl_solubility(1.8e-10, kw),
        "W04": solve_ammonia_buffer(0.02, 0.01, 1.0e-9, kw),
        "W05": solve_agcl_precipitation(
            0.01, 0.01, 0.01, 0.01, 1.8e-10, kw
        ),
        "G01": solve_no2_dimerization(0.01, 0.0, 298.15, 1.0e-3, 6.73),
        "G02": solve_h2_i2_hi(0.01, 0.01, 0.0, 298.15, 1.0e-3, 690.2),
    }


def _amount(av):
    if av["status"] != "present":
        raise AssertionError("expected a present typed quantity")
    return av["quantity"]["value"]


class A3LocalObservationsTests(unittest.TestCase):
    def test_all_seven_local_fixtures_are_strict_json_without_nulls_or_false_release(self):
        def verify_no_nulls(obj):
            if isinstance(obj, dict):
                self.assertNotIn(None, obj.values())
                for value in obj.values():
                    verify_no_nulls(value)
            elif isinstance(obj, list):
                for value in obj:
                    verify_no_nulls(value)

        for name, result in _fixtures().items():
            with self.subTest(fixture=name):
                data = project_local_equilibrium_observations(result)
                encoded = json.dumps(data, allow_nan=False, sort_keys=True)
                self.assertEqual(json.loads(encoded), data)
                verify_no_nulls(data)
                self.assertEqual(data["scope"], "a3_local_scientific_observations_only")
                self.assertEqual(data["state_kind"], "single_equilibrium_state")
                self.assertFalse(data["reference_admitted"])
                self.assertFalse(data["redistribution_approved"])
                self.assertEqual(data["scientific_applicability"], "idealized_approximation")
                self.assertNotIn("samples", data)
                self.assertNotIn("contract_version", data)
                self.assertNotIn("message_id", data)
                self.assertEqual(data["diagnostics"]["iterations"]["quantity"]["unit_id"], "1")

    def test_aqueous_unmodelled_solid_does_not_leak_placeholder_zero(self):
        fixtures = _fixtures()
        for name in ("W01", "W02", "W04"):
            with self.subTest(fixture=name):
                output = project_local_equilibrium_observations(fixtures[name])
                self.assertEqual(output["phase"], "aqueous")
                self.assertEqual(output["solid_phase"]["state"], "not_modelled")
                self.assertEqual(
                    output["solid_phase"]["concentration"], {"status": "not_assessed"},
                )
                self.assertEqual(output["pH"]["method"], "ideal_concentration_approximation")
                self.assertEqual(output["pH"]["availability"]["quantity"]["unit_id"], "1")
                self.assertEqual(
                    output["diagnostics"]["primary"]["availability"]["quantity"]["unit_id"],
                    "mol/L",
                )
                self.assertTrue(all(
                    av["quantity"]["unit_id"] == "mol/L"
                    for av in output["species"].values()
                ))
        w02 = project_local_equilibrium_observations(fixtures["W02"])
        self.assertEqual(
            w02["diagnostics"]["component_balance"]["kind"], "spectator_feed_identity"
        )
        # Computed Na/Cl output-to-feed identity zero is present, not unknown.
        self.assertEqual(
            w02["diagnostics"]["component_balance"]["availability"],
            {"status": "present", "quantity": {"value": 0.0, "unit_id": "mol/L"}},
        )

    def test_w03_reservoir_unknown_is_not_assessed_and_not_zero_inventory(self):
        out = project_local_equilibrium_observations(_fixtures()["W03"])
        self.assertEqual(out["solid_phase"]["state"], "reservoir_inventory_unknown")
        self.assertEqual(out["solid_phase"]["concentration"], {"status": "unknown"})
        for key in ("primary", "component_balance"):
            with self.subTest(residual=key):
                item = out["diagnostics"][key]
                self.assertEqual(item["kind"], "not_assessed")
                self.assertEqual(item["availability"], {"status": "not_assessed"})
        self.assertEqual(
            out["diagnostics"]["charge_balance"]["availability"]["status"], "present"
        )

    def test_w05_zero_ion_boundary_and_absent_vs_real_precipitation(self):
        kw, ksp = 1.0e-14, 1.8e-10
        inactive = project_local_equilibrium_observations(
            solve_agcl_precipitation(1e-6, 1e-6, 1e-6, 1e-6, ksp, kw)
        )
        self.assertEqual(inactive["solid_phase"]["state"], "no_precipitate")
        self.assertEqual(_amount(inactive["solid_phase"]["concentration"]), 0.0)
        self.assertEqual(
            inactive["diagnostics"]["primary"]["availability"]["status"], "present"
        )
        self.assertEqual(
            inactive["diagnostics"]["primary"]["availability"]["quantity"]["unit_id"],
            "1",
        )

        active = project_local_equilibrium_observations(_fixtures()["W05"])
        self.assertEqual(active["solid_phase"]["state"], "new_precipitate")
        self.assertGreater(_amount(active["solid_phase"]["concentration"]), 0.0)
        self.assertEqual(active["solid_phase"]["concentration"]["quantity"]["unit_id"], "mol/L")
        self.assertEqual(
            active["diagnostics"]["primary"]["kind"], "log_saturation_index"
        )

        zero_ion = project_local_equilibrium_observations(
            solve_agcl_precipitation(0.01, 0.0, 0.0, 0.01, ksp, kw)
        )
        self.assertEqual(zero_ion["solid_phase"]["state"], "no_precipitate")
        self.assertEqual(_amount(zero_ion["solid_phase"]["concentration"]), 0.0)
        primary = zero_ion["diagnostics"]["primary"]
        self.assertEqual(primary["kind"], "log_saturation_index")
        self.assertEqual(primary["domain_status"], "zero_ion_activity")
        self.assertEqual(primary["declared_unit_id"], "1")
        self.assertEqual(primary["availability"], {"status": "not_applicable"})
        self.assertNotIn("quantity", primary["availability"])

    def test_gas_amount_pressures_and_no_fabricated_pH_or_charge(self):
        for name in ("G01", "G02"):
            with self.subTest(fixture=name):
                out = project_local_equilibrium_observations(_fixtures()[name])
                self.assertEqual(out["phase"], "gas")
                self.assertEqual(out["pH"]["availability"], {"status": "not_applicable"})
                self.assertEqual(out["solid_phase"]["concentration"], {"status": "not_applicable"})
                self.assertEqual(
                    out["diagnostics"]["charge_balance"]["availability"],
                    {"status": "not_applicable"},
                )
                self.assertEqual(
                    out["diagnostics"]["primary"]["availability"]["quantity"]["unit_id"],
                    "1",
                )
                self.assertEqual(
                    out["diagnostics"]["component_balance"]["availability"]["quantity"]["unit_id"],
                    "mol",
                )
                self.assertEqual(out["extent"]["quantity"]["unit_id"], "mol")
                self.assertEqual(out["total_pressure"]["quantity"]["unit_id"], "Pa")
                self.assertTrue(all(
                    v["quantity"]["unit_id"] == "mol"
                    for v in out["species"].values()
                ))
                self.assertTrue(all(
                    v["quantity"]["unit_id"] == "Pa"
                    for v in out["partial_pressures"].values()
                ))

    def test_reject_forged_bad_aqueous_or_gas_result_and_unknown_input(self):
        fixtures = _fixtures()
        aqueous = fixtures["W01"]
        gas = fixtures["G01"]
        invalid_aqueous = (
            replace(aqueous, pH_method="thermodynamic_activity"),
            replace(aqueous, pH=7.0),
            replace(aqueous, species_mol_l={**aqueous.species_mol_l, "H+": math.nan}),
            replace(aqueous, diagnostics=replace(
                aqueous.diagnostics, residual_unit="Pa",
            )),
            replace(aqueous, diagnostics=replace(
                aqueous.diagnostics, activity_model="gas_ideal_partial_pressure",
            )),
            replace(aqueous, diagnostics=replace(
                aqueous.diagnostics, reliability_status="verified",
            )),
            replace(aqueous, solid_phase_state="new_precipitate", solid_mol_l=0.0),
        )
        for forged in invalid_aqueous:
            with self.subTest(model="aqueous", forged=repr(forged)[:130]):
                with self.assertRaises(EquilibriumConvergenceError):
                    project_local_equilibrium_observations(forged)
        invalid_gas = (
            replace(gas, partial_pressures_pa={
                **gas.partial_pressures_pa, "NO2": math.inf
            }),
            replace(gas, diagnostics=replace(
                gas.diagnostics, charge_balance_residual=0.0,
            )),
            replace(gas, diagnostics=replace(
                gas.diagnostics, activity_model="ideal_dilute_gamma_equals_1",
            )),
        )
        for forged in invalid_gas:
            with self.subTest(model="gas", forged=repr(forged)[:130]):
                with self.assertRaises(EquilibriumConvergenceError):
                    project_local_equilibrium_observations(forged)
        for x in (None, {}, "invalid"):
            with self.subTest(unsupported=x):
                with self.assertRaises(TypeError):
                    project_local_equilibrium_observations(x)
