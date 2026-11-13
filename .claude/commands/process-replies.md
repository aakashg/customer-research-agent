---
description: Check the connected Gmail inbox for new replies to the day-10 trial campaign and act on each per CLAUDE.md.
---

Run this every time you're invoked, whether interactively or from the scheduled poller (`scripts/poll.sh`). It should be a no-op if there's nothing new — don't ask the user anything, don't wait for input, just do the work and report a short summary at the end.

## 0. Load context
Read, in this order: `CLAUDE.md`, `company/programs.md`, `company/policies.md`, `company/escalation-playbook.md`, `config/campaign.json`, `customers.csv`.

`config/campaign.json` holds four settings:

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

**c. Log the inbound.** Append to `conversations/{email}.md`: timestamp, `IN`, sentiment, and a one-line extraction of any answer to the three campaign questions (what they hoped would be different, what got in the way, whether the level feels right) if present in the message.

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

  **If `reply_mode` is `"auto-send"`, run the groundedness eval below on the generated reply before sending.** (`"draft"`-mode replies skip the eval — a human reviews those before anything goes out.)

  **Groundedness eval (auto-send only).** Check the generated reply against `company/programs.md`, `company/policies.md`, and `CLAUDE.md`'s offer logic. Fail the eval if any of the following is true:
  - It states a program detail (session length, cadence, equipment, level range) not supported by `company/programs.md`, or contradicts it.
  - It states a policy/offer mechanic (annual-plan discount, trial extension terms, cancellation, refunds) not supported by `company/policies.md`, or invents a number/percentage/date not present there.
  - It offers a second trial extension to a customer whose `conversations/{email}.md` shows one already granted, or stacks the annual discount with anything else, or offers a discount outside the annual plan.
  - It states the customer's `workouts_completed` number back to them, or mentions a competitor.

  If the eval passes, proceed to send. If it fails:
  1. Regenerate the reply once, correcting the specific issue the eval found. Don't retry more than once — if the regenerated reply still fails, draft it anyway and flag the eval failure in the log and Slack post for human judgment.
  2. Save the regenerated reply as a Gmail draft (`draft_gmail_message`) instead of sending, even though `reply_mode` is `"auto-send"`.
  3. Log the `OUT` entry noting the eval failure (what was ungrounded), that it was regenerated, and that it's now a draft awaiting review.

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
End with a short summary: how many messages found, how many normal replies vs escalations vs unsubscribes, reply_mode used, how many auto-send replies were downgraded to a draft after failing the groundedness eval, and how many Slack notifications posted vs failed. If anything is sitting as an escalation draft or an eval-downgraded draft, call that out explicitly since those need a human to actually send them.
