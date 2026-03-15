# Patreon Login + Supabase Backend Integration

## Overview

Add a Patreon-based login system to the "How Janey Learned" mobile PWA, backed by Supabase. Logged-in Patreon members get access to exclusive games (Wordsky, Rootsky, Triviatsky), cross-device progress sync, score history, leaderboards, and streak tracking. Non-logged-in users continue to play free games (Bogglesky, Scramblisky, Snakesky, Fruitsky, Tetrisky) exactly as they do today.

## Game Tiers

| Tier | Games |
|---|---|
| Free (no login) | Bogglesky, Scramblisky, Snakesky, Fruitsky, Tetrisky |
| Patreon exclusive | Wordsky, Rootsky, Triviatsky |

- Free games are fully playable without any account.
- Patreon-exclusive games appear on the home screen with a lock icon overlay. Tapping a locked game shows a "Login with Patreon to play" prompt.
- Gating is configured in a single JS object so games can be moved between tiers by editing one line.

## Auth

### Provider

Supabase Auth with Patreon as an OAuth provider. Supabase manages sessions, tokens, refresh, and the `auth.users` table.

### Flow

1. User taps "Login with Patreon" (from locked game tile, home screen menu, or settings page).
2. `supabase.auth.signInWithOAuth({ provider: 'patreon', options: { redirectTo: window.location.origin + '/mobile/index.html' } })` redirects to Patreon consent screen.
3. Patreon redirects back to the Supabase callback URL, which then redirects to the `redirectTo` URL above.
4. Supabase creates or updates the user record and establishes a session (JWT stored in localStorage by the Supabase client).
5. On every page load, `auth.js` calls `supabase.auth.getSession()` to check login state. This is async — `auth.js` exposes an `authReady` Promise that resolves once the session check completes. All page-load logic (game tile rendering, redirect guards) must await `authReady` before checking `isLoggedIn()`. If a session exists, the user is treated as a Patreon member with full access.

### Session Persistence

The Supabase JS client handles session storage and automatic token refresh. Sessions persist across page reloads via localStorage (managed by Supabase, not custom code).

### Logout

Calling `supabase.auth.signOut()` clears the session. The user returns to the free-tier experience. Local localStorage game data is NOT cleared on logout — it remains as a local cache.

## Database Schema

All tables live in the Supabase PostgreSQL instance. Supabase Auth manages the `auth.users` table automatically; the tables below reference `auth.uid()`.

### user_settings

Stores per-user preferences. One row per user.

```sql
CREATE TABLE user_settings (
  user_id    UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  language   TEXT NOT NULL DEFAULT 'ru',
  theme      TEXT NOT NULL DEFAULT 'soviet',
  bg_mode    TEXT NOT NULL DEFAULT 'colors',
  bg_index   INT  NOT NULL DEFAULT 0,
  last_game  TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE user_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own settings"
  ON user_settings FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
```

### daily_game_state

Stores in-progress and completed state for daily games (Wordsky, Rootsky, Triviatsky). One row per user per game per language per date.

```sql
CREATE TABLE daily_game_state (
  user_id    UUID  NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  game       TEXT  NOT NULL,
  language   TEXT  NOT NULL DEFAULT 'ru',
  game_date  DATE  NOT NULL,
  state_json JSONB NOT NULL,
  phase      TEXT  NOT NULL DEFAULT 'playing',
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (user_id, game, language, game_date)
);

ALTER TABLE daily_game_state ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own daily state"
  ON daily_game_state FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
```

### session_scores

One row per completed game session (all games, free and exclusive). Used for score history and leaderboards.

```sql
CREATE TABLE session_scores (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  game            TEXT NOT NULL,
  language        TEXT NOT NULL DEFAULT 'ru',
  difficulty      TEXT,
  score           INT  NOT NULL,
  words_completed INT  DEFAULT 0,
  duration_secs   INT,
  seed            BIGINT,
  details_json    JSONB,
  played_at       TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_session_scores_user_game ON session_scores(user_id, game);
CREATE INDEX idx_session_scores_leaderboard ON session_scores(game, language, difficulty, score DESC);

ALTER TABLE session_scores ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users insert own scores"
  ON session_scores FOR INSERT
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Authenticated users read all scores"
  ON session_scores FOR SELECT
  USING (auth.role() = 'authenticated');
```

A single SELECT policy restricted to authenticated users. Anonymous/unauthenticated requests cannot read scores. Leaderboard access is further gated in the client (only shown to logged-in users).

### user_game_stats

Aggregated stats per user per game per language. Read-only from the client — updated exclusively by a database trigger on `session_scores` inserts. This prevents client-side score inflation.

```sql
CREATE TABLE user_game_stats (
  user_id        UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  game           TEXT NOT NULL,
  language       TEXT NOT NULL DEFAULT 'ru',
  games_played   INT  DEFAULT 0,
  best_score     INT  DEFAULT 0,
  total_score    BIGINT DEFAULT 0,
  current_streak INT  DEFAULT 0,
  best_streak    INT  DEFAULT 0,
  last_played    DATE,
  PRIMARY KEY (user_id, game, language)
);

ALTER TABLE user_game_stats ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users read own stats"
  ON user_game_stats FOR SELECT
  USING (auth.uid() = user_id);
```

