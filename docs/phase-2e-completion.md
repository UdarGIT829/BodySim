# Phase 2E Completion: Promotion

Phase 2E turns a unanimously accepted council revision into a canonical,
visualizable exercise. In the Review Council, select an accepted frozen
revision and press **Promote accepted revision**.

## Transaction

`src/exercises/promotion.py` (`promote_revision`) runs one all-or-nothing
transaction:

1. **Exact revision.** The Godot side first re-hashes the frozen revision with
   the serializer that froze it (`ReviewRevisionStore.verify_revision_hash`);
   any edit after review blocks promotion. Python then checks the revision file,
   its recorded hash and the council record all refer to the same hash.
2. **Unanimous council.** Both `human_owner` and `openai_reviewer` must have
   voted `accept`; any `reject` blocks promotion.
3. **Re-validation.** The candidate gate is re-run against today's anatomy and
   catalog. The regenerated 466-muscle profile must equal the profile the
   council reviewed, or the definition must be re-frozen and re-reviewed. The
   gate also rejects ids already in the catalog.
4. **Staged write.** The exercise definition, its engagement profile
   (`profile_version: 1` plus a `promotion` provenance block), the media
   manifest entry for the new id, and the source record (`status: promoted`,
   `body_sim_exercise_ids`, and a `promotions` provenance entry with the
   authoring/review provider and model, never raw responses or keys) are
   staged in memory and validated together: every exercise has a profile
   covering exactly the 466 canonical muscles and a media entry, ids are
   unique, and no promoted source points at a missing exercise.
5. **Atomic commit.** Files are written to temporary siblings and renamed into
   place; if any rename fails, the files already replaced are restored. Each
   file keeps its existing formatting (the hand-formatted `exercises.json` is
   appended to, not rewritten), so a promotion's git diff shows only the new
   exercise.
6. **Audit record.** `data/exercises/authoring/promotions/<hash>.json` records
   the revision, exercise id, timestamp and before/after file checksums.
   Promoting the same revision again is a no-op.

Drafts, frozen revisions, reviews and votes are never modified.

## Running and verifying

```bash
python3 tools/exercises/run_promotion.py <revision_sha256> --dry-run   # validate only
python3 tools/exercises/run_promotion.py <revision_sha256>             # promote
python3 -m pytest tests/exercises/test_promotion.py                    # 13 unit tests
tools/exercises/verify_promotion.sh                                    # end-to-end in Godot
```

`verify_promotion.sh` copies the project to a temporary directory and, inside
it, freezes a real draft, records two accepting votes, checks that tampered
revisions fail verification, promotes through the Godot→Python bridge, checks
idempotence, and confirms the exercise selector shows the promoted exercise as
visualizable. The working tree is never modified.

## After promoting

Commit the changed `data/` files and push, then publish the web demo with
`tools/web/deploy_pages.sh`.

## Not in scope

- Re-promoting a new revision over an existing exercise id. The gate rejects
  existing ids, so a changed definition needs a new variant id; versioned
  replacement of an existing profile can come later.
- Saved workout summaries are not persisted yet, so there is nothing to pin;
  `profile_version` is recorded for when they are.
