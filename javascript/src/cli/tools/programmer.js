// Binds the Programmer Calculator engine to the REPL (prompt: `programmer> `).
import {
  createProgrammerSession,
  formatAllBases,
} from "../../programmer/index.js";

export function programmerTool() {
  const session = createProgrammerSession();
  return {
    name: "Programmer Calculator",
    prompt: "programmer> ",
    intro: [
      "Programmer Calculator — 64-bit signed integers, shown in HEX / DEC / OCT / BIN.",
      "  Show a value:    255     0xFF     0b1010     0o17",
      "  Bitwise:         5 AND 3     5 OR 3     5 XOR 3     NOT 5",
      "  Shifts:          1 << 3      -8 >> 1 (arithmetic)    -8 >>> 1 (logical)",
      "  Convert a base:  convert 255 dec hex",
      "  Input base:      base hex   (then type FF instead of 0xFF)",
    ].join("\n"),
    helpText: [
      "base <bin|oct|dec|hex>        set the input base",
      "convert <value> <from> <to>   e.g. convert 255 dec hex",
      "<a> AND|OR|XOR <b>   NOT <a>   <a> << <n>   <a> >> <n>   <a> >>> <n>   (n is decimal, 0-63)",
      "Commands: help, back (main menu), quit (exit)",
    ].join("\n"),
    handle(line) {
      const result = session.run(line);
      if (result.type === "base") return "";
      if (result.type === "convert") return result.text;
      const all = formatAllBases(result.value);
      return ["HEX", "DEC", "OCT", "BIN"]
        .map((k) => `${k}: ${all[k]}`)
        .join("\n");
    },
  };
}
