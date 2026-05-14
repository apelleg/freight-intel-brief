# Briefing Quality Rubric (v1)

Five axes, each scored **1–5 integer**. Composite = weighted mean (weights below).

| Axis            | Weight | 1 (bad)                                  | 5 (excellent)                                                    |
| --------------- | -----: | ---------------------------------------- | ---------------------------------------------------------------- |
| factuality      |   0.30 | Unverifiable claims, no sources cited    | Every concrete claim (number/name/date) maps to a cited source   |
| novelty         |   0.20 | Stories already covered in last 7 days   | All stories new vs. prior 7-day window; no rehash                |
| source_diversity|   0.15 | One or two domains dominate              | 5+ distinct domains; mix of primary (filings, blogs) + secondary |
| signal_density  |   0.20 | Vague hype words, no numbers             | Concrete numbers, named entities, specific outcomes per item     |
| coherence       |   0.15 | Bullet soup, no narrative                | Items grouped by theme with a clear takeaway per topic           |

**Composite** = round( 0.30·F + 0.20·N + 0.15·D + 0.20·S + 0.15·C , 2 )

## Pass thresholds

- **publish gate**: composite ≥ 3.0 AND no axis < 2
- **regression gate** (golden set): per-card composite drop ≤ 0.5 vs. baseline
- **drift alert**: rolling-7d median composite > 1.5 stddev below trailing-30d median for 2 consecutive days

## Scoring rules

- Score the briefing **as published** — do not credit information not present in the card.
- If sources are absent, factuality caps at 2.
- Stories listed but with empty body cap signal_density at 2.
- Novelty is scored against the **prior 7 calendar days** of cards in `example-cards/` when available; otherwise score on intrinsic recency cues in the text.
