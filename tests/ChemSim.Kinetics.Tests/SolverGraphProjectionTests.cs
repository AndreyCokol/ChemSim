using System.Text.Json;
using ChemSim.Kinetics.Domain;
using ChemSim.Kinetics.Simulation;

namespace ChemSim.Kinetics.Tests;

public sealed class SolverGraphProjectionTests
{
    private static readonly GraphReference RunRef = new("run-uuid-owned-by-integrator", 4);

    private static SimulationRequest Request(double volume = 2d) => new()
    {
        Network = new ReactionNetwork(
            ["A", "B"],
            [new ReactionDefinition("synthetic-A-to-B",
                new Dictionary<string, int> { ["A"] = -1, ["B"] = 1 },
                new Dictionary<string, double> { ["A"] = 1d },
                new RateConstant(0.1d, 0d))]),
        InitialAmountsMol = new Dictionary<string, double> { ["A"] = 2d, ["B"] = 0d },
        VolumeM3 = volume,
        StartTimeSeconds = 0d,
        EndTimeSeconds = 2d,
        OutputIntervalSeconds = 1d,
        Solver = new SolverOptions { MaximumInternalSteps = 10000 }
    };

    private static IReadOnlyDictionary<string, GraphReference> Refs() =>
        new Dictionary<string, GraphReference>(StringComparer.Ordinal)
        {
            ["A"] = new("A", 10),
            ["B"] = new("B", 11)
        };

    private static IReadOnlyDictionary<string, string> SeriesIds() =>
        new Dictionary<string, string>(StringComparer.Ordinal)
        {
            ["A"] = "external-result-A-concentration",
            ["B"] = "external-result-B-concentration"
        };

    private static StateSample At(double time, double a, double b) =>
        new(time, new Dictionary<string, double>(StringComparer.Ordinal)
        {
            ["A"] = a,
            ["B"] = b
        });

    private static SimulationResult Result(SimulationStatus status, params StateSample[] samples) =>
        new(status, samples, new SimulationDiagnostics(1, 0, 7));

    private static IReadOnlyList<ConcentrationGraphSeries> Project(
        SimulationResult result,
        SimulationRequest? request = null,
        GraphReference? runRef = null,
        IReadOnlyDictionary<string, GraphReference>? refs = null,
        IReadOnlyDictionary<string, string>? ids = null) =>
        SolverGraphProjection.ProjectConcentrations(
            request ?? Request(), result, runRef ?? RunRef, refs ?? Refs(), ids ?? SeriesIds());

    [Fact]
    public void CompleteAmounts_ProduceTwoA5CompatibleConcentrationSeries_WithMeasuredZero()
    {
        var projected = Project(Result(SimulationStatus.Success,
            At(0, 2, 0), At(1, 1, 1), At(2, 0, 2)));
        Assert.Equal(2, projected.Count);
        Assert.Equal("external-result-A-concentration", projected[0].SeriesId);
        Assert.Equal("external-result-B-concentration", projected[1].SeriesId);
        Assert.All(projected, series =>
        {
            Assert.Equal("concentration", series.QuantityKey);
            Assert.Equal("mol/m3", series.UnitId);
            Assert.Equal(RunRef, series.ResultRef);
            Assert.Equal(3, series.Samples.Count);
            Assert.All(series.Samples, s => Assert.Equal("valid", s.ValueStatus));
        });
        Assert.Equal(0d, projected[0].Samples[^1].Value);
        Assert.Equal(0d, projected[1].Samples[0].Value);
        Assert.Equal(1d, projected[0].Samples[0].Value);
        Assert.Equal(0.5d, projected[0].Samples[1].Value);
        Assert.Equal(1d, projected[1].Samples[^1].Value);
        Assert.Equal(new GraphReference("A", 10), projected[0].SpeciesRef);
        Assert.Equal(new GraphReference("B", 11), projected[1].SpeciesRef);

        // Wire keys and optional sample value must match the *existing* A5
        // GraphSeries validator without introducing a new shared schema.
        using var json = JsonDocument.Parse(JsonSerializer.Serialize(projected[1]));
        var root = json.RootElement;
        Assert.Equal("external-result-B-concentration",
            root.GetProperty("series_id").GetString());
        Assert.Equal("run-uuid-owned-by-integrator",
            root.GetProperty("result_ref").GetProperty("id").GetString());
        Assert.Equal(4, root.GetProperty("result_ref").GetProperty("record_revision").GetInt32());
        Assert.Equal(11, root.GetProperty("species_ref").GetProperty("record_revision").GetInt32());
        Assert.Equal("mol/m3", root.GetProperty("unit_id").GetString());
        Assert.Equal("concentration", root.GetProperty("quantity_key").GetString());
        var first = root.GetProperty("samples")[0];
        Assert.Equal(0d, first.GetProperty("value").GetDouble());
        Assert.Equal("valid", first.GetProperty("value_status").GetString());
    }

