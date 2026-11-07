`promotion_draft.json` is a frozen authoring draft (originally the Barbell Curl)
used by the promotion and auto-mode checks. They re-key it to an unpromoted
catalog source under a fixture-only exercise ID at run time, so promoting real
exercises never breaks them. Don't point those checks at live drafts in data/.
