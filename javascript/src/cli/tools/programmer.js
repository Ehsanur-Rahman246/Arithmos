// Binds the Programmer Calculator engine to the REPL (prompt: `programmer> `).
import { createProgrammerSession, formatAllBases } from '../../programmer/index.js';

export function programmerTool() {
  const session = createProgrammerSession();
  return {
    name: 'Programmer Calculator',
    prompt: 'programmer> ',
    intro: [
      'Programmer Calculator · 64-bit integers   (help · back · quit)',
      'Try: 255    5 AND 3    1 << 3    255 dec hex',
    ].join('\n'),
    helpText: [
      '  255  0xFF  0b101    show a number in HEX DEC OCT BIN',
      '  5 AND 3             also OR, XOR;  NOT 5',
      '  1 << 3              shifts: << left, >> arithmetic, >>> logical',
      '  255 dec hex         convert between bin, oct, dec, hex',
      '  base hex            type numbers in hex from now on',
      '  back  main menu     quit  exit',
    ].join('\n'),
    handle(line) {
      const result = session.run(line);
      if (result.type === 'base') return `Input base: ${result.base}`;
      if (result.type === 'convert') return result.text;
      const all = formatAllBases(result.value);
      return ['HEX', 'DEC', 'OCT', 'BIN'].map((k) => `${k}: ${all[k]}`).join('\n');
    },
  };
}