using ChemSim.Kinetics.Domain;
using ChemSim.Kinetics.Simulation;

namespace ChemSim.Kinetics.Tests;

public sealed class ToleranceConvergenceBenchmarkTests
{
    [Fact]
    public void FirstOrderReaction_ProfileErrorDecreasesAsTolerancesTighten()
    {
        var looseError = MeasureMaximumProfileError(relativeTolerance: 1e-4d);
        var baselineError = MeasureMaximumProfileError(relativeTolerance: 1e-6d);
        var tightError = MeasureMaximumProfileError(relativeTolerance: 1e-8d);

        Assert.True(looseError > 0d, $"Expected a measurable loose-tolerance error, got {looseError:G17}.");
        Assert.True(baselineError < looseError * 0.5d,
            $"Baseline error {baselineError:G17} did not clearly improve on loose error {looseError:G17}.");
        Assert.True(tightError < baselineError * 0.5d,
            $"Tight error {tightError:G17} did not clearly improve on baseline error {baselineError:G17}.");
    }

    private static double MeasureMaximumProfileError(double relativeTolerance)
    {
        const double initialA = 1d;
        const double rateConstant = 0.7d;
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
            OutputIntervalSeconds = 0.5d,
            Solver = new SolverOptions
            {
                RelativeTolerance = relativeTolerance,
                AbsoluteToleranceMol = 1e-14d,
                InitialStepSeconds = 0.1d,
                MinimumStepSeconds = 1e-12d,
                MaximumStepSeconds = 0.5d
            }
        });

        Assert.True(result.IsSuccess, result.Diagnostics.Message);
        var maximumError = 0d;
        foreach (var sample in result.Samples)
        {
            var expectedA = initialA * Math.Exp(-rateConstant * sample.TimeSeconds);
            var expectedB = initialA - expectedA;
            maximumError = Math.Max(maximumError, Math.Abs(sample.AmountsMol["A"] - expectedA));
            maximumError = Math.Max(maximumError, Math.Abs(sample.AmountsMol["B"] - expectedB));
        }

        return maximumError;
    }

    [Fact]
    public void SecondOrderReaction_ProfileErrorDecreasesAsTolerancesTighten()
    {
        var looseError = MeasureSecondOrderMaximumProfileError(relativeTolerance: 1e-2d);
        var baselineError = MeasureSecondOrderMaximumProfileError(relativeTolerance: 1e-4d);
        var tightError = MeasureSecondOrderMaximumProfileError(relativeTolerance: 1e-6d);

        Assert.True(looseError > 0d, $"Expected a measurable loose-tolerance error, got {looseError:G17}.");
        Assert.True(baselineError < looseError * 0.5d,
            $"Baseline error {baselineError:G17} did not clearly improve on loose error {looseError:G17}.");
        Assert.True(tightError < baselineError * 0.5d,
            $"Tight error {tightError:G17} did not clearly improve on baseline error {baselineError:G17}.");
    }

    private static double MeasureSecondOrderMaximumProfileError(double relativeTolerance)
    {
        const double initialA = 2d;
        const double volume = 1d;
        const double rateConstant = 0.1d;
        const double endTime = 10d;

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
            OutputIntervalSeconds = 10d,
            Solver = new SolverOptions
            {
                RelativeTolerance = relativeTolerance,
                AbsoluteToleranceMol = 1e-14d,
                InitialStepSeconds = 10d,
                MinimumStepSeconds = 1e-12d,
                MaximumStepSeconds = 10d
            }
        });

        Assert.True(result.IsSuccess, result.Diagnostics.Message);
        var maximumError = 0d;
        foreach (var sample in result.Samples)
        {
            var expectedA = initialA /
                            (1d + 2d * rateConstant * initialA * sample.TimeSeconds / volume);
            var expectedB = (initialA - expectedA) / 2d;
            maximumError = Math.Max(maximumError, Math.Abs(sample.AmountsMol["A"] - expectedA));
            maximumError = Math.Max(maximumError, Math.Abs(sample.AmountsMol["B"] - expectedB));
        }

        return maximumError;
    }
}
