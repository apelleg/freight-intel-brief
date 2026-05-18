#!/usr/bin/env python3
"""Send the freight intel brief via Resend API.

Usage:
    python scripts/send_email.py \
        --api-key re_xxx \
        --to pelleg@gmail.com \
        --from "Freight Intel Brief <onboarding@resend.dev>" \
        --subject "🚛 Freight Intel Brief — 2026-05-18" \
        --html-file /tmp/brief.html \
        --text-file /tmp/brief.txt
"""
import argparse
import json
import sys
import urllib.error
import urllib.request


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--api-key", required=True)
    parser.add_argument("--to", required=True)
    parser.add_argument("--from", dest="from_addr", required=True)
    parser.add_argument("--subject", required=True)
    parser.add_argument("--html-file", required=True)
    parser.add_argument("--text-file", required=True)
    args = parser.parse_args()

    with open(args.html_file, "r", encoding="utf-8") as f:
        html = f.read()
    with open(args.text_file, "r", encoding="utf-8") as f:
        text = f.read()

    payload = {
        "from": args.from_addr,
        "to": [args.to],
        "subject": args.subject,
        "html": html,
        "text": text,
    }

    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        "https://api.resend.com/emails",
        data=data,
        headers={
            "Authorization": f"Bearer {args.api_key}",
            "Content-Type": "application/json",
        },
    )

    try:
        resp = urllib.request.urlopen(req)
        print(f"Email sent OK: {resp.status} {resp.read().decode()}")
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        print(f"Email failed: {e.code} {body}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
