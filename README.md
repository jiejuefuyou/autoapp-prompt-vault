# PromptVault

[![CI](https://github.com/jiejuefuyou/autoapp-prompt-vault/actions/workflows/ci.yml/badge.svg)](https://github.com/jiejuefuyou/autoapp-prompt-vault/actions/workflows/ci.yml)
[![Privacy: zero data](https://img.shields.io/badge/privacy-zero%20data%20collected-blue)](PRIVACY.md)
[![Platform](https://img.shields.io/badge/platform-iOS%2017%2B-lightgrey)]()
[![Swift](https://img.shields.io/badge/swift-5.9-orange)]()

> Save the AI prompts you actually use — for ChatGPT, Claude, Midjourney, ComfyUI, Coze. One offline vault for all of them.

The fourth product in the **AutoApp** experiment — an iOS portfolio of single-purpose, offline-first, privacy-respecting utilities developed end-to-end by an autonomous Claude Code agent. Validated against direct user behavior signal (B 站 AI content collection).

## Features

- Save prompts with title, body, and tags
- `{{variable}}` substitution with live preview before copying
- Search across titles, bodies, and tags
- One-tap copy with per-prompt usage statistics
- Pull-out tag filter for navigating large libraries
- 30 starter prompts free; 200+ curated in premium

## Pricing

- **Free** — 10 prompts, 3 tags per prompt
- **Premium** — one-time **$2.99** non-consumable IAP — unlimited prompts, full 200+ starter pack, unlimited tags, JSON import/export

## Privacy posture

Same as every AutoApp product:
- Zero network calls. Verifiable: `nm -gU PromptVault.app/PromptVault | grep -iE 'URL|HTTP|Network'` returns nothing.
- No analytics, no third-party SDKs.
- Privacy Manifest declares zero data collection.
- Your prompts never leave your device.

## Tech

| Layer | Choice |
|---|---|
| UI | SwiftUI (iOS 17+) |
| State | `@Observable` macro |
| Persistence | JSON in app sandbox |
| IAP | StoreKit 2 |
| Project | XcodeGen |
| Signing | fastlane match (shared `autoapp-certs`) |
| CI/CD | GitHub Actions on `macos-15` |

## Build locally

```sh
brew install xcodegen
xcodegen generate
open PromptVault.xcodeproj
```

The Debug build links against the bundled `StoreKitConfiguration.storekit` for local IAP testing — no App Store Connect setup required to test the paywall on simulator.

## Status

Phase 0 — scaffold complete, awaiting first TestFlight build. Driven by signal from `reports/concept-prompt-vault.md` in the orchestrator memory.

See [PRIVACY.md](PRIVACY.md) and [SECURITY.md](SECURITY.md).
