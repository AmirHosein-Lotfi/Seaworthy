---
description: Pre-deploy security scan via Seaworthy (SAFE TO SHIP / CAUTION / DO NOT DEPLOY)
argument-hint: [path]
---

Run a Seaworthy scan against "$ARGUMENTS" if a path was given, otherwise against the
current repository. Follow the seaworthy skill's instructions exactly: run
scripts/scan.sh (or scan.ps1 on Windows), filter findings through
reference/false-positive-rules.md, then render the verdict banner and findings
in the skill's required report format.
