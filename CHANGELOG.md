# Changelog

## 0.4.3 - 2026-11-02

- Give each strict logger ownership of its file, eliminating the global file
  table's cross-instance data race and garbage-collection leak.
- Reopen the configured path reliably after log rotation, including when the
  replacement file already exists.
- Evaluate lazy messages once and isolate console failures from file output.
- Make buffered logging work with arbitrary level enums, validate its sink,
  and define behavior after finalization.
- Accept quotes and backslashes in custom formats without generated string
  mixins.
- Add behavioral regression tests and an LDC ThreadSanitizer CI gate.

## 0.4.2 - 2026-11-01

- Fix custom levels in `StyledStrictLogger` and `StyledBufferedLogger` by using
  the matching `IStyledLogger` interface and `StyleEnum.max`. Thanks to
  [@burjui](https://github.com/burjui) for reporting and fixing the strict
  logger case in
  [#7](https://github.com/NCrashed/dlogg/pull/7) and
  [#9](https://github.com/NCrashed/dlogg/pull/9).
- Update the optional `colorize` dependency to `~>1.0.5`.
- Support current DMD and LDC releases without deprecated `TickDuration` APIs,
  and replace the false-positive concurrency test with real worker completion
  waits.
- Add reproducible Nix builds and GitHub Actions coverage for the default and
  colorized configurations, including DScanner analysis.
- Document why `reload()` must be called outside a POSIX signal handler and
  provide a signal-safe flagging pattern for
  [#8](https://github.com/NCrashed/dlogg/issues/8).
