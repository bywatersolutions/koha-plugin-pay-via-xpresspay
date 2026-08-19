# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **A nightly cleanup of abandoned checkout tokens.** Tokens were only removed when a payment
  completed, so rows from checkouts that were started and abandoned accumulated forever. The
  plugin now implements Koha's `cronjob_nightly` hook (run daily by the packages out of the box)
  and removes tokens older than seven days.

### Fixed

- **The token table's foreign key constraint is now named uniquely.** All of ByWater's payment
  plugins named theirs `token_bn`, and constraint names are database-global — so installing a
  second payment plugin on the same instance failed with "Duplicate key on write or update".
  Existing installs are unaffected; fresh installs now use a per-plugin name.

### Added (testing)

- `t/db_dependent/PayViaXpresspay.t` — the plugin's first behavioural test — and CI now runs
  `prove` recursively with the plugin directory on the include path.
