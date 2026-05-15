#!/usr/bin/env node
// update-memory.js — Parse memory block from brief output and update seen.json.
//
// Usage: node update-memory.js <path-to-seen.json> <memory-block-json>
//   Called automatically by run-brief.sh after each run.

const fs = require('fs');
const path = require('path');

const RETENTION_DAYS = 30;

function main() {
  const [, , memoryFilePath, memoryBlockJson] = process.argv;

  if (!memoryFilePath || !memoryBlockJson) {
    console.error('Usage: update-memory.js <seen.json path> <memory block JSON>');
    process.exit(1);
  }

  // Parse the memory update block from Claude's output
  let update;
  try {
    update = JSON.parse(memoryBlockJson);
  } catch (e) {
    console.error('Failed to parse memory block JSON:', e.message);
    process.exit(1);
  }

  // Load existing seen.json, or start fresh
  let seen = { seen_urls: [], seen_story_hashes: [], last_30_days: [] };
  if (fs.existsSync(memoryFilePath)) {
    try {
      seen = JSON.parse(fs.readFileSync(memoryFilePath, 'utf8'));
    } catch (e) {
      console.error('Warning: could not parse existing seen.json, starting fresh:', e.message);
    }
  }

  // Merge new URLs and hashes (deduplicated)
  const urlSet = new Set(seen.seen_urls || []);
  for (const url of update.new_urls || []) {
    urlSet.add(url);
  }

  const hashSet = new Set(seen.seen_story_hashes || []);
  for (const hash of update.new_hashes || []) {
    hashSet.add(hash);
  }

  // Add today's entry to last_30_days
  const todayEntry = {
    date: update.date,
    stories: update.story_summaries || []
  };

  const last30 = seen.last_30_days || [];
  // Remove any existing entry for today (idempotent re-runs)
  const filtered = last30.filter(e => e.date !== update.date);
  filtered.push(todayEntry);

  // Prune entries older than 30 days
  const cutoff = new Date();
  cutoff.setDate(cutoff.getDate() - RETENTION_DAYS);
  const pruned = filtered.filter(e => new Date(e.date) >= cutoff);

  // Prune seen_urls to only keep URLs from last 30 days
  // Build set of all URLs from retained days to identify what to keep
  const recentUrlSet = new Set();
  for (const entry of pruned) {
    // We don't track per-url dates, so keep all URLs that arrived in the last 30 days
    // by keeping the full URL set but capping at a reasonable size (3000 entries)
    // This is v1 — Phase 3 will add smarter pruning
  }

  // Cap URL set at 3000 entries (FIFO — drop oldest if over limit)
  const urlArray = Array.from(urlSet);
  const cappedUrls = urlArray.length > 3000 ? urlArray.slice(urlArray.length - 3000) : urlArray;

  const result = {
    seen_urls: cappedUrls,
    seen_story_hashes: Array.from(hashSet),
    last_30_days: pruned
  };

  // Write atomically via temp file
  const tmpPath = memoryFilePath + '.tmp';
  fs.writeFileSync(tmpPath, JSON.stringify(result, null, 2) + '\n', 'utf8');
  fs.renameSync(tmpPath, memoryFilePath);

  console.log(`Memory updated: ${cappedUrls.length} URLs, ${hashSet.size} hashes, ${pruned.length} day entries`);
}

main();
