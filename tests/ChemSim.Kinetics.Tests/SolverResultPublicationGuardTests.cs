using ChemSim.Kinetics.Domain;
using ChemSim.Kinetics.Simulation;

namespace ChemSim.Kinetics.Tests;

public sealed class SolverResultPublicationGuardTests
{
    private static SimulationRequest Request() => new()
    {
        Network = new ReactionNetwork(["A", "B"],
            [new ReactionDefinition("synthetic",
                new Dictionary<string, int> { ["A"] = -1, ["B"] = 1 },
                new Dictionary<string, double> { ["A"] = 1d },
                new RateConstant(0.2d, 0d))]),
        InitialAmountsMol = new Dictionary<string, double> { ["A"] = 1d, ["B"] = 0d },
        VolumeM3 = 1d,
        StartTimeSeconds = 0d,
        EndTimeSeconds = 2d,
        OutputIntervalSeconds = 1d
    };

    private static StateSample At(double time, double a, double b) =>
        new(time, new Dictionary<string, double>(StringComparer.Ordinal)
        {
            ["A"] = a, ["B"] = b
        });

    private static SimulationResult Make(SimulationStatus status, params StateSample[] samples) =>
        new(status, samples, new SimulationDiagnostics(2, 0, 14));

    private static ValidatedResultPrefix Check(SimulationResult result, int maxSamples = 8) =>
        SolverResultPublicationGuard.Validate(Request(), result, maxSamples);

    [Fact]
    public void RealNumericalSuccess_IsVerifiedBeforeItCanBeCalledComplete()
    {
        var request = Request();
        var run = new KineticsSimulator().Run(request);
        Assert.Equal(SimulationStatus.Success, run.Status);
        var checkedResult = SolverResultPublicationGuard.Validate(request, run, 8);

        Assert.True(checkedResult.IsComplete);
        Assert.Equal(3, checkedResult.ValidSampleCount);
        Assert.Equal(2d, checkedResult.LastValidTimeSeconds);
    }

    [Fact]
    public void NonSuccessWithValidPrefix_IsNeverPromotedToComplete()
    {
        var checkedResult = Check(Make(SimulationStatus.MaximumStepsExceeded,
            At(0, 1, 0), At(1, 0.8d, 0.2d)));
        Assert.False(checkedResult.IsComplete);
        Assert.Equal(2, checkedResult.ValidSampleCount);
        Assert.Equal(1d, checkedResult.LastValidTimeSeconds);
    }

    [Fact]
    public void NonSuccessEvenWithFinalTarget_RemainsNonSuccess()
    {
        var checkedResult = Check(Make(SimulationStatus.ConservationFailure,
            At(0, 1, 0), At(2, 0.8d, 0.2d)));
        Assert.False(checkedResult.IsComplete);
        Assert.Equal(2d, checkedResult.LastValidTimeSeconds);
    }

    [Fact]
    public void EmptyNonSuccess_HasNoValidTimeOrPublishedSamples()
    {
        var checkedResult = Check(Make(SimulationStatus.InvalidInput));
        Assert.False(checkedResult.IsComplete);
        Assert.Equal(0, checkedResult.ValidSampleCount);
        Assert.Null(checkedResult.LastValidTimeSeconds);
    }

    [Fact]
    public void SuccessWithoutFinalTimeOrAnyTrajectory_FailsClosed()
    {
        Assert.Throws<SolverResultPublicationException>(() =>
            Check(Make(SimulationStatus.Success, At(0, 1, 0), At(1, 0.8d, 0.2d))));
        Assert.Throws<SolverResultPublicationException>(() =>
            Check(Make(SimulationStatus.Success, At(0, 1, 0))));
        Assert.Throws<SolverResultPublicationException>(() =>
            Check(Make(SimulationStatus.Success)));
    }

    [Fact]
    public void NoValidInitialTime_OrWrongInitialState_FailsClosed()
    {
        Assert.Throws<SolverResultPublicationException>(() =>
            Check(Make(SimulationStatus.MaximumStepsExceeded, At(1, 1, 0))));
        Assert.Throws<SolverResultPublicationException>(() =>
            Check(Make(SimulationStatus.MaximumStepsExceeded, At(0, 0.9d, 0.1d))));
    }

    [Fact]
    public void DuplicatedDescendingOrOutOfRangeTime_FailsClosed()
    {
        Assert.Throws<SolverResultPublicationException>(() =>
            Check(Make(SimulationStatus.Cancelled,
                At(0, 1, 0), At(1, 0.8d, 0.2d), At(1, 0.7d, 0.3d))));
        Assert.Throws<SolverResultPublicationException>(() =>
            Check(Make(SimulationStatus.Cancelled,
                At(0, 1, 0), At(2, 0.8d, 0.2d), At(1, 0.7d, 0.3d))));
        Assert.Throws<SolverResultPublicationException>(() =>
            Check(Make(SimulationStatus.Cancelled,
                At(0, 1, 0), At(3, 0.8d, 0.2d))));
        Assert.Throws<SolverResultPublicationException>(() =>
            Check(Make(SimulationStatus.Cancelled,
                At(0, 1, 0), At(double.NaN, 0.8d, 0.2d))));
    }

    [Fact]
    public void MissingExtraNonfiniteOrNegativeAmounts_FailClosed()
    {
        StateSample[] samplesWith(StateSample second) => [At(0, 1, 0), second];
        Assert.Throws<SolverResultPublicationException>(() => Check(Make(
            SimulationStatus.MaximumStepsExceeded,
            samplesWith(new StateSample(1, new Dictionary<string, double> { ["A"] = 0.9d })))));
        Assert.Throws<SolverResultPublicationException>(() => Check(Make(
            SimulationStatus.MaximumStepsExceeded,
            samplesWith(new StateSample(1, new Dictionary<string, double>
            {
                ["A"] = 0.9d, ["C"] = 0.1d
            })))));
        Assert.Throws<SolverResultPublicationException>(() => Check(Make(
            SimulationStatus.MaximumStepsExceeded, samplesWith(At(1, double.PositiveInfinity, 0)))));
        Assert.Throws<SolverResultPublicationException>(() => Check(Make(
            SimulationStatus.MaximumStepsExceeded, samplesWith(At(1, -0.1d, 1.1d)))));
    }

    [Fact]
    public void ResourceLimitIsEnforcedOnOutput_NotJustCliInput()
    {
        var result = Make(SimulationStatus.Success,
            At(0, 1, 0), At(1, 0.8d, 0.2d), At(2, 0.6d, 0.4d));
        Assert.Throws<SolverResultPublicationException>(() => Check(result, maxSamples: 2));
    }

    [Fact]
    public void NegativeCountersAndUnknownStatus_AreInternalIntegrityFailures()
    {
        var invalidCounters = new SimulationResult(
            SimulationStatus.Success,
            [At(0, 1, 0), At(2, 0.8d, 0.2d)],
            new SimulationDiagnostics(-1, 0, 0));
        Assert.Throws<SolverResultPublicationException>(() => Check(invalidCounters));

        var unknown = Make((SimulationStatus)424242,
            At(0, 1, 0), At(2, 0.8d, 0.2d));
        Assert.Throws<SolverResultPublicationException>(() => Check(unknown));
    }
}
