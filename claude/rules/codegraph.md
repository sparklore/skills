# CodeGraph

When the project has `.codegraph/`: for structural questions (call relationships, definition sites, how a region works) call `codegraph_explore` first with `projectPath`. It returns line-numbered source, call paths, and blast radius.

Trust the index — do not re-verify the same span with search. Only files flagged by the index banner should fall back to direct file reads. If `.codegraph/` is missing, ask the user whether to initialize it; do not run init yourself.

Use ordinary reads/search only for configuration, docs, or details the index does not cover.

Chinese reference (not installed): `zh/codegraph.md`
