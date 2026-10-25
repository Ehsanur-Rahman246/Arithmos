import { Calculator } from '../calculator';
import { convertLine } from '../converter';
import { Programmer } from '../programmer';
import type { Io } from './io';
import { pick } from './pick';
import { formatError } from './report';
import { converterTool, programmerTool, renderProgrammer, standardTool, type ToolExit } from './tools';

const MENU_HELP = `Pick a tool with the arrow keys, or type a number or name.
  1 / standard     Standard Calculator
  2 / programmer   Programmer Calculator
  3 / converter    Unit Converter
  0 / exit         leave
  help (or ?)      this help        quit   exit`;

/** Main menu loop (spec §2.1). Returns when the user leaves or input ends. */
export async function runInteractive(io: Io): Promise<void> {
  const tools: Array<(io: Io) => Promise<ToolExit>> = [standardTool, programmerTool, converterTool];
  try {
    for (;;) {
      const r = await pick(io, {
        title: 'Arithmos 1.0 — Core CLI',
        options: [
          { label: 'Standard Calculator', names: ['standard', 'std'], key: '1' },
          { label: 'Programmer Calculator', names: ['programmer', 'prog'], key: '2' },
          { label: 'Unit Converter', names: ['converter', 'convert'], key: '3' },
          { label: 'Exit', names: ['exit'], key: '0' },
        ],
        back: false,
        quit: true,
        helpText: MENU_HELP,
      });
      if (r.kind !== 'choice' || r.index === 3) return;
      const exit = await tools[r.index](io);
      if (exit !== 'back') return; // quit or end of input
    }
  } finally {
    io.close();
  }
}

const USAGE = `Usage:
  arithmos                          interactive menu
  arithmos std "<expression>"       one calculation
  arithmos prog <command>           one programmer command
  arithmos convert <value> <from> <to>
  arithmos list [category]
Exit status: 0 success, 1 the line produced an Error [CODE], 2 bad usage.`;

/**
 * One-shot mode (R31). Results and --help go to stdout; Error lines and usage
 * after bad input go to stderr. Returns the exit status, or null when there are
 * no arguments (start the interactive menu).
 */
export function runOneShot(args: string[], out: (s: string) => void, err: (s: string) => void): number | null {
  if (args.length === 0) return null;

  const cmd = args[0].toLowerCase();
  const rest = args.slice(1);

  if (cmd === '--help' || cmd === '-h' || cmd === 'help') { out(USAGE + '\n'); return 0; }

  const known = ['std', 'standard', 'prog', 'programmer', 'convert', 'list'];
  if (!known.includes(cmd) || (rest.length === 0 && cmd !== 'list')) {
    err(USAGE + '\n');
    return 2;
  }

  try {
    const text = rest.join(' ');
    if (cmd === 'std' || cmd === 'standard') out(new Calculator().evaluate(text) + '\n');
    else if (cmd === 'prog' || cmd === 'programmer') out(renderProgrammer(new Programmer().execute(text)) + '\n');
    else out(convertLine(`${cmd} ${text}`).join('\n') + '\n');
    return 0;
  } catch (e) {
    err(formatError(e) + '\n');
    return 1;
  }
}