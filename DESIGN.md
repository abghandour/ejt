# Design

<!-- impeccable:design-schema 1 -->

## Direction

**Janey's Field Notes** recasts the home screen as a compact language expedition rather than a generic game dashboard. The player arrives at a daily dispatch, chooses a route, brings discoveries back to a field journal, and earns visible insignia for returning. The tone is editorial, warm, slightly handmade, and energetic without getting in the way of a short play session.

The visual evidence comes from the existing Korni theme: warm paper-like surfaces, strong ink contrast, Manrope display type, hard-edged poster color, and the megaphone cutout. Other language themes retain their own colors and display faces; the expedition system uses semantic theme colors rather than fixed brand colors.

## Visual System

- **Background:** the existing theme background remains the environmental layer. Korni adds one upright cut-paper megaphone as a decorative, non-interactive collage detail.
- **Surfaces:** `ExpeditionPanelModifier` is the shared notebook component. It uses a mostly opaque themed surface, an ink outline, and a low paper-shadow. It replaces the repeated translucent glass-card look in the redesigned hub, journal, and legacy game card.
- **Shape and type:** panels use the app's generous continuous 28-point card radius. Mastheads, labels, and game names use theme-aware display headings with compact uppercase tracking; instructional and progress copy uses normal text styles. Numeric XP and mission counts are monospaced where scanning matters.
- **Color:** one semantic accent carries the current route or action; success green marks completed stamps and journals; information color carries translations. Decorations stay deliberately low contrast so the play surface remains primary.
- **Controls:** home tools are 44-point circular targets. Native buttons, menus, sheets, search, and system symbols are retained where they improve familiarity.

## Home: Daily Dispatch

The home flow is ordered as a small ritual:

1. The masthead says **Janey's Field Notes**, identifies the selected language, and makes rank, progress to the next rank, and total XP immediately legible.
2. **Today's Dispatch** establishes the day and current streak, then gives Meddleysky a large, direct-launch “Daily Mix” feature card.
3. A **Field Passport** shows three live missions: play one round, collect eight distinct journal words, and visit three different game stations. Each row has a route icon, progress count, semantic progress bar, and a success seal when complete.
4. When Rootsky content is available, a compact **Word of the Day** dispatch offers a second purposeful entry point.
5. The remaining games live in a horizontal **Choose a Route** shelf of individual station cards instead of a paged card carousel. Each card carries its own icon, short description, direction mark, and existing score/streak context.

Mission progress is local and language-specific: completed `GameResultRecord`s supply rounds and distinct games, while distinct Word Book entries last seen today supply collected words. This lets the presentation update naturally after a round without introducing a separate daily-progress store.

## Field Journal

The former passive Word Book is a **Field Journal**. Its opening header frames the collection as words “safe” in the notebook and identifies the current language. Before the full collection, it may offer one lightweight review card:

- The candidate is the least-seen word, with oldest `lastSeen` as the tie-breaker.
- The player recalls first, then chooses **Reveal meaning**; that records one review for that presentation. Speech remains available when the language voice is installed.
- Saved words appear as tactile journal entries with source-game insignia, translation, seen count, and an accessible 44-point listen action.
- Search still covers both word and meaning; empty and no-result states remain explicit.

This is intentionally a local, gentle review cue rather than a new scheduling system or a destructive change to existing Word Book data.

## Progress Ceremonies

Rank and achievement changes are no longer hidden in profile or Game Center:

- A rank change produces a tappable **Rank Up** insignia banner with the English and native rank names.
- Locally unlocked achievements produce a **Stamp Earned** banner with a unique symbol, title, and meaningful explanation. Unlocks persist locally; milestones earned during the current launch wait for Game Center authentication and then report safely to that session's player.
- A banner is held briefly (3.8 seconds for rank, 4.6 seconds for achievement), can always be dismissed, and queues while a full-screen game is active. It presents after the player returns to the hub so play is never obscured.

## Game Stage Treatment

Every game now enters through `GameStageBackground`: the standard theme environment plus a low-contrast Canvas motif that makes the game recognizable before its board appears. Motifs are decorative, ignore hit testing, and are hidden from accessibility.

| Station | Stage mark | Mechanical character reinforced |
| --- | --- | --- |
| Bogglesky | outlined tile field | word-grid exploration |
| Scramblisky | offset letterpress blocks | rearranging physical letter pieces |
| Rootsky / Wordsky | branching ink paths | tracing roots and word families |
| Triviatsky | stacked rounded cards | a travel-dispatch / quiz dossier |
| Snakesky | winding sequence of dots | a route through letters |
| Slashsky | sweeping diagonal strokes | kinetic cuts through flying words |
| Tetrisky | sparse square grid | falling block construction |
| Meddleysky | concentric rings | a multi-stage mix and rising momentum |

The motif slowly drifts and rotates only when motion is allowed. It remains subdued under real game content, so it gives each station a signature without lowering legibility.

## Motion and Feedback

Motion is used to clarify causality, not to decorate every state change.

- The dispatch fades and rises into place on first appearance; its mission passport uses a short bouncy update when its data changes.
- Boggle tiles still enter in a stagger, pop and tilt as a path is formed, and shake for a wrong selection. Scramble tiles use a letterpress edge, small resting tilt, staggered entrance, used-state fade, and a deterministic burst on word transition.
- Snakesky interpolates the head between grid cells and leaves a soft fading trace instead of snapping at every tick.
- Tetrisky interpolates a falling tile between rows or columns, preserves the ghost destination, and gives the board a brief landing pulse.
- Existing gameplay signals continue to drive selection, success, and error haptics when the player's haptics setting is enabled. Existing confetti, game-specific sound, and end-state transitions remain part of the reward layer.

Shared timings live in `Design`: a short 0.14-second arcade step for board movement, a 0.25-second snappy response for state changes, a springy tile pop, and a slightly longer celebration spring for rank and home entry.

## Accessibility and Reduced Motion

- Reduce Motion removes the new stage drift, dispatch entrance travel, mission bounce, Snake/Tetris interpolation, and Tetrisky landing pulse. Existing games retain their established reduced-motion paths; new changes resolve directly or use a minimal opacity transition.
- Decorative motifs and Korni stickers are hidden from VoiceOver and never intercept input.
- Rank, mission, score, game launch, journal listen, and celebration controls carry explicit labels or combined descriptions. Celebration banners explain that tapping dismisses them.
- Progress is communicated in text as well as color (for example, `2/3` stamps and numeric rank progress). The hierarchy keeps the next action visible before decorative artwork.

## Implementation Anchors

- `Sources/Hub/HomeView.swift` — dispatch hierarchy, route shelf, missions, daily word, and Korni collage.
- `Sources/DesignSystem/ExpeditionPanel.swift` and `GameStageBackground.swift` — shared paper surface and station motifs.
- `Sources/Hub/WordBookView.swift` and `Sources/Persistence/WordBookService.swift` — journal and local review behavior.
- `Sources/App/RootView.swift` and `Sources/Services/AchievementService.swift` — queued rank/achievement ceremonies and persistent local unlocks.
- `Sources/Games/Snakesky/*` and `Sources/Games/Tetrisky/*` — continuous board movement; `Scramblisky/LetterRackView.swift` and `Bogglesky/BoggleCellView.swift` — tactile tile feedback.
