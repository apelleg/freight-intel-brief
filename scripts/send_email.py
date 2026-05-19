#!/usr/bin/env python3
"""Send the freight intel brief via Resend SMTP.

Uses SMTP (port 465) instead of the Resend HTTP API to avoid Cloudflare WAF
blocks that affect GitHub Actions runner IP ranges.

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
import smtplib
import sys
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText


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

    msg = MIMEMultipart("alternative")
    msg["Subject"] = args.subject
    msg["From"] = args.from_addr
    msg["To"] = args.to
    msg.attach(MIMEText(text, "plain", "utf-8"))
    msg.attach(MIMEText(html, "html", "utf-8"))

    try:
        with smtplib.SMTP_SSL("smtp.resend.com", 465) as smtp:
            smtp.login("resend", args.api_key)
            smtp.sendmail(args.from_addr, [args.to], msg.as_string())
        print("Email sent OK via SMTP")
    except Exception as e:
        print(f"Email failed: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
