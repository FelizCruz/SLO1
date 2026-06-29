#!/usr/bin/env python3
"""Minimal AI context logbook helper.

This script is intentionally dependency-free. Copy it to
`.ai-context/tools/aictx.py` inside a project, or adapt it into a packaged tool.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import secrets
import sys
from pathlib import Path
from typing import Any


ROOT_MARKER = ".ai-context"
VALID_DEPTHS = {0, 1, 2, 3}
VALID_TYPES = {
    "attention",
    "bugfix",
    "decision",
    "design_change",
    "implementation",
    "investigation",
    "maintenance",
    "refactor",
    "rejected_approach",
}
VALID_STATUS = {"active", "archived", "resolved", "superseded"}
VALID_ACTORS = {"ai", "human", "mixed"}
VALID_RELS = {"affects", "blocked-by", "extends", "implements", "supersedes"}
REQUIRED_FIELDS = {
    "v",
    "id",
    "created_at",
    "tool",
    "depth",
    "scope",
    "type",
    "title",
    "preview",
    "summary",
    "status",
}
SECRET_PATTERNS = [
    re.compile(r"sk-[A-Za-z0-9_-]{20,}"),
    re.compile(r"AKIA[0-9A-Z]{16}"),
    re.compile(r"(?i)(api[_-]?key|token|password|secret)\s*[:=]\s*['\"]?[^'\"\s]{12,}"),
    re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH |)PRIVATE KEY-----"),
]

LOGBOOK_TEMPLATE = """# AI Context Logbook

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
"""

ENTRY_SCHEMA = {
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    "title": "AI Context Logbook Entry",
    "type": "object",
    "required": sorted(REQUIRED_FIELDS),
    "properties": {
        "v": {"const": 1},
        "id": {"type": "string", "minLength": 8},
        "created_at": {"type": "string"},
        "updated_at": {"type": ["string", "null"]},
        "tool": {"type": "string"},
        "actor": {"enum": sorted(VALID_ACTORS)},
        "depth": {"enum": sorted(VALID_DEPTHS)},
        "scope": {"type": "string"},
        "type": {"enum": sorted(VALID_TYPES)},
        "title": {"type": "string"},
        "preview": {"type": "string", "maxLength": 100},
        "summary": {"type": "string"},
        "rationale": {"type": "string"},
        "outcome": {"type": "string"},
        "status": {"enum": sorted(VALID_STATUS)},
        "refs": {
            "type": "array",
            "items": {
                "type": "object",
                "required": ["rel", "id"],
                "properties": {
                    "rel": {"enum": sorted(VALID_RELS)},
                    "id": {"type": "string"},
                },
                "additionalProperties": True,
            },
        },
        "attention": {"type": "array"},
        "decisions": {"type": "array"},
        "files": {"type": "array", "items": {"type": "string"}},
        "tags": {"type": "array", "items": {"type": "string"}},
    },
    "additionalProperties": True,
}


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def new_id() -> str:
    # Sortable enough for local use: UTC timestamp plus random suffix.
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    return f"{stamp}-{secrets.token_hex(6)}"


def context_dir(start: Path | None = None) -> Path:
    cur = (start or Path.cwd()).resolve()
    for candidate in [cur, *cur.parents]:
        found = candidate / ROOT_MARKER
        if found.is_dir():
            return found
    return cur / ROOT_MARKER


def rel(path: Path, root: Path) -> str:
    return path.resolve().relative_to(root.resolve()).as_posix()


def read_jsonl(path: Path) -> list[dict[str, Any]]:
    if not path.exists():
        return []
    entries: list[dict[str, Any]] = []
    with path.open("r", encoding="utf-8") as handle:
        for line_no, line in enumerate(handle, 1):
            text = line.strip()
            if not text:
                continue
            try:
                value = json.loads(text)
            except json.JSONDecodeError as exc:
                raise ValueError(f"{path}:{line_no}: invalid JSON: {exc}") from exc
            if not isinstance(value, dict):
                raise ValueError(f"{path}:{line_no}: entry must be a JSON object")
            value["_source_file"] = path
            value["_source_line"] = line_no
            entries.append(value)
    return entries


def all_entries(ctx: Path) -> list[dict[str, Any]]:
    log_dir = ctx / "logbook"
    entries: list[dict[str, Any]] = []
    for path in sorted(log_dir.glob("*.jsonl")):
        entries.extend(read_jsonl(path))
    return entries


def public_entry(entry: dict[str, Any]) -> dict[str, Any]:
    return {k: v for k, v in entry.items() if not k.startswith("_")}


def entry_month(entry: dict[str, Any]) -> str:
    created = str(entry["created_at"])
    return created[:7]


def find_secrets(value: Any) -> list[str]:
    text = json.dumps(value, ensure_ascii=False, sort_keys=True)
    hits: list[str] = []
    for pattern in SECRET_PATTERNS:
        match = pattern.search(text)
        if match:
            hits.append(pattern.pattern)
    return hits


def validate_entry(entry: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    missing = sorted(REQUIRED_FIELDS - set(entry))
    if missing:
        errors.append(f"missing required fields: {', '.join(missing)}")
    if entry.get("v") != 1:
        errors.append("v must be 1")
    if "depth" in entry and entry["depth"] not in VALID_DEPTHS:
        errors.append("depth must be 0, 1, 2, or 3")
    if "type" in entry and entry["type"] not in VALID_TYPES:
        errors.append(f"type must be one of: {', '.join(sorted(VALID_TYPES))}")
    if "status" in entry and entry["status"] not in VALID_STATUS:
        errors.append(f"status must be one of: {', '.join(sorted(VALID_STATUS))}")
    if "actor" in entry and entry["actor"] not in VALID_ACTORS:
        errors.append(f"actor must be one of: {', '.join(sorted(VALID_ACTORS))}")
    if "preview" in entry and len(str(entry["preview"])) > 100:
        errors.append("preview must be <= 100 characters")
    refs = entry.get("refs", [])
    if refs is not None:
        if not isinstance(refs, list):
            errors.append("refs must be a list")
        else:
            for idx, ref in enumerate(refs):
                if not isinstance(ref, dict) or not ref.get("rel") or not ref.get("id"):
                    errors.append(f"refs[{idx}] must contain rel and id")
                elif ref["rel"] not in VALID_RELS:
                    errors.append(f"refs[{idx}].rel must be one of: {', '.join(sorted(VALID_RELS))}")
    return errors


def normalize_entry(entry: dict[str, Any]) -> dict[str, Any]:
    normalized = dict(entry)
    normalized.setdefault("v", 1)
    normalized.setdefault("id", new_id())
    normalized.setdefault("created_at", utc_now())
    normalized.setdefault("actor", "ai")
    normalized.setdefault("status", "active")
    if "title" not in normalized and "preview" in normalized:
        normalized["title"] = normalized["preview"]
    if "preview" not in normalized and "title" in normalized:
        normalized["preview"] = str(normalized["title"])[:100]
    if "preview" in normalized:
        normalized["preview"] = str(normalized["preview"])[:100]
    return normalized


def write_jsonl_line(path: Path, entry: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8", newline="\n") as handle:
        handle.write(json.dumps(entry, ensure_ascii=False, sort_keys=True))
        handle.write("\n")


def rebuild_toc(ctx: Path) -> None:
    root = ctx.parent
    rows = []
    for entry in all_entries(ctx):
        source_file = entry.get("_source_file")
        row = {
            "id": entry.get("id"),
            "created_at": entry.get("created_at"),
            "depth": entry.get("depth"),
            "scope": entry.get("scope"),
            "type": entry.get("type"),
            "status": entry.get("status"),
            "title": entry.get("title"),
            "preview": entry.get("preview"),
            "source_file": rel(source_file, ctx) if isinstance(source_file, Path) else None,
            "refs": entry.get("refs", []),
            "files": entry.get("files", []),
            "tags": entry.get("tags", []),
        }
        rows.append(row)
    rows.sort(key=lambda item: (str(item.get("created_at")), str(item.get("id"))))
    toc = ctx / "toc.jsonl"
    with toc.open("w", encoding="utf-8", newline="\n") as handle:
        for row in rows:
            handle.write(json.dumps(row, ensure_ascii=False, sort_keys=True))
            handle.write("\n")
    _ = root


def cmd_init(args: argparse.Namespace) -> int:
    ctx = context_dir()
    ctx.mkdir(parents=True, exist_ok=True)
    (ctx / "logbook").mkdir(exist_ok=True)
    (ctx / "tools").mkdir(exist_ok=True)
    (ctx / "schemas").mkdir(exist_ok=True)
    config = ctx / "config.json"
    if not config.exists():
        config.write_text(
            json.dumps(
                {
                    "v": 1,
                    "project_name": ctx.parent.name,
                    "privacy_mode": args.privacy,
                    "log_rotation": "monthly",
                    "default_load_depth": 0,
                    "obsidian": {
                        "enabled": False,
                        "vault_folder": "AI Context",
                        "project_folder": None,
                        "sync_depths": [0, 1],
                    },
                },
                indent=2,
                sort_keys=True,
            )
            + "\n",
            encoding="utf-8",
        )
    logbook = ctx / "LOGBOOK.md"
    if not logbook.exists():
        logbook.write_text(LOGBOOK_TEMPLATE, encoding="utf-8")
    schema = ctx / "schemas" / "entry.schema.json"
    if not schema.exists():
        schema.write_text(json.dumps(ENTRY_SCHEMA, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    for name in ["state.md", "attention.md", "toc.jsonl"]:
        path = ctx / name
        if not path.exists():
            path.write_text("", encoding="utf-8")
    print(f"initialized {ctx}")
    return 0


def cmd_append(args: argparse.Namespace) -> int:
    ctx = context_dir()
    raw = json.loads(Path(args.entry).read_text(encoding="utf-8"))
    if not isinstance(raw, dict):
        print("entry file must contain one JSON object", file=sys.stderr)
        return 2
    entry = normalize_entry(raw)
    errors = validate_entry(entry)
    secret_hits = find_secrets(entry)
    if secret_hits:
        errors.append("possible secret detected; redact entry before appending")
    existing = {item.get("id") for item in all_entries(ctx)}
    if entry["id"] in existing:
        errors.append(f"duplicate id: {entry['id']}")
    if errors:
        for error in errors:
            print(f"error: {error}", file=sys.stderr)
        return 2
    month = entry_month(entry)
    write_jsonl_line(ctx / "logbook" / f"{month}.jsonl", entry)
    rebuild_toc(ctx)
    print(entry["id"])
    return 0


def cmd_validate(args: argparse.Namespace) -> int:
    ctx = context_dir()
    errors: list[str] = []
    entries = all_entries(ctx)
    ids: dict[str, dict[str, Any]] = {}
    for entry in entries:
        location = f"{entry.get('_source_file')}:{entry.get('_source_line')}"
        for error in validate_entry(entry):
            errors.append(f"{location}: {error}")
        entry_id = entry.get("id")
        if entry_id in ids:
            errors.append(f"{location}: duplicate id {entry_id}")
        elif isinstance(entry_id, str):
            ids[entry_id] = entry
        if find_secrets(public_entry(entry)):
            errors.append(f"{location}: possible secret detected")
    for entry in entries:
        location = f"{entry.get('_source_file')}:{entry.get('_source_line')}"
        for ref in entry.get("refs", []) or []:
            ref_id = ref.get("id") if isinstance(ref, dict) else None
            if ref_id and ref_id not in ids:
                errors.append(f"{location}: missing ref target {ref_id}")
    if errors:
        for error in errors:
            print(f"error: {error}", file=sys.stderr)
        return 1
    print(f"ok: {len(entries)} entries")
    if args.rebuild_toc:
        rebuild_toc(ctx)
        print("rebuilt toc.jsonl")
    return 0


def cmd_rebuild_toc(args: argparse.Namespace) -> int:
    ctx = context_dir()
    rebuild_toc(ctx)
    print(f"rebuilt {ctx / 'toc.jsonl'}")
    return 0


def scope_matches(entry_scope: str, requested: str | None) -> bool:
    if not requested:
        return True
    left = entry_scope.replace("\\", "/").strip("/")
    right = requested.replace("\\", "/").strip("/")
    return left.startswith(right) or right.startswith(left)


def cmd_load(args: argparse.Namespace) -> int:
    ctx = context_dir()
    state = ctx / "state.md"
    attention = ctx / "attention.md"
    if state.exists() and state.read_text(encoding="utf-8").strip():
        print("# State\n")
        print(state.read_text(encoding="utf-8").strip())
        print()
    if attention.exists() and attention.read_text(encoding="utf-8").strip():
        print("# Attention\n")
        print(attention.read_text(encoding="utf-8").strip())
        print()
    entries = [public_entry(item) for item in all_entries(ctx)]
    depth = int(args.depth)
    print("# Matching Context\n")
    shown = 0
    previews = 0
    for entry in sorted(entries, key=lambda item: str(item.get("created_at"))):
        entry_depth = int(entry.get("depth", 99))
        scoped = scope_matches(str(entry.get("scope", "")), args.scope)
        if entry_depth == 0 or (scoped and entry_depth <= depth):
            print(f"- L{entry_depth} {entry.get('type')} {entry.get('scope')}: {entry.get('title')}")
            print(f"  id: {entry.get('id')}")
            print(f"  summary: {entry.get('summary')}")
            shown += 1
        elif scoped and entry_depth > depth:
            print(f"- preview L{entry_depth} {entry.get('scope')}: {entry.get('preview')} [{entry.get('id')}]")
            previews += 1
    print(f"\nshown: {shown}; deeper previews: {previews}")
    return 0


def cmd_refresh_state(args: argparse.Namespace) -> int:
    ctx = context_dir()
    entries = [
        public_entry(item)
        for item in all_entries(ctx)
        if item.get("depth") == 0 and item.get("status") == "active"
    ]
    entries.sort(key=lambda item: str(item.get("created_at")))
    lines = [
        "# AI Context State",
        "",
        "Generated from active L0 logbook entries.",
        "",
    ]
    by_scope: dict[str, list[dict[str, Any]]] = {}
    for entry in entries:
        by_scope.setdefault(str(entry.get("scope", "project")), []).append(entry)
    for scope in sorted(by_scope):
        lines.append(f"## {scope}")
        lines.append("")
        for entry in by_scope[scope]:
            lines.append(f"- {entry.get('title')} (`{entry.get('id')}`)")
            summary = str(entry.get("summary", "")).strip()
            if summary:
                lines.append(f"  {summary}")
        lines.append("")
    target = ctx / "state.md"
    target.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")
    print(f"refreshed {target}")
    return 0


def cmd_refresh_attention(args: argparse.Namespace) -> int:
    ctx = context_dir()
    rows: list[tuple[str, str, str, str, str]] = []
    for item in all_entries(ctx):
        entry = public_entry(item)
        if entry.get("status") not in {None, "active"}:
            continue
        if entry.get("type") == "attention":
            rows.append(
                (
                    str(entry.get("scope", "")),
                    "medium",
                    "",
                    str(entry.get("title", "")),
                    str(entry.get("id", "")),
                )
            )
        for attention in entry.get("attention", []) or []:
            if not isinstance(attention, dict):
                continue
            rows.append(
                (
                    str(attention.get("file") or entry.get("scope", "")),
                    str(attention.get("severity", "medium")),
                    str(attention.get("lines", "")),
                    str(attention.get("note", "")),
                    str(entry.get("id", "")),
                )
            )
    severity_order = {"high": 0, "medium": 1, "low": 2}
    rows.sort(key=lambda row: (severity_order.get(row[1], 1), row[0], row[4]))
    lines = [
        "# AI Context Attention",
        "",
        "Generated from active attention entries and attention blocks.",
        "",
    ]
    if not rows:
        lines.append("No active attention items.")
    else:
        for scope, severity, line_range, note, entry_id in rows:
            location = f"{scope}:{line_range}" if line_range else scope
            lines.append(f"- **{severity}** `{location}`: {note} (`{entry_id}`)")
    target = ctx / "attention.md"
    target.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")
    print(f"refreshed {target}")
    return 0


def cmd_doctor(args: argparse.Namespace) -> int:
    ctx = context_dir()
    print(f"context: {ctx}")
    config = ctx / "config.json"
    if config.exists():
        print(f"config: {config}")
        try:
            data = json.loads(config.read_text(encoding="utf-8"))
            print(f"privacy_mode: {data.get('privacy_mode', 'unknown')}")
        except json.JSONDecodeError:
            print("warning: config.json is not valid JSON")
    else:
        print("warning: missing config.json")
    return cmd_validate(argparse.Namespace(rebuild_toc=False))


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="aictx")
    sub = parser.add_subparsers(required=True)

    init = sub.add_parser("init")
    init.add_argument("--privacy", choices=["local-private", "team-shared"], default="local-private")
    init.set_defaults(func=cmd_init)

    append = sub.add_parser("append")
    append.add_argument("--entry", required=True)
    append.set_defaults(func=cmd_append)

    validate = sub.add_parser("validate")
    validate.add_argument("--rebuild-toc", action="store_true")
    validate.set_defaults(func=cmd_validate)

    rebuild = sub.add_parser("rebuild-toc")
    rebuild.set_defaults(func=cmd_rebuild_toc)

    load = sub.add_parser("load")
    load.add_argument("--scope")
    load.add_argument("--depth", choices=["0", "1", "2", "3"], default="0")
    load.set_defaults(func=cmd_load)

    refresh_state = sub.add_parser("refresh-state")
    refresh_state.set_defaults(func=cmd_refresh_state)

    refresh_attention = sub.add_parser("refresh-attention")
    refresh_attention.set_defaults(func=cmd_refresh_attention)

    doctor = sub.add_parser("doctor")
    doctor.set_defaults(func=cmd_doctor)
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        return int(args.func(args))
    except Exception as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
