---
description: Write the research insights report from everything in conversations/, per CLAUDE.md's Reports section. Works the same in live and dry-run mode.
---

Write the insights report, exactly as the Reports section of `CLAUDE.md` describes it.

1. Read `CLAUDE.md`, then every file in `conversations/`, including the `ESCALATE-*` files. Ignore `.dry-run-processed.txt`.
2. Write `reports/{date}-insights.md` with: themes, verbatim quotes, top blockers to training, conversion likelihood per customer (high, medium, low) with one line of evidence each, and one recommended change to onboarding or the offer.
3. Quote customers verbatim and only from the logs. If a theme has no quote, say what is missing instead of paraphrasing a customer.
4. End by printing the report path and the top three themes. This command never contacts anyone.
