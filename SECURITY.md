# Security Policy

## Supported versions

The latest TestFlight / App Store build of PromptVault is the only supported version. Previous TestFlight builds receive no fixes.

## Reporting a vulnerability

Please **do not** file public GitHub issues for security vulnerabilities.

Email: jiejuefuyou@gmail.com — subject line `SECURITY: PromptVault`. Expect an acknowledgement within 7 days. Coordinated disclosure preferred; we will work with you on a fix and credit you in the release notes if you wish.

## Scope

In scope:
- Code in this repository
- The build pipeline (GitHub Actions, fastlane, signing)
- The shipped app's handling of user-entered text and locally-stored state

Out of scope:
- Apple's StoreKit, App Store, and TestFlight infrastructure (report to Apple)
- iOS framework bugs not specific to our usage
- Issues requiring physical access to an unlocked device

## Threat model

PromptVault has no network surface and no user accounts. The realistic attack surface is:
- Crafted input in the choice/list-name text fields (length, encoding edge cases)
- Tampering with `promptvault_state.json` in the app's Documents directory by an attacker with filesystem access
- Supply-chain attacks against fastlane gems or the macos runner — covered by GitHub-hosted runner isolation and Bundler `Gemfile.lock` (TODO: pin once first CI run produces it)
