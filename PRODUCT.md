# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Users

Language learners who want a short, playful daily practice ritual. The primary use case is a phone session between other activities: choose a challenge, learn or reinforce words, and leave with a visible sense of progress.

## Product Purpose

How Janey Learned Russian turns vocabulary, roots, translation, and cultural trivia into short native iOS games. Success means a player returns for a daily challenge, remembers more words, and sees a growing personal record across the collection.

## Positioning

The product combines several language-learning game modes, a daily-puzzle cadence, adaptive arcade runs, speech, a saved word collection, and cross-game progression in one coherent ritual. The same words can be encountered, heard, collected, and revisited through different play styles.

## Operating Context

Players use portrait iPhone or iPad screens, often one-handed and in brief sessions. A home hub launches daily word/root/trivia challenges, score-driven arcade games, and Meddleysky runs. Completed words are retained in a searchable Word Book; local stats, streaks, ranks, achievements, Game Center, and optional reminders support return play.

## Capabilities and Constraints

- Native SwiftUI app targeting iOS 26 with Swift 6.2; no third-party UI framework.
- Supports Russian, Portuguese, and Ukrainian content, each with its own dictionaries and theme options.
- Existing gameplay, saved progress, premium gating, haptics, sound, speech, Game Center, and accessibility settings must remain functional.
- Game screens may be expressive and immersive; settings, search, sheets, and navigation retain familiar iOS behavior.

## Brand Commitments

- Product name: How Janey Learned Russian.
- Playful game naming ending in “-sky.”
- Existing Korni cut-paper collage, warm paper palette, megaphone artwork, Manrope type, and direct editorial voice are visual evidence to expand rather than discard.

## Evidence on Hand

- Game content and localized metadata: `native/HowJaneyLearnedRussian/Sources/Resources/languages.json`.
- Bundled Korni megaphone asset: `native/HowJaneyLearnedRussian/Sources/Resources/Assets.xcassets/korni-megaphone.imageset/`.
- Existing theme, sound, particle, rank, achievement, and Word Book implementations in `native/HowJaneyLearnedRussian/Sources/`.

## Product Principles

1. A completed round should feel like a small discovery, not merely a score update.
2. Every mechanic should strengthen language retention or the desire to return.
3. Each game earns a distinct physical and motion identity while the overall collection remains recognizably Janey.
4. Fast, understandable, interruption-tolerant play beats ornamental complexity.
5. Expression never hides status, controls, or accessibility feedback.

## Accessibility & Inclusion

Support Dynamic Type, VoiceOver, 44-point touch targets, contrast-aware themes, and an intentional Reduce Motion alternative for every expressive animation.
