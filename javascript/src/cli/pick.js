// One question, many answers. Real terminal: arrow-key selector with a highlighted
// row. Anywhere else: the same list, answered by typing a number, a name or a symbol.
//
//   options     : [{ key, label, value, aliases? }]
//   back, quit  : which of the "go back" / "quit" answers are on offer
//   passthrough : optional (line) => text; typed lines containing spaces (or `list`)
//                 are handed to it, so one-line commands keep working
// Resolves to { status: 'selected', option } or { status: 'back' | 'quit' | 'eof' }.
import { ArithmosError } from '../shared/index.js';
import { printError } from './repl.js';

export async function pick(io, { title, options, back = false, quit = true, passthrough, errorCode = 'UNKNOWN_COMMAND' }) {
  if (io.select) {
    const r = await io.select({ title, options: options.map((o) => o.label), back, quit });
    if (r.status === 'selected') return { status: 'selected', option: options[r.index] };
    return { status: r.status === 'abort' ? 'eof' : r.status };
  }

  const show = () => io.write(`${title}\n${options.map((o) => `  ${o.key}) ${o.label}`).join('\n')}\n`);
  show();
  for (;;) {
    const raw = await io.readLine('> ');
    if (raw === null) { io.write('\n'); return { status: 'eof' }; }
    const text = raw.trim().toLowerCase();
    if (text === '') continue;
    if (text === 'quit') return { status: 'quit' };
    if (text === 'back' && back) return { status: 'back' };
    if (text === 'help' || text === '?') { show(); continue; }

    const hit = options.find((o) => o.key === text || o.label.toLowerCase() === text || o.aliases?.includes(text));
    if (hit) return { status: 'selected', option: hit };

    if (passthrough && (/\s/.test(text) || text === 'list')) { // one-line commands still work
      try {
        const out = passthrough(raw.trim());
        if (out) io.write(`${out}\n`);
      } catch (err) {
        printError(io, err);
      }
      continue;
    }
    printError(io, new ArithmosError(errorCode, 'Pick one from the list'));
  }
}