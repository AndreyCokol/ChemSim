namespace ChemSim.Kinetics.Numerics;

/// <summary>
/// Adaptive Dormand-Prince 5(4) integrator. Trial stages outside the
/// non-negative state domain are rejected; state values are never clipped.
/// </summary>
internal sealed class DormandPrince54
{
    private readonly double _rtol;
    private readonly double _atol;
    private readonly double _minStep;
    private readonly double _maxStep;
    private readonly int _maxSteps;

    public DormandPrince54(double rtol, double atol, double minStep, double maxStep, int maxSteps)
    {
        _rtol = rtol;
        _atol = atol;
        _minStep = minStep;
        _maxStep = maxStep;
        _maxSteps = maxSteps;
    }

    public IntegrationOutcome Integrate(
        Func<double, double[], double[]> rhs,
        double startTime,
        double endTime,
        double[] initialState,
        double initialStep,
        CancellationToken cancellationToken)
    {
        var y = (double[])initialState.Clone();
        var duration = endTime - startTime;
        var elapsed = 0d;
        var rhsAtAbsoluteTime = (double time, double[] state) => rhs(startTime + time, state);
        var h = Math.Min(Math.Min(initialStep, _maxStep), duration);
        var accepted = 0;
        var rejected = 0;
        var evaluations = 0;
        var attempts = 0;
        var lastRejectionWasNonPhysical = false;

        while (elapsed < duration)
        {
            cancellationToken.ThrowIfCancellationRequested();
            if (++attempts > _maxSteps)
                return new(StepStatus.MaximumStepsExceeded, y, startTime + elapsed, accepted, rejected, evaluations);

            var remaining = duration - elapsed;
            var candidateStep = Math.Min(h, remaining);
            var nextElapsed = candidateStep >= remaining ? duration : elapsed + candidateStep;
            var stepSize = nextElapsed - elapsed;
            var isFinalStep = nextElapsed >= duration;

            // Integrate in elapsed time, not absolute clock time. This prevents
            // loss of step resolution when startTime is large relative to h.
            // The RHS still receives the corresponding absolute simulation time.
            if (!double.IsFinite(stepSize) || stepSize <= 0d ||
                (stepSize < _minStep && !isFinalStep))
            {
                var status = lastRejectionWasNonPhysical
                    ? StepStatus.NonPhysicalState
                    : StepStatus.StepSizeUnderflow;
                return new(status, y, startTime + elapsed, accepted, rejected, evaluations);
            }

            var step = TryStep(rhsAtAbsoluteTime, elapsed, y, stepSize);
            evaluations += step.Evaluations;

            if (step.HasNonFiniteValues)
                return new(StepStatus.NumericalFailure, y, startTime + elapsed, accepted, rejected, evaluations);

            var errorNorm = ErrorNorm(step.Error, y, step.FifthOrder);
            var physical = !step.HasNonPhysicalStage &&
                           step.FifthOrder.All(value => double.IsFinite(value) && value >= 0d);

            if (errorNorm <= 1d && physical)
            {
                elapsed = nextElapsed;
                y = step.FifthOrder;
                accepted++;
                lastRejectionWasNonPhysical = false;

                var factor = errorNorm == 0d
                    ? 5d
                    : Math.Clamp(0.9d * Math.Pow(errorNorm, -0.2d), 0.2d, 5d);
                h = Math.Min(_maxStep, h * factor);
            }
            else
            {
                rejected++;
                lastRejectionWasNonPhysical = !physical;
                var factor = !physical
                    ? 0.2d
                    : Math.Clamp(0.9d * Math.Pow(Math.Max(errorNorm, 1e-16d), -0.2d), 0.1d, 0.5d);
                h = stepSize * factor;
            }
        }

        return new(StepStatus.Success, y, endTime, accepted, rejected, evaluations);
    }

