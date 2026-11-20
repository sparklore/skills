# Database changes

After adding or editing migration files, run the repo’s documented migrate command in the **same turn**. Confirm the DB process is listening first. On failure, bring the DB up, then retry.

Do not end with only 「请你自己跑迁移」 / "please run the migration yourself". Even if startup scripts migrate automatically, this task must still run migrate once now and record the output.

If the project exports a schema snapshot via a command, that export is authoritative — do not hand-edit it. If the snapshot is hand-maintained, add the same tables/columns/indexes/constraints in the same change.

Seeds must not contain production passwords or real personal sensitive data. Whether seed *business* content may be invented → `no-fake-data` only.

Do not edit the contents of migrations already published / already applied in an environment — append new files. If the project has a “squash to a single baseline” process, follow that project’s docs; do not copy another repo’s DB name, ports, or freeze dates.

Chinese reference (not installed): `zh/db-change.md`
