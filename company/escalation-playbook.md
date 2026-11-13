# Escalation playbook

Applies to the triggers already named in CLAUDE.md: injury/pain/medical condition, anger, refund request, "talk to a human" / explicit human request, and unsubscribe requests. This file is the "how", CLAUDE.md's Hard Rules is the "when".

## Injury, pain, or medical condition
Never suggest a program, exercise, or modification. Don't say "take it easy" or "maybe try Mobility Daily instead" — that's still training advice. Acknowledge, say a real person will follow up, stop.

Template shape (adapt, don't copy verbatim):
> Thanks for letting me know, and sorry to hear that. I don't want to guess at anything training-related here — someone from our team will follow up directly. Take the time you need.
>
> Sam from Cadence

Log to `conversations/ESCALATE-{email}.md` with the verbatim customer message, timestamp, and what triggered the escalation. Draft the acknowledgment only — never auto-send, regardless of the global reply-mode setting.

## Anger, refund request, "talk to a human"
Same shape: acknowledge, no defense of policy, no upsell, no offer. Don't explain the refund policy from `company/policies.md` in this reply — that's for a human to walk through.

Template shape:
> I hear you, and I'm sorry this hasn't gone well. I'm looping in a person from our team to sort this out with you directly — you shouldn't have to keep going back and forth with an email bot about it.
>
> Sam from Cadence

Log to `conversations/ESCALATE-{email}.md` same as above. Draft only, never auto-send.

## Unsubscribe request
Not a training/support escalation, but still time-sensitive: honor immediately by setting `send=no` for that row in `customers.csv` before doing anything else. One short confirmation reply, no offer, no questions. This one follows the normal reply-mode setting (draft or auto-send) like any other reply — it's not high-stakes the way injury/anger/refund are.

Template shape:
> Done — you won't get any more emails from us on this. Thanks for giving Cadence a try.
>
> Sam from Cadence

## Why the draft-only override exists for injury/anger/refund
These are the three cases where a wrong or tone-deaf automated reply does the most damage, and where a human is explicitly supposed to take over next per CLAUDE.md. The auto-reply routine should never be the thing that sends those words to a customer without a person reading them first, even if the general reply-mode setting is auto-send.
