---
name: seaworthy
description: Pre-deploy security and secrets gate for AI-built ("vibe-coded") web apps. Scans the repo for the exact disaster pattern behind real 2026 breaches — hardcoded secrets, .env files committed to git history, Supabase Row Level Security disabled or unconfirmed, exposed service-role keys, API/serverless routes with no auth check before a database read or write, wildcard CORS combined with credentials, debug mode left on in production config, publicly-writable storage buckets, and unprotected admin routes. Produces a blunt, plain-English SAFE-TO-SHIP / SHIP-WITH-CAUTION / DO-NOT-DEPLOY verdict instead of an engineer-style audit report — built for someone who mostly prompted an AI to build their app and may not know what RLS or CORS even mean. Use this whenever the user asks "is this safe to deploy", "can I push this to production", "is my app secure enough to launch", "is my app seaworthy", "pre-launch check", "security check before deploy", "am I about to get hacked", or anything adjacent — and proactively run it before any deploy-shaped action (vercel deploy, git push to main/production, "let's launch") even if the user didn't explicitly ask for a security check.
---

# Seaworthy

Most security tools are written for engineers who already know what they're looking
at. This one isn't. It exists because the same disaster keeps repeating in 2026:
someone vibe-codes a real app, ships it, and it gets breached within days because
a database table had no access control or an API route would hand over anyone's
data to anyone who asked. Moltbook lost 1.5 million API tokens and 35,000 emails
three days after launch this way. Lovable, a $6.6B platform, left source code and
database credentials exposed for 48 days. Both came down to the same handful of
checks below.

This skill is not a full penetration test. It is a fast, static, no-network check
for the specific patterns that have actually sunk real launches — and a verdict
the person shipping can act on without needing a security background.

## When to run this

Run it whenever the user:
- Explicitly asks if their app/code is safe to deploy, secure, or "ready to launch"
- Is about to deploy, push to a production branch, or says anything like "let's
  ship this" / "ready to go live"
- Asks for a general code review right before a launch (run this in addition to
  whatever else they asked for)

Don't wait to be asked with the exact right words — if someone is clearly about to
put a vibe-coded app in front of real users, this check is cheap to run and the
cost of skipping it is exactly the kind of breach described above.

## How to run the scan

1. **Locate and run the scanner.** Prefer `scripts/scan.sh` (bash/WSL/macOS/Linux)
   or `scripts/scan.ps1` (native Windows PowerShell). Run it against the repo root:
   ```
   bash scripts/scan.sh <repo-root>
   ```
   or
   ```
   pwsh scripts/scan.ps1 -RepoRoot <repo-root>
   ```
   It prints one JSON object per line (JSONL) to stdout — one line per finding,
   zero lines if nothing was found. It makes no network calls and never modifies
   the scanned repo.

2. **If neither script can execute** (no shell available, sandboxed environment),
   fall back to running the individual checks yourself using the Grep/Glob/Bash
   tools directly. Every check in `reference/checks-catalog.md` lists the exact
   fallback command next to its description — use those verbatim rather than
   improvising new patterns, so results stay consistent with the documented
   severity model.

3. **Detect the stack** by looking for `package.json`, `supabase/` directory,
   `firebase.json`, `requirements.txt`, `Gemfile`, etc. This decides which
   reference doc's fix guidance to quote back at the user:
   - Next.js + Supabase → `reference/nextjs-supabase.md`
   - Generic Node/Express → `reference/node-express.md`
   - Firebase → `reference/firebase.md` (experimental in this version)
   - Django/Flask → `reference/django-flask.md` (experimental in this version)

4. **Filter findings through `reference/false-positive-rules.md` before reporting
   anything.** This step matters more than the scan itself. A security tool that
   cries wolf gets ignored on the next run, and these checks are written to be
   blunt on purpose — that only works if what survives filtering is real. Pay
   special attention to:
   - An exposed Supabase **anon** key alone is never a finding — it's public by
     design. It's only a finding when paired with disabled or unconfirmed RLS
     (`check_id: supabase-anon-key-without-confirmed-rls`).
   - "No auth check found" on a route needs a positive absence, not just a missing
     keyword — check the route isn't a webhook (signature-verified) or health check
     before flagging it.
   - A secret-shaped string inside a test fixture, `.example` file, or doc/README
     is not a real finding.
   - If RLS status genuinely can't be determined from the migrations present
     (e.g. it was toggled in the Supabase dashboard, not in a migration file),
     say so — "we couldn't confirm RLS is on or off for this table, check your
     dashboard" — rather than asserting it's a critical failure. Never turn an
     unknown into a false critical.

## How to report results — required format

Always render the report in this shape, in this order:

1. **One verdict banner at the top**, based on the *highest* severity present
   after filtering:
   - Any `critical` finding → `🛑 DO NOT DEPLOY — N critical issue(s) found`
   - No critical, but `high` or `medium` present → `⚠️ SHIP WITH CAUTION — N issue(s) to fix first`
   - Nothing → `✅ SAFE TO SHIP`

2. **Each finding**, sorted critical → high → medium (never bury a critical below
   a medium), rendered from its template in `reference/checks-catalog.md`:
   - A plain-English title (no jargon — "Your database has no lock on the door,"
     not "RLS policy missing")
   - What was found, with file and line
   - Why it matters, in concrete real-world terms — what an attacker could
     actually do, not an abstract CVSS-style description
   - The fix, and roughly how hard it is

3. **A closing line**: one sentence stating this checks for the most common
   vibe-coding disasters, not a full security audit, plus "run this again after
   you fix these." If the verdict was SAFE TO SHIP, keep this short and don't
   bury the good news under a wall of caveats.

Talk to the user the way you'd warn a friend, not the way a compliance report
reads. The whole point of this skill is that the person running it may not know
what RLS, CORS, or BOLA mean — translate every finding into what actually happens
to their users if they ship as-is.

## What this does NOT check

Say this explicitly when reporting, briefly: no dependency/CVE scanning, no
runtime or dynamic testing, no business-logic flaws beyond the patterns listed
above, no infrastructure-level checks (firewalls, VPCs). This is a fast first
gate, not a substitute for a real audit before something high-stakes.

## Severity model

Three tiers only, kept deliberately simple:

- **critical** — directly maps to the Moltbook/Lovable failure modes: exposed
  service-role key client-side, RLS disabled/unconfirmed on a table reachable via
  the anon key, hardcoded credentials in source, a publicly writable storage
  bucket, or an API route performing a database write with no auth check.
- **high** — wildcard CORS combined with credentials, debug mode in a production
  config, an admin/internal route reachable without auth, a `.env` found anywhere
  in git history even if it's gitignored now.
- **medium** — a secret-shaped file pattern missing from `.gitignore` (but nothing
  committed yet), partial RLS coverage, anything where confidence is genuinely
  uncertain rather than confirmed.

Full check-by-check detail, including every `check_id`, its template, and its
manual fallback command, lives in `reference/checks-catalog.md` — read that file
whenever you need the exact wording or detection logic for a specific check
rather than guessing from this summary.
