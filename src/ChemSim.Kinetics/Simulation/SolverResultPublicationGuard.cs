namespace ChemSim.Kinetics.Simulation;

/// <summary>
/// A numeric backend result that cannot safely be published as a time-series
/// response is an internal numerical publication failure, not invalid user input.
/// </summary>
public sealed class SolverResultPublicationException(string message) : Exception(message);

public sealed record ValidatedResultPrefix(
    bool IsComplete,
    int ValidSampleCount,
    double? LastValidTimeSeconds);

/// <summary>
/// Validates every solver sample before CLI result publication. The numerical
/// kernel is trusted to calculate, but its output must never bypass the same
/// roster/time/state safety requirements imposed on A5 graph consumers.
/// </summary>
public static class SolverResultPublicationGuard
{
    public static ValidatedResultPrefix Validate(
        SimulationRequest request,
        SimulationResult result,
        int maximumSamples)
    {
        ArgumentNullException.ThrowIfNull(request);
        ArgumentNullException.ThrowIfNull(result);
        if (maximumSamples <= 0)
            throw new ArgumentOutOfRangeException(nameof(maximumSamples));

        // This guard is only called after the CLI has admitted a valid request.
        // A malformed input is a separate admission failure.
        request.Validate();

        if (result.Samples is null || result.Diagnostics is null)
            throw new SolverResultPublicationException("Solver omitted its samples or diagnostics.");
        if (!Enum.IsDefined(result.Status))
            throw new SolverResultPublicationException("Solver returned an unknown termination status.");
        if (result.Samples.Count > maximumSamples)
            throw new SolverResultPublicationException("Solver exceeded the maximum serialized output sample count.");
        if (result.Diagnostics.AcceptedSteps < 0 ||
            result.Diagnostics.RejectedSteps < 0 ||
            result.Diagnostics.RightHandSideEvaluations < 0)
            throw new SolverResultPublicationException("Solver returned negative work counters.");

        var samples = result.Samples;
        var species = request.Network.SpeciesIds;
        var previousTime = double.NegativeInfinity;
        for (var i = 0; i < samples.Count; i++)
        {
            var sample = samples[i];
            if (sample is null || sample.AmountsMol is null)
                throw new SolverResultPublicationException("Solver sample or amount vector is missing.");
            if (!double.IsFinite(sample.TimeSeconds) ||
                sample.TimeSeconds < request.StartTimeSeconds ||
                sample.TimeSeconds > request.EndTimeSeconds ||
                sample.TimeSeconds <= previousTime)
                throw new SolverResultPublicationException("Solver timestamps must be finite, bounded and strictly increasing.");
            if (i == 0 && sample.TimeSeconds != request.StartTimeSeconds)
                throw new SolverResultPublicationException("Solver prefix did not begin at the requested initial time.");
            if (sample.AmountsMol.Count != species.Count)
                throw new SolverResultPublicationException("Solver sample species count is inconsistent with the reaction network.");

            foreach (var id in species)
            {
                if (!sample.AmountsMol.TryGetValue(id, out var amount) ||
                    !double.IsFinite(amount) || amount < 0d)
                    throw new SolverResultPublicationException("Solver output contains a missing, non-finite or negative species amount.");

                if (i == 0 && amount != request.InitialAmountsMol[id])
                    throw new SolverResultPublicationException("Solver initial sample differs from the admitted initial state.");
            }
            previousTime = sample.TimeSeconds;
        }

        var complete = samples.Count > 0 && previousTime == request.EndTimeSeconds;
        if (result.Status == SimulationStatus.Success && !complete)
            throw new SolverResultPublicationException("Successful solver status did not reach the final requested time.");
        if (result.Status == SimulationStatus.Success && samples.Count < 2)
            throw new SolverResultPublicationException("Successful solver status has no time evolution.");

        // A non-success can have a valid prefix, but must never be treated as
        // complete even if its last checked sample happened to reach end time.
        return new ValidatedResultPrefix(
            result.Status == SimulationStatus.Success && complete,
            samples.Count,
            samples.Count > 0 ? previousTime : null);
    }
}
