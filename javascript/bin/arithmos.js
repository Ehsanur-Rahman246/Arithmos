#!/usr/bin/env node
// Entry point. All behavior lives in src/cli; this file only forwards argv.
import { main } from '../src/cli/index.js';

main(process.argv.slice(2)).then((code) => {
  process.exitCode = code;
});
