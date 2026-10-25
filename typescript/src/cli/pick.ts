// Layer 4: pick() — one question, many answers. Uses the arrow-key selector when
// io.select exists, otherwise a numbered list answered by typing.

import type { Io } from './io';
import { formatError } from './report';

export interface PickOption {
  label: string;
  /** Words that select this option when typed (symbol, name). Case-insensitive. */
  names?: string[];
  /** Number shown in the plain list. Defaults to its position (1, 2, …). */
  key?: string;
}

export interface PickSpec {
  title: string;
  options: PickOption[];
  back: boolean;
  quit: boolean;
  helpText: string;
  /**
   * One-line commands typed at the list (`100 cm in`, `list`). Returns output
   * lines, or null when the text is not a command. May throw ArithmosError.
   */
  command?: (line: string) => string[] | null;
}

export type PickResult =
  | { kind: 'choice'; index: number }
  | { kind: 'back' }
  | { kind: 'quit' }
  | { kind: 'eof' };

export async function pick(io: Io, spec: PickSpec): Promise<PickResult> {
  const keys = spec.options.map((o, i) => o.key ?? String(i + 1));
  const labels = spec.options.map((o) => o.label);

  // Plain mode prints the numbered list once; selector mode redraws itself.
  if (!io.select) {
    io.write(`${spec.title}\n`);
    spec.options.forEach((o, i) => io.write(`  ${keys[i]}) ${o.label}\n`));
  }

  for (;;) {
    let line: string | null;
    if (io.select) {
      const r = await io.select({ title: spec.title, labels, back: spec.back, quit: spec.quit, typing: true });
      if (r.kind === 'index') return { kind: 'choice', index: r.index };
      if (r.kind === 'back') return { kind: 'back' };
      if (r.kind === 'quit') return { kind: 'quit' };
      if (r.kind === 'eof') return { kind: 'eof' };
      // A printable key was pressed: it opens a typed line, key included.
      line = await io.readLine('> ', { prefill: r.ch });
    } else {
      line = await io.readLine('> ');
    }

    if (line === null) return { kind: 'eof' };
    const text = line.trim();
    if (!text) continue;
    const lower = text.toLowerCase();

    if (lower === 'quit') return { kind: 'quit' };
    if (lower === 'back' && spec.back) return { kind: 'back' };
    if (lower === 'help' || lower === '?') { io.write(spec.helpText + '\n'); continue; }

    // A number, a name or a symbol selects an option.
    const index = spec.options.findIndex(
      (o, i) => keys[i] === text || (o.names ?? []).some((n) => n.toLowerCase() === lower),
    );
    if (index >= 0) return { kind: 'choice', index };

    // Otherwise it may be a one-line command; the list comes back afterwards.
    if (spec.command) {
      try {
        const out = spec.command(text);
        if (out) { io.write(out.join('\n') + '\n'); continue; }
      } catch (e) {
        io.write(formatError(e) + '\n');
        continue;
      }
    }
    io.write('Error [UNKNOWN_COMMAND]: Pick one from the list\n');
  }
}