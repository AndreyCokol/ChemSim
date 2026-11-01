namespace ChemSim.Kinetics.Domain;

/// <summary>
/// SI rate constant for a volumetric power law:
/// r [mol m^-3 s^-1] = k * product(c_i ^ alpha_i),
/// where c_i is expressed in mol m^-3.
/// The concentration exponent is therefore 1 - sum(alpha_i).
/// </summary>
public readonly record struct RateConstant(double Value, double ConcentrationExponent)
{
    private const double UnitExponentTolerance = 1e-10;

    public void ValidateForTotalOrder(double totalOrder, string reactionId)
    {
        if (!double.IsFinite(Value) || Value <= 0d)
        {
            throw new ArgumentOutOfRangeException(
                nameof(Value),
                $"Reaction '{reactionId}': rate constant must be finite and greater than zero.");
        }

        if (!double.IsFinite(ConcentrationExponent))
        {
            throw new ArgumentOutOfRangeException(
                nameof(ConcentrationExponent),
                $"Reaction '{reactionId}': rate-constant unit exponent must be finite.");
        }

        var expectedExponent = 1d - totalOrder;
        if (Math.Abs(ConcentrationExponent - expectedExponent) > UnitExponentTolerance)
        {
            throw new ArgumentException(
                $"Reaction '{reactionId}': rate constant has concentration exponent " +
                $"{ConcentrationExponent:G17}; expected {expectedExponent:G17} for total order {totalOrder:G17}.");
        }
    }
}
