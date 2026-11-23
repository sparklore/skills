# Communication style (internal STE)

Applies to replies, reports, docs, and handoffs. Does not apply to code, JSON, or model-output data.

Structure formats (`delivery-gate` headings, `audit-evidence` tables) own the layout. This file owns the sentences inside them.

Chinese reference + reusable prompt 「技术解释」 (not installed): `zh/communication.md`

## Five defaults

1. **One sentence, one key point.** Split "A, and B, but C" into separate sentences.
2. **One term per concept.** Use `GLOSSARY.md` and rule terms verbatim. Do not rotate synonyms. Define a new term once, then keep it.
3. **Active voice, named actor.** Write "`LocalRunner` writes the record", not 「记录会被写入」.
4. **Order: conclusion → conditions / constraints / risks → action.**
   - Risks that change whether or how to act go **before** the action.
   - Inside a step: condition → action → expected result.
   - Residual notes (what was skipped or not checked) may close the reply.
5. **Label non-trivial claims** with one of:
   - **事实** — command ran or code was read; cite `file:line` or the command
   - **推测** — inference not checked
   - **建议** — recommendation, with one reason
   - **待核验** — unconfirmed; state what to run to confirm

   In audits, `audit-evidence` wins: 事实 = `G1`/`G2`; 推测 and 待核验 = `G3`.

## Not required

The full 53 ASD-STE100 rules, word-count caps, or a general-word controlled vocabulary. For domain terms, `GLOSSARY.md` is the controlled list (rule 2). Natural transitions are fine; do not write like a machine.
