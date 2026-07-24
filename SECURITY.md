# Security Policy

## Reporting a vulnerability

Please **do not** open a public issue for security vulnerabilities.

Instead, report privately using GitHub's
[private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability)
on this repository (the **Security** tab → **Report a vulnerability**).

Please include:

- a description of the issue and its impact,
- the steps required to reproduce it,
- the action version affected.

We will acknowledge your report and keep you informed of the resolution.

## Scope

This action installs and runs [`google/go-licenses`](https://github.com/google/go-licenses)
at a pinned version and copies dependency licence files into your repository.
It does not require secrets and only writes inside the configured
`output-dir`. Reports about the pinned toolchain version, command injection
through inputs, or unexpected file writes are in scope.
