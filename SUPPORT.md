# Support

## Start Here

- Setup and usage: [`README.md`](README.md)
- Architecture and security notes: [`docs/architecture.md`](docs/architecture.md), [`docs/open-source-security.md`](docs/open-source-security.md)
- Bugs and feature requests: GitHub Issues

## Use Security Reporting Instead Of Issues For

- credential disclosure
- auth bypasses
- token leakage
- workflow or release pipeline vulnerabilities
- any issue that should not be disclosed publicly yet

## Useful Bug Report Checklist

Include as many of these as you can:

- OS and shell
- whether the issue is in the CLI, iOS app, or both
- the exact command you ran, with secrets redacted
- relevant stderr/stdout output
- whether the issue reproduces with a fresh login via `reportkit auth --email ...`

## Scope Notes

- `REPORTKIT_SUPABASE_ANON_KEY` is public-by-design configuration, not a privileged secret.
- Access tokens, refresh tokens, APNs credentials, signing assets, and service-role keys should never be posted in public issues.
