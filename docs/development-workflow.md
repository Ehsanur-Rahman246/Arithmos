# Development Workflow

## Per-language workflow

1. Read the spec: [specifications/release-1.md](specifications/release-1.md).
2. Implement the core logic, separate from I/O (see [ARCHITECTURE.md](../ARCHITECTURE.md)).
3. Add the CLI layer, including the arrow-key selector (default on a real terminal; numbered
      lists for pipes, files, tests and ARITHMOS_PLAIN=1). The selector is part of the CLI layer, not an
      extra: build it before running the shared cases.
4. Run the shared cases (see [test-cases.md](test-cases.md)). A language is not
   complete while any shared case fails.
5. Write the language README using the template below.
6. Record any deviation in the README and in [language-support.md](language-support.md).
7. Tick the language in release-1.md §9, add a CHANGELOG entry, bump the version, tag.

## Language README template

Every language folder contains one `README.md` with these sections:
Prerequisites · Run · Test · Layout · How the hard parts are done (64-bit integers,
12-digit formatting) · Interface (selector keys, numbered-list mode,
   ARITHMOS_PLAIN, NO_COLOR, platform notes) · Deviations · Documentation links.
It satisfies spec Section 6.

## Versioning

| Version | Meaning |
|---|---|
| `0.1.0` | Project start (nothing complete) |
| `0.N.0` | The N−1th language finished Release 1 (JavaScript `0.2.0`, Python `0.3.0`, …) |
| `0.N.P` | Fixes after a language release |
| `1.0.0` | Release 1 reviewed and complete across the whole track |
| Later releases | Decide before Release 2 starts (`1.1.0` per release, or `2.0.0`) and record it here |

The version is project-wide. Language folders do not carry independent versions;
sync a language's `package.json` or equivalent when it is released.

## Commit and tag

```bash
git add .
git commit -m "Release 1: <Language> edition complete"
git tag -a vX.Y.Z -m "Release 1: <Language> edition complete"
git push --follow-tags
```

Commit order matters: commit first, then tag. Never move a pushed tag; create a new
patch version instead.

## Adding a language: checklist

- [ ] Folder at the repo root, named in lowercase
- [ ] Loads `docs/release-1-cases.json` and passes all 175 cases
- [ ] Extra tests: number formatting boundaries, CLI scripted sessions, no crash on garbage input
- [ ] Arrow-key selector on a real terminal, numbered lists when piped or with `ARITHMOS_PLAIN=1`
            - [ ] Selector tests SL1–SL21 pass (docs/test-cases.md)
            - [ ] Hand-tested in a real terminal: arrows, Enter, Esc, b, q, typing, Ctrl-C, ARITHMOS_PLAIN=1,
                  terminal not left raw
            (A language without a terminal is exempt: record it per release-1.md §9.)
- [ ] README follows the template
- [ ] Row added to `language-support.md`
- [ ] Release-1 §9 row ticked
- [ ] CHANGELOG entry, version bump, tag
- [ ] Selector hand-tested in a narrow terminal (about 60 columns) and a short one (about 8 rows)

## Documentation rules

- Anything that must be identical across languages lives once in `docs/`.
- Anything specific to one language lives in that language's README.
- Do not duplicate the spec: error codes, checklists and unit tables are linked,
  never copied.