    [Fact]
    public void StepLimit_RetainsValidatedPrefix_AndAddsExplicitMissingEndMarkerWithoutValue()
    {
        var projected = Project(Result(SimulationStatus.MaximumStepsExceeded,
            At(0, 2, 0), At(1, 1, 1)));
        Assert.All(projected, series =>
        {
            Assert.Equal(3, series.Samples.Count);
            Assert.Equal("valid", series.Samples[0].ValueStatus);
            Assert.Equal("valid", series.Samples[1].ValueStatus);
            Assert.Equal("missing", series.Samples[2].ValueStatus);
            Assert.Equal(2d, series.Samples[2].TimeSeconds);
            Assert.Null(series.Samples[2].Value);
            using var document = JsonDocument.Parse(JsonSerializer.Serialize(series));
            var last = document.RootElement.GetProperty("samples")[2];
            Assert.False(last.TryGetProperty("value", out _));
            Assert.Equal("missing", last.GetProperty("value_status").GetString());
        });
    }

    [Fact]
    public void InitialOnlyFailure_IsNotMistakenForNumericalProgressOrCompletedGraph()
    {
        var projected = Project(Result(SimulationStatus.Cancelled, At(0, 2, 0)));
        Assert.All(projected, x =>
        {
            Assert.Equal(2, x.Samples.Count);
            Assert.Equal("valid", x.Samples[0].ValueStatus);
            Assert.Equal("missing", x.Samples[1].ValueStatus);
        });
    }

    [Fact]
    public void NoSamplesYieldNoGraph_UnlessIncorrectlyMarkedSuccess()
    {
        Assert.Empty(Project(Result(SimulationStatus.InvalidInput)));
        Assert.Throws<ArgumentException>(() => Project(Result(SimulationStatus.Success)));
    }

    [Fact]
    public void RealKineticsSimulatorResult_IsAdmittedWithoutInventingRatesOrTemperature()
    {
        var request = Request();
        var result = new KineticsSimulator().Run(request);
        Assert.Equal(SimulationStatus.Success, result.Status);
        var projected = Project(result, request);
        Assert.Equal(2, projected.Count);
        Assert.All(projected, series =>
        {
            Assert.Equal("concentration", series.QuantityKey);
            Assert.Equal("mol/m3", series.UnitId);
            Assert.Equal(3, series.Samples.Count);
            Assert.Equal(2d, series.Samples[^1].TimeSeconds);
        });
        Assert.InRange(
            Math.Abs(projected[0].Samples[^1].Value!.Value - Math.Exp(-0.2d)), 0d, 5e-6);
    }

    [Theory]
    [InlineData(0d)]
    [InlineData(-1d)]
    [InlineData(double.NaN)]
    [InlineData(double.PositiveInfinity)]
    public void InvalidVolume_IsRejectedBeforeProjection(double volume)
    {
        Assert.Throws<ArgumentException>(() => Project(
            Result(SimulationStatus.Success, At(0, 2, 0), At(2, 0, 2)),
            Request(volume)));
    }

    [Fact]
    public void SuccessWithoutFinalSample_CannotBePresentedAsComplete()
    {
        Assert.Throws<ArgumentException>(() => Project(
            Result(SimulationStatus.Success, At(0, 2, 0), At(1, 1, 1))));
    }

    [Fact]
    public void DuplicateOrDescendingTimestamp_IsRejected()
    {
        Assert.Throws<ArgumentException>(() => Project(Result(SimulationStatus.Success,
            At(0, 2, 0), At(1, 1, 1), At(1, 0, 2))));
        Assert.Throws<ArgumentException>(() => Project(Result(SimulationStatus.Success,
            At(0, 2, 0), At(2, 0, 2), At(1, 1, 1))));
    }

    [Fact]
    public void MissingOrNonFiniteSampleAmounts_AreRejected()
    {
        var missing = new StateSample(1, new Dictionary<string, double> { ["A"] = 1 });
        Assert.Throws<ArgumentException>(() => Project(Result(
            SimulationStatus.StepSizeUnderflow, At(0, 2, 0), missing)));
        Assert.Throws<ArgumentException>(() => Project(Result(
            SimulationStatus.StepSizeUnderflow, At(0, 2, 0), At(1, double.NaN, 1))));
        Assert.Throws<ArgumentException>(() => Project(Result(
            SimulationStatus.StepSizeUnderflow, At(0, 2, 0), At(1, -1, 3))));
    }

    [Fact]
    public void ConcentrationOverflow_IsRejectedInsteadOfRenderingNonFiniteData()
    {
        var request = Request(double.Epsilon);
        Assert.Throws<ArgumentException>(() => Project(Result(
            SimulationStatus.MaximumStepsExceeded, At(0, double.MaxValue, 0)),
            request));
    }

    [Fact]
    public void IdentityIsNeverGuessedOrRewrittenByTheNumericalLayer()
    {
        var valid = Result(SimulationStatus.Success, At(0, 2, 0), At(2, 0, 2));
        Assert.Throws<ArgumentException>(() => Project(valid, runRef: new GraphReference("result", 0)));
        Assert.Throws<ArgumentException>(() => Project(valid,
            refs: new Dictionary<string, GraphReference>
            {
                ["A"] = new("NOT-A", 1), ["B"] = new("B", 1)
            }));
        Assert.Throws<ArgumentException>(() => Project(valid,
            refs: new Dictionary<string, GraphReference>
            {
                ["A"] = new("A", 1)
            }));
        Assert.Throws<ArgumentException>(() => Project(valid,
            ids: new Dictionary<string, string>
            {
                ["A"] = "duplicate", ["B"] = "duplicate"
            }));
    }
}
