// Real stdin/stdout adapters. The CLI only talks to an `io` object:
//   readLine(prompt) -> Promise<string | null>   (null = end of input)
//   write(text)
//   select({ title, options, extras }) -> arrow-key selector (terminals only)
//   close()
import readline from "node:readline";
import { selectFromList } from "./select.js";

function createPipedIO(input, output) {
  const rl = readline.createInterface({ input, terminal: false });
  const lines = rl[Symbol.asyncIterator]();
  return {
    async readLine(prompt = "") {
      output.write(prompt);
      const { value, done } = await lines.next();
      return done ? null : value;
    },
    write(text) {
      output.write(text);
    },
    close() {
      rl.close();
    },
  };
}

// A fresh readline interface per question keeps raw-mode handling simple and
// lets the selector take over the keyboard between questions.
function createTerminalIO(input, output) {
  return {
    readLine(prompt = "") {
      return new Promise((resolve) => {
        const rl = readline.createInterface({ input, output, terminal: true });
        let settled = false;
        const finish = (value) => {
          if (settled) return;
          settled = true;
          rl.close();
          resolve(value);
        };
        rl.on("line", (line) => finish(line));
        rl.on("close", () => finish(null)); // Ctrl-D / Ctrl-C
        rl.setPrompt(prompt);
        rl.prompt();
      });
    },
    write(text) {
      output.write(text);
    },
    select({ title, options, extras }) {
      return selectFromList({ input, output, title, labels: options, extras });
    },
    close() {},
  };
}

export function createStdIO(input = process.stdin, output = process.stdout) {
  const interactive = Boolean(
    input.isTTY && output.isTTY && typeof input.setRawMode === "function",
  );
  return interactive
    ? createTerminalIO(input, output)
    : createPipedIO(input, output);
}
