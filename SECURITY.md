# Security Policy

## Supported versions

Only the latest released version receives security updates.

| Version | Supported |
| ------- | --------- |
| 3.x     | ✅        |
| < 3.0   | ❌        |

## Reporting a vulnerability

Please report vulnerabilities privately via [GitHub private vulnerability reporting](https://github.com/futamura/TLDExtractSwift/security/advisories/new). Do **not** open a public issue for security problems.

Include:

- A description of the issue and its impact
- Steps to reproduce (input URLs or hostnames that trigger the problem are especially helpful)
- The library version and platform

You can expect an initial response within a week. Fixes are released as a new patch version; version tags are immutable, so a fix always means a new release.

## Scope

TLDExtractSwift parses hostnames against the Public Suffix List. In SPM builds the list is downloaded from publicsuffix.org at initialization unless `useFrozenData: true` is used; framework builds load a bundled copy. The most relevant vulnerability classes are incorrect extraction results (e.g. domain spoofing vectors), crashes or unbounded resource use on malicious input, and mishandling of the downloaded list data.
