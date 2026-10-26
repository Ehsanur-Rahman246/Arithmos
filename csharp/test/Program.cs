using Arithmos.Tests;

// Usage (from csharp/):  dotnet run --project test -- ../docs/release-1-cases.json
string casesPath = args.Length > 0 ? args[0] : "../docs/release-1-cases.json";

RunCases.Run(casesPath);   // 175 shared cases
Extras.Run();              // C# extras
RunSelector.Run();         // SL1–SL21 + X2 + X3

Console.WriteLine($"{H.Pass} passed, {H.Fail} failed");
return H.Fail == 0 ? 0 : 1;