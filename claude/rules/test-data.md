# Test data hygiene

1. Unique strings (usernames, invite codes, etc.) use short names (short prefix + short random). Do not embed nanosecond timestamps in names.
2. Cleanup must run while the connection is still open. Register data deletes before connection close. If close runs first, deletes fail silently.
3. Delete failures fail the test — never ignore them.
4. Respect foreign keys: children before parents; subordinates before superiors when hierarchical.
5. After the run, assert zero rows for that prefix. Test rows must not remain as integration-seed litter.

Washing leftover data: only names the tests generated; do not touch seeds or human accounts. Backup first, then delete in one transaction by FK order. Afterward, rows pointing at missing principals must be zero. Do not mass-rename legacy long names; shorten when you touch that test.

Chinese reference (not installed): `zh/test-data.md`
