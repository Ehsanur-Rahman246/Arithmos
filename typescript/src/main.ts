import { runInteractive, runOneShot } from './cli/cli';
import { createIo } from './cli/io';

async function main(): Promise<void> {
  const status = runOneShot(
    process.argv.slice(2),
    (s) => { process.stdout.write(s); },
    (s) => { process.stderr.write(s); },
  );
  if (status !== null) {
    process.exitCode = status;
    return;
  }
  await runInteractive(createIo());
}

main().catch((e: unknown) => {
  process.stderr.write(`Error [INTERNAL]: ${e instanceof Error ? e.message : String(e)}\n`);
  process.exitCode = 1;
});