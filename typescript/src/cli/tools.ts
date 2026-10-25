import { Calculator } from '../calculator';
import { CATEGORIES, convertLine, convertValue, type Category, type Unit } from '../converter';
import { Programmer, type ProgrammerResult } from '../programmer';
import type { Io } from './io';
import { pick } from './pick';
import { formatError } from './report';

/** How a tool ended: back to the menu, quit the program, or end of input. */
export type ToolExit = 'back' | 'quit' | 'eof';

const COMMON_HELP = `  help (or ?)   show this help
  back          return to the previous screen
  quit          exit the program`;

const STANDARD_HELP = `Standard Calculator
  Operators: + - * / ^   unary signs   parentheses   %   of   sqrt()   abs()   ans
  Examples:  2 + 3 * 4    (2 + 3) ^ 2    20% of 150    200 + 10%    sqrt(16)    ans * 2
  Not supported: 1e5 input, implicit multiplication such as 2(3)
${COMMON_HELP}`;

const PROGRAMMER_HELP = `Programmer Calculator (64-bit signed)
  <value>                   show in HEX, DEC, OCT, BIN (prefixes 0b 0o 0d 0x)
  base <bin|oct|dec|hex>    set the input base
  [convert] <value> <from> <to>      convert 255 dec hex   or   255 dec hex
  <a> AND|OR|XOR <b>        NOT <a>
  <a> << n    <a> >> n (arithmetic)    <a> >>> n (logical)      n is decimal, 0-63
${COMMON_HELP}`;

const CONVERTER_HELP = `Unit Converter
  convert <value> <from> <to>    e.g. convert 100 cm in   (or: 100 cm in)
  <value> <from> all             the value in every unit of that category
  list                           the twelve categories
  list <category>                the units of one category
${COMMON_HELP}`;

/** Prompt loop shared by the calculators (spec §2.1). */
async function promptLoop(io: Io, prompt: string, helpText: string, run: (line: string) => string): Promise<ToolExit> {
  for (;;) {
    const line = await io.readLine(prompt);
    if (line === null) return 'eof'; // end of input exits cleanly
    const text = line.trim();
    if (!text) continue; // blank lines are ignored
    const lower = text.toLowerCase();
    if (lower === 'back') return 'back';
    if (lower === 'quit') return 'quit';
    if (lower === 'help' || lower === '?') { io.write(helpText + '\n'); continue; }
    try {
      const out = run(text);
      if (out) io.write(out + '\n');
    } catch (e) {
      io.write(formatError(e) + '\n'); // invalid input never crashes the program
    }
  }
}

export async function standardTool(io: Io): Promise<ToolExit> {
  io.write('Standard Calculator. Type an expression; help for commands, back for the menu.\n');
  const calc = new Calculator();
  return promptLoop(io, 'standard> ', STANDARD_HELP, (line) => calc.evaluate(line));
}

/** Text for a Programmer result. Also used by one-shot mode. */
export function renderProgrammer(r: ProgrammerResult): string {
  switch (r.kind) {
    case 'value':
      return `HEX: ${r.display.HEX}\nDEC: ${r.display.DEC}\nOCT: ${r.display.OCT}\nBIN: ${r.display.BIN}`;
    case 'converted':
      return r.text;
    case 'base':
      return `Input base: ${r.base}`;
  }
}

export async function programmerTool(io: Io): Promise<ToolExit> {
  io.write('Programmer Calculator (64-bit signed). Type a value or command; help for commands.\n');
  const prog = new Programmer();
  return promptLoop(io, 'programmer> ', PROGRAMMER_HELP, (line) => renderProgrammer(prog.execute(line)));
}

/** One-line converter commands typed at a picker: `convert …`, `list …`, `<v> <from> <to>`. */
function converterCommand(line: string): string[] | null {
  const words = line.trim().split(/\s+/);
  const first = words[0].toLowerCase();
  return first === 'convert' || first === 'list' || words.length === 3 ? convertLine(line) : null;
}

const capitalize = (s: string): string => s.charAt(0).toUpperCase() + s.slice(1);

/**
 * Guided converter: a four-stage state machine (category → from → to → values).
 * `back` steps back one stage and leaves to the main menu from the first.
 */
export async function converterTool(io: Io): Promise<ToolExit> {
  let stage = 0;
  let category: Category = CATEGORIES[0];
  let from: Unit = category.units[0];
  let to: Unit = category.units[0];

  const unitOptions = (c: Category) =>
    c.units.map((x) => ({ label: `${x.symbol} — ${x.name}`, names: [x.symbol, x.name] }));

  for (;;) {
    if (stage < 3) {
      const base = { back: true, quit: true, helpText: CONVERTER_HELP, command: converterCommand };
      const r =
        stage === 0
          ? await pick(io, {
              ...base,
              title: 'Unit Converter — choose a category',
              options: CATEGORIES.map((c) => ({ label: c.name, names: [c.name] })),
            })
          : stage === 1
            ? await pick(io, { ...base, title: `${capitalize(category.name)} — convert from`, options: unitOptions(category) })
            : await pick(io, {
                ...base,
                title: `${capitalize(category.name)} — convert from ${from.symbol} to`,
                options: unitOptions(category),
              });

      if (r.kind === 'eof') return 'eof';
      if (r.kind === 'quit') return 'quit';
      if (r.kind === 'back') {
        if (stage === 0) return 'back';
        stage--;
        continue;
      }
      if (stage === 0) category = CATEGORIES[r.index];
      else if (stage === 1) from = category.units[r.index];
      else to = category.units[r.index];
      stage++;
      continue;
    }

    // Stage 3: values. The prompt shows the units; one-line forms still work.
    io.write(`${from.symbol} → ${to.symbol}: type a value such as 100. help for commands, back to change units.\n`);
    for (;;) {
      const line = await io.readLine(`converter (${from.symbol} → ${to.symbol})> `, { escapeIsBack: true });
      if (line === null) return 'eof';
      const text = line.trim();
      if (!text) continue;
      const lower = text.toLowerCase();
      if (lower === 'back') { stage = 2; break; }
      if (lower === 'quit') return 'quit';
      if (lower === 'help' || lower === '?') { io.write(CONVERTER_HELP + '\n'); continue; }
      try {
        const single = !/\s/.test(text) && lower !== 'list';
        const out = single
          ? [`${text} ${from.symbol} = ${convertValue(text, from.symbol, to.symbol)} ${to.symbol}`]
          : convertLine(text);
        io.write(out.join('\n') + '\n');
      } catch (e) {
        io.write(formatError(e) + '\n');
      }
    }
  }
}