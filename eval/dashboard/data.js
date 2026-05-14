window.EVAL_DATA = {
  "generated_at": "2026-05-14T04:39:37+00:00",
  "weights": {
    "factuality": 0.3,
    "novelty": 0.2,
    "source_diversity": 0.15,
    "signal_density": 0.2,
    "coherence": 0.15
  },
  "axes": [
    "factuality",
    "novelty",
    "source_diversity",
    "signal_density",
    "coherence"
  ],
  "summary": {
    "card_count": 18,
    "composite_min": 2.9,
    "composite_max": 4.2,
    "composite_median": 3.67,
    "composite_mean": 3.59,
    "axis_medians": {
      "factuality": 3.5,
      "novelty": 3.0,
      "source_diversity": 4.0,
      "signal_density": 4.0,
      "coherence": 4.0
    },
    "judges": [
      "claude-haiku-4-5-20251001"
    ],
    "prompt_versions": [
      "v1"
    ],
    "golden_count": 18
  },
  "drift": {
    "status": "ok",
    "short_median": 4.05,
    "long_median": 3.67,
    "long_mad": 0.425,
    "z": 0.88
  },
  "cards": [
    {
      "card_date": "2026-03-01",
      "ran_at": "2026-05-14T02:48:15+00:00",
      "judge_model": "claude-haiku-4-5-20251001",
      "prompt_version": "v1",
      "composite": 3.7,
      "axes": {
        "factuality": 3,
        "novelty": 3,
        "source_diversity": 4,
        "signal_density": 5,
        "coherence": 4
      },
      "notes": "Sources listed but not inline-mapped; claims like '500+ zero-days detected' and '70% of Claude Code tests' lack verification paths. Feb 5 Claude Opus story (24 days old) appears in a daily briefing dated March 1, suggesting recycled content if featured prior week.",
      "baseline_composite": 3.7,
      "baseline_judge": "claude-haiku-4-5-20251001",
      "delta_vs_baseline": 0.0
    },
    {
      "card_date": "2026-03-02",
      "ran_at": "2026-05-14T02:48:26+00:00",
      "judge_model": "claude-haiku-4-5-20251001",
      "prompt_version": "v1",
      "composite": 3.8,
      "axes": {
        "factuality": 4,
        "novelty": 3,
        "source_diversity": 4,
        "signal_density": 4,
        "coherence": 4
      },
      "notes": "Most briefing items are follow-ups from prior week: Trump ban \u2192 Anthropic legal challenge, MWC preview \u2192 Day 0 coverage, DeepSeek V4 launch (already expected), Apple Siri iOS rollout (already in motion). New elements present (#QuitGPT 2.5M supporters, Claude App Store #1, London protest with Extinction Rebellion, Deutsche Telekom 6G Hub, Nvidia optical partnerships) but don't offset heavy rehash of Anthropic ban, Pentagon deal, MWC, and GPT-5 launch cycle.",
      "baseline_composite": 3.8,
      "baseline_judge": "claude-haiku-4-5-20251001",
      "delta_vs_baseline": 0.0
    },
    {
      "card_date": "2026-03-03",
      "ran_at": "2026-05-14T02:48:03+00:00",
      "judge_model": "claude-haiku-4-5-20251001",
      "prompt_version": "v1",
      "composite": 3.25,
      "axes": {
        "factuality": 4,
        "novelty": 2,
        "source_diversity": 3,
        "signal_density": 3,
        "coherence": 4
      },
      "notes": "Novelty is lowest. #QuitGPT, OpenAI Pentagon deal, and DeepSeek V4 launch were all previewed in prior week; briefing largely reports the expected next chapters rather than new developments. Qwen 3.5 was also pre-announced. Strong topical organization and most claims have sources, but limited signal density on OpenAI safeguards and Samsung Galaxy keynote (vague pending announcement).",
      "baseline_composite": 3.25,
      "baseline_judge": "claude-haiku-4-5-20251001",
      "delta_vs_baseline": 0.0
    },
    {
      "card_date": "2026-03-04",
      "ran_at": "2026-05-14T02:48:17+00:00",
      "judge_model": "claude-haiku-4-5-20251001",
      "prompt_version": "v1",
      "composite": 3.2,
      "axes": {
        "factuality": 2,
        "novelty": 3,
        "source_diversity": 4,
        "signal_density": 4,
        "coherence": 4
      },
      "notes": "No sources cited anywhere (hard cap: factuality \u2264 2). Pentagon/Anthropic designation, DeepSeek V4, Samsung Gemini recycled from prior 7 days; novel additions (Meta\u2013News Corp deal, NY/Florida AI legislation) partially offset repetition.",
      "baseline_composite": 3.2,
      "baseline_judge": "claude-haiku-4-5-20251001",
      "delta_vs_baseline": 0.0
    },
    {
      "card_date": "2026-03-05",
      "ran_at": "2026-05-14T02:48:41+00:00",
      "judge_model": "claude-haiku-4-5-20251001",
      "prompt_version": "v1",
      "composite": 3.2,
      "axes": {
        "factuality": 2,
        "novelty": 3,
        "source_diversity": 4,
        "signal_density": 4,
        "coherence": 4
      },
      "notes": "No sources cited anywhere\u2014hard cap applied. Claims align with prior headlines (Anthropic ban, DeepSeek delays, Qwen 3.5) but lack URLs or attribution for benchmarks (83% GDPval, 75% OSWorld-V), policy targets ($1.4T by 2030), or dates. GPT-5.4 launch and Anthropic lawsuit filing are new, but Qwen 3.5 and DeepSeek V4 delays are repeats from Feb 27\u2013Mar 4 coverage.",
      "baseline_composite": 3.2,
      "baseline_judge": "claude-haiku-4-5-20251001",
      "delta_vs_baseline": 0.0
    },
    {
      "card_date": "2026-03-06",
      "ran_at": "2026-05-14T02:49:09+00:00",
      "judge_model": "claude-haiku-4-5-20251001",
      "prompt_version": "v1",
      "composite": 3.7,
      "axes": {
        "factuality": 4,
        "novelty": 4,
        "source_diversity": 3,
        "signal_density": 4,
        "coherence": 3
      },
      "notes": "Sources concentrated in tech and government; 'Block employees publicly stated' is sole independent voice. Quick Hits section (5 disparate items) fragments narrative and dilutes focus from core stories.",
      "baseline_composite": 3.7,
      "baseline_judge": "claude-haiku-4-5-20251001",
      "delta_vs_baseline": 0.0
    },
    {
      "card_date": "2026-03-07",
      "ran_at": "2026-05-14T02:48:49+00:00",
      "judge_model": "claude-haiku-4-5-20251001",
      "prompt_version": "v1",
      "composite": 2.9,
      "axes": {
        "factuality": 3,
        "novelty": 2,
        "source_diversity": 1,
        "signal_density": 5,
        "coherence": 3
      },
      "notes": "Only TechCrunch explicitly cited; top stories (Claude #1, #QuitGPT surge, Oracle/Block layoffs, Samsung Gemini) already in prior-week headlines. New items (Google `gws` CLI, Anthropic lawsuit filings, Pro-Human declaration mainstream coverage) lack visible attribution.",
      "baseline_composite": 2.9,
      "baseline_judge": "claude-haiku-4-5-20251001",
      "delta_vs_baseline": 0.0
    },
    {
      "card_date": "2026-03-08",
      "ran_at": "2026-05-14T02:49:56+00:00",
      "judge_model": "claude-haiku-4-5-20251001",
      "prompt_version": "v1",
      "composite": 3.0,
      "axes": {
        "factuality": 3,
        "novelty": 3,
        "source_diversity": 3,
        "signal_density": 3,
        "coherence": 3
      },
      "notes": "DeepSeek V4 (longest story) offers no concrete outcome \u2014 specs are explicitly unverified, launch is absent, echoing prior week's delay narrative. Signal is strong in featured stories (MacBook Neo specs, Pentagon analysis) but dragged down by speculative Quick Hits and What to Watch.",
      "baseline_composite": 3.0,
      "baseline_judge": "claude-haiku-4-5-20251001",
      "delta_vs_baseline": 0.0
    },
    {
      "card_date": "2026-03-09",
      "ran_at": "2026-05-14T02:49:15+00:00",
      "judge_model": "claude-haiku-4-5-20251001",
      "prompt_version": "v1",
      "composite": 3.85,
      "axes": {
        "factuality": 4,
        "novelty": 4,
        "source_diversity": 3,
        "signal_density": 4,
        "coherence": 4
      },
      "notes": "Six sources listed for twelve stories with no in-text attribution \u2014 source mapping opaque. Signal-dense on numbers/names (11K vulns, 97M MCP downloads, bill votes) but 'MiniMax praised for rivaling' and 'seven contenders' lack specifics. Excellent topical grouping but no coherent narrative arc tying themes together.",
      "baseline_composite": 3.85,
      "baseline_judge": "claude-haiku-4-5-20251001",
      "delta_vs_baseline": 0.0
    },
    {
      "card_date": "2026-03-10",
      "ran_at": "2026-05-14T02:49:43+00:00",
      "judge_model": "claude-haiku-4-5-20251001",
      "prompt_version": "v1",
      "composite": 3.55,
      "axes": {
        "factuality": 3,
        "novelty": 4,
        "source_diversity": 3,
        "signal_density": 4,
        "coherence": 4
      },
      "notes": "Multiple concrete claims lack attribution: GPT-5.2 benchmarks, Cursor's 1M-user milestone, Coral Dev Board, and all three regulatory items presented without sources. 7 sources cited for 23 stories\u2014good primary/secondary mix where cited, but ~60% of claims orphaned.",
      "baseline_composite": 3.55,
      "baseline_judge": "claude-haiku-4-5-20251001",
      "delta_vs_baseline": 0.0
    },
    {
      "card_date": "2026-03-11",
      "ran_at": "2026-05-14T02:50:03+00:00",
      "judge_model": "claude-haiku-4-5-20251001",
      "prompt_version": "v1",
      "composite": 3.25,
      "axes": {
        "factuality": 2,
        "novelty": 4,
        "source_diversity": 3,
        "signal_density": 4,
        "coherence": 4
      },
      "notes": "Sourcing gap: 75% of stories (outage, DryRun, NVIDIA, OpenRouter, World Labs, Replit, FTC, Washington HB 2225) lack any attribution. Seven sources provided but cover only ~5 stories; inline mapping missing. Novelty strong (78% new vs. prior 7 days) but some thematic repeats (Pentagon, DeepSeek V4, regulation).",
      "baseline_composite": 3.25,
      "baseline_judge": "claude-haiku-4-5-20251001",
      "delta_vs_baseline": 0.0
    },
    {
      "card_date": "2026-03-12",
      "ran_at": "2026-05-14T02:50:32+00:00",
      "judge_model": "claude-haiku-4-5-20251001",
      "prompt_version": "v1",
      "composite": 4.2,
      "axes": {
        "factuality": 4,
        "novelty": 4,
        "source_diversity": 4,
        "signal_density": 5,
        "coherence": 4
      },
      "notes": "Novelty includes carryover from Mar 10\u201311: Copilot Cowork, Claude outage. Coherence organized by topic but lacks thematic synthesis connecting related stories like agentic AI launches (Hermes, NemoClaw, Alibaba Page Agent).",
      "baseline_composite": 4.2,
      "baseline_judge": "claude-haiku-4-5-20251001",
      "delta_vs_baseline": 0.0
    },
    {
      "card_date": "2026-03-13",
      "ran_at": "2026-05-14T02:50:14+00:00",
      "judge_model": "claude-haiku-4-5-20251001",
      "prompt_version": "v1",
      "composite": 3.65,
      "axes": {
        "factuality": 4,
        "novelty": 3,
        "source_diversity": 4,
        "signal_density": 4,
        "coherence": 3
      },
      "notes": "NVIDIA Nemotron 3 Super was already covered Mar 10; recycling it as lead story weakens novelty. Header claims 10 stories but contains 14 items. While thematically organized (NVIDIA, xAI, Industry, Policy, Open Source, Research), no explicit synthesis or takeaway ties themes together.",
      "baseline_composite": 3.65,
      "baseline_judge": "claude-haiku-4-5-20251001",
      "delta_vs_baseline": 0.0
    },
    {
      "card_date": "2026-03-14",
      "ran_at": "2026-05-14T02:50:44+00:00",
      "judge_model": "claude-haiku-4-5-20251001",
      "prompt_version": "v1",
      "composite": 4.05,
      "axes": {
        "factuality": 4,
        "novelty": 4,
        "source_diversity": 4,
        "signal_density": 5,
        "coherence": 3
      },
      "notes": "Briefing is organized by company/topic but lacks synthesis or takeaways. Meta's 20% layoff ($600B infra context), Stanford's entry-level hiring cuts, and BlackRock's bankruptcy prediction could synthesize into a labor-disruption narrative, but each remains isolated. ~40% overlap with prior-week headlines (Nscale, robotics funding, AMI Labs, Pentagon lawsuit all previously covered).",
      "baseline_composite": 4.05,
      "baseline_judge": "claude-haiku-4-5-20251001",
      "delta_vs_baseline": 0.0
    },
    {
      "card_date": "2026-03-15",
      "ran_at": "2026-05-14T02:51:00+00:00",
      "judge_model": "claude-haiku-4-5-20251001",
      "prompt_version": "v1",
      "composite": 3.0,
      "axes": {
        "factuality": 3,
        "novelty": 2,
        "source_diversity": 3,
        "signal_density": 4,
        "coherence": 3
      },
      "notes": "Weak novelty: ~50% rehash of prior 7 days (Pentagon dispute, GPT-5.1 retirement, Windsurf Wave 13, AAIF/MCP 10K servers, Meta 20% cuts, Gemini Embedding 2, Nscale $2B). Only ~40% new (GigaTIME, Copilot Health, Granite 4.0, Vercel SDK 6, Next.js 16, policy statements). No synthesis or takeaways within sections.",
      "baseline_composite": 3.0,
      "baseline_judge": "claude-haiku-4-5-20251001",
      "delta_vs_baseline": 0.0
    },
    {
      "card_date": "2026-03-16",
      "ran_at": "2026-05-14T02:51:00+00:00",
      "judge_model": "claude-haiku-4-5-20251001",
      "prompt_version": "v1",
      "composite": 4.2,
      "axes": {
        "factuality": 4,
        "novelty": 4,
        "source_diversity": 4,
        "signal_density": 5,
        "coherence": 4
      },
      "notes": "Thematically organized but lacks synthesis or takeaway. Vera Rubin and Groq 3 LPU were previewed in prior coverage; briefing confirms details but doesn't advance narrative.",
      "baseline_composite": 4.2,
      "baseline_judge": "claude-haiku-4-5-20251001",
      "delta_vs_baseline": 0.0
    },
    {
      "card_date": "2026-03-17",
      "ran_at": "2026-05-14T02:51:14+00:00",
      "judge_model": "claude-haiku-4-5-20251001",
      "prompt_version": "v1",
      "composite": 4.2,
      "axes": {
        "factuality": 3,
        "novelty": 4,
        "source_diversity": 5,
        "signal_density": 5,
        "coherence": 5
      },
      "notes": "Sources cited but not granularly mapped to claims. Unsourced specifics: '~250 users affected' (Claude outage), '1,016 Blackwell Ultra GPUs, 9,000+ petaflops' (Eli Lilly). Robotics mega-round (Mind, Rhoda, Sunday, Oxa) repeats prior week reporting.",
      "baseline_composite": 4.2,
      "baseline_judge": "claude-haiku-4-5-20251001",
      "delta_vs_baseline": 0.0
    },
    {
      "card_date": "2026-03-18",
      "ran_at": "2026-05-14T02:51:27+00:00",
      "judge_model": "claude-haiku-4-5-20251001",
      "prompt_version": "v1",
      "composite": 4.0,
      "axes": {
        "factuality": 4,
        "novelty": 3,
        "source_diversity": 4,
        "signal_density": 5,
        "coherence": 4
      },
      "notes": "Novelty drags from GPT-5.4 mini pricing (prior headlines show arrival days before) and UK copyright report (expected delivery on Mar 18, not novel). TADA TTS and SAFECHAT Act are new; fourth Claude outage also new. Strong sourcing and concrete numbers throughout.",
      "baseline_composite": 4.0,
      "baseline_judge": "claude-haiku-4-5-20251001",
      "delta_vs_baseline": 0.0
    }
  ]
};
