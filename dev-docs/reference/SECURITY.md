# Security policy

## Supported versions

Until the first public release, only the current default branch is eligible
for security fixes. After release, the project will document supported
versions here and in the release notes.

## Reporting a vulnerability

Do not open a public issue for vulnerabilities involving arbitrary file
writes, path traversal, cache poisoning, unsafe archive handling, credential
exposure or malicious workbook execution.

Use the repository's private security-advisory channel after the public remote
is configured. The `example.com` address currently present in `DESCRIPTION` is
a known placeholder and is not a valid security contact. The publication
checklist requires a monitored private contact before release.

Include:

- affected version or commit;
- minimal reproduction using non-sensitive synthetic data;
- expected and observed behaviour;
- likely impact and attack preconditions; and
- any suggested remediation.

Please allow maintainers time to reproduce, patch and coordinate disclosure.

## Security boundaries

`readreq` treats source workbooks and HTML as untrusted input. Downloads are
staged, format-checked and hashed before promotion. Parsers do not execute
macros, scripts or workbook formulas. Cache paths must remain package-owned
and content-addressed.
