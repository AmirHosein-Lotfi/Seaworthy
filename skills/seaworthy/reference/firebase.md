# Firebase (experimental — v2 candidate)

> **Status: experimental.** This doc exists so Firebase apps get *some* coverage
> in v1, but the detection here is shallower and less false-positive-tested than
> the Next.js/Supabase and Node/Express docs. Report Firebase findings with
> explicitly lower confidence and say so in the output. Treat this as a starting
> point for v2 hardening, not a finished check.

## Security rules

Look for `firestore.rules` and `storage.rules` at the project root.

- `allow read, write: if true;` (in any form, including split `allow read: if
  true;` / `allow write: if true;`) on any path is the equivalent of
  `supabase-anon-key-without-confirmed-rls` — open access to that collection/path
  for anyone.
- **Important false-positive trap**: a missing rules file does not reliably mean
  "open" or "locked" — it depends on which mode the project was created in.
  Projects created in newer Firebase versions often default to locked-down rules
  even without an explicit file checked into this repo (rules can be deployed
  separately from the app code, similar to Supabase's dashboard-only RLS case).
  If no rules file is present in the repo, report this as "we couldn't find your
  Firestore/Storage rules in this repo to check them — please verify directly in
  the Firebase console" rather than asserting either pass or fail.

## API keys

Firebase web API keys are meant to be public (similar to Supabase's anon key) —
don't flag a Firebase config object with an `apiKey` field as a finding on its
own. The actual security boundary is the rules files above, not the key.
