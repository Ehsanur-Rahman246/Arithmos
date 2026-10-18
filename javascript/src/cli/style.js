// Tiny ANSI styling. Disabled (plain text) for pipes, tests and NO_COLOR.
export class Style {
  constructor(enabled = false) {
    this.enabled = enabled;
  }

  wrap(code, text) {
    return this.enabled ? `\x1b[${code}m${text}\x1b[0m` : text;
  }

  bold(text) { return this.wrap('1', text); }
  dim(text) { return this.wrap('2', text); }
  red(text) { return this.wrap('31', text); }
  green(text) { return this.wrap('32', text); }
  inverse(text) { return this.wrap('7', text); } // the highlight bar of the selector
}

export const PLAIN = new Style(false);