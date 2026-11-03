using ChemSim.Kinetics.Domain;
using ChemSim.Kinetics.Simulation;

namespace ChemSim.Kinetics.Tests;

public sealed class FirstAndSecondOrderBenchmarkTests
{
    [Fact]
    public void FirstOrderReaction_MatchesAnalyticalProfileAtEveryOutputSample()
    {
        const double initialA = 1d;
        const double rateConstant = 0.5d;
        const double endTime = 5d;

        var network = new ReactionNetwork(
            ["A", "B"],
            [
                new ReactionDefinition(
                    "first-order-A-to-B",
                    new Dictionary<string, int> { ["A"] = -1, ["B"] = 1 },
                    new Dictionary<string, double> { ["A"] = 1d },
                    new RateConstant(rateConstant, 0d))
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
            VolumeM3 = 1d,
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
        Assert.Equal(21, result.Samples.Count);

        foreach (var sample in result.Samples)
        {
            var expectedA = initialA * Math.Exp(-rateConstant * sample.TimeSeconds);
            var expectedB = initialA - expectedA;

            Assert.InRange(Math.Abs(sample.AmountsMol["A"] - expectedA), 0d, 3e-9);
            Assert.InRange(Math.Abs(sample.AmountsMol["B"] - expectedB), 0d, 3e-9);
            Assert.InRange(Math.Abs(sample.AmountsMol.Values.Sum() - initialA), 0d, 2e-10);
            Assert.All(sample.AmountsMol.Values, amount => Assert.True(double.IsFinite(amount) && amount >= 0d));
        }
    }

    [Fact]
    public void SecondOrderReaction_MatchesAnalyticalProfileAtEveryOutputSample()
    {
        const double initialA = 2d;
        const double volume = 1d;
        const double rateConstant = 0.1d;
        const double endTime = 3d;

        var network = new ReactionNetwork(
            ["A", "B"],
            [
                new ReactionDefinition(
                    "second-order-2A-to-B",
                    new Dictionary<string, int> { ["A"] = -2, ["B"] = 1 },
                    new Dictionary<string, double> { ["A"] = 2d },
                    new RateConstant(rateConstant, -1d))
            ],
            [
                new ConservationLaw("A-fragment", new Dictionary<string, double>
                {
                    ["A"] = 1d, ["B"] = 2d
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
            OutputIntervalSeconds = 0.1d,
            Solver = new SolverOptions
            {
                RelativeTolerance = 1e-9,
                AbsoluteToleranceMol = 1e-12
            }
        });

        Assert.True(result.IsSuccess, result.Diagnostics.Message);
        Assert.Equal(31, result.Samples.Count);

        foreach (var sample in result.Samples)
        {
            var expectedA = initialA /
                            (1d + 2d * rateConstant * initialA * sample.TimeSeconds / volume);
            var expectedB = (initialA - expectedA) / 2d;

            Assert.InRange(Math.Abs(sample.AmountsMol["A"] - expectedA), 0d, 3e-9);
            Assert.InRange(Math.Abs(sample.AmountsMol["B"] - expectedB), 0d, 3e-9);
            Assert.InRange(
                Math.Abs(sample.AmountsMol["A"] + 2d * sample.AmountsMol["B"] - initialA),
                0d,
                2e-10);
            Assert.All(sample.AmountsMol.Values, amount => Assert.True(double.IsFinite(amount) && amount >= 0d));
        }
    }
}
