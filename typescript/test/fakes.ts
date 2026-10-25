import type { Io, ReadLineOptions } from '../src/cli/io';
import type { Key, KeySource } from '../src/cli/keys';
import type { Screen, SelectResult, SelectSpec, Size } from '../src/cli/selector';
import { makeStyle } from '../src/cli/style';

/** A scripted keyboard. Counts enter()/leave() so tests can check the terminal is restored. */
export class FakeKeys implements KeySource {
  entered = 0;
  left = 0;
  constructor(private readonly keys: Key[]) {}
  enter(): void { this.entered++; }
  leave(): void { this.left++; }
  async readKey(): Promise<Key> {
    const k = this.keys.shift();
    if (!k) throw new Error('FakeKeys: out of keys');
    return k;
  }
}

/** A screen that records everything written to it. */
export class FakeScreen implements Screen {
  out = '';
  constructor(public cols = 80, public rows = 24) {}
  write(text: string): void { this.out += text; }
  size(): Size { return { cols: this.cols, rows: this.rows }; }
}

/**
 * A scripted Io. `lines` feed readLine (null or empty = end of input).
 * Passing `selects` makes the fake behave like a real terminal (io.select exists).
 */
export class FakeIo implements Io {
  out = '';
  readCalls = 0;
  selectCalls = 0;
  closed = false;
  readonly style = makeStyle(false);
  select?: (spec: SelectSpec) => Promise<SelectResult>;

  constructor(private readonly lines: Array<string | null> = [], selects?: SelectResult[]) {
    if (selects) {
      this.select = async () => {
        this.selectCalls++;
        const r = selects.shift();
        if (!r) throw new Error('FakeIo: out of select results');
        return r;
      };
    }
  }

  write(text: string): void { this.out += text; }

  async readLine(prompt: string, _opts?: ReadLineOptions): Promise<string | null> {
    this.readCalls++;
    this.out += prompt;
    return this.lines.length === 0 ? null : (this.lines.shift() as string | null);
  }

  close(): void { this.closed = true; }
}