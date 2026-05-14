---
id: brandkit-usage-promptvault
title: "BrandKit Usage: PromptVault"
category: design-system
priority: p2
---

# BrandKit Usage — PromptVault

PromptVault brand: indigo `#734AE6` / deep `#1E1B4B` / gold `#FFD580`

## Colors

```swift
// Brand accent (replaces .accentColor where brand-specific tinting is needed)
Text("PromptVault").foregroundStyle(Color.brandPrimary)
Rectangle().fill(Color.brandSecondary)
Image(systemName: "sparkles").foregroundStyle(Color.brandTint)  // gold sparkle

// Semantic surfaces (same as existing Color(.secondarySystemBackground) usage)
RoundedRectangle(cornerRadius: Radius.md).fill(Color.surface)
Text("Secondary info").foregroundStyle(Color.onSurfaceSecondary)

// Status
Image(systemName: "checkmark").foregroundStyle(Color.success)
Text("Copy failed").foregroundStyle(Color.error)
```

## Typography

```swift
Text("PromptVault").font(Typography.h1)         // largeTitle rounded heavy
Text("My Prompts").font(Typography.h2)          // title rounded bold
Text("Section header").font(Typography.h3)      // title3 semibold
Text("Prompt body").font(Typography.body)
Text("Category label").font(Typography.bodyEmphasis)
Text("Hint text").font(Typography.caption)
Text("128").font(Typography.displayNumber)      // 56pt heavy rounded — prompt count
Text("GPT-4").font(Typography.monospace)        // code / model names
```

## Spacing

```swift
VStack(spacing: Spacing.md) { ... }             // 16 pt gap
.padding(.horizontal, Spacing.lg)               // 24 pt side padding
.padding(.vertical, Spacing.sm)                 // 8 pt vertical
HStack(spacing: Spacing.xs) { ... }             // 4 pt tight gap
```

## Corner radius

```swift
.cornerRadius(Radius.sm)                        // 6 — small chips / tags
.cornerRadius(Radius.md)                        // 12 — cards, buttons
.cornerRadius(Radius.lg)                        // 20 — sheets, modals
Capsule() // or .cornerRadius(Radius.pill)      // 999 — category pills
```

## Shadow / elevation

```swift
CardView()
    .brandCardShadow()                          // Elevation.card default
    .brandCardShadow(Elevation.hover)           // hover / focused state
```

## Migration guide

Replace scattered magic values with BrandKit tokens:

| Before | After |
|--------|-------|
| `Color.accentColor` (brand use) | `Color.brandPrimary` |
| `Color.accentColor.opacity(0.12)` | `Color.brandPrimary.opacity(0.12)` |
| `Color(.secondarySystemBackground)` | `Color.surface` |
| `Color(.tertiarySystemBackground)` | `Color.surfaceElevated` |
| `Font.system(.title)` | `Typography.h2` |
| `padding(16)` | `padding(Spacing.md)` |
| `.cornerRadius(14)` | `.cornerRadius(Radius.md)` |
| `.cornerRadius(8)` | `.cornerRadius(Radius.sm)` |
| `shadow(radius: 6)` | `.brandCardShadow()` |

**Rule: no new magic values in new code. Use BrandKit semantic tokens.**
