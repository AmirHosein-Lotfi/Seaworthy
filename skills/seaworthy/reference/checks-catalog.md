# Check catalog

Every check Seaworthy v1 runs, in one place. Each entry has a fixed shape so new
checks stay consistent as the catalog grows:

- `check_id` — the machine-readable id, emitted by the matching detector script
- `severity` — critical / high / medium (see SKILL.md for the model)
- `title` — the plain-English heading to use when reporting this finding
- `what_we_found` — template for the file:line description
- `why_it_matters` — the real-world consequence, in non-jargon terms
- `the_fix` — what to actually do
- `fix_difficulty` — a rough honest estimate, so people aren't scared off a 5-minute fix
- `manual_fallback` — the exact command to run if `scan.sh`/`scan.ps1` can't execute

When rendering a finding, fill in `{file}`, `{line}`, `{table}`, etc. from the
JSONL record. Never invent a finding that isn't backed by an actual scan result.

---

### `secrets-hardcoded`
- severity: critical
- title: "You have a real password or API key sitting in your code"
- what_we_found: "{file}:{line} — looks like a real secret, not a placeholder: `{matched}`"
- why_it_matters: "Anyone who can see this file — and if it's on GitHub, that's the whole internet — has the actual key. This is different from `process.env.X`, which is safe; this is the literal value typed into the file."
- the_fix: "Move the value into an environment variable (`.env`, never committed) and rotate the exposed key immediately — assume it's already been seen."
- fix_difficulty: "10 minutes, plus rotating the key with whoever issued it"
- manual_fallback: `rg -n "(api[_-]?key|secret|password|token)\s*[:=]\s*['\"][A-Za-z0-9_\-/+]{16,}['\"]" --glob '!*.test.*' --glob '!*.spec.*' --glob '!**/fixtures/**' --glob '!**/__tests__/**' --glob '!*.example*' --glob '!*.md'`

### `env-file-in-git-history`
- severity: high
- title: "A secrets file was committed to git at some point — even if it's gone now"
- what_we_found: "`{file}` appears in git history (added in a past commit)"
- why_it_matters: "Even if you deleted it and added it to `.gitignore` afterward, the old commit still has it. Anyone who clones the repo or already has, including on a public GitHub repo, can read it from history."
- the_fix: "Rotate every secret that was ever in that file. Deleting the file going forward isn't enough — the history needs scrubbing too (`git filter-repo` or BFG Repo-Cleaner) if the repo is or will be public."
- fix_difficulty: "Rotating secrets: 15 minutes. Scrubbing history: longer, only needed if the repo is public."
- manual_fallback: `git log --all --diff-filter=A --name-only | grep -E '(^|/)\.env($|\.[a-z]+$)'`

### `env-missing-from-gitignore`
- severity: medium
- title: "Your secrets file isn't protected from being committed by accident"
- what_we_found: "`{file}` exists but isn't covered by `.gitignore`"
- why_it_matters: "It hasn't leaked yet, but the next `git add .` could commit it without anyone noticing."
- the_fix: "Add it to `.gitignore` now, before it's ever committed."
- fix_difficulty: "1 minute"
- manual_fallback: `git check-ignore -v .env .env.local .env.production 2>&1 | grep -q . || echo "not ignored"`

### `supabase-anon-key-without-confirmed-rls`
- severity: critical
- title: "Your database has no lock on the door"
- what_we_found: "`{file}:{line}` — table `{table}` is reachable using your public anon key, and we could not confirm Row Level Security is enabled for it anywhere in `supabase/migrations/`"
- why_it_matters: "Your anon key is meant to be public — it ships in your browser JS on purpose. What's supposed to stop a stranger from reading or wiping every row is Row Level Security on the table. Without it, anyone who opens your browser's network tab can read or change your entire database. This is exactly the bug that exposed 1.5 million records in a real app within days of launch."
- the_fix: "Run `alter table {table} enable row level security;` then add a policy scoping access to the row owner. See `reference/nextjs-supabase.md#rls` for the exact pattern."
- fix_difficulty: "5–15 minutes, one SQL migration, no app code changes"
- manual_fallback: see `reference/nextjs-supabase.md#rls` for the migration-aware check — a plain grep for `enable row level security` is not reliable here because it can appear in a different migration file than the one that created the table.

### `supabase-service-role-key-client-exposed`
- severity: critical
- title: "Your master database key is exposed to every visitor's browser"
- what_we_found: "`{file}:{line}` — a Supabase `service_role` key is referenced from what looks like client-side code"
- why_it_matters: "The service-role key bypasses Row Level Security entirely — it's the master key. If it ships to the browser, every visitor effectively has full admin access to your database, no matter what your RLS policies say."
- the_fix: "Only ever use the service-role key on the server (API routes, server actions, edge functions) — never in a file that runs in the browser. Rotate the key now."
- fix_difficulty: "15–30 minutes to move the logic server-side, plus rotating the key"
- manual_fallback: `rg -n "service_role" --glob 'app/**' --glob 'components/**' --glob 'src/**' --glob '!**/*.server.*' --glob '!**/api/**'`

### `supabase-rls-partial-coverage`
- severity: medium
- title: "Some of your tables are locked, some aren't"
- what_we_found: "RLS is enabled for some tables but not for `{table}`, which is also reachable via the anon key"
- why_it_matters: "It's easy to assume RLS is 'on' for the project once you've enabled it somewhere — but it's per-table. One unlocked table is enough."
- the_fix: "Add the same RLS treatment to `{table}` as your other tables."
- fix_difficulty: "5 minutes"
- manual_fallback: compare the table list from `CREATE TABLE` statements against tables with a matching `ENABLE ROW LEVEL SECURITY` statement across all files in `supabase/migrations/`.

