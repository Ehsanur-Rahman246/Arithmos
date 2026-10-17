// Unit Converter screens (prompt: `converter> `).
//   1. choose a category (12)   2. convert FROM   3. convert TO   4. type values
// Only units of the chosen category are ever offered, so a mismatch such as
// inches -> kelvin cannot be picked. One-line commands (`convert 100 cm in`,
// `list`, `... all`) still work. converterTool() is the one-shot/one-line form.
import { CATEGORIES, createConverterSession } from "../../converter/index.js";
import { pick } from "../pick.js";
import { printError } from "../repl.js";

const cap = (s) => s[0].toUpperCase() + s.slice(1);

const HELP = [
  "Type a value to convert it, e.g. 100   (one-line commands also work: convert 1 km mi, convert 1 km all)",
  "Commands: help, back (main menu), quit (exit), change (pick another category or units)",
].join("\n");

export function converterTool() {
  const session = createConverterSession();
  return {
    name: "Unit Converter",
    prompt: "converter> ",
    helpText: HELP,
    handle: (line) => session.run(line),
  };
}

const categoryOptions = CATEGORIES.map((c, i) => ({
  key: String(i + 1),
  label: c.name,
  value: c,
  aliases: [c.name],
}));

const unitOptions = (category) =>
  category.units.map((u, i) => ({
    key: String(i + 1),
    label: `${u.symbol.padEnd(9)}${u.name}`,
    value: u.symbol,
    aliases: [u.symbol],
  }));

const LEAVE = { back: "back", quit: "quit", eof: "eof" };
const wentUp = (r) => r.status === "esc" || r.status === "word"; // Esc key or typed `change`

export async function runGuidedConverter(io) {
  const session = createConverterSession();
  const passthrough = (line) => session.run(line);
  const common = { back: "main menu", quit: "quit" };

  for (;;) {
    const cat = await pick(io, {
      title: "Unit Converter — choose a category",
      options: categoryOptions,
      extras: { esc: "main menu", ...common },
      words: ["change"],
      passthrough,
    });
    if (cat.status === "word") continue;
    if (cat.status === "esc") return "back";
    if (cat.status !== "selected") return LEAVE[cat.status];
    const category = cat.option.value;
    const name = cap(category.name);

    const from = await pick(io, {
      title: `${name} — convert FROM`,
      options: unitOptions(category),
      extras: { esc: "categories", ...common },
      words: ["change"],
      passthrough,
    });
    if (wentUp(from)) continue;
    if (from.status !== "selected") return LEAVE[from.status];

    const to = await pick(io, {
      title: `${name} — convert TO   (from: ${from.option.value})`,
      options: unitOptions(category),
      extras: { esc: "categories", ...common },
      words: ["change"],
      passthrough,
    });
    if (wentUp(to)) continue;
    if (to.status !== "selected") return LEAVE[to.status];

    const a = from.option.value;
    const b = to.option.value;
    io.write(
      `\n${name}: ${a} → ${b}   Type a value and press Enter ("change" to pick again, "help", "back", "quit").\n`,
    );
    const prompt = `converter [${a} → ${b}]> `;
    for (;;) {
      const raw = await io.readLine(prompt);
      if (raw === null) {
        io.write("\n");
        return "eof";
      }
      const line = raw.trim();
      if (line === "") continue;
      const word = line.toLowerCase();
      if (word === "back") return "back";
      if (word === "quit") return "quit";
      if (word === "change") break;
      if (word === "help") {
        io.write(`${HELP}\n`);
        continue;
      }
      try {
        if (/\s/.test(line))
          io.write(`${session.run(line)}\n`); // a full one-line command
        else
          io.write(
            `${line} ${a} = ${session.run(`convert ${line} ${a} ${b}`)} ${b}\n`,
          );
      } catch (err) {
        printError(io, err);
      }
    }
  }
}
