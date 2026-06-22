# False-positive rules

This is the most important document in the skill. A security tool that cries wolf
gets ignored on the very next run — so every rule here exists to keep a "critical"
finding meaning something real. When in doubt, downgrade confidence and say so in
plain language rather than asserting a problem that might not exist.

These rules are enforced in two places that must stay in sync: the detector
scripts read `../scripts/lib/allowlist.json` directly (so path-allowlisting is
data, not duplicated logic), and Claude applies the judgment-based rules below
when rendering the final report. If you add a new path pattern, add it to
`allowlist.json`, not just here.

## Path allowlist (applies to every check)

Skip or downgrade-to-`info` any match under:
- `__tests__/`, `*.test.*`, `*.spec.*`, `tests/`, `fixtures/`
- `*.example*`, `*.sample*`
- `docs/`, `*.md`, `README*`
- `node_modules/`, `vendor/`, `.git/`, build output directories (`dist/`, `.next/`, `build/`)

A hardcoded-looking key inside a test fixture or a code sample in a README is not
a real finding. If a check would otherwise fire there, drop it entirely rather
than reporting it at a lower severity — it adds noise without adding signal.

## Secrets detection

- A match against `process.env.X`, `import.meta.env.X`, `os.environ[...]`, or
  similar environment-variable access patterns is the *safe* pattern, not a
  violation — never flag these.
- Only flag what looks like an actual literal value: a quoted string of
  plausible length/entropy assigned directly to a key/secret/password/token-named
  variable. `const apiKey = "changeme"` or `const apiKey = "your-key-here"` are
  placeholders, not real secrets — maintain a small list of obvious placeholder
  strings (`changeme`, `your-key-here`, `xxx`, `replace-me`, `<api-key>`) and skip
  them.

## `.env` / git history

- A `.env` that's gitignored *right now* is not automatically clean. Check
  `git log --all --diff-filter=A -- .env .env.local .env.production` — if it was
  ever added in a past commit, it's still a finding (`env-file-in-git-history`),
  even if a later commit deleted it and added it to `.gitignore`. The secret is
  still sitting in history.
- Conversely, don't flag `env-missing-from-gitignore` for a `.env.example` or
  `.env.sample` file — those are meant to be committed; they shouldn't contain
  real values, but their existence isn't the problem this check is for.

## Supabase / RLS

- **An anon key found in client-side code is never, by itself, a finding.** It is
  meant to be public — that's the entire design of Supabase's PostgREST model.
  The only thing that matters is whether RLS is confirmed enabled on the tables
  that key can reach. Emitting "anon key found" as a standalone critical would
  flag almost every legitimate Supabase app and destroy trust in the tool
  immediately. The check_id is specifically
  `supabase-anon-key-without-confirmed-rls` — the compound condition is the
  point, not an implementation detail.
- RLS can be enabled in a *different* migration file than the one that created
  the table (e.g. `0001_create_users.sql` then `0004_secure_tables.sql`). Scan
  **all** files under `supabase/migrations/` for `ENABLE ROW LEVEL SECURITY` on
  each table name found via `CREATE TABLE`, not just the creating file.
- RLS can also be toggled through the Supabase dashboard UI, which leaves no
  trace in the migrations directory at all. If a project has no migrations
  directory, or has one but it looks incomplete (tables referenced in code that
  never appear in any migration), do not assert RLS is disabled — report
  confidence as low and say plainly: "we couldn't determine RLS status for these
  tables from the code alone; please verify in your Supabase dashboard."
- A `service_role` key reference is only a finding when it appears in a path that
  looks like it ships to the browser (typical client/component directories, files
  marked `'use client'`, anything imported by a page component) — a `service_role`
  key used in a server-only file (API route, server action, edge function, a file
  explicitly named `*.server.*`) is the *correct* usage, not a finding.

## Auth-route checks

- Before flagging a route as missing an auth check, look for a positive signal
  first: `getServerSession`, `auth()`, `requireUser`, `currentUser()`, session
  middleware imports, `@login_required`, `verifyIdToken`, or equivalent for the
  detected framework. Absence of a keyword is weak evidence on its own — combine
  it with "and the route also performs a DB write/sensitive read" before flagging.
- Webhook receivers have their own legitimate auth pattern — signature
  verification, not a session check (`stripe.webhooks.constructEvent`,
  `verifySignature`, HMAC comparison against a request header). Recognize these
  and don't flag the absence of a *session* check on a route that's clearly
  verifying a signature instead.
- Allowlist common public-by-design route name patterns before flagging:
  `/api/health`, `/api/healthz`, `/api/og`, `/api/webhook(s)`, `/api/cron` (cron
  routes typically authenticate via a shared secret header, not a user session —
  check for that instead of a session check).
- If the auth pattern used genuinely isn't recognized (a custom or unusual auth
  setup), say so with lower confidence rather than asserting the route is
  unprotected — a custom `withAuth()` wrapper that the detector doesn't recognize
  by name is a missed positive-signal match, not necessarily a real vulnerability.

## CORS

- Wildcard origin (`*`) alone is frequently correct and intentional for a public,
  unauthenticated API — only flag the combination of wildcard *and* a credentials
  flag (cookies, `Authorization` header forwarding, `credentials: include` on the
  client side, or `credentials: true` in the CORS middleware config).

## General principle

If a check's confidence is anything less than "we are confident this is real,"
say so in the rendered report rather than rounding up to a confident-sounding
critical. "We found X but couldn't fully confirm Y — please check manually" is a
better outcome than a false alarm that erodes trust in every future scan.
