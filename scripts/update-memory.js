#!/usr/bin/env node
// update-memory.js — Parse memory block from brief output and update seen.json.
//
// Usage: node update-memory.js <path-to-seen.json> <memory-block-json>
//   Called automatically by run-brief.sh after each run.

const fs = require('fs');
const path = require('path');

const RETENTION_DAYS = 30;        // seen_urls freshness window
const THREAD_RETENTION_DAYS = 60; // threads move slower than daily news — keep longer

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
  let seen = { seen_urls: [], seen_story_hashes: [], threads: [] };
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

  // Upsert thread updates (keyed by id), preserving first_covered_date
  const threadMap = new Map((seen.threads || []).map(t => [t.id, t]));
  for (const t of update.thread_updates || []) {
    if (!t.id || !t.status) continue;
    const existing = threadMap.get(t.id);
    threadMap.set(t.id, {
      id: t.id,
      label: t.label || (existing && existing.label) || t.id,
      status: t.status,
      last_covered_date: update.date,
      first_covered_date: existing ? existing.first_covered_date : update.date
    });
  }

  // Prune threads that haven't been touched within THREAD_RETENTION_DAYS
  const threadCutoff = new Date();
  threadCutoff.setDate(threadCutoff.getDate() - THREAD_RETENTION_DAYS);
  const prunedThreads = Array.from(threadMap.values())
    .filter(t => new Date(t.last_covered_date) >= threadCutoff);

  // Cap URL set at 3000 entries (FIFO — drop oldest if over limit)
  const urlArray = Array.from(urlSet);
  const cappedUrls = urlArray.length > 3000 ? urlArray.slice(urlArray.length - 3000) : urlArray;

  const result = {
    seen_urls: cappedUrls,
    seen_story_hashes: Array.from(hashSet),
    threads: prunedThreads
  };

  // Write atomically via temp file
  const tmpPath = memoryFilePath + '.tmp';
  fs.writeFileSync(tmpPath, JSON.stringify(result, null, 2) + '\n', 'utf8');
  fs.renameSync(tmpPath, memoryFilePath);

  console.log(`Memory updated: ${cappedUrls.length} URLs, ${hashSet.size} hashes, ${prunedThreads.length} threads`);
}

main();
