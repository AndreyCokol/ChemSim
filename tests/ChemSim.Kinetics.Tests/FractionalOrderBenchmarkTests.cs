using ChemSim.Kinetics.Domain;
using ChemSim.Kinetics.Simulation;

namespace ChemSim.Kinetics.Tests;

public sealed class FractionalOrderBenchmarkTests
{
    [Fact]
    public void HalfOrderReaction_MatchesAnalyticalProfileAtEveryOutputSample()
    {
        const double initialA = 4d;
        const double volume = 2d;
        const double rateConstant = 0.1d;
        const double endTime = 10d;
        var squareRootVolume = Math.Sqrt(volume);
        var network = new ReactionNetwork(
            ["A", "B"],
            [
                new ReactionDefinition(
                    "half-order-A-to-B",
                    new Dictionary<string, int> { ["A"] = -1, ["B"] = 1 },
                    new Dictionary<string, double> { ["A"] = 0.5d },
                    new RateConstant(rateConstant, 0.5d))
            ],
            [
                new ConservationLaw("total", new Dictionary<string, double>
                {
                    ["A"] = 1d, ["B"] = 1d
                })
            ]);

        var result = new KineticsSimulator().Run(new SimulationRequest
        {
            Network = network,
            InitialAmountsMol = new Dictionary<string, double>
            {
                ["A"] = initialA, ["B"] = 0d
            },
            VolumeM3 = volume,
            StartTimeSeconds = 0d,
            EndTimeSeconds = endTime,
            OutputIntervalSeconds = 0.25d,
            Solver = new SolverOptions
            {
                RelativeTolerance = 1e-9,
                AbsoluteToleranceMol = 1e-12
            }
        });

        Assert.True(result.IsSuccess, result.Diagnostics.Message);
        Assert.Equal(41, result.Samples.Count);

        foreach (var sample in result.Samples)
        {
            var expectedRootA = Math.Sqrt(initialA) -
                                0.5d * rateConstant * squareRootVolume * sample.TimeSeconds;
            var expectedA = expectedRootA * expectedRootA;
            var expectedB = initialA - expectedA;

            Assert.InRange(Math.Abs(sample.AmountsMol["A"] - expectedA), 0d, 3e-9);
            Assert.InRange(Math.Abs(sample.AmountsMol["B"] - expectedB), 0d, 3e-9);
            Assert.InRange(Math.Abs(sample.AmountsMol.Values.Sum() - initialA), 0d, 2e-10);
            Assert.All(sample.AmountsMol.Values, amount => Assert.True(double.IsFinite(amount) && amount >= 0d));
        }
    }
}
