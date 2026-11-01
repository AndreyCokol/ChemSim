using ChemSim.Kinetics.Domain;
using ChemSim.Kinetics.Numerics;

namespace ChemSim.Kinetics.Simulation;

/// <summary>
/// Executes a closed, constant-volume, isothermal reaction network.
/// State variables are species amounts in mol; rate laws use concentrations
/// in mol/m^3 and return volumetric rates in mol/(m^3 s).
/// </summary>
public sealed class KineticsSimulator
{
    public SimulationResult Run(SimulationRequest request, CancellationToken cancellationToken = default)
    {
        try
        {
            request.Validate();
        }
        catch (ArgumentException exception)
        {
            return Failure(SimulationStatus.InvalidInput, exception.Message);
        }

        var speciesIds = request.Network.SpeciesIds;
        var speciesIndex = speciesIds
            .Select((id, index) => (id, index))
            .ToDictionary(pair => pair.id, pair => pair.index, StringComparer.Ordinal);

        var initialState = speciesIds.Select(id => request.InitialAmountsMol[id]).ToArray();
        var samples = new List<StateSample>
        {
            CreateSample(request.StartTimeSeconds, initialState, speciesIds)
        };

        var rhs = BuildRightHandSide(request, speciesIndex);
        var time = request.StartTimeSeconds;
        var state = initialState;
        var accepted = 0;
        var rejected = 0;
        var evaluations = 0;

        try
        {
            while (time < request.EndTimeSeconds)
            {
                cancellationToken.ThrowIfCancellationRequested();

                var remainingSteps = request.Solver.MaximumInternalSteps - accepted - rejected;
                if (remainingSteps <= 0)
                    return new(SimulationStatus.MaximumStepsExceeded, Array.AsReadOnly(samples.ToArray()),
                        new(accepted, rejected, evaluations, "Maximum internal-step budget exceeded."));

                var target = Math.Min(request.EndTimeSeconds, time + request.OutputIntervalSeconds);
                var integrator = new DormandPrince54(
                    request.Solver.RelativeTolerance,
                    request.Solver.AbsoluteToleranceMol,
                    request.Solver.MinimumStepSeconds,
                    request.Solver.MaximumStepSeconds,
                    remainingSteps);

                var outcome = integrator.Integrate(
                    rhs, time, target, state, request.Solver.InitialStepSeconds, cancellationToken);

                accepted += outcome.AcceptedSteps;
                rejected += outcome.RejectedSteps;
                evaluations += outcome.RightHandSideEvaluations;

                if (outcome.Status != StepStatus.Success)
                {
                    var status = outcome.Status switch
                    {
                        StepStatus.StepSizeUnderflow => SimulationStatus.StepSizeUnderflow,
                        StepStatus.MaximumStepsExceeded => SimulationStatus.MaximumStepsExceeded,
                        StepStatus.NonPhysicalState => SimulationStatus.NonPhysicalState,
                        _ => SimulationStatus.NumericalFailure
                    };
                    return new(status, Array.AsReadOnly(samples.ToArray()),
                        new(accepted, rejected, evaluations, $"Integrator stopped at t={outcome.Time:G17} s."));
                }

                time = target;
                state = outcome.State;

                var conservationError = CheckConservation(request, initialState, state);
                if (conservationError is not null)
                    return new(SimulationStatus.ConservationFailure, Array.AsReadOnly(samples.ToArray()),
                        new(accepted, rejected, evaluations, conservationError));

                samples.Add(CreateSample(time, state, speciesIds));
            }
        }
        catch (OperationCanceledException)
        {
            return new(SimulationStatus.Cancelled, Array.AsReadOnly(samples.ToArray()),
                new(accepted, rejected, evaluations, "Simulation cancelled."));
        }
        catch (ArithmeticException exception)
        {
            return new(SimulationStatus.NumericalFailure, Array.AsReadOnly(samples.ToArray()),
                new(accepted, rejected, evaluations, exception.Message));
        }

        return new(SimulationStatus.Success, Array.AsReadOnly(samples.ToArray()),
            new(accepted, rejected, evaluations));
    }

    private static string? CheckConservation(
        SimulationRequest request,
        IReadOnlyList<double> initialState,
        IReadOnlyList<double> currentState)
    {
        foreach (var law in request.Network.ConservationLaws)
        {
            var initialTotal = law.Evaluate(request.Network.SpeciesIds, initialState);
            var currentTotal = law.Evaluate(request.Network.SpeciesIds, currentState);
            var scale = Math.Max(Math.Abs(initialTotal), Math.Abs(currentTotal));
            var tolerance = 10d * (
                request.Solver.AbsoluteToleranceMol * law.CoefficientMagnitudeSum +
                request.Solver.RelativeTolerance * scale);

            if (Math.Abs(currentTotal - initialTotal) > tolerance)
                return $"Conservation law '{law.Id}' drifted by {currentTotal - initialTotal:G17}.";
        }

        return null;
    }

    private static Func<double, double[], double[]> BuildRightHandSide(
        SimulationRequest request,
        IReadOnlyDictionary<string, int> speciesIndex)
    {
        return (_, amounts) =>
        {
            var concentrations = new double[amounts.Length];
            for (var i = 0; i < amounts.Length; i++)
                concentrations[i] = amounts[i] / request.VolumeM3;

            var derivative = new double[amounts.Length];

            foreach (var reaction in request.Network.Reactions)
            {
                var volumetricRate = reaction.RateConstant.Value;
                foreach (var (speciesId, order) in reaction.KineticOrders)
                {
                    if (order == 0d)
                        continue;

                    var concentration = concentrations[speciesIndex[speciesId]];
                    if (concentration == 0d)
                    {
                        volumetricRate = 0d;
                        break;
                    }

                    volumetricRate *= Math.Pow(concentration, order);
                }

                if (!double.IsFinite(volumetricRate))
                    throw new ArithmeticException($"Reaction '{reaction.Id}' produced a non-finite rate.");

                var extentRateMolPerSecond = request.VolumeM3 * volumetricRate;
                foreach (var (speciesId, coefficient) in reaction.Stoichiometry)
                    derivative[speciesIndex[speciesId]] += coefficient * extentRateMolPerSecond;
            }

            if (derivative.Any(value => !double.IsFinite(value)))
                throw new ArithmeticException("The reaction network produced a non-finite state derivative.");

            return derivative;
        };
    }

    private static StateSample CreateSample(double time, double[] amounts, IReadOnlyList<string> speciesIds)
    {
        var state = new Dictionary<string, double>(StringComparer.Ordinal);
        for (var i = 0; i < speciesIds.Count; i++)
            state.Add(speciesIds[i], amounts[i]);

        return new(time, new System.Collections.ObjectModel.ReadOnlyDictionary<string, double>(state));
    }

    private static SimulationResult Failure(SimulationStatus status, string message) =>
        new(status, Array.Empty<StateSample>(), new(0, 0, 0, message));
}