### `auth-route-missing-check`
- severity: critical
- title: "This endpoint hands out or accepts data with no login check"
- what_we_found: "`{file}:{line}` — route appears to read or write data with no auth check found in the same handler"
- why_it_matters: "Without a check that confirms who's asking, anyone who finds this URL can use it — read other people's data, or write/delete data they shouldn't be able to touch. This is the same root-cause shape as the bug that exposed a $6.6B vibe-coding platform's user data for 48 days."
- the_fix: "Add a session/auth check (e.g. `getServerSession`, `requireUser()`, `@login_required`) before the database call, and confirm the requester actually owns the resource being read or modified — not just that they're logged in as *someone*."
- fix_difficulty: "15–45 minutes depending on the auth library already in use"
- manual_fallback: see `reference/node-express.md#auth-routes` or `reference/nextjs-supabase.md#auth-routes` for the framework-specific positive-signal list (this check needs to confirm an auth call is *absent*, which is harder to grep reliably than confirming one is *present* — read the reference doc rather than improvising).

### `cors-wildcard-with-credentials`
- severity: high
- title: "Your API accepts requests from any website, with login cookies attached"
- what_we_found: "{file}:{line} — `Access-Control-Allow-Origin: *` combined with `credentials: true` (or equivalent)"
- why_it_matters: "Wildcard CORS alone is often fine for a public API. Combined with credentials, it means any other website can make authenticated requests to your API on a logged-in user's behalf."
- the_fix: "List specific allowed origins instead of `*` wherever credentials are involved."
- fix_difficulty: "10 minutes"
- manual_fallback: `rg -n "Access-Control-Allow-Origin.*\*" -A3 -B3 | rg -i "credentials"`

### `debug-mode-enabled-prod`
- severity: high
- title: "Debug mode looks like it's still on"
- what_we_found: "{file}:{line} — a debug flag is set to true in what looks like a production config"
- why_it_matters: "Debug mode often leaks stack traces, internal file paths, environment variables, or full request data to anyone who triggers an error."
- the_fix: "Make sure the flag is driven by an environment variable that's `false`/unset in production, not hardcoded `true`."
- fix_difficulty: "5 minutes"
- manual_fallback: `rg -n "DEBUG\s*=\s*True|debug:\s*true|app\.run\(.*debug=True"`

### `admin-route-unprotected`
- severity: high
- title: "There's an admin-looking page or route with no guard on it"
- what_we_found: "{file}:{line} — route path looks administrative/internal (`{path}`) with no auth check found"
- why_it_matters: "These routes usually exist for you, the builder — but if anyone can find the URL (and these are easy to guess), they can use it the same way you do."
- the_fix: "Add the same auth check used elsewhere in the app, restricted to admin users specifically, not just any logged-in user."
- fix_difficulty: "15–30 minutes"
- manual_fallback: `rg -n --glob '**/api/**' --glob '**/admin/**' "(admin|internal|debug)" -l`, then manually check each result for an auth/role check.

### `cloud-storage-public-write`
- severity: critical
- title: "A storage bucket is configured so anyone can upload or overwrite files in it"
- what_we_found: "{file}:{line} — bucket/IaC config grants public write access"
- why_it_matters: "Anyone can upload arbitrary files (including ones that look legitimate but aren't) or overwrite existing ones, on a bucket your app trusts."
- the_fix: "Restrict write access to authenticated server-side roles only; keep public access read-only if it needs to be public at all."
- fix_difficulty: "10–20 minutes"
- manual_fallback: `rg -n "allUsers|public-read-write|\"Principal\"\s*:\s*\"\*\"" --glob '*.tf' --glob 'serverless.yml' --glob 'next.config.*'`

### `firebase-rules-open` (experimental)
- severity: critical
- title: "Your Firebase rules let anyone read or write your data"
- what_we_found: "{file}:{line} — `allow ... if true` found in your security rules"
- why_it_matters: "This is Firebase's equivalent of disabled RLS — anyone can read or write the data covered by this rule, no login required."
- the_fix: "Replace `if true` with a condition tied to authentication, e.g. `if request.auth != null && request.auth.uid == resource.data.owner`."
- fix_difficulty: "10–20 minutes"
- manual_fallback: `grep -nE 'allow (read|write|read, write): if true' firestore.rules storage.rules`
- note: experimental check (see `reference/firebase.md`) — a *missing* rules file is deliberately not flagged, since that can mean either "locked by default" or "open," and static analysis can't tell which without seeing the deployed rules.

---

## Notes on confidence

Several checks above (`supabase-anon-key-without-confirmed-rls`, `auth-route-missing-check`)
are inherently about confirming an *absence* — RLS not enabled, an auth check not
present. Static analysis cannot always prove a negative with certainty (RLS could
be toggled outside any migration file; an auth check could be implemented in a way
the pattern list doesn't recognize). When a detector can't reach high confidence,
it should still emit the finding but mark `"confidence": "low"` or `"medium"` in
the JSONL record, and the report must say so explicitly ("we couldn't confirm X,
please check manually") rather than asserting a false critical. See
`reference/false-positive-rules.md` for the full list of guards.
