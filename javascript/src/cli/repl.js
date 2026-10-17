// Shared prompt loop: handles help/back/quit (case-insensitive), blank lines,
// EOF (clean exit), and prints `Error [CODE]: message`.
// handle(line) returns the text to print (or '' / undefined for nothing) and
// throws ArithmosError for failures (UNKNOWN_COMMAND included).
// Resolves to 'back' | 'quit' | 'eof'.
import { ArithmosError, formatError } from "../shared/index.js";

export function printError(io, err) {
  if (err instanceof ArithmosError) io.write(`${formatError(err)}\n`);
  else io.write(`Error [INTERNAL]: ${err?.message ?? err}\n`); // a bug, but the loop survives
}

export async function runRepl({ prompt, handle, helpText, intro, io }) {
  io.write(
    'Type "help" for commands, "back" for the main menu, "quit" to exit.\n',
  );
  if (intro) io.write(`${intro}\n`);
  for (;;) {
    const raw = await io.readLine(prompt);
    if (raw === null) {
      io.write("\n");
      return "eof";
    }
    const line = raw.trim();
    if (line === "") continue;
    const word = line.toLowerCase();
    if (word === "back") return "back";
    if (word === "quit") return "quit";
    if (word === "help") {
      io.write(`${helpText}\n`);
      continue;
    }
    try {
      const out = handle(line);
      if (out) io.write(`${out}\n`);
    } catch (err) {
      printError(io, err);
    }
  }
}
