#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from datetime import datetime, timezone
from pathlib import Path


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: amazon_append.py <text> [context_json]", file=sys.stderr)
        return 1

    text = sys.argv[1].strip()
    if not text:
        print("Empty amazon text", file=sys.stderr)
        return 1

    context = {}
    if len(sys.argv) >= 3 and sys.argv[2].strip():
        try:
            context = json.loads(sys.argv[2])
        except Exception:
            context = {"raw_context": sys.argv[2]}

    now = datetime.now(timezone.utc)
    entry = {
        "id": now.strftime("amazon-%Y%m%d-%H%M%S"),
        "created_at_utc": now.isoformat(),
        "text": text,
        "context": context,
    }

    base = Path("/Users/bici/.openclaw/workspace/shopping")
    base.mkdir(parents=True, exist_ok=True)
    path = base / "amazon_wishlist.jsonl"
    with path.open("a", encoding="utf-8") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")

    print(str(path))
    print(entry["id"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