The trigger that maintains this table:

```sql
CREATE OR REPLACE FUNCTION update_user_game_stats()
RETURNS TRIGGER AS $$
DECLARE
  prev_last_played DATE;
  prev_streak INT;
BEGIN
  -- Get current stats
  SELECT last_played, current_streak INTO prev_last_played, prev_streak
  FROM user_game_stats
  WHERE user_id = NEW.user_id AND game = NEW.game AND language = NEW.language;

  IF NOT FOUND THEN
    -- First time playing this game
    INSERT INTO user_game_stats (user_id, game, language, games_played, best_score, total_score, current_streak, best_streak, last_played)
    VALUES (NEW.user_id, NEW.game, NEW.language, 1, NEW.score, NEW.score, 1, 1, (NEW.played_at AT TIME ZONE 'UTC')::DATE);
  ELSE
    UPDATE user_game_stats SET
      games_played = games_played + 1,
      best_score = GREATEST(best_score, NEW.score),
      total_score = total_score + NEW.score,
      current_streak = CASE
        WHEN prev_last_played = (NEW.played_at AT TIME ZONE 'UTC')::DATE THEN current_streak  -- same day
        WHEN prev_last_played = (NEW.played_at AT TIME ZONE 'UTC')::DATE - 1 THEN current_streak + 1  -- consecutive
        ELSE 1  -- streak broken
      END,
      best_streak = GREATEST(best_streak, CASE
        WHEN prev_last_played = (NEW.played_at AT TIME ZONE 'UTC')::DATE THEN current_streak
        WHEN prev_last_played = (NEW.played_at AT TIME ZONE 'UTC')::DATE - 1 THEN current_streak + 1
        ELSE 1
      END),
      last_played = (NEW.played_at AT TIME ZONE 'UTC')::DATE
    WHERE user_id = NEW.user_id AND game = NEW.game AND language = NEW.language;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_update_user_game_stats
  AFTER INSERT ON session_scores
  FOR EACH ROW EXECUTE FUNCTION update_user_game_stats();
```

All date comparisons use UTC. The client does not need to pass a date — the server derives it from `played_at`.

### profiles

Public-facing user profile. Needed because `auth.users` is not accessible from client queries. Populated by a trigger on user creation. Display name comes from Patreon's `full_name` field in `raw_user_meta_data`.

```sql
CREATE TABLE profiles (
  user_id      UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT NOT NULL DEFAULT 'Player'
);

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Profiles are publicly readable"
  ON profiles FOR SELECT
  USING (true);
CREATE POLICY "Users update own profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Auto-create profile on user signup
CREATE OR REPLACE FUNCTION create_profile_on_signup()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (user_id, display_name)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'full_name', 'Player'));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_create_profile
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION create_profile_on_signup();
```

## New Files

### web/shared/supabase-config.js

Contains the Supabase project URL and anon key. These are public values safe for browser inclusion.

```javascript
var SUPABASE_URL = 'https://YOUR_PROJECT.supabase.co';
var SUPABASE_ANON_KEY = 'YOUR_ANON_KEY';
```

### web/shared/auth.js

Central auth module. Loaded after `supabase-config.js` and the Supabase JS client (loaded from CDN). Provides:

**Game gating config:**
```javascript
var PATREON_ONLY_GAMES = ['wordsky', 'rootsky', 'triviatsky'];
function isGameLocked(gameId) {
  return PATREON_ONLY_GAMES.includes(gameId) && !isLoggedIn();
}
```

**Session helpers:**
```javascript
var _supabase = null;
var _authReady = null; // Promise that resolves when session check completes
function getSupabase() { /* lazy-init supabase client */ }
var authReady = /* Promise — all page-load logic must await this before checking isLoggedIn() */;
function isLoggedIn() { /* returns boolean from cached session; only valid after authReady resolves */ }
function getUser() { /* returns user object or null */ }
function getDisplayName() { /* reads from profiles table; falls back to user.user_metadata.full_name */ }
async function loginWithPatreon() { /* supabase.auth.signInWithOAuth */ }
async function logout() { /* supabase.auth.signOut */ }
```

**Sync helpers (called from game code):**
```javascript
async function syncSettings(settings) { /* upsert to user_settings */ }
async function loadSettings() { /* fetch from user_settings, apply to localStorage */ }
async function syncDailyState(game, language, date, stateObj) { /* upsert to daily_game_state */ }
async function loadDailyState(game, language, date) { /* fetch from daily_game_state */ }
async function submitScore(game, language, scoreData) { /* insert to session_scores; user_game_stats updated automatically by DB trigger */ }
async function getLeaderboard(game, language, difficulty, limit) { /* query session_scores ordered by score */ }
async function getMyStats(game, language) { /* query user_game_stats */ }
```

All sync functions are fire-and-forget from the game's perspective — they write to Supabase in the background and do not block gameplay. Errors are caught and silently logged.

