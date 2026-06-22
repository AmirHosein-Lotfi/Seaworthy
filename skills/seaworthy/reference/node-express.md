# Generic Node / Express

For apps that aren't on the Next.js + Supabase stack but are still a Node-based
API.

## Auth-route checks (`#auth-routes`)

Look at route definitions: `router.get/post/put/delete/patch(...)` and
`app.get/post/put/delete/patch(...)`. Positive auth signals before flagging an
absence: `passport.authenticate(...)`, `req.session.user`/`req.user` checks,
`jwt.verify(...)`, or a named middleware that's clearly auth-related
(`requireAuth`, `isAuthenticated`, `withAuth`) appearing either as router-level
middleware (`router.use(requireAuth)`) or inline in the handler's middleware
chain. Router-level middleware is easy to miss if you only look inside the
handler function itself — check both the handler and anything registered with
`.use()` earlier in the same router/file.

A handler that performs a DB write (look for ORM-shaped calls: `.create(`,
`.update(`, `.destroy(`, `.save(`, `.deleteOne(`, `.findOneAndUpdate(`, a raw SQL
`INSERT`/`UPDATE`/`DELETE`) with none of the above signals anywhere in its
middleware chain is `auth-route-missing-check`.

Webhook routes (look for `stripe.webhooks.constructEvent`, HMAC signature
comparisons, a route literally named `/webhook(s)`) authenticate via signature
verification, not a session — don't flag the absence of a session check there;
check for the signature-verification call instead.

## `.env` loading conventions

Node/Express apps almost always use the `dotenv` package
(`require('dotenv').config()` or `import 'dotenv/config'`) and load from a
`.env` file at the repo root. The same git-history and gitignore checks apply
(see `checks-catalog.md`) — there's no Node-specific nuance here beyond locating
the file, which is usually just `.env` / `.env.local` / `.env.production` at the
root or in a `config/` directory.

## CORS middleware

The common misconfiguration is `cors({ origin: '*', credentials: true })` — the
`cors` npm package will actually throw or behave inconsistently with this exact
combination in some versions, but plenty of hand-rolled middleware
(`res.setHeader('Access-Control-Allow-Origin', '*')` next to
`res.setHeader('Access-Control-Allow-Credentials', 'true')`) hits this without
the library catching it. Flag the combination wherever both headers/options
appear, regardless of whether it's via the `cors` package or hand-rolled.

## Debug mode

Look for `app.set('env', 'development')` hardcoded outside of an environment
check, `NODE_ENV` not being read at all (defaults can leave a framework in dev
mode), or framework-specific debug flags (e.g. `express-error-handler` or similar
packages configured to dump stack traces to the response body unconditionally).
