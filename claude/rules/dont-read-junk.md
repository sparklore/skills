# Do not read junk paths

By default do not scan: `vendor/`, `node_modules/`, `dist/`, `build/`, `coverage/`, `*.min.js`, `*.map`, `logs/`, `tmp/`, `*.log`, `**/testdata/**`, `**/fixtures/**`, bulk CSV/JSON dumps.

Exceptions: a single file the user names; when editing tests, only the matching test sources; dependency manifests (e.g. `go.mod`, `package.json`) are OK; lockfiles only when resolving a version conflict (single-line search).

If this conflicts with `.cursorignore`, the stricter rule wins.

Chinese reference (not installed): `zh/dont-read-junk.md`
