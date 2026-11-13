---
description: Send the day-10 trial check-in outreach to every in-scope customer who hasn't been contacted yet. With DRY_RUN=1 it writes the emails to outbox/ instead of Gmail.
allowed-tools: Bash(printenv:*), Bash(echo:*)
---

Run this to kick off (or catch up) the campaign's initial outreach. It should be a no-op for any customer who's already been contacted — safe to re-run without duplicating sends.

## Mode: live or dry run

Value of the `DRY_RUN` environment variable (`1` means dry run, `0` means not set): !`printenv DRY_RUN || echo 0`

This is a **dry run** if the value above is `1`, or if `config/campaign.json` has `"dry_run": true`. Otherwise it is live.

In a dry run nothing touches Gmail or Slack. Never call any Gmail or Slack tool, and never use an address that isn't in `customers.csv`. Instead:

- If `config/campaign.json` doesn't exist, read `config/campaign.example.json`. If `customers.csv` doesn't exist, create it as a copy of `customers.example.csv`.
- Where this command says to send an email, write it to `outbox/{email}-{NN}.md` with `status: sent` (`NN` is the next unused number for that address, starting at `01`).
- Where it says to save a draft, write it to `outbox/drafts/{email}-{NN}.md` with `status: draft`.
- File format: front matter with `to`, `from` (`Sam from Cadence <brand_mailbox>`), `subject`, `kind: outreach`, `status`, `eval` (`PASS`, or `FAIL, regenerated`) and `sent_at` (from the `date` command), then the email body as plain readable paragraphs. No HTML in these files, since nobody's mail client renders them. Every other rule, including the voice rules, still applies.
- Get timestamps from the `date` command.

If this is not a dry run and `config/campaign.json` doesn't exist, stop and tell the user to either run with `DRY_RUN=1` or finish the Setup steps in the README.

## 0. Load context

Read, in this order: `CLAUDE.md`, `company/programs.md`, `company/policies.md`, `config/campaign.json`, `customers.csv`.

Live runs only: every Gmail MCP tool call in this command passes `config/campaign.json`'s `brand_mailbox` as `user_google_email`. That's the authorized Cadence mailbox, not the operator's own inbox. Never substitute another address.

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
- Live runs: use `body_format: "html"` (never `"plain"`) per `CLAUDE.md`'s Email format section — one `<div>` per paragraph, `<div><br></div>` between them, no manual line wrapping, no other styling or markup.

## 3. Groundedness eval

Initial outreach goes out automatically, so every composed email is checked before anything is sent. Run the eval in `evals/groundedness.md` on each one (the `groundedness-judge` subagent).

- **Pass:** go to step 4 and send it.
- **Fail:** don't send. Rerun the whole composition in step 2 for that customer with the judge's findings as extra input (not a patch to the failing sentence), judge the new version, and save it as a draft for review instead of sending it. Live: `draft_gmail_message`. Dry run: `outbox/drafts/`.

## 4. Send

Send each email that passed the eval directly with `send_gmail_message`. Initial outreach is a deliberate, one-time campaign kickoff rather than a reply to something a customer said, so it doesn't go through `config/campaign.json`'s `reply_mode` draft/auto-send toggle — that setting governs replies only. (Dry run: write the file to `outbox/` as described above.)

## 5. Log

Create `conversations/{email}.md` with an `OUT` entry: timestamp, `n/a` (no sentiment for an outbound message), a one-line note of which offer was made and why, and the eval outcome (`eval: PASS`, or `eval: FAIL on <what was ungrounded>, regenerated, saved as draft`).

## 6. Report

End with a short summary: how many emails sent, how many held as drafts after failing the groundedness eval (and what was ungrounded), how many customers skipped as already-contacted, and any send failures. In a dry run, say so and list the files written under `outbox/`.
