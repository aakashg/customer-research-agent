# Cadence: a two-way email campaign run by Claude Code

> Built by [Greg Greiner](https://www.linkedin.com/in/greggreiner1/), CEO of [Woven](https://woven.ai/), for [The Growth Podcast](https://youtu.be/JpyhPePe150) with Aakash Gupta. Watch him build it and add the eval loop live in the episode.

A working example of an AI agent running a real customer conversation, not just a mail merge. It sends a personalized check-in, reads each reply, decides what to do, answers within company policy, hands sensitive cases to a human, and turns all of it into a research report.

There is no application code. The whole system is plain-English Markdown that [Claude Code](https://code.claude.com) runs against a Gmail inbox.

> Cadence is a fictional fitness app, and every customer in this repo is made up. The campaign is a **day-10 trial check-in**. Four days before a free trial converts, each trial user gets an email about their actual program. It asks one good question and makes the right offer for how engaged they've been.

---

## How it works

```
                 ┌──────────────────────────────────────────────┐
                 │  The brief (what to do)                      │
                 │  CLAUDE.md          voice, offers, hard rules│
                 │  company/*.md       facts emails may cite    │
                 │  customers.csv      who to contact           │
                 └──────────────────────┬───────────────────────┘
                                        │
   /send-outreach ──── personalized check-in ───────────────►  Customer
                                                                   │
   /process-replies ◄──── unread replies (Gmail) ◄─────────────────┘
        │
        ├─ classify:  normal · injury/medical · angry/refund/human · unsubscribe
        ├─ act:       reply · escalate to a person · honor the unsubscribe
        ├─ check:     every claim is grounded in company/*.md before auto-send
        ├─ log:       conversations/{email}.md   (sentiment + answers)
        └─ notify:    Slack, with a link to any draft waiting on a human

   "Write the insights report" ──► reports/{date}-insights.md
```

**The brief is the program.** `CLAUDE.md` sets the voice ("no exclamation marks, no em dashes"), the offer logic (engaged users get the annual plan, dormant users get a trial extension), and the hard rules. `company/` holds the only facts an email is allowed to state. `.claude/commands/` holds the step-by-step procedures. To change how the campaign behaves, you edit a sentence.

**Two jobs in every conversation.** The agent is trying to *convert* the trial, and also to *learn*: what each person hoped would change, what got in the way, and whether the program fits their level. It works those questions in naturally, logs the answers, and the report rolls them up into themes, verbatim quotes and blockers.

### Guardrails

| Rule | How it's enforced |
|---|---|
| Only email people who opted in | Only rows with `send=yes` in `customers.csv` are in scope |
| Humans handle anything sensitive | Injury, anger, refund and "talk to a human" replies are always **saved as drafts** and never auto-sent, whatever `reply_mode` says |
| Don't invent facts or discounts | Before an auto-send, the reply is checked against `company/*.md`. A failed reply is rewritten once, then held as a draft for review |
| Never pester | No two outbound emails in a row without a reply in between. Processed mail gets a `Cadence/Processed` label so nothing is answered twice |
| Unsubscribe means now | The roster is updated before the confirmation goes out |
| Least privilege | `.claude/settings.json` allowlists the exact Gmail and Slack tools and denies `rm` and `curl` |

A few hard-won details live in the command files. Customers are matched by the thread a reply belongs to, not by its `From` address, because Gmail plus-aliases change on reply. Emails are sent as HTML, because plain text gets hard-wrapped into a narrow column.

---

## Repo map

```
CLAUDE.md                      Campaign brief: voice, offer logic, hard rules, logging
company/
  programs.md                  Product facts (session length, equipment, levels)
  policies.md                  Billing facts (trial, annual plan, refunds)
  escalation-playbook.md       Exactly how to handle sensitive replies
.claude/
  commands/send-outreach.md    /send-outreach   first email to everyone in scope
  commands/process-replies.md  /process-replies read and act on new replies
  commands/reset-gmail.md      /reset-gmail     clean the inbox between demo takes
  settings.json                Tool permissions for unattended runs
.mcp.json                      Gmail connection (google_workspace_mcp)
config/campaign.example.json   Mailbox, reply mode, Slack channel
customers.example.csv          Sample roster
scripts/
  run-once.sh                  Process replies once, headlessly
  poll.sh                      Run it every N seconds in the background (macOS)
  reset.sh                     Back to a clean slate
```

`conversations/`, `reports/`, `logs/`, your real `customers.csv` and `config/campaign.json` are gitignored, so customer data never ends up in the repo.

---

## Setup

You'll need Claude Code, [`uv`](https://docs.astral.sh/uv/), and a Gmail or Google Workspace mailbox to send from. Slack is optional.

1. **Configure.**
   ```bash
   cp config/campaign.example.json config/campaign.json   # set brand_mailbox
   cp customers.example.csv customers.csv                 # your roster
   cp customers.csv customers.seed.csv                    # what reset.sh restores
   ```
   Start with `"reply_mode": "draft"` so every reply waits for you in Gmail. Switch to `"auto-send"` once you trust it. Leave `slack_channel_id` empty to skip Slack.

2. **Connect Gmail.** Create a Google Cloud OAuth client (type *Desktop app*) and put the credentials in `.env`:
   ```bash
   GOOGLE_OAUTH_CLIENT_ID=...
   GOOGLE_OAUTH_CLIENT_SECRET=...
   ```
   Then run `claude` in this folder and ask it to list your Gmail labels. A browser window opens to authorize. Do this interactively once, because headless runs can't complete OAuth.

3. **Test without real customers.** Gmail plus-addresses all land in one inbox (`you+jordan@gmail.com`, `you+riley@gmail.com`), so you can play every customer yourself. Set `test_sender_filter` to that inbox so each poll skips your other mail.

## Running it

| Do this | With |
|---|---|
| Send the first round of check-ins | `claude` then `/send-outreach` |
| Handle new replies now | `/process-replies`, or `scripts/run-once.sh` |
| Handle replies automatically | `scripts/poll.sh start 600` (10 min). Use `30` for a live demo, and `scripts/poll.sh stop` when done |
| Get the research readout | Ask Claude: *"write the insights report"* |
| Start over | `scripts/reset.sh` |

---

## Taking it further

This version is meant to be easy to understand: one laptop, one inbox, files on disk. Those same choices limit it in production:

- **It only runs while your laptop is awake.** A missed night means slow replies in a 4-day window.
- **Polling wastes work.** Every tick is a full agent run, and almost all of them find nothing.
- **State is local files.** The conversation history and the unsubscribe list live on one machine.
- **Gmail is a personal inbox, not campaign infrastructure.** There's no bounce or spam-complaint handling and no automatic suppression list. Deliverability is limited, and replies have to be matched back to customers indirectly.

Two upgrades address these, and they work best together.

### 1. Run the agent on Claude Managed Agents

[Claude Managed Agents](https://platform.claude.com/docs/en/managed-agents/overview) hosts the agent loop and a sandboxed workspace for you. Almost every piece here has a direct counterpart:

| Today (local) | Hosted |
|---|---|
| `CLAUDE.md` and the command files | The agent's system prompt and skills, versioned on the platform |
| `scripts/poll.sh` (launchd) | A **scheduled deployment** that fires sessions on a cron, or a session started by a webhook |
| `conversations/`, `customers.csv` | A **memory store**: persistent documents mounted into every session (or an attached GitHub repo) |
| `.env`, local OAuth token | A **vault**. Secrets are injected on the way out, so the sandbox, and anything the agent writes, never sees them |
| `.claude/settings.json` allowlist | Per-tool **permission policies**, plus **limited networking** that allows only the hosts you list |
| `logs/process-replies.log` | Session transcripts in the Console, a record for every run, and a spending cap per session |

The catch is that hosted agents connect to MCP servers by URL. The Gmail server used here runs locally, so you'd either host it somewhere or swap the email layer, which leads to the next upgrade.

### 2. Use a transactional email service such as Postmark

[Postmark](https://postmarkapp.com) (or a similar service) replaces a personal inbox with infrastructure built for this:

- **Replies come to you.** Postmark's inbound processing POSTs every reply to your webhook as JSON, so you don't need to poll. Set each customer's `Reply-To` to `reply+{customer_id}@your-inbound-domain`, and the `MailboxHash` field tells you exactly who replied. That removes the thread-matching workaround. `StrippedTextReply` gives you only the new text, without the quoted history.
- **Suppression is automatic.** Bounces, spam complaints and unsubscribe-link clicks arrive as webhooks and stop future sends, so your roster stays in sync.
- **Better deliverability.** Use separate message streams for the campaign (broadcast) and the one-to-one replies (transactional), with proper domain authentication.
- **A plain HTTP API.** Sending is one authenticated POST, with `In-Reply-To` and `References` headers to keep threads intact. An agent can call it with nothing more than an API token.

Postmark has no "draft" concept, so the human-review path moves elsewhere. Escalations and failed groundedness checks go to a review queue, such as a Slack message with Approve and Edit buttons or a helpdesk ticket.

### 3. Both together

```
Customer replies ─► Postmark Inbound ─► webhook (a few lines of code)
                                          └─► starts a Managed Agents session
                                                ├─ reads roster + history     (memory store)
                                                ├─ replies via Postmark API   (token in vault,
                                                │                              egress limited to
                                                │                              api.postmarkapp.com)
                                                ├─ escalates to Slack         (human approves)
                                                └─ writes the conversation log (memory store)

Scheduled deployment, daily 9am  ─► check in with everyone reaching day 10
Scheduled deployment, Mondays    ─► insights report, graded against a rubric
Postmark bounce/unsubscribe hook ─► roster updated, no agent needed
```

The result is event-driven. You pay for an agent run only when a customer actually writes back, nothing depends on a laptop, credentials never enter the agent's environment, and the campaign brief is still the same plain-English Markdown you started with.
