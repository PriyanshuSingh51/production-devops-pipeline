# Snyk Configuration

Snyk scans dependency manifests (`pom.xml`, `package.json`) on every PR and on a weekly
schedule via `.github/workflows/security-scan.yml`.

## Setup

1. Create a Snyk account and generate an API token.
2. Add it to the repo as the `SNYK_TOKEN` secret.
3. Snyk fails the pipeline on `--severity-threshold=high` findings (see workflow).

## Local usage

```bash
npm install -g snyk
snyk auth
snyk test --severity-threshold=high
snyk monitor   # tracks the project on snyk.io for ongoing alerts
```
