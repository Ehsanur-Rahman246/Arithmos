// Public API of the Standard Calculator engine (no I/O).
//   createStandardSession() -> { evaluate(line) -> number, run(line) -> string, get ans() }
// `ans` only changes after a successful evaluation (spec 3.1).
import { formatNumber } from '../shared/index.js';
import { tokenize } from './tokenizer.js';
import { parse } from './parser.js';
import { evaluateAst } from './evaluator.js';

export { tokenize, parse, evaluateAst };

export function createStandardSession() {
  let ans = 0;
  const evaluate = (line) => {
    const result = evaluateAst(parse(tokenize(line)), { ans });
    formatNumber(result); // throws if it cannot be displayed; ans stays unchanged
    ans = result;
    return result;
  };
  return {
    evaluate,
    run: (line) => formatNumber(evaluate(line)),
    get ans() { return ans; },
  };
}
