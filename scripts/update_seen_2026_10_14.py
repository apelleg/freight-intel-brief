#!/usr/bin/env python3
import json
import hashlib
from datetime import datetime, timedelta

SEEN_PATH = "memory/seen.json"

# New URLs fetched today (Oct 14)
NEW_URLS = [
    "https://bloomberg.com/news/newsletters/2026-10-14/soaring-oil-freight-is-becoming-a-risk-to-fuel-supply",
    "https://summar.com/freight-market-update-october-2026/",
    "https://www.chrobinson.com/en-us/resources/insights-and-advisories/north-america-freight-insights/oct-2026-freight-market-update/na-truckload/",
    "https://www.ccjdigital.com/business/article/15836592/ch-robinson-acquiring-rxo-in-58-billion-stock-and-cash-transaction",
    "https://www.ccjdigital.com/business/mergers-acquisitions/article/15832326/trimble-weighs-sale-of-transportation-unit-following-buyer-interest",
    "https://www.supplychaindive.com/topic/freight/",
    "https://mexiconewsdaily.com/business/ebrard-tariff-deadline-oct-29/",
    "https://news.xpo.com/3170/xpo-schedules-third-quarter-2026-earnings-conference-call/",
    "https://www.cnn.com/2026/10/08/business/oil-diesel-prices-tanker-attacks-hormuz-intl",
    "https://gvwire.com/2026/10/09/port-of-los-angeles-sets-september-volume-record-executive-director-says/",
    "https://dotnumberstore.com/blogs/news/state-of-the-trucking-industry-october-2026-brings-better-rates-and-tougher-cost-decisions",
    "https://foreignpolicy.com/2026/10/01/oil-strait-hormuz-iran-trump-war-gulf-gas-diesel-prices/",
]

# Stories included in the brief
STORY_HASHES_RAW = [
    ("soaring tanker-charter rates are cutting into refinery margins globally and beginning to constrain diesel supply av", "bloomberg"),
    ("dat van all-in ~$3.07/mi nationally (week oct 5-11, +43% yoy); reefer ~$3.62/mi; flatbed ~$3.71/mi. cass tl lineh", "dat"),
    ("van l/t 13.72 (dat, week oct 5-9) vs. 11.2 three weeks prior — quarter-end surge still flowing through; load posts", "summar"),
    ("panama canal adds 10th daily neopanamax transit slot effective oct 15 — first structural slot increase since el niñ", "cnn"),
    ("loadsmart ceo disclosed saas now accounts for 50% of gross profit — first digital 3pl to cross this threshold", "freightwaves"),
    ("c.h. robinson rxo integration planning underway following $5.8b acquisition (oct 5); combined ev >$25b, $300m syner", "ccj digital"),
    ("nippon express and japan airlines launched a weekly los angeles–asia dedicated cargo circuit targeting ai and semico", "supply chain dive"),
    ("aurora gen-2 production ramp: roush on track for 20 gen-2 driverless trucks/week upfit in october; 200-truck year-e", "aurora innovation"),
    ("flexport (oct 6) and freight right (oct 9) both now running mcp server apis enabling ai agents (claude, chatgpt, co", "freightwaves"),
    ("trimble tms sale stalled: goldman sachs process ongoing — apax and bain both out; third buyer evaluating transporeon", "ccj digital"),
    ("xpo q3 earnings oct 29: conference call scheduled. q2 north american ltl or was 79.9%; august ltl tonnage/day +3.7%", "xpo investor relations"),
    ("mexico economy minister ebrard says bilateral tariff negotiations are 90% complete as the oct 29 deadline nears", "mexico news daily"),
    ("fmcsa advancing a new comment period for testing shorter split sleeper configurations", "freightwaves"),
]

def make_hash(headline_prefix, source):
    combined = (headline_prefix[:100] + source).lower()
    return hashlib.md5(combined.encode()).hexdigest()

NEW_HASHES = [make_hash(h, s) for h, s in STORY_HASHES_RAW]

TODAY_DATE = "2026-10-14"
CUTOFF_DATE = "2026-09-14"

TODAY_STORIES = [
    "Bloomberg Oct 14: soaring tanker-charter rates constraining diesel AVAILABILITY (not just price); IRGC attacks 15+ vessels in Oct; 4PL managed transportation most exposed to carrier-availability shock",
    "DAT week Oct 5-11: van all-in ~$3.07/mi (+43% YoY), reefer ~$3.62/mi, flatbed ~$3.71/mi; van L/T 13.72; Cass TL linehaul +10% YoY in September",
    "Diesel $6.199/gal (EIA Oct 5) — down from $6.549 record; Panama Canal adds 10th daily Neopanamax slot effective Oct 15 (first structural increase since El Niño)",
    "Loadsmart CEO: SaaS now 50% of gross profit — first digital 3PL to cross this threshold (Oct 13, FreightWaves)",
    "CHR/RXO $5.8B integration underway; CHR October Edge Report anchors TL costs +30% YoY 2026, +10% 2027; RICO chameleon-carrier suit (2:26-cv-00869) active",
    "Nippon Express/JAL weekly LA-Asia dedicated AI/semiconductor air cargo lane launched (Oct 8-9, Supply Chain Dive)",
    "Aurora Gen-2: Roush 20/week, 200-truck year-end target intact after DOT 5-year beacon exemption (Oct 7-8)",
    "MCP freight APIs: Flexport (Oct 6) + Freight Right (Oct 9) both in production — AI agents can book/track freight without human login",
    "Trimble TMS sale: Apax/Bain out, third buyer evaluating Transporeon/TMW-TM4 split; Q4 RFP window open (CCJ Digital)",
    "XPO Q3 earnings Oct 29; Q2 LTL OR 79.9%, August tonnage/day +3.7% YoY",
    "USMCA Oct 29 deadline: Mexico 90% done per Economy Minister Ebrard (Mexico News Daily)",
    "FMCSA advancing split sleeper berth pilot comment period — could expand effective driver hours",
]

with open(SEEN_PATH, 'r') as f:
    data = json.load(f)

existing_urls = set(data.get("seen_urls", []))
for url in NEW_URLS:
    if url not in existing_urls:
        data["seen_urls"].append(url)
        existing_urls.add(url)

if len(data["seen_urls"]) > 3000:
    data["seen_urls"] = data["seen_urls"][-3000:]

existing_hashes = set(data.get("seen_story_hashes", []))
for h in NEW_HASHES:
    if h not in existing_hashes:
        data["seen_story_hashes"].append(h)
        existing_hashes.add(h)

last_30 = data.get("last_30_days", [])
last_30 = [e for e in last_30 if e.get("date") != TODAY_DATE]
last_30.append({"date": TODAY_DATE, "stories": TODAY_STORIES})
last_30.sort(key=lambda e: e.get("date", ""))
last_30 = [e for e in last_30 if e.get("date", "") >= CUTOFF_DATE]
data["last_30_days"] = last_30

with open(SEEN_PATH, 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

print(f"Updated seen.json: {len(data['seen_urls'])} URLs, {len(data['seen_story_hashes'])} hashes, {len(last_30)} last_30_days entries")
print(f"Last date entry: {last_30[-1]['date'] if last_30 else 'none'}")
