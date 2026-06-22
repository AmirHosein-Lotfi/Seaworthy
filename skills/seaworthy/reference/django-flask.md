# Django / Flask (experimental — v2 candidate)

> **Status: experimental.** Same caveat as `firebase.md` — shallower coverage,
> report with lower confidence, treat as a v2 hardening target.

## Debug mode

- Django: `DEBUG = True` in `settings.py` with no environment-variable gate
  around it. This is the single most common and most damaging Django
  misconfiguration in production — Django's debug error pages dump source code,
  local variables, and settings (including secrets) directly into the HTTP
  response.
- Flask: `app.run(debug=True)`, or `app.debug = True` set unconditionally.

## Auth checks

- Django: views with no `@login_required` (function-based) or no
  `LoginRequiredMixin` (class-based) performing a model `.save()`, `.delete()`,
  or `.update()`. Note Django REST Framework views use a different pattern
  (`permission_classes`) — check for that instead when `rest_framework` is in
  use.
- Flask: no `@login_required` (Flask-Login) or equivalent decorator on a route
  that performs a DB write via SQLAlchemy (`.add(`, `.delete(`, `.commit()`
  immediately following a mutation).

## Secrets

Django's `SECRET_KEY` hardcoded directly in `settings.py` (rather than loaded
from an environment variable) is a critical finding on its own — it's used for
session signing, password reset tokens, and CSRF protection, so its exposure is
more severe than a typical API key.