    private double ErrorNorm(double[] error, double[] oldState, double[] newState)
    {
        double sumSquares = 0d;
        for (var i = 0; i < error.Length; i++)
        {
            var scale = _atol + _rtol * Math.Max(Math.Abs(oldState[i]), Math.Abs(newState[i]));
            var normalized = error[i] / scale;
            sumSquares += normalized * normalized;
        }

        return Math.Sqrt(sumSquares / error.Length);
    }

    private static TrialStep TryStep(Func<double, double[], double[]> rhs, double t, double[] y, double h)
    {
        var evaluations = 0;
        double[] Eval(double time, double[] state)
        {
            evaluations++;
            return Evaluate(rhs, time, state);
        }

        try
        {
            var k1 = Eval(t, y);
            var k2 = Eval(t + h * (1d / 5d), Combine(y, h, (1d / 5d, k1)));
            var k3 = Eval(t + h * (3d / 10d), Combine(y, h, (3d / 40d, k1), (9d / 40d, k2)));
            var k4 = Eval(t + h * (4d / 5d), Combine(y, h, (44d / 45d, k1), (-56d / 15d, k2), (32d / 9d, k3)));
            var k5 = Eval(t + h * (8d / 9d), Combine(y, h,
                (19372d / 6561d, k1), (-25360d / 2187d, k2), (64448d / 6561d, k3), (-212d / 729d, k4)));
            var k6 = Eval(t + h, Combine(y, h,
                (9017d / 3168d, k1), (-355d / 33d, k2), (46732d / 5247d, k3), (49d / 176d, k4), (-5103d / 18656d, k5)));
            var y5 = Combine(y, h,
                (35d / 384d, k1), (500d / 1113d, k3), (125d / 192d, k4), (-2187d / 6784d, k5), (11d / 84d, k6));
            var k7 = Eval(t + h, y5);
            var y4 = Combine(y, h,
                (5179d / 57600d, k1), (7571d / 16695d, k3), (393d / 640d, k4),
                (-92097d / 339200d, k5), (187d / 2100d, k6), (1d / 40d, k7));

            var error = new double[y.Length];
            var nonFinite = false;
            for (var i = 0; i < y.Length; i++)
            {
                error[i] = y5[i] - y4[i];
                nonFinite |= !double.IsFinite(y5[i]) || !double.IsFinite(error[i]);
            }

            return new(y5, error, evaluations, nonFinite, false);
        }
        catch (NonPhysicalStageException)
        {
            return new((double[])y.Clone(), new double[y.Length], evaluations, false, true);
        }
    }

    private static double[] Evaluate(Func<double, double[], double[]> rhs, double time, double[] state)
    {
        if (state.Any(value => !double.IsFinite(value)))
            throw new ArithmeticException("An integration stage produced a non-finite state.");
        if (state.Any(value => value < 0d))
            throw new NonPhysicalStageException();

        var derivative = rhs(time, state);
        if (derivative is null || derivative.Length != state.Length)
            throw new ArithmeticException("The right-hand side returned a derivative vector with an invalid dimension.");
        if (derivative.Any(value => !double.IsFinite(value)))
            throw new ArithmeticException("The right-hand side returned a non-finite derivative.");

        return derivative;
    }

    private static double[] Combine(double[] y, double h, params (double Coefficient, double[] K)[] terms)
    {
        var result = (double[])y.Clone();
        for (var i = 0; i < result.Length; i++)
        {
            double increment = 0d;
            foreach (var (coefficient, k) in terms)
                increment += coefficient * k[i];
            result[i] += h * increment;
        }

        return result;
    }
}

internal sealed class NonPhysicalStageException : Exception
{
}

internal enum StepStatus
{
    Success,
    StepSizeUnderflow,
    MaximumStepsExceeded,
    NonPhysicalState,
    NumericalFailure
}

internal sealed record TrialStep(
    double[] FifthOrder,
    double[] Error,
    int Evaluations,
    bool HasNonFiniteValues,
    bool HasNonPhysicalStage);

internal sealed record IntegrationOutcome(
    StepStatus Status,
    double[] State,
    double Time,
    int AcceptedSteps,
    int RejectedSteps,
    int RightHandSideEvaluations);
