// Unit Converter screens: category -> from -> to -> values. Only units of the chosen
// category are ever offered, so inches -> kelvin cannot be picked. `back` (or Esc)
// goes one screen back; from the category list it returns to the main menu.
import { CATEGORIES, createConverterSession } from '../../converter/index.js';
import { pick } from '../pick.js';
import { printError } from '../repl.js';

const cap = (s) => s[0].toUpperCase() + s.slice(1);

const HELP = [
  '  100            convert that number',
  '  100 cm in      or the full form:  convert 100 cm in',
  '  1 km all       the value in every unit',
  '  list           categories;   list length   its units',
  '  back  previous screen     quit  exit',
].join('\n');

// One-line form, used by `node bin/arithmos.js convert 100 cm in`.
export function converterTool() {
  const session = createConverterSession();
  return { name: 'Unit Converter', prompt: 'converter> ', intro: '', helpText: HELP, handle: (line) => session.run(line) };
}

const categoryOptions = CATEGORIES.map((c, i) => ({
  key: String(i + 1), label: c.name, value: c, aliases: [c.name],
}));

const unitOptions = (category) => category.units.map((u, i) => ({
  key: String(i + 1), label: `${u.symbol.padEnd(8)}${u.name}`, value: u.symbol, aliases: [u.symbol],
}));

// Resolves to 'back' | 'quit' | 'eof'.
export async function runGuidedConverter(io) {
  const session = createConverterSession();
  const passthrough = (line) => session.run(line);
  let stage = 0;
  let category; let source; let target;

  for (;;) {
    if (stage === 0) {
      const r = await pick(io, { title: 'Unit Converter — choose a category', options: categoryOptions, back: true, passthrough });
      if (r.status !== 'selected') return r.status;
      category = r.option.value;
      stage = 1;
    } else if (stage === 1) {
      const r = await pick(io, { title: `${cap(category.name)} — convert from`, options: unitOptions(category), back: true, passthrough });
      if (r.status === 'back') stage = 0;
      else if (r.status !== 'selected') return r.status;
      else { source = r.option.value; stage = 2; }
    } else if (stage === 2) {
      const r = await pick(io, { title: `${cap(category.name)} — convert from ${source} to`, options: unitOptions(category), back: true, passthrough });
      if (r.status === 'back') stage = 1;
      else if (r.status !== 'selected') return r.status;
      else { target = r.option.value; stage = 3; }
    } else {
      const outcome = await convertValues(io, session, cap(category.name), source, target);
      if (outcome !== 'back') return outcome;
      stage = 2;
    }
  }
}

async function convertValues(io, session, name, source, target) {
  const style = io.style;
  io.write(`\n${style.bold(`${name}: ${source} → ${target}`)}\n`);
  io.write(`${style.dim('Type a number.   (help · back · quit)')}\n`);
  const prompt = `${source} → ${target}> `;
  for (;;) {
    const raw = await io.readLine(prompt);
    if (raw === null) { io.write('\n'); return 'eof'; }
    const line = raw.trim();
    if (line === '') continue;
    const word = line.toLowerCase();
    if (word === 'back' || word === 'quit') return word;
    if (word === 'help' || word === '?') { io.write(`${HELP}\n`); continue; }
    try {
      if (/\s/.test(line)) io.write(`${session.run(line)}\n`); // a full one-line command
      else io.write(`${line} ${source} = ${session.run(`convert ${line} ${source} ${target}`)} ${target}\n`);
    } catch (err) {
      printError(io, err);
    }
  }
}