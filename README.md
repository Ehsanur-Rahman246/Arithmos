# Arithmos

> One specification. Many languages. CLI first, GUI next.

Arithmos is a multi-language computational toolkit. Release 1 delivers three
command-line tools, implemented identically in every language on the track:

- **Standard Calculator** — expressions, precedence, percentages, `sqrt`, `abs`, `ans`
- **Programmer Calculator** — 64-bit two's-complement integers, bases, bitwise ops, shifts
- **Unit Converter** — twelve categories, including temperature

The long-term goal is a Windows Calculator–style application (Scientific, Graphing,
Date Calculation, Currency, memory/history, GUI). See [docs/roadmap.md](docs/roadmap.md).

## Status

Release 1 is complete in **3 of 43** languages. Per-language progress is tracked in
Section 9 of [the Release 1 spec](docs/specifications/release-1.md).

| Language | Version tag | Folder |
|---|---|---|
| JavaScript (reference) | `v0.2.0` | [javascript/](javascript/) |
| Python | `v0.3.0` | [python/](python/) |
| C | `v0.4.0` | [c/](c/) |

## Quick start

```bash
# JavaScript (Node.js 20+)
cd javascript && npm start

# Python (3.9+)
cd python && python -m arithmos

cd c && arithmos.exe
```

Each language folder's README has run, test and one-shot commands.

## Repository layout

```text
docs/        specifications, shared test cases, workflow, amendments
scripts/     build-cases.py (generates docs/release-1-cases.json from the spec)
javascript/  reference edition
python/      Python edition
c/           C edition
```

## Documentation

| Document | Contents |
|---|---|
| [ARCHITECTURE.md](ARCHITECTURE.md) | The layered design every edition follows |
| [CHANGELOG.md](CHANGELOG.md) | One entry per version tag |
| [docs/specifications/release-1.md](docs/specifications/release-1.md) | The behaviour contract |
| [docs/test-cases.md](docs/test-cases.md) | Shared test-case format and workflow |
| [docs/spec-amendments.md](docs/spec-amendments.md) | Ambiguities found and how they were settled |
| [docs/language-support.md](docs/language-support.md) | Runtime and delivery model per edition |
| [docs/development-workflow.md](docs/development-workflow.md) | Versioning, tagging, adding a language |
| [docs/roadmap.md](docs/roadmap.md) | Releases 1–5 and the language track |
| [docs/error-messages.md](docs/error-messages.md) | Error messages shown throughout the app |

Current version: 0.4.2.

## Versioning

`0.1.0` was the project start. Each completed Release 1 language edition bumps the
minor version; fixes bump the patch. `1.0.0` means Release 1 is complete across the
whole track. Details in [docs/development-workflow.md](docs/development-workflow.md).

## License

MIT