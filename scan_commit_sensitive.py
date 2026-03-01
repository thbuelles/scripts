#!/usr/bin/env python3
"""
Scan one or more git commits for potentially sensitive data:
- API keys/tokens/private keys
- Email addresses
- Phone numbers

Usage:
  python3 scan_commit_sensitive.py --repo /path/to/repo --commit HEAD
  python3 scan_commit_sensitive.py --repo /path/to/repo --range origin/main..HEAD

Exit codes:
  0 = no findings
  1 = findings detected
  2 = usage/runtime error
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import List


@dataclass
class Rule:
    name: str
    regex: re.Pattern
    severity: str = "warning"


RULES: List[Rule] = [
    Rule("GitHub classic PAT", re.compile(r"\bghp_[A-Za-z0-9]{36}\b"), "high"),
    Rule("GitHub fine-grained PAT", re.compile(r"\bgithub_pat_[A-Za-z0-9_]{20,}\b"), "high"),
    Rule("AWS access key", re.compile(r"\bAKIA[0-9A-Z]{16}\b"), "high"),
    Rule("OpenAI-style key", re.compile(r"\bsk-[A-Za-z0-9]{20,}\b"), "high"),
    Rule("Google API key", re.compile(r"\bAIza[0-9A-Za-z\-_]{35}\b"), "high"),
    Rule("Slack token", re.compile(r"\bxox[baprs]-[A-Za-z0-9-]{10,}\b"), "high"),
    Rule("Private key block", re.compile(r"-----BEGIN (RSA|OPENSSH|EC|DSA|PGP) PRIVATE KEY-----"), "critical"),
    Rule("Generic assignment: token=", re.compile(r"\b(token|secret|password|passwd|api[_-]?key)\s*[:=]\s*[^\s'\"]+", re.IGNORECASE), "medium"),
    Rule("Email address", re.compile(r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b"), "medium"),
    Rule("Phone number", re.compile(r"\b(?:\+?\d{1,3}[\s.-]?)?(?:\(?\d{2,4}\)?[\s.-]?)\d{3}[\s.-]?\d{4}\b"), "low"),
]


@dataclass
class Finding:
    commit: str
    file_path: str
    line_no: int
    sign: str
    rule: Rule
    snippet: str


DIFF_HEADER_RE = re.compile(r"^@@\s+-(\d+)(?:,\d+)?\s+\+(\d+)(?:,\d+)?\s+@@")


def run_git(repo: Path, args: List[str]) -> str:
    out = subprocess.check_output(["git", "-C", str(repo), *args], stderr=subprocess.STDOUT)
    return out.decode("utf-8", errors="replace")


def commits_from_args(repo: Path, commit: str | None, commit_range: str | None) -> List[str]:
    if bool(commit) == bool(commit_range):
        raise ValueError("Provide exactly one of --commit or --range")
    if commit:
        return [run_git(repo, ["rev-parse", "--verify", commit]).strip()]
    out = run_git(repo, ["rev-list", commit_range])
    commits = [c.strip() for c in out.splitlines() if c.strip()]
    return list(reversed(commits))


def scan_patch_text(commit: str, patch: str) -> List[Finding]:
    findings: List[Finding] = []
    current_file = "<unknown>"
    old_ln = 0
    new_ln = 0

    for raw in patch.splitlines():
        line = raw.rstrip("\n")

        if line.startswith("diff --git "):
            current_file = "<unknown>"
            old_ln = 0
            new_ln = 0
            continue

        if line.startswith("+++ b/"):
            current_file = line[6:]
            continue

        m = DIFF_HEADER_RE.match(line)
        if m:
            old_ln = int(m.group(1))
            new_ln = int(m.group(2))
            continue

        if line.startswith("index ") or line.startswith("--- "):
            continue

        if line.startswith("+") and not line.startswith("+++"):
            payload = line[1:]
            for rule in RULES:
                if rule.regex.search(payload):
                    findings.append(Finding(commit, current_file, new_ln, "+", rule, payload[:300]))
            new_ln += 1
            continue

        if line.startswith("-") and not line.startswith("---"):
            payload = line[1:]
            for rule in RULES:
                if rule.regex.search(payload):
                    findings.append(Finding(commit, current_file, old_ln, "-", rule, payload[:300]))
            old_ln += 1
            continue

        if line.startswith(" "):
            old_ln += 1
            new_ln += 1

    return findings


def main() -> int:
    ap = argparse.ArgumentParser(description="Scan git commits for secrets, emails, and phone numbers")
    ap.add_argument("--repo", default=".", help="Path to git repo (default: current dir)")
    ap.add_argument("--commit", help="Single commit-ish to scan (e.g., HEAD)")
    ap.add_argument("--range", dest="commit_range", help="Commit range to scan (e.g., origin/main..HEAD)")
    ap.add_argument("--only-added", action="store_true", help="Report findings only on added lines (+)")
    args = ap.parse_args()

    repo = Path(args.repo).resolve()
    if not (repo / ".git").exists():
        print(f"ERROR: not a git repo: {repo}", file=sys.stderr)
        return 2

    try:
        commits = commits_from_args(repo, args.commit, args.commit_range)
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 2

    if not commits:
        print("No commits found for provided input.")
        return 0

    all_findings: List[Finding] = []
    for c in commits:
        patch = run_git(repo, ["show", "--patch", "--find-renames", "--format=", c])
        all_findings.extend(scan_patch_text(c[:12], patch))

    if args.only_added:
        all_findings = [f for f in all_findings if f.sign == "+"]

    if not all_findings:
        print(f"OK: no matches in {len(commits)} commit(s)")
        return 0

    print(f"FOUND: {len(all_findings)} potential sensitive match(es) in {len(commits)} commit(s)")
    print("commit\tfile:line\tsign\tseverity\trule\tsnippet")
    for f in all_findings:
        snippet = re.sub(r"\s+", " ", f.snippet).strip()
        print(f"{f.commit}\t{f.file_path}:{f.line_no}\t{f.sign}\t{f.rule.severity}\t{f.rule.name}\t{snippet}")

    return 1


if __name__ == "__main__":
    sys.exit(main())
