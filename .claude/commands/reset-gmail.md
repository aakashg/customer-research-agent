---
description: Clear demo mail from the Cadence brand mailbox (`brand_mailbox` in config/campaign.json) so the next take starts from a clean inbox. Invoked by scripts/reset.sh — not part of the campaign itself.
---

Run this once per invocation. It should be safe to run on an already-clean mailbox (no-op) and safe to run repeatedly.

## Scope — read this first

This command touches exactly one mailbox: the `brand_mailbox` in `config/campaign.json`. It never touches any other account, and it never permanently deletes anything — the only Gmail MCP capability available here is adding the `TRASH` label, which Gmail keeps recoverable for ~30 days. It only acts on messages that match the campaign's own customer addresses or its own processed-label, never a blanket mailbox wipe.

It does not touch the personal Gmail inbox where customer replies are typed and sent from (that inbox isn't connected to this Gmail MCP). Re-seeding fresh replies there before the next take is still a manual step.

Every Gmail MCP tool call in this command passes that `brand_mailbox` as `user_google_email`. Never substitute another address.

## 1. Build the address list

Read `customers.csv` (`scripts/reset.sh` has already restored it from the seed file by the time this runs). Collect every email address in the file, not just `send=yes` rows — a customer could have been `send=no` in a prior take.

If the file is missing or has no rows, stop and report "nothing to clear — customers.csv has no addresses."

## 2. Find demo mail

Search the brand mailbox with `search_gmail_messages`, using `brand_mailbox` as `user_google_email`:

- One query per batch of addresses: `in:anywhere (to:{addr1} OR from:{addr1} OR to:{addr2} OR from:{addr2} ...)` — `in:anywhere` so this also catches drafts and sent mail, not just inbox.
- A second query: `label:Cadence/Processed` — catches anything already labeled, even if an address was later removed from the CSV.

Merge the results and de-duplicate by message ID.

If nothing matches, report "brand mailbox already clean" and stop — do not touch the label in step 4.

## 3. Trash the matches

For each matched message ID, call `modify_gmail_message_labels` with `add_label_ids: ["TRASH"]`. Do this one message at a time; if one call fails, continue with the rest and note the failure in the final report rather than stopping.

## 4. Clear the processed label

Call `list_gmail_labels` and check whether `Cadence/Processed` still exists. If it does, delete it with `manage_gmail_label` (`action: "delete"`). It gets recreated automatically the next time `/process-replies` runs, so removing it now just avoids stale state.

## 5. Report

One short summary: how many messages were trashed, whether the `Cadence/Processed` label was removed, and any individual failures from step 3. End with a reminder that the personal Gmail side still needs fresh replies typed and sent by hand before the next take.
