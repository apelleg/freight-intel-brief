-- Briefing eval store schema v1
-- Idempotent on (card_date, prompt_version, judge_model): re-runs overwrite.

CREATE TABLE IF NOT EXISTS eval_runs (
    card_date        TEXT NOT NULL,        -- YYYY-MM-DD of the briefing card
    prompt_version   TEXT NOT NULL,        -- judge prompt version, e.g. "v1"
    judge_model      TEXT NOT NULL,        -- e.g. "claude-haiku-4-5-20251001"
    ran_at           TEXT NOT NULL,        -- ISO-8601 UTC timestamp
    factuality       INTEGER NOT NULL CHECK (factuality       BETWEEN 1 AND 5),
    novelty          INTEGER NOT NULL CHECK (novelty          BETWEEN 1 AND 5),
    source_diversity INTEGER NOT NULL CHECK (source_diversity BETWEEN 1 AND 5),
    signal_density   INTEGER NOT NULL CHECK (signal_density   BETWEEN 1 AND 5),
    coherence        INTEGER NOT NULL CHECK (coherence        BETWEEN 1 AND 5),
    composite        REAL    NOT NULL,
    notes            TEXT,
    judge_raw        TEXT,                 -- raw judge response for debug
    PRIMARY KEY (card_date, prompt_version, judge_model)
);

CREATE INDEX IF NOT EXISTS idx_eval_runs_date ON eval_runs (card_date);
CREATE INDEX IF NOT EXISTS idx_eval_runs_ran_at ON eval_runs (ran_at);
