// One question, many answers. On a real terminal it is an arrow-key selector;
// everywhere else (pipes, tests, terminals without raw mode) it is the same
// question as a numbered list answered by typing.
//
//   options : [{ key, label, value, aliases? }]
//   extras  : { esc, back, quit } - extra keys to offer (text = what the key does)
//   words   : extra typed words to report, e.g. ['change']
//   passthrough(line) : optional; typed lines containing spaces (or `list`) are
//                       handed to it, so one-line commands keep working
// Resolves to { status: 'selected', option } or { status: 'esc' | 'back' | 'quit' | 'word' | 'eof', word? }.
import { ArithmosError } from "../shared/index.js";
import { printError } from "./repl.js";

export async function pick(
  io,
  {
    title,
    options,
    extras = {},
    words = [],
    passthrough,
    errorCode = "UNKNOWN_COMMAND",
  },
) {
  if (io.select) {
    const r = await io.select({
      title,
      options: options.map((o) => o.label),
      extras,
    });
    if (r.status === "selected")
      return { status: "selected", option: options[r.index] };
    return { status: r.status === "abort" ? "eof" : r.status };
  }

  const show = () =>
    io.write(
      `${title}\n${options.map((o) => `  ${o.key}) ${o.label}`).join("\n")}\n`,
    );
  show();
  for (;;) {
    const raw = await io.readLine("> ");
    if (raw === null) {
      io.write("\n");
      return { status: "eof" };
    }
    const text = raw.trim().toLowerCase();
    if (text === "") continue;
    if (text === "quit") return { status: "quit" };
    if (text === "back" && extras.back) return { status: "back" };
    if (text === "help") {
      show();
      continue;
    }
    if (words.includes(text)) return { status: "word", word: text };

    const hit = options.find(
      (o) =>
        o.key === text ||
        o.label.toLowerCase() === text ||
        o.aliases?.includes(text),
    );
    if (hit) return { status: "selected", option: hit };

    if (passthrough && (/\s/.test(text) || text === "list")) {
      try {
        const out = passthrough(raw.trim());
        if (out) io.write(`${out}\n`);
      } catch (err) {
        printError(io, err);
      }
      continue;
    }
    printError(
      io,
      new ArithmosError(errorCode, "Choose one of the listed options"),
    );
  }
}
