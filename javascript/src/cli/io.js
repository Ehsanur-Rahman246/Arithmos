// Real stdin/stdout adapters. The CLI only talks to an `io` object:
//   readLine(prompt) -> Promise<string | null>   (null = end of input)
//   write(text)
//   style                                         (colours; plain for pipes)
//   select({ title, options, back, quit })        (arrow-key selector, terminals only)
//   close()
import readline from 'node:readline';
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

// A fresh readline interface per question keeps raw-mode handling simple and
// lets the selector take over the keyboard between questions.
function createTerminalIO(input, output) {
  const style = new Style(!process.env.NO_COLOR && process.env.TERM !== 'dumb');
  return {
    style,
    readLine(prompt = '') {
      return new Promise((resolve) => {
        const rl = readline.createInterface({ input, output, terminal: true });
        let settled = false;
        const finish = (value) => {
          if (settled) return;
          settled = true;
          rl.close();
          resolve(value);
        };
        rl.on('line', (line) => finish(line));
        rl.on('close', () => finish(null)); // Ctrl-D / Ctrl-C
        rl.setPrompt(prompt);
        rl.prompt();
      });
    },
    write(text) { output.write(text); },
    select({ title, options, back, quit }) {
      return selectFromList({ input, output, title, labels: options, style, back, quit });
    },
    close() {},
  };
}

export function createStdIO(input = process.stdin, output = process.stdout) {
  const interactive = Boolean(input.isTTY && output.isTTY && typeof input.setRawMode === 'function');
  return interactive ? createTerminalIO(input, output) : createPipedIO(input, output);
}