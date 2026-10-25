// The arrow-key selector in the layers the architecture asks for:
//   1. key handling (pure)   2. drawing (pure)   3. the draw/read loop
// pick() (layer 4) lives in pick.ts.

import type { Key, KeySource } from './keys';
import type { Style } from './style';

export interface SelectSpec {
  title: string;
  labels: string[];
  initial?: number;
  /** Esc and `b` mean back. */
  back: boolean;
  /** `q` means quit. */
  quit: boolean;
  /** Any other printable key ends the selector and carries its character. */
  typing: boolean;
}

export type SelectResult =
  | { kind: 'index'; index: number }
  | { kind: 'back' }
  | { kind: 'quit' }
  | { kind: 'typed'; ch: string }
  | { kind: 'eof' };

export interface SelState { index: number; top: number }

export const MAX_WINDOW = 10;

/** Rows of the list window: at most 10, and the whole block (title + rows + hint) must fit the terminal. */
export function windowSize(count: number, rows: number): number {
  return Math.max(1, Math.min(MAX_WINDOW, count, rows - 3));
}

/** Keep the selected row inside the window. */
export function scrollTo(state: SelState, count: number, win: number): SelState {
  let top = Math.min(state.top, Math.max(0, count - win));
  if (state.index < top) top = state.index;
  if (state.index >= top + win) top = state.index - win + 1;
  return { index: state.index, top };
}

// ---------- 1. key handling (pure) ----------

export type KeyOutcome = { state: SelState } | { done: SelectResult };

export function handleKey(state: SelState, key: Key, spec: SelectSpec, win: number): KeyOutcome {
  const n = spec.labels.length;
  const move = (index: number): KeyOutcome => ({ state: scrollTo({ index, top: state.top }, n, win) });

  switch (key.name) {
    case 'up': return move((state.index - 1 + n) % n);
    case 'down': return move((state.index + 1) % n);
    case 'home': return move(0);
    case 'end': return move(n - 1);
    case 'pageup': return move(Math.max(0, state.index - win));
    case 'pagedown': return move(Math.min(n - 1, state.index + win));
    case 'enter': return { done: { kind: 'index', index: state.index } };
    case 'escape': return spec.back ? { done: { kind: 'back' } } : { state };
    case 'ctrl-c':
    case 'ctrl-d': return { done: { kind: 'eof' } };
    case 'char': {
      const ch = key.ch as string;
      // b and q act at once, only where offered, with no prompt line.
      if (ch === 'b' && spec.back) return { done: { kind: 'back' } };
      if (ch === 'q' && spec.quit) return { done: { kind: 'quit' } };
      // Space and control keys never start a typed line.
      if (spec.typing && ch !== ' ' && ch >= ' ' && ch !== '\x7f') return { done: { kind: 'typed', ch } };
      return { state };
    }
    default:
      return { state }; // tab, left/right, other control keys: ignored
  }
}

// ---------- 2. drawing (pure) ----------

/** The hint line lists only the keys that are on offer. */
export function hint(spec: SelectSpec): string {
  const parts = ['↑↓ move', 'Enter select'];
  if (spec.back) parts.push('Esc/b back');
  if (spec.quit) parts.push('q quit');
  if (spec.typing) parts.push('or type');
  return parts.join(' · ');
}

export interface Size { cols: number; rows: number }

/**
 * One logical line is one screen line: every line is at most (cols - 1) wide,
 * with "…" where it was cut, so erasing by line count is always right.
 */
export function render(state: SelState, spec: SelectSpec, size: Size, style: Style): string[] {
  const n = spec.labels.length;
  const win = windowSize(n, size.rows);
  const st = scrollTo(state, n, win);
  const width = Math.max(1, size.cols - 1);
  const fit = (s: string): string => (s.length <= width ? s : s.slice(0, Math.max(0, width - 1)) + '…');

  const lines = [style.bold(fit(spec.title))];
  for (let i = st.top; i < st.top + win; i++) {
    const selected = i === st.index;
    const text = fit((selected ? '❯ ' : '  ') + spec.labels[i]);
    // Selected row: a full reverse-video bar. Without colour the ❯ pointer remains.
    lines.push(selected && style.enabled ? style.reverse(text.padEnd(width)) : text);
  }
  lines.push(style.dim(fit(hint(spec))));
  return lines;
}

// ---------- 3. the loop over an injectable keyboard and screen ----------

export interface Screen {
  write(text: string): void;
  size(): Size;
}

export async function runSelector(
  keys: KeySource,
  screen: Screen,
  spec: SelectSpec,
  style: Style,
): Promise<SelectResult> {
  const n = spec.labels.length;
  let state: SelState = scrollTo(
    { index: Math.min(Math.max(spec.initial ?? 0, 0), n - 1), top: 0 }, n, windowSize(n, screen.size().rows));
  let drawn = 0;

  const draw = (): void => {
    const lines = render(state, spec, screen.size(), style); // size re-measured on every redraw
    screen.write(lines.join('\n') + '\n');
    drawn = lines.length;
  };
  const erase = (): void => {
    if (drawn > 0) screen.write(`\x1b[${drawn}A\r\x1b[J`); // up by the drawn line count, clear below
    drawn = 0;
  };

  keys.enter();
  screen.write('\x1b[?25l'); // hide cursor
  try {
    draw();
    for (;;) {
      const key = await keys.readKey();
      const out = handleKey(state, key, spec, windowSize(n, screen.size().rows));
      if ('done' in out) {
        erase();
        // A chosen row leaves `✔ <title>: <label>` behind (R28).
        if (out.done.kind === 'index') screen.write(`✔ ${spec.title}: ${spec.labels[out.done.index]}\n`);
        return out.done;
      }
      if (out.state.index !== state.index || out.state.top !== state.top) {
        state = out.state;
        erase();
        draw();
      }
    }
  } finally {
    erase();
    screen.write('\x1b[?25h'); // cursor visible again, whatever happened
    keys.leave();
  }
}