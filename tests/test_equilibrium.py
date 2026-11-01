import math
import unittest

from chemsim.equilibrium import (
    EquilibriumInputError,
    solve_agcl_precipitation,
    solve_agcl_solubility,
    solve_ammonia_buffer,
    solve_h2_i2_hi,
    solve_no2_dimerization,
    solve_strong_neutralization,
    solve_weak_acid,
)


class AqueousBenchmarkTests(unittest.TestCase):
    def test_w01_acetic_acid(self):
        ka = 10 ** -4.756
        result = solve_weak_acid(0.01000, ka, 1.0e-14)
        self.assertAlmostEqual(result.species_mol_l["HA"] + result.species_mol_l["A-"], 0.01000, places=12)
        self.assertAlmostEqual(result.species_mol_l["H+"], result.species_mol_l["A-"] + result.species_mol_l["OH-"], places=11)
        self.assertAlmostEqual(result.pH, 3.387, delta=0.01)
        self.assertGreater(result.diagnostics.iterations, 0)

    def test_w02_strong_neutralization(self):
        result = solve_strong_neutralization(0.01000, 0.01000, 1.0e-14)
        self.assertAlmostEqual(result.pH, 7.0, places=10)
        self.assertAlmostEqual(result.species_mol_l["Na+"], 0.01000)
        self.assertAlmostEqual(result.species_mol_l["Cl-"], 0.01000)
        self.assertLess(result.diagnostics.charge_balance_mol, 1e-12)

    def test_w03_agcl_solubility(self):
        result = solve_agcl_solubility(10 ** -9.748, 1.0e-14)
        self.assertAlmostEqual(result.species_mol_l["Ag+"], 1.335e-5, delta=2e-8)
        self.assertAlmostEqual(result.species_mol_l["Ag+"], result.species_mol_l["Cl-"], places=14)
        self.assertAlmostEqual(result.pH, 7.0, places=10)
        self.assertEqual(result.solid_mol_l, 0.0)  # no initial solid inventory is fabricated

    def test_w04_ammonia_buffer(self):
        result = solve_ammonia_buffer(0.02000, 0.01000, 10 ** -9.245, 1.0e-14)
        self.assertAlmostEqual(result.species_mol_l["NH3"] + result.species_mol_l["NH4+"], 0.02000, places=12)
        self.assertAlmostEqual(result.species_mol_l["Cl-"], 0.01000)
        self.assertAlmostEqual(result.pH, 9.245, delta=0.01)

    def test_w05_agcl_precipitation(self):
        ksp = 10 ** -9.748
        result = solve_agcl_precipitation(
            0.01000, 0.01000, 0.01000, 0.01000, ksp, 1.0e-14
        )
        self.assertAlmostEqual(result.species_mol_l["Ag+"], math.sqrt(ksp), delta=1e-10)
        self.assertAlmostEqual(result.species_mol_l["Cl-"], math.sqrt(ksp), delta=1e-10)
        self.assertAlmostEqual(result.solid_mol_l, 0.01000 - math.sqrt(ksp), delta=1e-10)
        self.assertLess(result.diagnostics.mass_balance_max_mol, 1e-11)
        self.assertLess(result.diagnostics.charge_balance_mol, 1e-11)

    def test_precipitation_is_inactive_when_undersaturated(self):
        result = solve_agcl_precipitation(
            1e-6, 1e-6, 1e-6, 1e-6, 10 ** -9.748, 1e-14
        )
        self.assertEqual(result.solid_mol_l, 0.0)

    def test_rejects_inconsistent_spectator_totals(self):
        with self.assertRaises(EquilibriumInputError):
            solve_agcl_precipitation(0.01, 0.01, 0.02, 0.01, 1e-10, 1e-14)


class GasBenchmarkTests(unittest.TestCase):
    def test_g01_no2_dimerization(self):
        result = solve_no2_dimerization(0.010, 0.0, 298.15, 1.0e-3, 6.73)
        self.assertGreater(result.species_mol["N2O4"], 0.0)
        self.assertGreater(result.species_mol["NO2"], 0.0)
        self.assertAlmostEqual(
            result.species_mol["NO2"] + 2 * result.species_mol["N2O4"],
            0.010,
            places=11,
        )
        p_no2 = result.partial_pressures_pa["NO2"] / 100_000.0
        p_n2o4 = result.partial_pressures_pa["N2O4"] / 100_000.0
        self.assertAlmostEqual(p_n2o4 / (p_no2 * p_no2), 6.73, delta=1e-7)

    def test_g02_h2_i2_hi(self):
        result = solve_h2_i2_hi(0.010, 0.010, 0.0, 298.15, 1.0e-3, 690.2)
        self.assertGreater(result.species_mol["HI"], 0.0)
        self.assertAlmostEqual(result.species_mol["H2"], result.species_mol["I2(g)"], places=11)
        p_hi = result.partial_pressures_pa["HI"] / 100_000.0
        p_h2 = result.partial_pressures_pa["H2"] / 100_000.0
        p_i2 = result.partial_pressures_pa["I2(g)"] / 100_000.0
        self.assertAlmostEqual((p_hi * p_hi) / (p_h2 * p_i2), 690.2, delta=1e-5)

    def test_rejects_zero_equilibrium_constant(self):
        with self.assertRaises(EquilibriumInputError):
            solve_no2_dimerization(0.01, 0.0, 298.15, 1e-3, 0.0)


if __name__ == "__main__":
    unittest.main()
