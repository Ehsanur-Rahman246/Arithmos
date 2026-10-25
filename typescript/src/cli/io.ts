import * as readline from 'node:readline';
import { TtyKeys } from './keys';
import { runSelector, type SelectResult, type SelectSpec } from './selector';
import { makeStyle, type Style } from './style';

export interface ReadLineOptions {
  /** Text already on the line (the key that opened a typed line). */
  prefill?: string;
  /** Esc returns the word `back` (the converter's values prompt). */
  escapeIsBack?: boolean;
}

/**
 * Everything the CLI needs from the terminal. Tools only talk to this object,
 * so tests can script a whole session with a fake.
 */
export interface Io {
  readonly style: Style;
  write(text: string): void;
  /** One line of input; null at end of input. */
  readLine(prompt: string, opts?: ReadLineOptions): Promise<string | null>;
  /** Present on a real terminal only. Absent means numbered lists. */
  select?(spec: SelectSpec): Promise<SelectResult>;
  close(): void;
}

/** Real terminal: stdin and stdout are terminals, TERM is not dumb, ARITHMOS_PLAIN is not 1. */
export function isRealTerminal(env: NodeJS.ProcessEnv = process.env): boolean {
  return Boolean(process.stdin.isTTY && process.stdout.isTTY) && env.TERM !== 'dumb' && env.ARITHMOS_PLAIN !== '1';
}

// ---------- pipes, files, tests, ARITHMOS_PLAIN=1: numbered lists ----------

export class PipeIo implements Io {
  readonly style = makeStyle(false);
  private readonly lines: string[] = [];
  private readonly waiters: Array<(line: string | null) => void> = [];
  private closed = false;
  private readonly rl: readline.Interface;
  private readonly echo: boolean;

  constructor(input: NodeJS.ReadableStream = process.stdin) {
    // When the input is not a terminal nothing echoes it, so we do, to keep transcripts readable.
    this.echo = !(input as NodeJS.ReadStream).isTTY;
    this.rl = readline.createInterface({ input, terminal: false, crlfDelay: Infinity });
    this.rl.on('line', (line) => {
      const waiter = this.waiters.shift();
      if (waiter) waiter(line);
      else this.lines.push(line);
    });
    this.rl.on('close', () => {
      this.closed = true;
      for (const w of this.waiters.splice(0)) w(null);
    });
  }

  write(text: string): void { process.stdout.write(text); }

  async readLine(prompt: string, opts: ReadLineOptions = {}): Promise<string | null> {
    this.write(prompt + (opts.prefill ?? ''));
    const line = await new Promise<string | null>((resolve) => {
      const queued = this.lines.shift();
      if (queued !== undefined) resolve(queued);
      else if (this.closed) resolve(null);
      else this.waiters.push(resolve);
    });
    if (line === null) { this.write('\n'); return null; } // EOF exits cleanly
    if (this.echo) this.write(line + '\n');
    return line;
  }

  close(): void { this.rl.close(); }
}

// ---------- real terminal: arrow-key selector + a small line editor ----------

export class TtyIo implements Io {
  readonly style: Style;
  private readonly keys = new TtyKeys();

  constructor(env: NodeJS.ProcessEnv = process.env) {
    this.style = makeStyle(!env.NO_COLOR);
  }

  write(text: string): void { process.stdout.write(text); }

  select(spec: SelectSpec): Promise<SelectResult> {
    const screen = {
      write: (s: string) => { process.stdout.write(s); },
      size: () => ({ cols: process.stdout.columns || 80, rows: process.stdout.rows || 24 }),
    };
    return runSelector(this.keys, screen, spec, this.style);
  }

  /** Line editor: typing, Backspace and Enter. No cursor movement or history. */
  async readLine(prompt: string, opts: ReadLineOptions = {}): Promise<string | null> {
    let buf = opts.prefill ?? '';
    this.write(prompt + buf);
    this.keys.enter();
    try {
      for (;;) {
        const key = await this.keys.readKey();
        switch (key.name) {
          case 'enter':
            this.write('\n');
            return buf;
          case 'ctrl-c':
            this.write('\n');
            return null;
          case 'ctrl-d':
            if (buf === '') { this.write('\n'); return null; }
            break;
          case 'escape':
            if (opts.escapeIsBack) { this.write('\n'); return 'back'; }
            break;
          case 'backspace':
            if (buf.length > 0) {
              buf = Array.from(buf).slice(0, -1).join('');
              this.write('\b \b');
            }
            break;
          case 'char':
            buf += key.ch;
            this.write(key.ch as string);
            break;
          default:
            break;
        }
      }
    } finally {
      this.keys.leave(); // never left raw
    }
  }

  close(): void { this.keys.leave(); }
}

export function createIo(): Io {
  return isRealTerminal() ? new TtyIo() : new PipeIo();
}