### web/mobile/profile.html

New page accessible from settings or home screen (when logged in). Displays:

- Patreon display name
- Per-game stats: games played, best score, total score
- Streak badges: current streak, best streak (for daily games)
- Links to per-game leaderboards

## Changes to Existing Files

### web/mobile/index.html

1. Add `<script>` tags for Supabase CDN client, `supabase-config.js`, and `auth.js` (after `engine.js`).
2. Add a login/logout button to the header area (next to the hamburger menu).
3. For each game tile, await `authReady` then check `isGameLocked(gameId)` on page load:
   - If locked: add a lock icon overlay and a CSS class `game-locked`. Click handler calls `loginWithPatreon()` instead of navigating to the game.
   - If unlocked: normal behavior.
4. On auth state change (Supabase callback), re-render game tiles to unlock/lock as needed.
5. If logged in, call `loadSettings()` on page load to sync settings from Supabase.

### web/mobile/settings.html

1. Add `<script>` tags for auth dependencies.
2. Add an "Account" section at the top:
   - Logged in: show display name, "View Profile" link, "Logout" button.
   - Not logged in: show "Login with Patreon" button.
3. On settings change (theme, language, etc.), if logged in, call `syncSettings()` in addition to the existing localStorage write.

### web/mobile/wordsky.html, rootsky.html, triviatsky.html (Patreon-exclusive games)

1. Add `<script>` tags for auth dependencies.
2. On page load: await `authReady`, then check `isLoggedIn()`. If not logged in, redirect to `index.html` (prevents direct URL access).
3. On game init: call `loadDailyState()` — if server has state and localStorage does not (new device), use server state; otherwise use localStorage as-is.
4. On state change (answer submitted, game phase change): call `syncDailyState()` to persist to Supabase.
5. On game end: call `submitScore()` with final score data.

### web/mobile/bogglesky.html, scramblisky.html, snakesky.html, fruitsky.html, tetrisky.html (free games)

1. Add `<script>` tags for auth dependencies.
2. On game end: if `isLoggedIn()`, call `submitScore()` with score data. If not logged in, do nothing (current behavior preserved).
3. No other changes — game logic, UI, and localStorage usage remain identical.

## Data Sync Strategy

### Conflict Resolution

localStorage is the primary source during gameplay. Supabase is the sync/backup layer.

- **Settings**: last-write-wins. On login, server settings overwrite local (assuming new device). On settings change, local is updated immediately, server is updated async.
- **Daily game state**: on page load, if localStorage has no state for today but server does, use server state. If both exist, use localStorage (user is mid-game on this device). On state change, write to both.
- **Scores**: append-only. No conflict possible — each game session generates a new row.
- **Stats**: computed server-side by a database trigger on `session_scores` inserts. The client has read-only access to `user_game_stats`.

### Offline Behavior

If Supabase is unreachable, all sync calls silently fail. The game continues to work via localStorage. Scores are not retried — if the network call fails, the score is lost from the server (but the game experience is unaffected). This is acceptable for v1; a queue could be added later.

## Leaderboards

- Per-game, per-language, optionally per-difficulty.
- Accessible from a "Leaderboard" button on game end screens (only shown to logged-in users).
- Shows top 20 entries: rank, display name, score, date.
- Query: `SELECT` from `session_scores` joined with `profiles` table for display names, ordered by `score DESC`, limited to 20.
- User's own best rank is highlighted if present.

## Streaks

- Tracked in `user_game_stats.current_streak` and `best_streak`.
- Updated when `submitScore()` is called for daily games (Wordsky, Rootsky, Triviatsky).
- Logic is handled by the `update_user_game_stats` database trigger (see schema). All date comparisons use UTC.
- Displayed on the profile page with visual badges at milestones (7, 30, 100 days).

## Supabase Client Loading

The Supabase JS client is loaded from CDN in each HTML file that needs auth:

```html
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.min.js"></script>
<script src="../shared/supabase-config.js"></script>
<script src="../shared/auth.js"></script>
```

This keeps the project bundler-free, consistent with the existing vanilla JS approach.

## Prerequisites

Before implementation:
1. Create a Supabase project at supabase.com (free tier).
2. Register a Patreon OAuth application at patreon.com/portal/registration/register-clients. Set the redirect URI to `https://YOUR_PROJECT.supabase.co/auth/v1/callback`.
3. In Supabase dashboard > Authentication > Providers, enable Patreon and enter the client ID and client secret. Also set the "Site URL" in Authentication > URL Configuration to the app's base URL (e.g., `https://yourapp.com/mobile/index.html`).
4. Copy the Supabase project URL and anon key into `supabase-config.js`.
5. Run the SQL schema (from the Database Schema section above) in the Supabase SQL editor.

## Out of Scope for v1

- Dictionary management via API (keep static JSON).
- Offline score queueing/retry.
- Progress-gated content (unlock games based on stats).
- Native iOS app migration to Supabase auth (keep existing Patreon flow in Swift).
- Admin dashboard for managing users or dictionaries.
- Real-time leaderboard updates (polling or manual refresh is fine).
