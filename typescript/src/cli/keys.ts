// Raw terminal bytes → keys (pure, test X3), plus the real key reader.

export type KeyName =
  | 'up' | 'down' | 'left' | 'right' | 'home' | 'end' | 'pageup' | 'pagedown'
  | 'enter' | 'escape' | 'backspace' | 'tab' | 'ctrl-c' | 'ctrl-d' | 'char' | 'other';

export interface Key { name: KeyName; ch?: string }

const CSI_FINAL: Record<string, KeyName> = { A: 'up', B: 'down', C: 'right', D: 'left', H: 'home', F: 'end' };
const CSI_TILDE: Record<string, KeyName> = { '1': 'home', '7': 'home', '4': 'end', '8': 'end', '5': 'pageup', '6': 'pagedown' };

/**
 * Parse one chunk read from stdin. Terminals deliver an arrow key as one chunk
 * (ESC [ A), so a chunk that is only ESC is a lone Esc press; no timer needed.
 */
export function parseKeys(input: string): Key[] {
  const out: Key[] = [];
  const cps = Array.from(input); // code points, so UTF-8 characters stay whole
  let i = 0;
  while (i < cps.length) {
    const c = cps[i];

    if (c === '\x1b') {
      const n = cps[i + 1];
      if (n === undefined) { out.push({ name: 'escape' }); i++; continue; }
      if (n === '[' || n === 'O') {
        let j = i + 2;
        let params = '';
        while (j < cps.length && /[0-9;]/.test(cps[j])) params += cps[j++];
        const fin = cps[j];
        if (fin === undefined) { out.push({ name: 'other' }); i = j; continue; }
        const name = fin === '~' ? CSI_TILDE[params.split(';')[0]] ?? 'other' : CSI_FINAL[fin] ?? 'other';
        out.push({ name });
        i = j + 1;
        continue;
      }
      out.push({ name: 'other' }); // Alt+key and unknown escapes
      i += 2;
      continue;
    }

    i++;
    if (c === '\r') out.push({ name: 'enter' });
    else if (c === '\n') { if (cps[i - 2] !== '\r') out.push({ name: 'enter' }); }
    else if (c === '\x7f' || c === '\b') out.push({ name: 'backspace' });
    else if (c === '\x03') out.push({ name: 'ctrl-c' });
    else if (c === '\x04') out.push({ name: 'ctrl-d' });
    else if (c === '\t') out.push({ name: 'tab' });
    else if (c < ' ') out.push({ name: 'other' });
    else out.push({ name: 'char', ch: c });
  }
  return out;
}

/** Anything that can supply keys: the real terminal, or a fake in tests. */
export interface KeySource {
  /** Start reading keys (raw mode on). */
  enter(): void;
  /** Stop reading keys (raw mode off). Always called, even after an error. */
  leave(): void;
  readKey(): Promise<Key>;
}

/**
 * The real keyboard. One persistent reader for the whole session (a fresh
 * readline per screen froze terminals in the JavaScript edition). Raw mode is on
 * only between enter() and leave(), so the terminal is never left raw.
 */
export class TtyKeys implements KeySource {
  private queue: Key[] = [];
  private waiter: ((k: Key) => void) | null = null;
  private active = false;

  private readonly onData = (chunk: Buffer | string): void => {
    for (const key of parseKeys(chunk.toString())) {
      if (this.waiter) {
        const w = this.waiter;
        this.waiter = null;
        w(key);
      } else {
        this.queue.push(key);
      }
    }
  };

  constructor() {
    // Safety nets: restore the terminal however the process ends.
    process.once('exit', () => { this.setRaw(false); process.stdout.write('\x1b[?25h'); });
    process.once('SIGTERM', () => process.exit(143));
    process.once('SIGHUP', () => process.exit(129));
  }

  private setRaw(on: boolean): void {
    try { process.stdin.setRawMode?.(on); } catch { /* not a terminal any more */ }
  }

  enter(): void {
    if (this.active) return;
    this.active = true;
    this.setRaw(true);
    process.stdin.on('data', this.onData);
    process.stdin.resume();
  }

  leave(): void {
    if (!this.active) return;
    this.active = false;
    process.stdin.off('data', this.onData);
    process.stdin.pause();
    this.setRaw(false);
  }

  readKey(): Promise<Key> {
    const queued = this.queue.shift();
    if (queued) return Promise.resolve(queued);
    return new Promise((resolve) => { this.waiter = resolve; });
  }
}