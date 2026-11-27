# Data-Driven Sync Policy & Two-Layer Privacy Gate

This rule is mandatory for every sync, storage, privacy, memory/KG, or outbound LLM/tool egress change across `sparklore-forge` and `sparklore-clients`.

## Rule 1 — Data-Driven `UserSyncPolicy` (Zero Domain Hardcoding)

1. `UserSyncPolicy` (`ud/privacy`) MUST remain 100% domain-agnostic with zero hardcoded vertical/use-case strings in Go or JS. It operates strictly on 3 generic levels:
   - Master switch (`auto_sync_enabled`);
   - Category toggles (`agent_chat`, `preferences`, `workspace_records`) plus dynamic per-bundle `excluded_bundles` discovered from installed bundles (`SyncCatalogIndex`);
   - Ephemeral/no-save controls (`ephemeral_bundles` and per-session `X-Sparklore-Private: 1` / `ephemeral` toggle).
2. `config/<user>/sync_policy` in `ud_sync` is the cross-device policy record (exempt from exclusion so policy syncs across devices), mirrored locally in `ud_local` (`config/sync_policy/<seg>`) as a bootstrap snapshot before initial sync.

## Rule 2 — Two-Layer Privacy Gate (Exclusion + Zero-Persist)

1. **Layer 1 (Sync Boundary — `PolicyFilter` & Cloud Purge)**:
   - Keys excluded by `UserSyncPolicy` (`PolicyLocalOnly`) MUST be filtered symmetrically on both push and pull (`ud/sync` `PolicyFilter`) and MUST NEVER be appended to `SK_UD_REV`.
   - Changing a previously synced category or bundle to Excluded MUST stop future pushes immediately and support explicit local-preserving Cloud Purge (`POST /api/sync/purge` -> `PurgeKeysDoc` emits `Op: "delete"` on `SK_UD_REV` + `DetachCloud` clears `Base`/`Dirty`/`Upstream*` while preserving local `Current`).
2. **Layer 2 (Storage & Memory Boundary — `ZeroPersist` & `sensitive`)**:
   - Data in `ephemeral` sessions/bundles or carrying `persist: false` (`ZeroPersist`) MUST live strictly in volatile RAM (`VolatileOverlay`), MUST be wiped cleanly on logout, session expiry, or tenant eviction (`webSessionStore` in root `ud_local` remains intact), and MUST NEVER be written to `ud_sync`, `ud_local`, `SK_UD_REV`, CME (`LocalCME`, `appendWorkingMemory`, `EpisodicWorker`, `EpisodicConsumer`, `Assembler`), or Knowledge Graph (`GraphExtractWorker`, `cme_graph_triple`).
   - Records flagged `sensitive: true` MUST remain in `ud_local` (`sensitive/record/<id>`); fields listed in `sensitive_fields` (or `IsLocalField`) MUST be stripped into `ud_local` (`local/<key>`) before `ud_sync` writes.

## Rule 3 — Fail-Closed Outbound Cloud PII Redaction

1. Every outbound Cloud LLM, embedding, media, or web-search call MUST pass through `privacy.Redactor` (`mask` or `block`) according to `SyncRedactionPolicy`.
2. Invalid redaction regexes (`400 INVALID_REDACTION_PATTERN`) and `block`-mode matches (`422 REDACTION_BLOCKED`) MUST fail closed without silent fallback to secondary providers.
3. Only validated loopback local sidecars (`privacy.IsLoopbackURL(targetURL)`) may bypass redaction.
4. Outbound redaction MUST NEVER mutate stored local records (`ud_sync`, `ud_local`, or `VolatileOverlay`).

## Rule 4 — Single-Source `orbthread/*` Persistence

Orb Agent chat threads (`orbthread/<scope>`) belong exclusively to `ud_sync` (via `KindBridge` + domain-agnostic `orbThreadMergeResolver`) with one-time lossless migration from `ud_local`, respecting `agent_chat`, `excluded_bundles`, and `ZeroPersist` (`VolatileOverlay`). Permanent `ud_sync`/`ud_local` dual-write is strictly forbidden.

Chinese reference (not installed): `zh/sync-privacy-policy.md`
