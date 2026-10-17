// Binds the Standard Calculator engine to the REPL (prompt: `standard> `).
import { createStandardSession } from "../../calculator/index.js";

export function standardTool() {
  const session = createStandardSession();
  return {
    name: "Standard Calculator",
    prompt: "standard> ",
    intro: [
      "Standard Calculator — type an expression and press Enter.",
      "  Examples:  25 + 17    (2 + 3) * 4    2^10    sqrt(16)    20% of 150    200 + 10%",
      '  "ans" is the previous result, e.g.  ans * 2',
    ].join("\n"),
    helpText: [
      "Operators: + - * / ^   Functions: sqrt(x) abs(x)   Percent: 50%  20% of 150  200 + 10%",
      "Commands: help, back (main menu), quit (exit)",
    ].join("\n"),
    handle: (line) => session.run(line),
  };
}
