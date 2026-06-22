# Contributing

The most valuable contribution is a new stack detector — Rails, Laravel, a
different cloud provider's storage config, whatever you've actually seen go
wrong. Here's the contract that keeps that easy to add and easy to review.

## Adding a new check or stack

1. **Add a detector script** at `skills/seaworthy/scripts/detectors/<name>.sh`.
   - Source `../lib/common.sh` and use its helpers — especially `search_repo`
     (content search) or `list_repo_files` (path-based checks — note the
     difference, a path pattern piped into `search_repo` will silently match
     nothing since that function greps file *contents*).
   - Emit findings with the `emit` helper:
     `emit "<check_id>" "<severity>" "<file>" "<line>" "<stack>" "<matched text>" "<confidence>"`.
   - Print nothing when there's nothing to report. Exit 0 even when findings
     exist — a finding is data, not a script failure.
   - Don't hardcode path exclusions or known-safe value lists inline; add them
     to `skills/seaworthy/scripts/lib/allowlist.json` so they're shared with
     every other detector and documented in `false-positive-rules.md` in one
     place. **Important:** that file is hand-parsed without requiring `jq` —
     keep exactly one array element per line, or the no-`jq` fallback parser
     in `common.sh` will silently misparse it.

2. **Add the check to the catalog**: an entry in
   `skills/seaworthy/reference/checks-catalog.md` with the same fixed shape as
   the existing entries — `title`, `what_we_found`, `why_it_matters` (in
   concrete, non-jargon terms — that's the entire point of this tool),
   `the_fix`, `fix_difficulty`, and `manual_fallback` (the exact command to run
   if the script can't execute).

3. **Add a fixture pair**: a deliberately vulnerable example under
   `tests/fixtures/vuln-<stack>-pattern/` and, if it's meaningfully different
   from an existing clean fixture, a corresponding clean one. Each fixture
   should be its own git repo (`git init && git add -A && git commit`) — some
   checks (git history, `.gitignore` coverage) need an actual repo to mean
   anything.

4. **Run `tests/run-fixture-tests.sh`** and add an `assert_present`/
   `assert_absent` line for your new fixture. All existing assertions must
   still pass — a new check should never start firing on the other fixtures.

5. **If the check needs real judgment** (confirming an absence, like "no auth
   check found" or "RLS not confirmed"), write down the false-positive traps
   you already know about in `reference/false-positive-rules.md` rather than
   letting the detector guess. A security tool that's wrong even occasionally
   gets ignored on every later run — false positives are a worse failure mode
   here than a missed detection, and the existing entries in that file are all
   real traps that were caught during this tool's own development. The
   `supabase-anon-key-without-confirmed-rls` entry's note on the anon key
   being public by design is the canonical example of why this matters.

6. Open a PR. Mention what real-world incident or pattern motivated the check,
   if there is one — that context belongs in the catalog entry's
   `why_it_matters` field, in plain language, not just in the PR description.

## Why scripts, not just SKILL.md instructions

Detection logic lives in small shell scripts rather than as freeform
instructions for Claude to improvise per stack, specifically so a contribution
is "add one file that emits the documented JSONL shape," not "rewrite a
paragraph of Markdown and hope the model's behavior doesn't drift between
runs." Judgment — filtering false positives, writing the plain-English
explanation, deciding the overall verdict — stays with Claude in `SKILL.md`,
where it belongs, since that's exactly the kind of contextual reasoning a
script can't do reliably.

## Running the tests

```
bash tests/run-fixture-tests.sh
```

This only tests the deterministic script layer (does `scan.sh` emit the right
`check_id`s). It does not test SKILL.md's prose rendering — for that, actually
install the skill and run it against a fixture, or ask Claude Code to do so
directly, and read the output.
