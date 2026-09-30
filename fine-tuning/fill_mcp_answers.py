#!/usr/bin/env python3
"""Fill the "mcp_science_output" fields in opalx_examples.json.

For every example, builds a prompt from "instruction" and "input", sends it to
Claude Opus 5.5 through the Claude Code CLI and stores the answer in the JSON.
The model is told to answer from the physicscode-science MCP server only; all
built-in tools are disabled, so it can read neither the local OPALX checkout
nor the reference answers in the JSON.

Defer pairs ("defer": true) are not sent to the model: their "output" is copied
into the field as it is.

The CLI is started in this folder because physicscode-science is configured
for it (local scope, see `claude mcp list`).

Usage:
    python3 fill_mcp_answers.py                # fill all empty fields
    python3 fill_mcp_answers.py --only 0 3     # only these example indices
    python3 fill_mcp_answers.py --force        # overwrite existing answers
    python3 fill_mcp_answers.py --dry-run      # print the prompts, call nothing

By default ANTHROPIC_API_KEY is removed from the environment of the call, so the
CLI uses the claude.ai login. Pass --use-api-key to bill the API key instead.
"""

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
DEFAULT_FILE = HERE / "opalx_examples.json"

MODEL = "claude-opus-5-5"
MCP_SERVER = "physicscode-science"
FIELD = "mcp_science_output"

PREAMBLE = f"""\
Answer the question below about the OPALX codebase (OPALX-project/OPALX).

You must use the science MCP (the `{MCP_SERVER}` MCP server) to look up the \
relevant code and documentation before you answer. Base the answer on what it \
returns, not on memory, and cite the files and lines you relied on. If the \
science MCP is not available or returns nothing useful, say so explicitly \
instead of guessing."""


def build_prompt(example):
    prompt = f"{PREAMBLE}\n\n### Instruction:\n{example['instruction']}\n"
    if example.get("input"):
        prompt += f"\n### Input:\n{example['input']}\n"
    return prompt


def ask_claude(prompt, timeout, use_api_key=False):
    cmd = [
        "claude",
        "--print",
        "--model", MODEL,
        "--tools", "",  # no built-in tools: MCP is the only source
        "--allowedTools", f"mcp__{MCP_SERVER}",
        "--output-format", "json",
        "--no-session-persistence",
    ]
    env = dict(os.environ)
    if not use_api_key:
        # An exported ANTHROPIC_API_KEY takes precedence over the claude.ai login.
        env.pop("ANTHROPIC_API_KEY", None)
    proc = subprocess.run(
        cmd, input=prompt, capture_output=True, text=True, cwd=HERE, timeout=timeout, env=env)
    # On failure the actual reason is in the JSON on stdout; stderr only has warnings.
    try:
        reply = json.loads(proc.stdout)
    except json.JSONDecodeError:
        reply = None
    if reply is None or proc.returncode != 0 or reply.get("is_error"):
        reason = reply.get("result") if reply else proc.stdout.strip()
        raise RuntimeError(
            f"claude exited with {proc.returncode}: {reason or proc.stderr.strip()}")
    return reply["result"].strip()


def save(path, doc):
    with open(path, "w") as f:
        json.dump(doc, f, indent=2, ensure_ascii=False)
        f.write("\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("file", nargs="?", type=Path, default=DEFAULT_FILE)
    parser.add_argument("--only", nargs="+", type=int, metavar="INDEX",
                        help="example indices to process (default: all)")
    parser.add_argument("--force", action="store_true",
                        help="overwrite fields that are already filled")
    parser.add_argument("--dry-run", action="store_true",
                        help="print the prompts without calling claude")
    parser.add_argument("--timeout", type=int, default=900,
                        help="seconds to wait per example (default: 900)")
    parser.add_argument("--use-api-key", action="store_true",
                        help="keep ANTHROPIC_API_KEY for the call instead of the claude.ai login")
    args = parser.parse_args()

    doc = json.loads(args.file.read_text())
    examples = doc["examples"]
    indices = args.only if args.only is not None else range(len(examples))

    failed = 0
    for i in indices:
        example = examples[i]
        label = f"[{i}] {example['category']}"
        if example.get(FIELD) and not args.force:
            print(f"{label}: already filled, skipping")
            continue

        if example.get("defer"):
            if args.dry_run:
                print(f"--- {label} ---\n(defer pair: copies \"output\", no call)\n")
                continue
            example[FIELD] = example["output"]
            save(args.file, doc)
            print(f"{label}: defer pair, copied \"output\"")
            continue

        prompt = build_prompt(example)
        if args.dry_run:
            print(f"--- {label} ---\n{prompt}")
            continue

        print(f"{label}: asking {MODEL} ...", flush=True)
        try:
            example[FIELD] = ask_claude(prompt, args.timeout, args.use_api_key)
        except (RuntimeError, subprocess.TimeoutExpired) as err:
            failed += 1
            print(f"{label}: FAILED: {err}", file=sys.stderr)
            continue

        # Save after every answer so a later failure does not lose earlier ones.
        save(args.file, doc)
        print(f"{label}: done ({len(example[FIELD])} characters)")

    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
