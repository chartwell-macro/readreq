# Governance

`readreq` is currently maintainer-led.

## Roles

- Maintainers approve releases, public API changes, source-support decisions
  and security responses.
- Contributors propose code, documentation, fixtures and evidence.
- Independent reviewers reproduce new-release and parser evidence before a
  support claim or public release.

## Decisions

Routine fixes are decided through review. Changes to the observation schema,
status vocabulary, cache immutability, precedence policy, licensing posture or
supported-release definition require a written decision record under
`../decisions/`.

When source ambiguity cannot be resolved safely, the project prefers an
explicit unsupported status or typed error over a guessed value.

## Releases

A maintainer owns the release checklist. A release requires clean package
checks, documentation, source and fixture audits, performance evidence,
independent reproduction and a pinned commit. Tags are immutable and are never
moved after publication.

## Deprecation

Public functions and stable schema fields receive a documented deprecation
period before removal, except where continued behaviour would be unsafe or
materially incorrect. Parser-profile and supported-release changes are
recorded in `NEWS.md`.
