// Binds the Standard Calculator engine to the REPL (prompt: `standard> `).
import { createStandardSession } from '../../calculator/index.js';

export function standardTool() {
  const session = createStandardSession();
  return {
    name: 'Standard Calculator',
    prompt: 'standard> ',
    intro: [
      'Standard Calculator   (help · back · quit)',
      'Try: 2 + 3 * 4    sqrt(16)    20% of 150    ans * 2',
    ].join('\n'),
    helpText: [
      '  2 + 3 * 4        + - * / ^ and ( )',
      '  sqrt(x) abs(x)   functions',
      '  20% of 150       percent;  200 + 10% adds 10% of 200',
      '  ans              the last result',
      '  back  main menu     quit  exit',
    ].join('\n'),
    handle: (line) => session.run(line),
  };
}