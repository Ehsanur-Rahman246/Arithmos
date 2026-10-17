// Arrow-key list selector (the "pick a framework" style of prompt).
// No dependencies. The key handling is a pure function so it can be tested
// without a terminal; selectFromList() is the thin terminal wrapper around it.
import { emitKeypressEvents } from "node:readline";

const HINT = {
  esc: (text) => `Esc ${text}`,
  back: (text) => `b ${text}`,
  quit: (text) => `q ${text}`,
};

export function initialState(count, size = 10) {
  return { index: 0, offset: 0, count, size: Math.min(size, count) };
}

function moveTo(state, index) {
  let { offset } = state;
  if (index < offset) offset = index;
  if (index >= offset + state.size) offset = index - state.size + 1;
  return { ...state, index, offset };
}

// extras = which extra keys are active, e.g. { esc: 'categories', back: 'main menu', quit: 'quit' }
// Returns { state, done? } where done is 'selected' | 'esc' | 'back' | 'quit' | 'abort'.
export function applyKey(state, key, extras = {}) {
  const name = key?.name;
  if (key?.ctrl)
    return name === "c" || name === "d" ? { state, done: "abort" } : { state };
  const { index, count } = state;
  switch (name) {
    case "up":
      return { state: moveTo(state, (index - 1 + count) % count) };
    case "down":
      return { state: moveTo(state, (index + 1) % count) };
    case "home":
      return { state: moveTo(state, 0) };
    case "end":
      return { state: moveTo(state, count - 1) };
    case "return":
    case "enter":
      return { state, done: "selected" };
    case "escape":
      return extras.esc ? { state, done: "esc" } : { state };
    case "b":
      return extras.back ? { state, done: "back" } : { state };
    case "q":
      return extras.quit ? { state, done: "quit" } : { state };
    default:
      return { state };
  }
}

export function renderList(title, labels, state, extras = {}) {
  const lines = [title];
  for (let i = state.offset; i < state.offset + state.size; i += 1) {
    lines.push(`${i === state.index ? "❯" : " "} ${labels[i]}`);
  }
  if (state.count > state.size)
    lines.push(`  (${state.index + 1} of ${state.count})`);
  const keys = ["↑↓ move", "Enter select"];
  for (const k of ["esc", "back", "quit"]) {
    if (!extras[k]) continue;
    if (k === "back" && extras.back === extras.esc) continue; // same destination: one hint is enough
    keys.push(HINT[k](extras[k]));
  }
  lines.push(`  ${keys.join(" · ")}`);
  return lines;
}

// Resolves to { status: 'selected', index } or { status: 'esc' | 'back' | 'quit' | 'abort' }.
export function selectFromList({ input, output, title, labels, extras = {} }) {
  return new Promise((resolve) => {
    emitKeypressEvents(input);
    const wasRaw = Boolean(input.isRaw);
    input.setRawMode(true);
    input.resume();

    let state = initialState(labels.length);
    let drawn = 0;
    const erase = () => {
      if (drawn) output.write(`\x1b[${drawn}A\x1b[0J`);
      drawn = 0;
    };
    const draw = () => {
      erase();
      const lines = renderList(title, labels, state, extras);
      output.write(`${lines.join("\n")}\n`);
      drawn = lines.length;
    };

    const finish = (status) => {
      input.off("keypress", onKey);
      input.setRawMode(wasRaw);
      input.pause();
      erase();
      if (status === "selected")
        output.write(`✔ ${title}: ${labels[state.index]}\n`);
      output.write("\x1b[?25h");
      resolve(
        status === "selected" ? { status, index: state.index } : { status },
      );
    };

    function onKey(_str, key) {
      const result = applyKey(state, key, extras);
      state = result.state;
      if (result.done) finish(result.done);
      else draw();
    }

    output.write("\x1b[?25l");
    draw();
    input.on("keypress", onKey);
  });
}
