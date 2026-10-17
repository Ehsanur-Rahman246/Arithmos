// Main menu: "Arithmos 1.0 — Core CLI", options 1/2/3/0 (spec 2.1).
import { pick } from "./pick.js";
import { runRepl } from "./repl.js";
import { standardTool } from "./tools/standard.js";
import { programmerTool } from "./tools/programmer.js";
import { runGuidedConverter } from "./tools/converter.js";

export const MENU_TITLE = "Arithmos 1.0 — Core CLI";

const MENU = [
  { key: "1", label: "Standard Calculator", value: "standard" },
  { key: "2", label: "Programmer Calculator", value: "programmer" },
  { key: "3", label: "Unit Converter", value: "converter" },
  { key: "0", label: "Exit", value: "exit" },
];

function runTool(value, io) {
  if (value === "converter") return runGuidedConverter(io);
  const tool = value === "standard" ? standardTool() : programmerTool();
  return runRepl({
    prompt: tool.prompt,
    handle: tool.handle,
    helpText: tool.helpText,
    intro: tool.intro,
    io,
  });
}

// Resolves to the exit reason; the caller exits with status 0 either way.
export async function runMenu(io) {
  for (;;) {
    const r = await pick(io, {
      title: MENU_TITLE,
      options: MENU,
      extras: { esc: "exit" },
    });
    if (r.status === "eof") return "eof";
    if (r.status !== "selected" || r.option.value === "exit") return "exit";
    const outcome = await runTool(r.option.value, io);
    if (outcome === "quit" || outcome === "eof") return outcome;
  }
}
