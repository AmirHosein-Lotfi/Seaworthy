<div align="center">

# 🌊 Seaworthy

### One scan before you deploy. One straight answer: ship it or don't.

[![tests](https://github.com/AmirHosein-Lotfi/Seaworthy/actions/workflows/test.yml/badge.svg)](https://github.com/AmirHosein-Lotfi/Seaworthy/actions/workflows/test.yml)
[![license](https://img.shields.io/github/license/AmirHosein-Lotfi/Seaworthy)](LICENSE)
[![stars](https://img.shields.io/github/stars/AmirHosein-Lotfi/Seaworthy?style=social)](https://github.com/AmirHosein-Lotfi/Seaworthy/stargazers)

[فارسی](README.fa.md) · [Report a bug](https://github.com/AmirHosein-Lotfi/Seaworthy/issues) · [Add a stack](CONTRIBUTING.md)

</div>

---

On January 28, 2026, a social app called Moltbook went live. Its founder told everyone he hadn't written a single line of it himself: the whole thing was prompted into existence. Three days later someone found the database wide open. 1.5 million API tokens, 35,000 emails, plaintext passwords, all sitting behind a key that ships in every browser by design. Nobody had switched on the one setting that keeps that key from being a master password.

A few months after that, Lovable (a $6.6 billion company in this exact business) left customer source code and database credentials hanging out for **48 days**, because one API route checked if you were logged in but never checked if you were the *right* logged-in person.

Two different teams, two different products, the same dumb mistake wearing a different hat. It keeps happening because the people shipping these apps asked an AI to build them and have no particular reason to know what "row-level security" means, or why "logged in" and "allowed to do this" are two separate questions. Every security tool on the market is written for the engineer who already knows that. This one isn't.

## Who this is for

You vibe-coded something (a SaaS, a tool, a side project) mostly by talking to an AI assistant. You're about to run `vercel deploy` or push to `main`, and you have a nagging feeling you should check something first, except you don't know what "something" is. That's the entire audience. If you already do security reviews for a living, you don't need this. You need the [checks catalog](skills/seaworthy/reference/checks-catalog.md) for the regex patterns, and that's a five-minute read.

## What it actually does

It reads your code. It never runs it, never touches the network, and looks for the specific handful of mistakes that have actually taken real apps down within days of launch:

- A real API key or password typed straight into a file, or a `.env` that got committed and then "deleted" (it's still sitting in your git history)
- A Supabase table with no row-level security, reachable through the key your browser already has
- Your database's master key, the one that ignores every permission rule, sitting somewhere a browser can load it
- An endpoint that updates or deletes something with no check that the caller is allowed to touch it
- CORS wide open *and* accepting cookies, which is a different and worse problem than CORS wide open alone
- Debug mode quietly still on in what's supposed to be your production build
- An `/admin` route anyone can hit if they just guess the URL
- A storage bucket anyone on the internet can write files into

Then it tells you, in one of three ways:

```
✅ SAFE TO SHIP
⚠️  SHIP WITH CAUTION — 2 issues to fix first
🛑 DO NOT DEPLOY — 1 critical issue found
```

Every issue comes with the exact file and line, what an attacker actually gets if you ignore it, and how long the fix really takes. It skips the padding and the "consult a security professional" cop-out you get from most scanners.

## Where it helps

Right before you deploy, every time, the same way you'd check your mirrors before pulling out of a parking spot. Open a terminal in your project and run:

```
npx skills add AmirHosein-Lotfi/seaworthy@seaworthy && mkdir -p .claude/commands && curl -fsSL https://raw.githubusercontent.com/AmirHosein-Lotfi/Seaworthy/main/commands/sw.md -o .claude/commands/sw.md
```

That's the whole setup. It installs the skill itself, plus a `/sw` command for anyone who'd rather type something explicit than wait for Claude to notice on its own (`/sw ./apps/web` works too, if you want to point it at a subfolder). Either way, you can also just ask "is this safe to deploy?" or "can I push this to prod?", or don't ask at all: it's written to step in on its own right before anything deploy-shaped happens. See [examples/sample-output-blocked.md](examples/sample-output-blocked.md) and [examples/sample-output-safe.md](examples/sample-output-safe.md) for what a real scan actually prints.

On Windows PowerShell, run this instead:

```
npx skills add AmirHosein-Lotfi/seaworthy@seaworthy; New-Item -ItemType Directory -Force .claude/commands | Out-Null; Invoke-WebRequest https://raw.githubusercontent.com/AmirHosein-Lotfi/Seaworthy/main/commands/sw.md -OutFile .claude/commands/sw.md
```

## What it won't do

It's not a penetration test, and it won't catch a vulnerable npm package, a business-logic flaw three steps removed from the patterns above, or anything that requires watching your app run. It's the five-second gut check that would have stopped two very real, very avoidable breaches, nothing grander than that, and it says so out loud at the bottom of every report.

The full breakdown (every check, its severity, and the exact command to run by hand if you'd rather not trust a script) lives in [reference/checks-catalog.md](skills/seaworthy/reference/checks-catalog.md).

## How it's built

The detection itself is a handful of small, boring shell scripts (`skills/seaworthy/scripts/detectors/`) that each look for one thing and print one line of JSON per finding. No ripgrep, no `jq`, nothing beyond `git` and the tools every machine already has, which is also why this thing runs in seconds. The judgment calls (is this actually a real key or just a placeholder, could this auth check be a custom wrapper nobody's seen before) happen one layer up, not buried inside a regex. [reference/false-positive-rules.md](skills/seaworthy/reference/false-positive-rules.md) documents every one of those calls, because a security tool that's wrong even once stops getting trusted on the second run.

Four test fixtures back this up: two deliberately broken (one rebuilding the Moltbook bug, one rebuilding the Lovable bug), one with a little of everything, and one clean app that's required to come back with zero findings. Run them yourself:

```
bash tests/run-fixture-tests.sh
```

## Built for

Next.js and Supabase first, since that's the exact stack behind both incidents above, plus generic Node/Express. Firebase and Django/Flask have a start but are marked experimental on purpose: lower confidence until they've been through the same fixture treatment as everything else. Rails, Laravel, mobile, whatever you're running, [CONTRIBUTING.md](CONTRIBUTING.md) lays out exactly what a new detector needs, and it's a smaller PR than you'd think.

## License

MIT. Use it, fork it, ship it inside something you sell. See [LICENSE](LICENSE).
