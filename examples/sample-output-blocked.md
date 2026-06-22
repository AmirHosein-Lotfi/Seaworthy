# Example: a real DO-NOT-DEPLOY verdict

This is Seaworthy's actual output against `tests/fixtures/vuln-moltbook-pattern` —
a minimal Next.js + Supabase app with the exact bug that breached Moltbook three
days after launch: an anon key used client-side, with no Row Level Security
confirmed on the table it queries.

---

🛑 DO NOT DEPLOY — 1 critical issue found

**1. Your database has no lock on the door**
- **Found:** `supabase/migrations` (table `users`, created in `0001_init.sql`) — your `users` table is reachable using your public anon key (used client-side in `app/page.tsx` via `lib/supabase/client.ts`), and Row Level Security was never turned on for it anywhere in `supabase/migrations/`.
- **Why it matters:** Your anon key is *supposed* to be public — it's sitting right there in your browser's JavaScript on purpose. What's supposed to stop a random stranger from reading or wiping out your entire `users` table is Row Level Security. Right now there's nothing. Anyone who opens their browser's network tab, or just calls your Supabase URL directly, can read every row in `users` — emails, IDs, everything in that table. This is exactly the bug that took down Moltbook: 1.5 million tokens and 35,000 emails pulled within three days of launch, same root cause.
- **The fix:** Run `alter table users enable row level security;` then add a policy that scopes access to the row owner (e.g. only let a user read their own row). No app code changes needed.
- **How hard:** 5–15 minutes, one SQL migration.

This only checks for the handful of disasters that have actually sunk real vibe-coded launches — hardcoded secrets, missing RLS, exposed service keys, unguarded routes, that kind of thing — not a full security audit. Fix the RLS issue above, then run this again before you ship.
