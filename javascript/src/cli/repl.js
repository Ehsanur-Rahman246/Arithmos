// The shared prompt loop for the two calculators: help (or ?), back, quit (any
// case), blank lines ignored, end of input exits cleanly, errors never end the loop.
// Resolves to 'back' | 'quit' | 'eof'.
import { ArithmosError, formatError } from '../shared/index.js';
import { PLAIN } from './style.js';

export function printError(io, err) {
  const style = io.style ?? PLAIN;
  if (err instanceof ArithmosError) io.write(`${style.red(formatError(err))}\n`);
  else io.write(`${style.red(`Error [INTERNAL]: ${err?.message ?? err}`)}\n`); // a bug, but the loop survives
}

export async function runRepl({ prompt, handle, helpText, intro, io }) {
  if (intro) io.write(`${intro}\n`);
  for (;;) {
    const raw = await io.readLine(prompt);
    if (raw === null) { io.write('\n'); return 'eof'; }
    const line = raw.trim();
    if (line === '') continue;
    const word = line.toLowerCase();
    if (word === 'back') return 'back';
    if (word === 'quit') return 'quit';
    if (word === 'help' || word === '?') { io.write(`${helpText}\n`); continue; }
    try {
      const out = handle(line);
      if (out) io.write(`${out}\n`);
    } catch (err) {
      printError(io, err);
    }
  }
}