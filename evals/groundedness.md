# Groundedness eval

An eval that runs before any email goes out without a person reading it first. It checks one thing: every claim in the email is backed by the documentation in `company/*.md` (and the offer logic in `CLAUDE.md`).

It runs on:
- every `/send-outreach` email (outreach is always auto-sent), and
- every `/process-replies` normal reply or unsubscribe confirmation when `reply_mode` is `"auto-send"`.

It does not run on drafts a human reviews anyway: replies in `"draft"` mode, and every escalation draft.

The wording of the loop below follows how Greg described it on the episode: add an eval step after classification for responses queued to be auto-sent, focus it on groundedness in the documentation, and if it fails, rerun the generation and save the new generation as a draft for review.

## The judge

Launch the `groundedness-judge` subagent (`.claude/agents/groundedness-judge.md`) once per email. It starts with a fresh context and a Read-only toolset, so it judges the email without having written it. Pass it:

- the full draft, subject and body
- the customer's `first_name`, `email`, `program`, `segment` and `workouts_completed`
- for a reply, the customer's inbound message

If the subagent cannot be launched, run the rubric yourself as a separate, explicit pass, and write `judge: inline` in the log entry so a human knows it was a weaker check.

## Rubric

The email fails if any of these is true:

- It states a program detail (session length, cadence, equipment, level range) not supported by `company/programs.md`, or contradicts it.
- It states a policy or offer mechanic (annual-plan discount, trial extension terms, cancellation, refunds) not supported by `company/policies.md`, or invents a number, percentage or date not present there.
- It offers a second trial extension to a customer whose `conversations/{email}.md` shows one already granted, stacks the annual discount with anything else, or offers a discount outside the annual plan.
- It states the customer's `workouts_completed` number back to them, or mentions a competitor.

To add another eval later (voice, brand tone, objection handling), add a rubric file next to this one and run its judge in the same place. The loop below stays the same.

## When it fails

A failed eval should not just stop the process. Use the failure as input to the process:

1. **Rerun the whole generation**, not a patch. Go back to the compose step (the same one that wrote the first version) and write the email again from scratch, with the judge's FAILURES list added as extra input: "a reviewer found these claims unsupported by company/*.md: ...". Don't edit the failing sentence in place and don't follow the findings as step-by-step instructions. Running the full logic again, with the failure as one more input, keeps the new version from overfitting to the eval.
2. **Judge the new version** with the same subagent and record its verdict.
3. **Save it as a draft for review** instead of sending, whatever `reply_mode` says and whatever the second verdict was. (Live: `draft_gmail_message`. Dry run: `outbox/drafts/`.) A person sees every email that failed once.
4. **Log it.** The `OUT` entry says what was ungrounded, that it was regenerated, the second verdict, and that it is now a draft awaiting review.
5. **Notify.** The Slack post (dry run: `outbox/slack-notifications.md`) uses the warning emoji and names what was ungrounded.

One retry is deliberate for now. The natural next step is to retry several times and only fall back to a draft when none pass.
