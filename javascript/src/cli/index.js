// CLI entry: one-shot arguments (`arithmos convert 100 cm in`) when given,
// otherwise the interactive main menu (spec 2.1).
// Exit status: 0 success, 1 the line produced an Error [CODE], 2 bad usage.
import { ArithmosError, formatError } from '../shared/index.js';
import { createStdIO } from './io.js';
import { runMenu } from './menu.js';
import { standardTool } from './tools/standard.js';
import { programmerTool } from './tools/programmer.js';
import { converterTool } from './tools/converter.js';

const USAGE = [
  'Usage:',
  '  arithmos                          interactive menu',
  '  arithmos std "<expression>"       one Standard Calculator line',
  '  arithmos prog "<command>"         one Programmer Calculator line',
  '  arithmos convert <value> <from> <to>   one Unit Converter line (also: list, ... all)',
].join('\n');

const ONE_SHOT = {
  std: { tool: standardTool, rest: 1 },
  standard: { tool: standardTool, rest: 1 },
  prog: { tool: programmerTool, rest: 1 },
  programmer: { tool: programmerTool, rest: 1 },
  convert: { tool: converterTool, rest: 0 }, // the line keeps its leading `convert`
  list: { tool: converterTool, rest: 0 },
};

export async function main(argv, io) {
  const args = argv ?? [];
  if (args.length === 0) {
    const stdio = io ?? createStdIO();
    try {
      await runMenu(stdio);
    } finally {
      stdio.close?.();
    }
    return 0;
  }

  const out = io ?? { write: (t) => process.stdout.write(t) };
  const head = args[0].toLowerCase();
  if (head === '-h' || head === '--help' || head === 'help') { out.write(`${USAGE}\n`); return 0; }
  const entry = Object.hasOwn(ONE_SHOT, head) ? ONE_SHOT[head] : null;
  const line = entry ? args.slice(entry.rest).join(' ') : '';
  if (!entry || line.trim() === '') { out.write(`${USAGE}\n`); return 2; }

  try {
    const text = entry.tool().handle(line);
    if (text) out.write(`${text}\n`);
    return 0;
  } catch (err) {
    if (err instanceof ArithmosError) { out.write(`${formatError(err)}\n`); return 1; }
    throw err;
  }
}
