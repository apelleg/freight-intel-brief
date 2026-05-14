"""Extract plain-text briefing content from a Microsoft Teams adaptive card JSON.

Cards live in ``example-cards/YYYY-MM-DD-card.json``. Each card has nested
``Container``/``TextBlock`` items. We walk the tree and emit a flat text view
that the judge model can score, plus a list of headline lines for novelty
comparison against prior days.
"""

from __future__ import annotations

import json
import os
import re
from dataclasses import dataclass
from datetime import date, timedelta
from pathlib import Path

CARD_DIR_DEFAULT = Path(__file__).resolve().parent.parent / "example-cards"


@dataclass
class Briefing:
    card_date: str
    title: str
    body_text: str
    headlines: list[str]
    source_urls: list[str]


def _walk_textblocks(node, out: list[str]) -> None:
    if isinstance(node, dict):
        if node.get("type") == "TextBlock" and isinstance(node.get("text"), str):
            out.append(node["text"])
        for v in node.values():
            _walk_textblocks(v, out)
    elif isinstance(node, list):
        for x in node:
            _walk_textblocks(x, out)


def _walk_actions(node, out: list[str]) -> None:
    """Pull URLs from Action.OpenUrl entries (cards link to source articles)."""
    if isinstance(node, dict):
        if node.get("type") == "Action.OpenUrl" and isinstance(node.get("url"), str):
            out.append(node["url"])
        for v in node.values():
            _walk_actions(v, out)
    elif isinstance(node, list):
        for x in node:
            _walk_actions(x, out)


_URL_RE = re.compile(r"https?://[^\s\)\]\>]+")


def load_card(path: Path) -> Briefing:
    card = json.loads(path.read_text())
    texts: list[str] = []
    urls: list[str] = []
    _walk_textblocks(card, texts)
    _walk_actions(card, urls)
    # Pull any URLs embedded inline in TextBlocks too.
    for t in texts:
        urls.extend(_URL_RE.findall(t))

    title = texts[0] if texts else ""
    headlines = [t for t in texts if t.startswith("- ")]
    body_text = "\n".join(texts)

    m = re.search(r"(\d{4}-\d{2}-\d{2})", path.name)
    card_date = m.group(1) if m else ""

    return Briefing(
        card_date=card_date,
        title=title,
        body_text=body_text,
        headlines=headlines,
        source_urls=sorted(set(urls)),
    )


def prior_headlines(card_date: str, days: int = 7, card_dir: Path | None = None) -> list[str]:
    """Return headlines from the N days *before* ``card_date`` (exclusive)."""
    card_dir = card_dir or CARD_DIR_DEFAULT
    y, m, d = (int(x) for x in card_date.split("-"))
    target = date(y, m, d)
    out: list[str] = []
    for i in range(1, days + 1):
        prev = target - timedelta(days=i)
        p = card_dir / f"{prev.isoformat()}-card.json"
        if p.exists():
            try:
                out.extend(load_card(p).headlines)
            except Exception:
                pass
    return out


def find_card(card_date: str, card_dir: Path | None = None) -> Path:
    card_dir = card_dir or CARD_DIR_DEFAULT
    p = card_dir / f"{card_date}-card.json"
    if not p.exists():
        raise FileNotFoundError(f"No card for {card_date} at {p}")
    return p


if __name__ == "__main__":  # quick manual check
    import sys

    path = Path(sys.argv[1]) if len(sys.argv) > 1 else find_card("2026-03-18")
    b = load_card(path)
    print(f"date={b.card_date} title={b.title!r}")
    print(f"headlines={len(b.headlines)} urls={len(b.source_urls)}")
    print(b.body_text[:400])
