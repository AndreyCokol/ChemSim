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
                if (target <= time)
                    return new(SimulationStatus.InvalidInput, Array.AsReadOnly(samples.ToArray()),
                        new(accepted, rejected, evaluations,
                            "Output interval cannot advance the representable simulation time at the current timestamp."));

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
                    var message = outcome.FailureMessage ?? $"Integrator stopped at t={outcome.Time:G17} s.";
                    return new(status, Array.AsReadOnly(samples.ToArray()),
                        new(accepted, rejected, evaluations, message));
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
            var difference = currentTotal - initialTotal;
            var scale = Math.Max(Math.Abs(initialTotal), Math.Abs(currentTotal));
            var tolerance = 10d * (
                request.Solver.AbsoluteToleranceMol * law.CoefficientMagnitudeSum +
                request.Solver.RelativeTolerance * scale);

            if (!double.IsFinite(difference) || !double.IsFinite(tolerance))
                return $"Conservation law '{law.Id}' produced non-finite comparison arithmetic.";

            if (Math.Abs(difference) > tolerance)
                return $"Conservation law '{law.Id}' drifted by {difference:G17}.";
        }

        return null;
    }

    private static Func<double, double[], double[]> BuildRightHandSide(
        SimulationRequest request,
        IReadOnlyDictionary<string, int> speciesIndex)
    {
        return (_, amounts) =>
        {
            var derivative = new double[amounts.Length];

            foreach (var reaction in request.Network.Reactions)
            {
                // Convert the volumetric power law to an extent rate algebraically:
                // V * k * product((n_i / V)^order_i)
                // = k * V^(1 - totalOrder) * product(n_i^order_i).
                // Evaluating concentration and volumetric rate first can underflow
                // to zero even when the final mol/s extent rate is representable.
                var totalOrder = reaction.TotalKineticOrder;
                var logExtentRate = Math.Log(reaction.RateConstant.Value) +
                                    (1d - totalOrder) * Math.Log(request.VolumeM3);
                var zeroRate = false;

                foreach (var (speciesId, order) in reaction.KineticOrders)
                {
                    if (order == 0d)
                        continue;

                    var amount = amounts[speciesIndex[speciesId]];
                    if (amount == 0d)
                    {
                        zeroRate = true;
                        break;
                    }

                    logExtentRate += order * Math.Log(amount);
                }

                if (zeroRate)
                    continue;

                if (double.IsNaN(logExtentRate) || double.IsPositiveInfinity(logExtentRate))
                    throw new ArithmeticException($"Reaction '{reaction.Id}' produced a non-finite extent rate.");

                // Exp(-Infinity) and underflow to zero are valid limiting rates.
                var extentRateMolPerSecond = Math.Exp(logExtentRate);
                if (!double.IsFinite(extentRateMolPerSecond))
                    throw new ArithmeticException($"Reaction '{reaction.Id}' produced a non-finite extent rate.");

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
