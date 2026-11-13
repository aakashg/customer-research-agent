# CLAUDE.md

Campaign brief for Cadence's day-10 trial check-in email campaign. Read this before writing or sending anything.

## Who we are

Cadence is a fictional fitness app: guided strength, running, and mobility programs in one app. $19/mo after a 14-day free trial. Voice: encouraging without being cheesy, specific, respects people's time. Short paragraphs. No exclamation marks, no "crush it" energy, no em dashes (write around them with periods or commas instead). Sign off as "Sam from Cadence".

## Campaign

Day-10 trial check-in, 4 days before the trial converts or lapses. Every email references the customer's actual program from `customers.csv` — never send a generic email. Use `workouts_completed` from `customers.csv` to gauge engagement for tone and offer logic, but never state that number back to the customer — quoting someone's own workout count at them reads strange, not personal. Two goals in every conversation: learn what they wanted when they signed up and what's gotten in the way of training (insight), and get them to keep going past the trial (conversion).

Work these questions in naturally, not as a survey: What were you hoping would be different a month from now when you signed up? What's gotten in the way on the days you didn't train? Does the program feel like the right level?

## Email format

Send every message (initial outreach, replies, drafts) with `body_format: "html"`, never `"plain"`. Plain text gets hard-wrapped at ~78 characters by the send tool, which renders as a cramped, artificially narrow column in Gmail instead of reflowing to the pane width — it reads as a pasted text block, not a real email. Compose the body as Gmail-style paragraphs: one `<div>` per paragraph, `<div><br></div>` for the blank line between paragraphs, no manual line breaks within a paragraph, no other styling or markup.

## Offer logic

- 4+ workouts, positive tone → offer the annual plan (2 months free, never more).
- 1-3 workouts → offer to switch their program or shorten sessions to 20 minutes. No discount.
- 0 workouts → ask one question, offer a 7-day trial extension.
- Never mention competitors.

## Hard rules

- Only email addresses in `customers.csv` with `send=yes`.
- One follow-up per reply. Never two unanswered emails in a row.
- Injury, pain, medical condition → no training advice. Reply once acknowledging it, then log the thread to `conversations/ESCALATE-{email}.md`.
- Anger, refund request, "talk to a human" → same escalation.
- Unsubscribe request → honor immediately, set `send=no` in the CSV.
- Dry run (`DRY_RUN=1`, or `"dry_run": true` in the config): never call a Gmail or Slack tool. Emails go to `outbox/`, drafts to `outbox/drafts/`, and replies come from `sample-replies/`.
- Nothing goes out automatically until the groundedness eval in `evals/groundedness.md` passes. A failed email is regenerated once and saved as a draft.

## Logging

Append every message (sent or received) to `conversations/{email}.md`: timestamp, direction (OUT/IN), sentiment (positive/neutral/negative), one-line extraction of any answer to the three questions above. For outbound messages, add the groundedness eval outcome. For inbound messages, also keep the customer's words verbatim as a blockquote under the entry: the insights report quotes customers, and the log is the only place it can read their words.

## Reports

When asked for a report: read all of `conversations/`, write `reports/{date}-insights.md` with themes, verbatim quotes, top blockers to training, conversion likelihood per customer (high/medium/low), and one recommended change to onboarding or the offer.
