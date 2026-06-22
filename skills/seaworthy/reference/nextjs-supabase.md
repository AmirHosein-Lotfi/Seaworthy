# Next.js + Supabase

This is the v1 priority stack — it's the exact combination behind the Moltbook
breach (Supabase anon key exposed client-side, RLS disabled) and matches the
shape of the Lovable incident closely enough (an authenticated-but-unauthorized
API route) to be the primary target for v1 detection.

## Identifying client-exposed code

Next.js convention: anything in a file marked `'use client'` at the top, anything
under `app/**/page.tsx` / `app/**/layout.tsx` without a clear server-only marker,
and anything imported transitively by those files, ends up in the browser bundle.
Environment variables prefixed `NEXT_PUBLIC_` are *designed* to be public — that's
expected and fine. The actual risk is a variable that is **not** `NEXT_PUBLIC_`-
prefixed (meaning the developer thought it was server-only) but is still
referenced from a client-marked file — that's an accidental exposure, not an
intentional one, and is a stronger signal than just "any key in client code."

Supabase client init usually lives in a predictable spot:
- `lib/supabase.ts`, `lib/supabase/client.ts`, `utils/supabase/client.ts` →
  client-side, should only ever use the anon key
- `lib/supabase/server.ts`, `utils/supabase/server.ts`, anything inside
  `app/api/**/route.ts` or a Server Action (`'use server'`) → server-side, where
  the service-role key is allowed

If a `service_role` string appears in a file matching the first pattern, or in any
file reachable from a `'use client'` boundary, that's
`supabase-service-role-key-client-exposed`.

## RLS (`#rls`)

Supabase migrations live under `supabase/migrations/*.sql`, applied in filename
order. To check RLS coverage correctly:

1. Collect every table name from `CREATE TABLE` (and `CREATE TABLE IF NOT EXISTS`)
   statements across **all** migration files, not just one.
2. Collect every table name that appears in an `ALTER TABLE {table} ENABLE ROW
   LEVEL SECURITY` statement, again across all migration files — the enabling
   statement is very often in a *later* migration than the table's creation.
3. Any table in set 1 but not set 2 is a candidate for
   `supabase-anon-key-without-confirmed-rls`, **provided** that table is actually
   reachable through client code using the anon key (cross-reference against
   Supabase client calls like `.from('{table}')` in client-marked files). A table
   that's never queried from client code isn't reachable via the anon key in
   practice, even without RLS — lower its severity/confidence accordingly rather
   than dropping it silently (it may still be queried via a service-role path
   you haven't seen, so still worth a mention at lower severity).
4. If there is no `supabase/migrations/` directory at all, or it looks
   incomplete relative to the tables referenced in code, report this as a
   low-confidence note rather than a confirmed critical: RLS may have been
   configured directly via the Supabase dashboard, which leaves no trace here.

The correct fix pattern to suggest:

```sql
alter table public.{table} enable row level security;

create policy "owner can read own rows"
  on public.{table}
  for select
  using (auth.uid() = user_id);
```

(Adjust the policy condition to match the actual ownership column — don't
suggest this exact SQL if the table doesn't have a `user_id`-shaped column; say
so and point at Supabase's RLS policy docs instead of guessing wrong.)

## Auth-route checks (`#auth-routes`)

Look in `app/api/**/route.ts` (route handlers) and Server Actions (`'use server'`
functions). Positive auth signals to look for before flagging an absence:
`auth()` (NextAuth/Auth.js), `getServerSession(...)`, a Supabase
`supabase.auth.getUser()` / `getSession()` call, or a custom `requireUser()`-style
helper. A route handler that calls `.insert(`, `.update(`, `.delete(`, or
`.upsert(` on a Supabase client with none of those signals present in the same
function is `auth-route-missing-check`.

Specifically watch for the Lovable-shaped bug: a route that *does* check the
requester is logged in, but then reads/writes a resource by an ID taken from the
URL or request body **without** checking that the logged-in user actually owns
that resource (e.g. `supabase.from('projects').select().eq('id', params.id)` with
no `.eq('user_id', session.user.id)` alongside it). This is subtler than a fully
missing auth check — flag it at medium confidence as a distinct note ("this route
checks login but not ownership") rather than silently treating "has *some* auth
check" as fully safe.
