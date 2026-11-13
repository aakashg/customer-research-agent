---
description: Check the connected Gmail inbox (or sample-replies/ with DRY_RUN=1) for new replies to the day-10 trial campaign and act on each per CLAUDE.md.
allowed-tools: Bash(printenv:*), Bash(echo:*)
---

Run this every time you're invoked, whether interactively or from the scheduled poller (`scripts/poll.sh`). It should be a no-op if there's nothing new — don't ask the user anything, don't wait for input, just do the work and report a short summary at the end.

## Mode: live or dry run

Value of the `DRY_RUN` environment variable (`1` means dry run, `0` means not set): !`printenv DRY_RUN || echo 0`

This is a **dry run** if the value above is `1`, or if `config/campaign.json` has `"dry_run": true`. Otherwise it is live. If it is not a dry run and `config/campaign.json` doesn't exist, stop and tell the user to either run with `DRY_RUN=1` or finish the Setup steps in the README.

In a dry run nothing touches Gmail or Slack. Never call any Gmail or Slack tool, and never use an address that isn't in `customers.csv`. Everywhere below that names a Gmail or Slack tool, do this instead:

| Live | Dry run |
|---|---|
| Search Gmail for unread mail, fetch each message and its thread | Glob `sample-replies/*.md`. Each file is one inbound email: front matter with `from` and `received`, then the body. A file is unread if its name isn't listed in `conversations/.dry-run-processed.txt`. Process oldest `received` first. Ignore `test_sender_filter`. |
| Thread-origin check (step 1) | The outbound origin is the outreach file `outbox/{email}-01.md` (or `outbox/drafts/{email}-01.md`) whose `to:` is the reply's `from`. No such file means the reply isn't a campaign reply: skip it and don't mark it processed. |
| `Cadence/Processed` label | Append the reply's file name to `conversations/.dry-run-processed.txt`. |
| `send_gmail_message` | Write `outbox/{email}-{NN}.md` with `status: sent` (`NN` is the next unused number for that address). |
| `draft_gmail_message` | Write `outbox/drafts/{email}-{NN}.md` with `status: draft` and a `reason:` line (`escalation`, `eval-failed` or `reply-mode-draft`). |
| `slack_send_message` | Append the same message to `outbox/slack-notifications.md`. Put the draft's file path where the Gmail thread link would go. |
| `in_reply_to`, `thread_id` | Front matter `in_reply_to:` holding the file name of the message being answered. |

Outbox file format: front matter with `to`, `from` (`Sam from Cadence <brand_mailbox>`), `subject` (`Re:` the original), `kind` (`reply`, `escalation` or `unsubscribe-confirmation`), `status`, `in_reply_to`, `eval` (`PASS`, `FAIL, regenerated` or `skipped`), then the body as plain readable paragraphs. No HTML in these files. Every other rule, including the voice rules and the escalation overrides, still applies. Get timestamps from the `date` command.

Dry-run defaults: if `config/campaign.json` doesn't exist, read `config/campaign.example.json` and treat `reply_mode` as `"auto-send"` (nothing leaves your machine, and auto-send is the path that runs the groundedness eval). If `customers.csv` doesn't exist, create it as a copy of `customers.example.csv`. Unsubscribes still edit `customers.csv` and conversation logs are still written, because those are local files.

## 0. Load context
Read, in this order: `CLAUDE.md`, `company/programs.md`, `company/policies.md`, `company/escalation-playbook.md`, `config/campaign.json`, `customers.csv`.

`config/campaign.json` holds five settings (the fifth, `dry_run`, is covered above):

- `brand_mailbox`: the authorized Cadence mailbox. Every Gmail MCP tool call in this command passes it as `user_google_email`. Never substitute another address.
- `reply_mode`: `"draft"` or `"auto-send"`. Controls normal replies only. See step 2d for the escalation override, which ignores this setting.
- `slack_channel_id`: where step 2e posts reply notifications. If empty, skip step 2e.
- `test_sender_filter`: optional. See step 1.

Build the set of in-scope customer emails: every `customers.csv` row with `send=yes`.

## 1. Find new inbound messages
Ensure a Gmail label called `Cadence/Processed` exists (check `list_gmail_labels`, create it with `manage_gmail_label` if missing).

