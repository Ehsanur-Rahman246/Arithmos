// Loads the shared, language-neutral cases (repo: docs/release-1-cases.json).
// Resolved relative to this file so tests work from any working directory.
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const CASES_PATH = resolve(here, '../../../docs/release-1-cases.json');

export function loadCases(tool) {
  const all = JSON.parse(readFileSync(CASES_PATH, 'utf8'));
  return all.filter((c) => c.tool === tool);
}
