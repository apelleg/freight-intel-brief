"""Judge backends.

The project shells out to AI CLIs (claude / codex / gemini) everywhere else,
so we match that convention. A ``stub`` backend is provided for tests and CI
so the harness exercises end-to-end without burning API credits.

Each backend returns ``(scores_dict, raw_response_text, model_id)``.
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

PROMPT_VERSION = "v1"
JUDGE_PROMPT_PATH = Path(__file__).resolve().parent / "judge_prompt.md"


@dataclass
class JudgeResult:
    scores: dict
    raw: str
    model: str
    prompt_version: str


def _load_judge_prompt() -> str:
    return JUDGE_PROMPT_PATH.read_text()


def _compose_input(briefing_text: str, prior_headlines: list[str]) -> str:
    prior = "\n".join(prior_headlines) if prior_headlines else "(none available)"
    return (
        f"{_load_judge_prompt()}\n\n"
        f"---\nBRIEFING:\n{briefing_text}\n\n"
        f"---\nPRIOR_HEADLINES (last 7 days):\n{prior}\n"
    )


_JSON_BLOCK = re.compile(r"```json\s*(\{.*?\})\s*```", re.DOTALL)
_BARE_JSON = re.compile(r"(\{[^{}]*\"factuality\"[^{}]*\})", re.DOTALL)
_REQUIRED = ("factuality", "novelty", "source_diversity", "signal_density", "coherence")


def parse_judge_response(text: str) -> dict:
    m = _JSON_BLOCK.search(text) or _BARE_JSON.search(text)
    if not m:
        raise ValueError(f"No JSON object found in judge response:\n{text[:500]}")
    obj = json.loads(m.group(1))
    for k in _REQUIRED:
        if k not in obj:
            raise ValueError(f"Judge response missing key: {k}")
        v = obj[k]
        if not (isinstance(v, int) and 1 <= v <= 5):
            raise ValueError(f"Axis {k} out of range or non-int: {v!r}")
    obj.setdefault("notes", "")
    return obj


# --- Backends -----------------------------------------------------------------


LOG_DIR = Path(__file__).resolve().parent.parent / "logs"


def _log_call(cmd: list[str], stdin: str, stdout: str, stderr: str, rc: int, elapsed: float) -> None:
    """Append a per-call trace to logs/eval-judge-YYYY-MM-DD.log."""
    try:
        LOG_DIR.mkdir(exist_ok=True)
        import datetime as _dt
        day = _dt.date.today().isoformat()
        log_path = LOG_DIR / f"eval-judge-{day}.log"
        with log_path.open("a") as f:
            f.write(f"--- {_dt.datetime.now().isoformat(timespec='seconds')} "
                    f"rc={rc} elapsed={elapsed:.1f}s ---\n")
            f.write(f"CMD: {' '.join(cmd)}\n")
            if stdin:
                f.write(f"STDIN[:200]: {stdin[:200]}\n")
            f.write(f"STDOUT[:2000]:\n{stdout[:2000]}\n")
            if stderr:
                f.write(f"STDERR[:800]:\n{stderr[:800]}\n")
            f.write("\n")
    except Exception:
        pass  # logging must never break a run


def _run_cli(cmd: list[str], stdin: str, timeout: int = 240) -> str:
    # Match briefing.sh: clear CLAUDECODE so the judge CLI does not refuse to
    # launch when invoked from inside an existing Claude Code session.
    env = {k: v for k, v in os.environ.items() if k not in ("CLAUDECODE", "CLAUDE_CODE")}
    import time as _time
    t0 = _time.monotonic()
    try:
        proc = subprocess.run(
            cmd, input=stdin, capture_output=True, text=True,
            timeout=timeout, env=env,
        )
    except subprocess.TimeoutExpired as e:
        _log_call(cmd, stdin, e.stdout or "", e.stderr or "", -1, _time.monotonic() - t0)
        raise RuntimeError(f"Judge CLI timed out after {timeout}s") from e
    elapsed = _time.monotonic() - t0
    _log_call(cmd, stdin, proc.stdout, proc.stderr, proc.returncode, elapsed)
    if proc.returncode != 0:
        raise RuntimeError(
            f"Judge CLI failed (rc={proc.returncode}): {proc.stderr.strip()[:400]}"
        )
    return proc.stdout


def _backend_stub(prompt: str) -> tuple[dict, str, str]:
    """Deterministic stub: scores reflect simple heuristics on the prompt."""
    has_url = "http" in prompt.lower()
    has_numbers = bool(re.search(r"\$\d|\d+%|\d{2,}", prompt))
    bullet_count = prompt.count("\n- ")
    factuality = 4 if has_url else 2
    novelty = 4
    diversity = 4 if prompt.count("http") >= 5 else 3
    density = 5 if has_numbers and bullet_count >= 8 else 3
    coherence = 4 if "**" in prompt else 3
    scores = {
        "factuality": factuality,
        "novelty": novelty,
        "source_diversity": diversity,
        "signal_density": density,
        "coherence": coherence,
        "notes": "stub judge: heuristics over URL/number/bullet/bold presence",
    }
    raw = "```json\n" + json.dumps(scores, indent=2) + "\n```"
    return scores, raw, "stub-v1"


def _backend_claude_cli(prompt: str) -> tuple[dict, str, str]:
    claude = shutil.which("claude") or os.path.expanduser("~/.local/bin/claude")
    if not (claude and os.path.exists(claude)):
        raise RuntimeError("claude CLI not found; install or use --judge stub")
    model = os.environ.get("EVAL_JUDGE_MODEL", "claude-haiku-4-5-20251001")
    # Match briefing.sh invocation: prompt as positional arg, not stdin.
    raw = _run_cli(
        [claude, "-p", "--model", model, "--dangerously-skip-permissions", prompt],
        "",
    )
    return parse_judge_response(raw), raw, model


def _backend_codex_cli(prompt: str) -> tuple[dict, str, str]:
    codex = shutil.which("codex")
    if not codex:
        raise RuntimeError("codex CLI not found")
    raw = _run_cli([codex, "exec", "--full-auto", prompt], "")
    return parse_judge_response(raw), raw, "codex-cli"


def _backend_gemini_cli(prompt: str) -> tuple[dict, str, str]:
    gemini = shutil.which("gemini")
    if not gemini:
        raise RuntimeError("gemini CLI not found")
    raw = _run_cli([gemini, "-p", prompt], "")
    return parse_judge_response(raw), raw, "gemini-cli"


BACKENDS = {
    "stub": _backend_stub,
    "claude": _backend_claude_cli,
    "codex": _backend_codex_cli,
    "gemini": _backend_gemini_cli,
}


def judge(briefing_text: str, prior_headlines: list[str], backend: str = "stub") -> JudgeResult:
    if backend not in BACKENDS:
        raise ValueError(f"Unknown backend {backend!r}. Choose from {list(BACKENDS)}")
    prompt = _compose_input(briefing_text, prior_headlines)
    scores, raw, model = BACKENDS[backend](prompt)
    return JudgeResult(scores=scores, raw=raw, model=model, prompt_version=PROMPT_VERSION)
