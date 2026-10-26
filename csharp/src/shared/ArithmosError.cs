namespace Arithmos.Shared;

/// <summary>
/// The one error type engines throw. Carries one of the 14 codes of spec §2.2.
/// Only the CLI layer turns it into "Error [CODE]: message".
/// </summary>
public sealed class ArithmosError : Exception
{
    public string Code { get; }

    public ArithmosError(string code, string message) : base(message) => Code = code;
}