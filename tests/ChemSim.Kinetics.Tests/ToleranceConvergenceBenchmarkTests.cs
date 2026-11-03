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

    [Fact]
    public void ConsecutiveFirstOrderNetwork_ProfileErrorDecreasesAsTolerancesTighten()
    {
        var looseError = MeasureConsecutiveMaximumProfileError(relativeTolerance: 1e-2d);
        var baselineError = MeasureConsecutiveMaximumProfileError(relativeTolerance: 1e-4d);
        var tightError = MeasureConsecutiveMaximumProfileError(relativeTolerance: 1e-6d);

        Assert.True(looseError > 0d, $"Expected a measurable loose-tolerance error, got {looseError:G17}.");
        Assert.True(baselineError < looseError * 0.5d,
            $"Baseline error {baselineError:G17} did not clearly improve on loose error {looseError:G17}.");
        Assert.True(tightError < baselineError * 0.5d,
            $"Tight error {tightError:G17} did not clearly improve on baseline error {baselineError:G17}.");
    }

    private static double MeasureConsecutiveMaximumProfileError(double relativeTolerance)
    {
        const double initialA = 1d;
        const double rateConstant = 0.4d;
        const double endTime = 5d;

        var network = new ReactionNetwork(
            ["A", "B", "C"],
            [
                new ReactionDefinition(
                    "A-to-B",
                    new Dictionary<string, int> { ["A"] = -1, ["B"] = 1 },
                    new Dictionary<string, double> { ["A"] = 1d },
                    new RateConstant(rateConstant, 0d)),
                new ReactionDefinition(
                    "B-to-C",
                    new Dictionary<string, int> { ["B"] = -1, ["C"] = 1 },
                    new Dictionary<string, double> { ["B"] = 1d },
                    new RateConstant(rateConstant, 0d))
            ],
            [
                new ConservationLaw("total", new Dictionary<string, double>
                {
                    ["A"] = 1d, ["B"] = 1d, ["C"] = 1d
                })
            ]);

        var result = new KineticsSimulator().Run(new SimulationRequest
        {
            Network = network,
            InitialAmountsMol = new Dictionary<string, double>
            {
                ["A"] = initialA, ["B"] = 0d, ["C"] = 0d
            },
            VolumeM3 = 1d,
            StartTimeSeconds = 0d,
            EndTimeSeconds = endTime,
            OutputIntervalSeconds = endTime,
            Solver = new SolverOptions
            {
                RelativeTolerance = relativeTolerance,
                AbsoluteToleranceMol = 1e-14d,
                InitialStepSeconds = endTime,
                MinimumStepSeconds = 1e-12d,
                MaximumStepSeconds = endTime
            }
        });

        Assert.True(result.IsSuccess, result.Diagnostics.Message);
        Assert.Equal(2, result.Samples.Count);

        var maximumError = 0d;
        foreach (var sample in result.Samples)
        {
            var expectedA = initialA * Math.Exp(-rateConstant * sample.TimeSeconds);
            var expectedB = rateConstant * sample.TimeSeconds * expectedA;
            var expectedC = initialA - expectedA - expectedB;

            maximumError = Math.Max(maximumError, Math.Abs(sample.AmountsMol["A"] - expectedA));
            maximumError = Math.Max(maximumError, Math.Abs(sample.AmountsMol["B"] - expectedB));
            maximumError = Math.Max(maximumError, Math.Abs(sample.AmountsMol["C"] - expectedC));
            Assert.All(sample.AmountsMol.Values, amount =>
                Assert.True(double.IsFinite(amount) && amount >= 0d));
            Assert.InRange(
                Math.Abs(sample.AmountsMol["A"] + sample.AmountsMol["B"] + sample.AmountsMol["C"] - initialA),
                0d,
                5e-10d);
        }

        return maximumError;
    }

    [Fact]
    public void ParallelFirstOrderPathways_ProfileErrorDecreasesAsTolerancesTighten()
    {
        var looseError = MeasureParallelMaximumEndpointError(relativeTolerance: 1e-2d);
        var baselineError = MeasureParallelMaximumEndpointError(relativeTolerance: 1e-4d);
        var tightError = MeasureParallelMaximumEndpointError(relativeTolerance: 1e-6d);

        Assert.True(looseError > 0d, $"Expected a measurable loose-tolerance error, got {looseError:G17}.");
        Assert.True(baselineError < looseError * 0.5d,
            $"Baseline error {baselineError:G17} did not clearly improve on loose error {looseError:G17}.");
        Assert.True(tightError < baselineError * 0.5d,
            $"Tight error {tightError:G17} did not clearly improve on baseline error {baselineError:G17}.");
    }

    private static double MeasureParallelMaximumEndpointError(double relativeTolerance)
    {
        const double initialA = 1d;
        const double firstRate = 0.7d;
        const double secondRate = 0.3d;
        const double totalRate = firstRate + secondRate;
        const double endTime = 5d;

        var network = new ReactionNetwork(
            ["A", "B", "C"],
            [
                new ReactionDefinition(
                    "A-to-B",
                    new Dictionary<string, int> { ["A"] = -1, ["B"] = 1 },
                    new Dictionary<string, double> { ["A"] = 1d },
                    new RateConstant(firstRate, 0d)),
                new ReactionDefinition(
                    "A-to-C",
                    new Dictionary<string, int> { ["A"] = -1, ["C"] = 1 },
                    new Dictionary<string, double> { ["A"] = 1d },
                    new RateConstant(secondRate, 0d))
            ],
            [
                new ConservationLaw("total", new Dictionary<string, double>
                {
                    ["A"] = 1d, ["B"] = 1d, ["C"] = 1d
                })
            ]);

        var result = new KineticsSimulator().Run(new SimulationRequest
        {
            Network = network,
            InitialAmountsMol = new Dictionary<string, double>
            {
                ["A"] = initialA, ["B"] = 0d, ["C"] = 0d
            },
            VolumeM3 = 1d,
            StartTimeSeconds = 0d,
            EndTimeSeconds = endTime,
            OutputIntervalSeconds = endTime,
            Solver = new SolverOptions
            {
                RelativeTolerance = relativeTolerance,
                AbsoluteToleranceMol = 1e-14d,
                InitialStepSeconds = endTime,
                MinimumStepSeconds = 1e-12d,
                MaximumStepSeconds = endTime
            }
        });

        Assert.True(result.IsSuccess, result.Diagnostics.Message);
        Assert.Equal(2, result.Samples.Count);

        var final = result.Samples[^1];
        var expectedA = initialA * Math.Exp(-totalRate * endTime);
        var expectedB = firstRate / totalRate * (initialA - expectedA);
        var expectedC = secondRate / totalRate * (initialA - expectedA);
        var actualA = final.AmountsMol["A"];
        var actualB = final.AmountsMol["B"];
        var actualC = final.AmountsMol["C"];

        Assert.All(final.AmountsMol.Values, amount =>
            Assert.True(double.IsFinite(amount) && amount >= 0d));
        Assert.InRange(Math.Abs(actualA + actualB + actualC - initialA), 0d, 5e-10d);

        return Math.Max(
            Math.Abs(actualA - expectedA),
            Math.Max(Math.Abs(actualB - expectedB), Math.Abs(actualC - expectedC)));
    }

    [Fact]
    public void HalfOrderReaction_ProfileErrorDecreasesAsTolerancesTighten()
    {
        var looseError = MeasureHalfOrderMaximumEndpointError(relativeTolerance: 1e-2d);
        var baselineError = MeasureHalfOrderMaximumEndpointError(relativeTolerance: 1e-4d);
        var tightError = MeasureHalfOrderMaximumEndpointError(relativeTolerance: 1e-6d);

        Assert.True(looseError > 0d, $"Expected a measurable loose-tolerance error, got {looseError:G17}.");
        Assert.True(baselineError < looseError * 0.5d,
            $"Baseline error {baselineError:G17} did not clearly improve on loose error {looseError:G17}.");
        Assert.True(tightError < baselineError * 0.5d,
            $"Tight error {tightError:G17} did not clearly improve on baseline error {baselineError:G17}.");
    }

    private static double MeasureHalfOrderMaximumEndpointError(double relativeTolerance)
    {
        const double initialA = 4d;
        const double volume = 2d;
        const double rateConstant = 0.6d;
        const double endTime = 2d;

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
            OutputIntervalSeconds = endTime,
            Solver = new SolverOptions
            {
                RelativeTolerance = relativeTolerance,
                AbsoluteToleranceMol = 1e-14d,
                InitialStepSeconds = endTime,
                MinimumStepSeconds = 1e-12d,
                MaximumStepSeconds = endTime
            }
        });

        Assert.True(result.IsSuccess, result.Diagnostics.Message);
        Assert.Equal(2, result.Samples.Count);

        var maximumError = 0d;
        foreach (var sample in result.Samples)
        {
            var remainingRoot = Math.Sqrt(initialA) -
                                rateConstant * Math.Sqrt(volume) * sample.TimeSeconds / 2d;
            var expectedA = remainingRoot * remainingRoot;
            var expectedB = initialA - expectedA;
            var actualA = sample.AmountsMol["A"];
            var actualB = sample.AmountsMol["B"];

            Assert.True(double.IsFinite(actualA) && actualA >= 0d);
            Assert.True(double.IsFinite(actualB) && actualB >= 0d);
            Assert.InRange(Math.Abs(actualA + actualB - initialA), 0d, 5e-10d);

            maximumError = Math.Max(maximumError, Math.Abs(actualA - expectedA));
            maximumError = Math.Max(maximumError, Math.Abs(actualB - expectedB));
        }

        return maximumError;
    }
}
