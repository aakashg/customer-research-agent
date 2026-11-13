---
description: Send the day-10 trial check-in outreach to every in-scope customer who hasn't been contacted yet.
---

Run this to kick off (or catch up) the campaign's initial outreach. It should be a no-op for any customer who's already been contacted — safe to re-run without duplicating sends.

## 0. Load context

Read, in this order: `CLAUDE.md`, `company/programs.md`, `company/policies.md`, `config/campaign.json`, `customers.csv`.

Every Gmail MCP tool call in this command passes `config/campaign.json`'s `brand_mailbox` as `user_google_email`. That's the authorized Cadence mailbox, not the operator's own inbox. Never substitute another address.

## 1. Build the send list

In-scope customers are every `customers.csv` row with `send=yes`.

For each in-scope customer, check whether `conversations/{email}.md` already exists. If it does, they've already received the day-10 outreach (or have an active thread) — skip them. Never send a second initial outreach to the same customer. Only customers with no conversation file yet are new sends.

If every in-scope customer already has a conversation file, stop here and report "no new outreach to send — everyone in scope has already been contacted."

## 2. Compose each email

Process the remaining customers one at a time. For each:

Pull `first_name`, `program`, `workouts_completed`, and `segment` from their `customers.csv` row.

- Reference their actual program by name — never send a generic email.
- Use `workouts_completed` only to pick tone and offer (see `CLAUDE.md`'s Offer logic). Never state that number back to the customer in the copy — quoting someone's own workout count at them reads strange, not personal.
- Naturally work in whichever one of the three campaign questions (`CLAUDE.md`'s Campaign section) fits their segment best. Don't ask all three — this isn't a survey.
- Apply `CLAUDE.md`'s Offer logic based on `workouts_completed`/`segment`. Pull factual details (program specifics, extension/annual-plan mechanics) from `company/programs.md` and `company/policies.md` rather than improvising.
- Match voice exactly per `CLAUDE.md`: encouraging, no exclamation marks, no em dashes, short paragraphs, sign off "Sam from Cadence."
- Use `body_format: "html"` (never `"plain"`) per `CLAUDE.md`'s Email format section — one `<div>` per paragraph, `<div><br></div>` between them, no manual line wrapping, no other styling or markup.

## 3. Send

Send directly with `send_gmail_message`. Initial outreach is a deliberate, one-time campaign kickoff rather than a reply to something a customer said, so it doesn't go through `config/campaign.json`'s `reply_mode` draft/auto-send toggle — that setting governs replies only.

## 4. Log

Create `conversations/{email}.md` with an `OUT` entry: timestamp, `n/a` (no sentiment for an outbound message), and a one-line note of which offer was made and why.

## 5. Report

End with a short summary: how many emails sent, how many customers skipped as already-contacted, and any send failures.
