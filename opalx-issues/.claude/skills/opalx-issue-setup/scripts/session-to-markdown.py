#!/usr/bin/env python3
"""Render a `physicscode export` session JSON as a human-readable
Markdown transcript: user/assistant turns, thinking, and tool calls
(input + output) roughly as they'd appear in the TUI -- no internal ids.

Usage: session-to-markdown.py <session.json> [output.md]
"""
import json
import sys
from datetime import datetime


def fmt_time(ms):
    if not ms:
        return ""
    return datetime.fromtimestamp(ms / 1000).strftime("%Y-%m-%d %H:%M:%S")


def fence(text, lang=""):
    text = (text or "").rstrip("\n")
    return f"```{lang}\n{text}\n```"


def render_bash(inp, out):
    lines = [f"**$ {inp.get('command', '')}**"]
    if inp.get("description"):
        lines.append(f"*{inp['description']}*")
    lines.append("")
    lines.append(fence(out, "text"))
    return "\n".join(lines)


def render_read(inp, out):
    loc = inp.get("filePath", "")
    extra = []
    if inp.get("offset"):
        extra.append(f"offset {inp['offset']}")
    if inp.get("limit"):
        extra.append(f"limit {inp['limit']}")
    suffix = f" ({', '.join(extra)})" if extra else ""
    return f"**Read** `{loc}`{suffix}\n\n{fence(out, 'text')}"


def render_glob(inp, out):
    return (f"**Glob** `{inp.get('pattern', '')}` in `{inp.get('path') or '.'}`"
            f"\n\n{fence(out, 'text')}")


def render_grep(inp, out):
    return (f"**Grep** `{inp.get('pattern', '')}` in `{inp.get('path') or '.'}`"
            f"\n\n{fence(out, 'text')}")


def render_edit(inp, out, part):
    loc = inp.get("filePath", "")
    diff = (part.get("state", {}).get("metadata", {}) or {}).get("diff")
    if diff:
        body = fence(diff, "diff")
    else:
        body = fence(
            f"- {inp.get('oldString', '')}\n+ {inp.get('newString', '')}", "diff"
        )
    return f"**Edit** `{loc}`\n\n{body}"


def render_write(inp, out):
    loc = inp.get("filePath", "")
    return f"**Write** `{loc}`\n\n{fence(inp.get('content', ''), '')}"


def render_skill(inp, out):
    return f"**Skill** `{inp.get('name', '')}`\n\n{fence(out, 'text')}"


def render_invalid(inp, out):
    return f"**Invalid tool call**\n\n{fence(out, 'text')}"


def render_generic(name, inp, out):
    return (f"**Tool: {name}**\n\nInput:\n{fence(json.dumps(inp, indent=2), 'json')}"
            f"\n\nOutput:\n{fence(out, 'text')}")


TOOL_RENDERERS = {
    "bash": render_bash,
    "read": render_read,
    "glob": render_glob,
    "grep": render_grep,
    "write": render_write,
    "skill": render_skill,
    "invalid": render_invalid,
}


def render_tool_part(part):
    name = part.get("tool", "unknown")
    state = part.get("state", {})
    inp = state.get("input", {})
    out = state.get("output", "")
    if name == "edit":
        return render_edit(inp, out, part)
    renderer = TOOL_RENDERERS.get(name)
    if renderer:
        return renderer(inp, out)
    return render_generic(name, inp, out)


def strip_wrapping_quotes(text):
    # run-agent.bash passes the prompt file as a shell-quoted argument;
    # the literal wrapping quote characters sometimes end up in the
    # stored message text. Strip one matching pair if present.
    if len(text) >= 2 and text[0] == '"' and text[-1] == '"':
        return text[1:-1]
    return text


def render_message(message):
    info = message["info"]
    role = info["role"]
    out = []

    if role == "user":
        out.append("## User")
    else:
        model = info.get("model", {})
        model_str = f"{model.get('providerID', '')}/{model.get('modelID', '')}".strip("/")
        header = f"## Assistant ({model_str})" if model_str else "## Assistant"
        out.append(header)

    created = fmt_time(info.get("time", {}).get("created"))
    if created:
        out.append(f"*{created}*")
    out.append("")

    for part in message["parts"]:
        ptype = part["type"]
        if ptype == "text":
            text = part.get("text", "")
            if role == "user":
                text = strip_wrapping_quotes(text)
            if text.strip():
                out.append(text.strip())
                out.append("")
        elif ptype == "reasoning":
            text = part.get("text", "").strip()
            if text:
                out.append("**Thinking:**")
                out.append("")
                out.append("> " + text.replace("\n", "\n> "))
                out.append("")
        elif ptype == "tool":
            out.append(render_tool_part(part))
            out.append("")
        # step-start, step-finish, patch: internal bookkeeping, skipped.

    return "\n".join(out)


def main():
    if len(sys.argv) < 2:
        print(__doc__, file=sys.stderr)
        sys.exit(1)

    in_path = sys.argv[1]
    out_path = sys.argv[2] if len(sys.argv) > 2 else in_path.rsplit(".", 1)[0] + ".md"

    with open(in_path) as f:
        data = json.load(f)

    info = data["info"]
    lines = [
        f"# {info.get('title', 'Session transcript')}",
        "",
        f"- Directory: `{info.get('directory', '')}`",
        f"- Model version: {info.get('version', '')}",
        f"- Created: {fmt_time(info.get('time', {}).get('created'))}",
        f"- Updated: {fmt_time(info.get('time', {}).get('updated'))}",
        "",
        "---",
        "",
    ]

    for message in data["messages"]:
        lines.append(render_message(message))
        lines.append("")
        lines.append("---")
        lines.append("")

    with open(out_path, "w") as f:
        f.write("\n".join(lines))

    print(f"Wrote {out_path}")


if __name__ == "__main__":
    main()
