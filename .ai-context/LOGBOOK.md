# AI Context Logbook

This project uses `.ai-context/` to preserve durable AI working context across tools.

## Required Workflow

Before non-trivial work:

1. Run `python .ai-context/tools/aictx.py load`.
2. Add `--scope <path>` when touching a known module or file.
3. Use `--depth 1` for module work and `--depth 2` for debugging.

After meaningful changes:

1. Draft one concise entry JSON object.
2. Run `python .ai-context/tools/aictx.py append --entry <entry.json>`.
3. Do not hand-edit `.ai-context/toc.jsonl`; use `rebuild-toc`.

## What To Log

Log durable information that future agents need to avoid rediscovery or accidental regressions:

- Architecture or API decisions.
- Non-obvious implementation details.
- Bug fixes with root cause.
- Rejected approaches and why they failed.
- Fragile areas, risks, and follow-up decisions.
- Debugging findings that are likely to recur.

Do not log routine formatting, unchanged reruns, trivial command output, or private chain-of-thought.

## Depth Rules

| Depth | Meaning | Use For |
| --- | --- | --- |
| L0 | Project-level context | Architecture, public contracts, security boundaries, major decisions |
| L1 | Module-level context | Important behavior inside a component or feature |
| L2 | Diagnostic context | Debugging findings, rejected hypotheses, tricky test setup |
| L3 | Trace context | Line-level reasoning and temporary investigative notes |

If future agents need it before touching architecture, auth, persistence, deployment, or public APIs, use L0.
If future agents need it to safely modify a module, use L1.

## Entry Types

- `decision`
- `implementation`
- `bugfix`
- `refactor`
- `design_change`
- `rejected_approach`
- `attention`
- `investigation`
- `maintenance`

## Link Types

V1 supports a fixed relation set:

| Relation | Inverse | Meaning |
| --- | --- | --- |
| `implements` | `implemented-by` | This entry carries out an earlier decision or plan |
| `supersedes` | `superseded-by` | This entry replaces an earlier entry |
| `affects` | `affected-by` | This entry has consequences for another area |
| `extends` | `extended-by` | This entry builds on earlier work |
| `blocked-by` | `blocks` | This entry cannot proceed until another item is resolved |

References use stable entry ids:

```json
{"refs": [{"rel": "implements", "id": "20260626T074411Z-2b68ca96cbff"}]}
```

## Scope Conventions

Use repo-relative paths. Prefer directories for broad decisions (`src/auth/`) and files for implementation details (`src/auth/middleware.ts`).

## Privacy Rules

Never log:

- API keys, tokens, passwords, private keys, cookies, or session ids.
- Customer data, personal data, payment details, emails, or phone numbers.
- Large source excerpts.
- Exploit details unless explicitly approved.
- Absolute local paths outside the repo.

The helper script performs basic secret checks, but the agent is still responsible for redaction.

## Maintenance

- `validate`: check log consistency.
- `rebuild-toc`: regenerate the derived index.
- `refresh-state`: regenerate `state.md` from active L0 entries.
- `refresh-attention`: regenerate `attention.md` from active warnings.
- `doctor`: run diagnostics and print next actions.
