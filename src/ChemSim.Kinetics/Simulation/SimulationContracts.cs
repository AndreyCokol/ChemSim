using ChemSim.Kinetics.Domain;

namespace ChemSim.Kinetics.Simulation;

public sealed record SolverOptions
{
    public double RelativeTolerance { get; init; } = 1e-6;
    public double AbsoluteToleranceMol { get; init; } = 1e-12;
    public double InitialStepSeconds { get; init; } = 1e-3;
    public double MinimumStepSeconds { get; init; } = 1e-12;
    public double MaximumStepSeconds { get; init; } = 1d;
    public int MaximumInternalSteps { get; init; } = 1_000_000;

    public void Validate()
    {
        if (!double.IsFinite(RelativeTolerance) || RelativeTolerance <= 0d)
            throw new ArgumentOutOfRangeException(nameof(RelativeTolerance));
        if (!double.IsFinite(AbsoluteToleranceMol) || AbsoluteToleranceMol <= 0d)
            throw new ArgumentOutOfRangeException(nameof(AbsoluteToleranceMol));
        if (!double.IsFinite(InitialStepSeconds) || InitialStepSeconds <= 0d)
            throw new ArgumentOutOfRangeException(nameof(InitialStepSeconds));
        if (!double.IsFinite(MinimumStepSeconds) || MinimumStepSeconds <= 0d)
            throw new ArgumentOutOfRangeException(nameof(MinimumStepSeconds));
        if (!double.IsFinite(MaximumStepSeconds) || MaximumStepSeconds < MinimumStepSeconds)
            throw new ArgumentOutOfRangeException(nameof(MaximumStepSeconds));
        if (InitialStepSeconds < MinimumStepSeconds)
            throw new ArgumentException("Initial step cannot be smaller than minimum step.");
        if (MaximumInternalSteps <= 0)
            throw new ArgumentOutOfRangeException(nameof(MaximumInternalSteps));
    }
}

public sealed record SimulationRequest
{
    public required ReactionNetwork Network { get; init; }
    public required IReadOnlyDictionary<string, double> InitialAmountsMol { get; init; }
    public required double VolumeM3 { get; init; }
    public required double StartTimeSeconds { get; init; }
    public required double EndTimeSeconds { get; init; }
    public required double OutputIntervalSeconds { get; init; }
    public SolverOptions Solver { get; init; } = new();

    public void Validate()
    {
        ArgumentNullException.ThrowIfNull(Network);
        ArgumentNullException.ThrowIfNull(InitialAmountsMol);
        ArgumentNullException.ThrowIfNull(Solver);
        Solver.Validate();

        if (!double.IsFinite(VolumeM3) || VolumeM3 <= 0d)
            throw new ArgumentOutOfRangeException(nameof(VolumeM3), "Volume must be finite and greater than zero.");
        if (!double.IsFinite(StartTimeSeconds) || !double.IsFinite(EndTimeSeconds) || EndTimeSeconds <= StartTimeSeconds)
            throw new ArgumentException("End time must be finite and greater than start time.");
        if (!double.IsFinite(OutputIntervalSeconds) || OutputIntervalSeconds <= 0d)
            throw new ArgumentOutOfRangeException(nameof(OutputIntervalSeconds));

        var expected = Network.SpeciesIds.ToHashSet(StringComparer.Ordinal);
        if (InitialAmountsMol.Count != expected.Count || InitialAmountsMol.Keys.Any(id => !expected.Contains(id)))
            throw new ArgumentException("Initial state must contain exactly one amount for every network species.", nameof(InitialAmountsMol));

        foreach (var speciesId in Network.SpeciesIds)
        {
            var amount = InitialAmountsMol[speciesId];
            if (!double.IsFinite(amount) || amount < 0d)
                throw new ArgumentOutOfRangeException(nameof(InitialAmountsMol), $"Initial amount for '{speciesId}' must be finite and non-negative.");
        }
    }
}

public sealed record StateSample(double TimeSeconds, IReadOnlyDictionary<string, double> AmountsMol);

public enum SimulationStatus
{
    Success,
    InvalidInput,
    StepSizeUnderflow,
    MaximumStepsExceeded,
    NonPhysicalState,
    ConservationFailure,
    Cancelled,
    NumericalFailure
}

public sealed record SimulationDiagnostics(
    int AcceptedSteps,
    int RejectedSteps,
    int RightHandSideEvaluations,
    string? Message = null);

public sealed record SimulationResult(
    SimulationStatus Status,
    IReadOnlyList<StateSample> Samples,
    SimulationDiagnostics Diagnostics)
{
    public bool IsSuccess => Status == SimulationStatus.Success;
}
