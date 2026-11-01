# Changelog

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
