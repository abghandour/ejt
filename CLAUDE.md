# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

"How Janey Learned" — a collection of language-learning mini-games (Rootsky, Scramblisky, Bogglesky, Snakesky, Fruitsky, Triviatsky) supporting Russian, Portuguese, and Ukrainian. The project has two targets: a mobile-first PWA served as static HTML/JS/CSS, and a native iOS app (JTopGames) that wraps the same web games in a WKWebView with Patreon OAuth authentication.

## Commands

- **Serve locally:** `npm run serve` (starts Python HTTP server on port 3124, opens mobile index)
- **Run all tests:** `npm test` (runs vitest)
- **Run a single test file:** `npx vitest --run web/mobile/__tests__/fruitsky/game-state.unit.test.js`
- **Generate Xcode project:** `cd native/JTopGames && xcodegen generate` (uses project.yml)

## Architecture

### Web (`web/`)

- **`web/shared/`** — Shared engine and assets used by all games:
  - `engine.js` — Core shared module: audio engine (Web Audio API with iOS unlock), seeded RNG (mulberry32 `SeedEngine`), dictionary validation/loading, share utility, language/theme management
  - `theme.js` / `theme.css` / `base.css` — Theming system with per-language themes (soviet, brazil, etc.)
  - `languages.json` — Language registry defining available games, themes, letter pools, validation regexes, and dictionary paths per language
  - `dictionaries/` — JSON dictionaries organized by language (`ru/`, `pt-br/`, `uk/`) and by game type
- **`web/mobile/`** — Mobile PWA game pages, each a self-contained HTML file (e.g., `bogglesky.html`, `fruitsky.html`, `snakesky.html`). Game-specific engines live alongside (e.g., `fruitsky-engine.js`)
- **`web/desktop/`** — Desktop-specific pages (e.g., `russian-word-roots.html`, `cities.js`)

### Native iOS (`native/JTopGames/`)

- SwiftUI app (iOS 16+) wrapping the web games in WKWebView
- `GameWebView.swift` — WKWebView wrapper with loading/error overlays
- `JSBridge.swift` — JavaScript ↔ Swift communication bridge
- `LocalFileSchemeHandler.swift` — Custom URL scheme handler to serve local game files
- `AuthManager.swift` / `KeychainStore.swift` / `PatreonModels.swift` — Patreon OAuth flow
- `GameRegistry.swift` — Maps game IDs to their HTML files
- Built via XcodeGen (`project.yml`) or Swift Package Manager (`Package.swift`)

### Testing

Tests use Vitest with fast-check for property-based testing. Test files live in `__tests__/` directories alongside the code they test. The test pattern is `web/**/__tests__/**/*.test.js`.

## Key Conventions

- Web code is vanilla JS (no transpiler, no bundler) — all game HTML files are self-contained and include `engine.js` via script tag
- Games are designed mobile-first with `touch-action: manipulation` and iOS PWA meta tags
- The shared `SeedEngine` provides deterministic randomness for reproducible game states
- Dictionary entries are validated at load time via `isValidEntry()` using per-language regex from `languages.json`
- Audio uses Web Audio API with iOS-specific unlock pattern (silent buffer + resume on touch events)
