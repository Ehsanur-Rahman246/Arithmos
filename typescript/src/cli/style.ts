export interface Style {
  readonly enabled: boolean;
  bold(s: string): string;
  dim(s: string): string;
  reverse(s: string): string;
}

/** Colours on for real terminals, off for pipes, tests and NO_COLOR. */
export function makeStyle(enabled: boolean): Style {
  const wrap = (on: string, off: string) => (s: string) => (enabled ? `\x1b[${on}m${s}\x1b[${off}m` : s);
  return { enabled, bold: wrap('1', '22'), dim: wrap('2', '22'), reverse: wrap('7', '27') };
}