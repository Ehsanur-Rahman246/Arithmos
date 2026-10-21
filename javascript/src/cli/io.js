// Real stdin/stdout adapters. The CLI only talks to an `io` object:
//   readLine(prompt) -> Promise<string | null>   (null = end of input)
//   write(text)
//   style                                         (colours; plain for pipes)
//   select({ title, options, back, quit, typing }) (arrow-key selector, terminals only)
//   close()
import readline, { emitKeypressEvents } from 'node:readline';
import { selectFromList } from './select.js';
import { PLAIN, Style } from './style.js';

function createPipedIO(input, output) {
  const rl = readline.createInterface({ input, terminal: false });
  const lines = rl[Symbol.asyncIterator]();
  return {
    style: PLAIN,
    async readLine(prompt = '') {
      output.write(prompt);
      const { value, done } = await lines.next();
      return done ? null : value;
    },
    write(text) { output.write(text); },
    close() { rl.close(); },
  };
}

// One key reader owns the terminal for the whole session. Raw mode is switched on once
// and off once; stdin is never paused or re-created between screens, and no readline
// interface is opened per question. (Doing that on every screen could leave Windows
// consoles deaf to every key, Ctrl+C included.) Keys that arrive while no screen is
// waiting are queued, so none are lost.
function createKeyReader(input) {
  // Node waits 500 ms after a lone Esc and merges Esc presses closer than that; 50 ms
  // keeps each Esc a separate key. Must run before anything else listens for keys.
  emitKeypressEvents(input, { escapeCodeTimeout: 50 });
  const wasRaw = Boolean(input.isRaw);
  input.setRawMode(true);
  input.resume();

  const queue = [];
  let waiter = null;
  let closed = false;
  const deliver = (key) => {
    if (waiter) { const w = waiter; waiter = null; w(key); } else queue.push(key);
  };
  const onKey = (str, key) => {
    const k = { ...(key ?? {}), str };
    if (k.ctrl && k.name === 'c' && !waiter) { close(); process.exit(130); } // nobody is listening
    deliver(k);
  };
  const onEnd = () => deliver({ name: 'd', ctrl: true }); // stdin closed: behave like Ctrl-D
  input.on('keypress', onKey);
  input.on('end', onEnd);

  function close() {
    if (closed) return;
    closed = true;
    input.off('keypress', onKey);
    input.off('end', onEnd);
    try { input.setRawMode(wasRaw); } catch { /* terminal already gone */ }
    input.pause();
  }
  process.once('exit', close);
  return {
    readKey: () => (queue.length ? Promise.resolve(queue.shift()) : new Promise((resolve) => { waiter = resolve; })),
    close,
  };
}

// A minimal line editor on top of the key reader: type, Backspace, Enter. Ctrl-C, or
// Ctrl-D on an empty line, resolves to null (end of input). With escBack, Esc resolves
// to 'back'. Cursor movement and history are not supported.
async function readEditedLine(readKey, output, prompt, { escBack = false } = {}) {
  output.write(prompt);
  let line = '';
  for (;;) {
    const key = await readKey();
    if (key.ctrl) {
      if (key.name === 'c' || (key.name === 'd' && line === '')) return null;
      continue;
    }
    switch (key.name) {
      case 'return':
      case 'enter':
        output.write('\n');
        return line;
      case 'escape':
        if (escBack) { output.write('\n'); return 'back'; }
        break;
      case 'backspace':
        if (line.length) { line = line.slice(0, -1); output.write('\b \b'); }
        break;
      default: {
        const text = key.str;
        if (!key.meta && typeof text === 'string' && text.length > 0 && text >= ' ' && text !== '\x7f') {
          line += text;
          output.write(text);
        }
      }
    }
  }
}

function createTerminalIO(input, output) {
  const style = new Style(!process.env.NO_COLOR && process.env.TERM !== 'dumb');
  const keys = createKeyReader(input);
  return {
    style,
    readLine(prompt = '', options) { return readEditedLine(keys.readKey, output, prompt, options); },
    write(text) { output.write(text); },
    select({ title, options, back, quit, typing }) {
      return selectFromList({ readKey: keys.readKey, output, title, labels: options, style, back, quit, typing });
    },
    close() { keys.close(); output.write('\x1b[?25h'); },
  };
}

export function createStdIO(input = process.stdin, output = process.stdout) {
  const interactive = process.env.ARITHMOS_PLAIN !== '1' && Boolean(input.isTTY && output.isTTY && typeof input.setRawMode === 'function');
  return interactive ? createTerminalIO(input, output) : createPipedIO(input, output);
}