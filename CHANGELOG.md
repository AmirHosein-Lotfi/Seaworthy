# Changelog

## v1.0.0

Initial release. Checks: hardcoded secrets, `.env` in git history/gitignore
coverage, Supabase anon-key-without-RLS, service-role key client exposure,
partial RLS coverage, missing auth checks on API routes (Next.js/Node/Express),
wildcard CORS with credentials, debug mode in prod config, unprotected
admin/internal routes, public-write storage buckets.

Experimental, lower-confidence: Firebase rules check.

Documented but not yet implemented as detectors (reference docs only):
Django/Flask deeper auth coverage.