Search Gmail for `is:unread -label:Cadence/Processed`. If `test_sender_filter` is set, prepend `from:{test_sender_filter}` to the query. That's a demo shortcut for when every test customer replies from one inbox: it skips the unrelated unread mail (vendor newsletters, account notices) that would otherwise be fetched and discarded on every run. Leave it empty for real customers, whose replies can come from any address. For each match, fetch full content (`get_gmail_message_content` or the batch variant) including thread id and the RFC Message-ID (needed for threaded replies).

**Identify the customer by thread origin, not by the reply's From address.** A customer's reply often arrives From their bare Gmail address rather than the `+alias` address in `customers.csv`, because Gmail defaults replies to the account's primary address unless the alias was explicitly chosen as the send-as identity — matching on From alone silently misses these. Instead, fetch the thread (`get_gmail_thread_content`) and find the earliest message in it sent from `brand_mailbox`; the address it was sent **To** is the customer's `customers.csv` email. Skip (and don't label) any unread message whose thread has no such outbound origin, or whose origin address isn't in the in-scope set (`send=yes`) — those aren't campaign replies.

If there are no in-scope messages after this filtering, stop here and report "no new replies."

## 2. Process each message
Do these one at a time, oldest first. For each:

**a. Identify the customer.** Use the thread-origin address found in step 1 (not the reply's From header) to match the `customers.csv` row (name, program, segment, workouts_completed). Read `conversations/{email}.md` for full history — this determines whether they've already been offered/extended something, and whether the last exchange was already answered (never send two outbound messages in a row without an inbound in between, per CLAUDE.md's hard rules).

**b. Classify the message.** Decide sentiment (positive/neutral/negative) and check for, in priority order:
   1. Injury, pain, or medical condition
   2. Anger, refund request, or an explicit request to talk to a human
   3. Unsubscribe request
   4. None of the above — a normal reply

**c. Log the inbound.** Append to `conversations/{email}.md`: timestamp, `IN`, sentiment, and a one-line extraction of any answer to the three campaign questions (what they hoped would be different, what got in the way, whether the level feels right) if present in the message. Under the entry, keep the customer's message verbatim as a blockquote, so the insights report can quote them.

**d. Branch on classification, per `company/escalation-playbook.md`:**

Every `draft_gmail_message`/`send_gmail_message` call in this step uses `body_format: "html"` (never `"plain"`) per `CLAUDE.md`'s Email format section — one `<div>` per paragraph, `<div><br></div>` between them, no manual line wrapping. This HTML-escaping applies **only** to the `body` argument's contents.

> ⚠️ **`in_reply_to` / `references` / `thread_id` are never HTML-escaped, regardless of `body_format`.** These are RFC 2822 header values, not markup, and `body_format: "html"` has no bearing on them. Copy the Message-ID exactly as the Gmail tool returned it, character for character, with literal `<` and `>`.
>
> - Correct: `in_reply_to="<CAExampleMessageId0123456789abcdef@mail.gmail.com>"`
> - Wrong: `in_reply_to="&lt;CAExampleMessageId0123456789abcdef@mail.gmail.com&gt;"`
>
> A message sent with the wrong form still looks fine in Gmail's own thread view for the sending mailbox (Gmail also groups by subject/participants), so the mistake doesn't show up there — it only surfaces as a broken thread in the *recipient's* client. That silent-looking success is exactly what makes this worth double-checking: before calling `draft_gmail_message`/`send_gmail_message`, re-read the literal `in_reply_to`/`references` string you're about to pass and confirm it contains `<`/`>`, not `&lt;`/`&gt;`, before sending.

- **Injury/pain/medical or anger/refund/human-request:** Compose the one-time acknowledgment per the playbook (no training advice, no policy explanation, no offer). Write/append `conversations/ESCALATE-{email}.md` with the verbatim inbound message, timestamp, and trigger reason. **Always create this as a Gmail draft (`draft_gmail_message`), never send it automatically** — this overrides `reply_mode` regardless of its value. Log the drafted acknowledgment as an `OUT` entry noting it's an escalation draft awaiting human review.

- **Unsubscribe:** Immediately edit `customers.csv` to set that row's `send` to `no`. Compose the short confirmation from the playbook. This one follows `reply_mode` like a normal reply (draft or auto-send). Log the `OUT` entry.

- **Normal reply:** Compose a reply that acknowledges what they said, naturally works in whichever of the three campaign questions hasn't been answered yet (don't re-ask an already-answered one), and applies the offer logic from `CLAUDE.md` based on their segment/workout count — but don't repeat an offer already made and not yet acted on unless they're asking about it. Pull factual details (program specifics, extension/annual-plan mechanics) from `company/programs.md` and `company/policies.md` rather than improvising. Match voice: encouraging, no exclamation marks, no em dashes, short paragraphs, sign off "Sam from Cadence." Don't state their `workouts_completed` number back to them — it's for picking tone/offer only, not for the copy.

  **If `reply_mode` is `"auto-send"`, run the groundedness eval on the generated reply before sending.** The procedure, the rubric and the judge are in `evals/groundedness.md` (the `groundedness-judge` subagent checks every claim against `company/programs.md`, `company/policies.md` and `CLAUDE.md`'s offer logic). Replies in `"draft"` mode skip the eval because a human reviews those before anything goes out. Escalation drafts skip it for the same reason.

  If the eval passes, proceed to send. If it fails:
  1. Rerun the whole generation for this reply, not a patch: go back to composing the normal reply at the top of this branch with the judge's findings added as extra input. Don't edit the failing sentence in place, and don't retry more than once. Judge the new version too. If it still fails, draft it anyway and flag the eval failure in the log and Slack post for human judgment.
  2. Save the regenerated reply as a draft (`draft_gmail_message`) instead of sending, even though `reply_mode` is `"auto-send"`.
  3. Log the `OUT` entry noting the eval failure (what was ungrounded), that it was regenerated, the second verdict, and that it's now a draft awaiting review.

  Then act per `reply_mode` (subject to the eval override above):
  - `"draft"` → `draft_gmail_message`, threaded via `thread_id`/`in_reply_to`.
  - `"auto-send"` → if the eval passed, `send_gmail_message`, threaded the same way. If the eval failed, `draft_gmail_message` instead, per above.
  Log the `OUT` entry noting draft vs sent (and eval outcome, if `auto-send` was in play).

**e. Notify Slack.** Post one message to `config/campaign.json`'s `slack_channel_id` via `slack_send_message`, once whichever action in (d) has actually completed:

- **If (d) sent a message** (an `auto-send` normal reply or unsubscribe confirmation): wait for `send_gmail_message` to succeed, then post the inbound message and the reply that was sent.
- **If (d) only drafted a message** (a `draft`-mode normal reply or unsubscribe confirmation, any escalation — escalations always draft — or an `auto-send` normal reply downgraded to a draft after failing the groundedness eval): wait for `draft_gmail_message` to succeed, then post the inbound message, the drafted reply, and a link to the thread so a human can review and send it: `https://mail.google.com/mail/u/0/#all/{thread_id}`.

Pick an emoji by classification/action so these scan quickly in the channel: 📬 sent normal reply/unsubscribe, 📝 drafted normal reply/unsubscribe awaiting review, 🚨 escalation draft awaiting review, ⚠️ auto-send downgraded to draft after failing the groundedness eval. Format:

```
{emoji} *{first_name}* ({email}) replied — {classification}, {sent/drafted}
> Inbound: {inbound excerpt, ~200 chars}
> {Reply sent/Draft}: {reply excerpt, ~200 chars}
{eval-failure note — only when (d) downgraded an auto-send reply, one line naming what was ungrounded}
{thread link — omit this line when the reply was sent, not drafted}
```

If the Slack post fails, don't block on it — note the failure in the step 3 report and continue to (f). A missed notification should never leave a real customer message unlabeled or stuck out of the processed set.

**f. Mark it processed.** Apply the `Cadence/Processed` label to the inbound message via `modify_gmail_message_labels` so it's never re-processed.

## 3. Report
End with a short summary: how many messages found, how many normal replies vs escalations vs unsubscribes, reply_mode used, how many auto-send replies were downgraded to a draft after failing the groundedness eval, and how many Slack notifications posted vs failed. If anything is sitting as an escalation draft or an eval-downgraded draft, call that out explicitly since those need a human to actually send them. In a dry run, say so and list the files written under `outbox/` and `outbox/drafts/`.
