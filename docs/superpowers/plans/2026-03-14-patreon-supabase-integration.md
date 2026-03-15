# Patreon + Supabase Integration — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Patreon login via Supabase to the "How Janey Learned" PWA so subscribers can sync settings, save scores, view leaderboards, and track streaks — while all games remain playable by everyone.

**Architecture:** Supabase handles auth (Patreon OAuth), database (PostgreSQL with RLS), and client queries. A new `auth.js` shared module provides session management and sync helpers. Each game HTML file gets three `<script>` tags added and a single `submitScore()` call at game end. No bundler, no server code — everything runs client-side against the Supabase REST API.

**Tech Stack:** Supabase JS client v2 (CDN), PostgreSQL (Supabase-hosted), Patreon OAuth, vanilla JS

**Spec:** `docs/superpowers/specs/2026-03-14-patreon-login-backend-design.md`

---

## Chunk 1: Database Setup + Core Auth Module

### Task 1: Run SQL Schema in Supabase

**Files:**
- Create: `web/shared/supabase-schema.sql` (reference copy of the full schema)

This task is manual — run in the Supabase SQL editor. The file is kept in the repo as documentation.

- [ ] **Step 1: Create the schema file**

```sql
-- =============================================
-- Supabase schema for How Janey Learned
-- Run this in Supabase SQL Editor (supabase.com > SQL)
-- =============================================

-- Profiles (public-facing, auto-created on signup)
CREATE TABLE profiles (
  user_id      UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT NOT NULL DEFAULT 'Player'
);
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Profiles are publicly readable" ON profiles FOR SELECT USING (true);
CREATE POLICY "Users update own profile" ON profiles FOR UPDATE
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

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

-- User settings
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
CREATE POLICY "Users manage own settings" ON user_settings FOR ALL
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Daily game state
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
CREATE POLICY "Users manage own daily state" ON daily_game_state FOR ALL
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Session scores
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
CREATE POLICY "Subscribers insert own scores" ON session_scores FOR INSERT
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Anyone can read scores" ON session_scores FOR SELECT
  USING (true);

-- User game stats (read-only from client, updated by trigger)
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
CREATE POLICY "Users read own stats" ON user_game_stats FOR SELECT
  USING (auth.uid() = user_id);

-- Trigger: auto-update stats on score insert
CREATE OR REPLACE FUNCTION update_user_game_stats()
RETURNS TRIGGER AS $$
DECLARE
  prev_last_played DATE;
  prev_streak INT;
BEGIN
  SELECT last_played, current_streak INTO prev_last_played, prev_streak
  FROM user_game_stats
  WHERE user_id = NEW.user_id AND game = NEW.game AND language = NEW.language;

  IF NOT FOUND THEN
    INSERT INTO user_game_stats (user_id, game, language, games_played, best_score, total_score, current_streak, best_streak, last_played)
    VALUES (NEW.user_id, NEW.game, NEW.language, 1, NEW.score, NEW.score, 1, 1, (NEW.played_at AT TIME ZONE 'UTC')::DATE);
  ELSE
    UPDATE user_game_stats SET
      games_played = games_played + 1,
      best_score = GREATEST(best_score, NEW.score),
      total_score = total_score + NEW.score,
      current_streak = CASE
        WHEN prev_last_played = (NEW.played_at AT TIME ZONE 'UTC')::DATE THEN current_streak
        WHEN prev_last_played = (NEW.played_at AT TIME ZONE 'UTC')::DATE - 1 THEN current_streak + 1
        ELSE 1
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

- [ ] **Step 2: Run the SQL in Supabase dashboard**

Go to supabase.com > your project > SQL Editor > paste the contents of `web/shared/supabase-schema.sql` > Run.

- [ ] **Step 3: Commit**

```bash
git add web/shared/supabase-schema.sql
git commit -m "feat: add Supabase schema reference file"
```

---

### Task 2: Create supabase-config.js

**Files:**
- Create: `web/shared/supabase-config.js`

- [ ] **Step 1: Create the config file**

```javascript
var SUPABASE_URL = 'https://yegbudbzbsnrwcjtygro.supabase.co';
var SUPABASE_ANON_KEY = 'sb_publishable_3Gm24GXAfwQIGdz4UG3FBQ_MpFB438U';
```

- [ ] **Step 2: Commit**

```bash
git add web/shared/supabase-config.js
git commit -m "feat: add Supabase config with project URL and anon key"
```

---

### Task 3: Create auth.js — Core Auth Module

**Files:**
- Create: `web/shared/auth.js`

This is the central module. It provides session management, subscriber checks, mock mode, and all sync/query helpers. Every other task depends on this file.

- [ ] **Step 1: Create auth.js**

```javascript
/* ===== AUTH MODULE ===== */
/* Supabase session management, subscriber checks, sync helpers */
/* Load after: supabase CDN client, supabase-config.js, engine.js */

var _supabase = null;
var _session = null;
var _mockMode = false;

// Check mock mode (localhost only)
(function() {
  try {
    var host = window.location.hostname;
    if (host === 'localhost' || host === '127.0.0.1') {
      var params = new URLSearchParams(window.location.search);
      if (params.get('mock_subscriber') === 'true') {
        _mockMode = true;
      }
    }
  } catch(e) {}
})();

function getSupabase() {
  if (!_supabase) {
    _supabase = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  }
  return _supabase;
}

// authReady resolves once the session check completes.
// All page-load logic must await this before calling isLoggedIn()/isSubscriber().
var authReady = (function() {
  if (_mockMode) {
    _session = { mock: true };
    _displayName = 'Debug User';
    return Promise.resolve();
  }
  return getSupabase().auth.getSession().then(function(result) {
    _session = result.data.session;
    // Fetch display name from profiles table
    if (_session && _session.user) {
      return getSupabase().from('profiles')
        .select('display_name')
        .eq('user_id', _session.user.id)
        .single()
        .then(function(res) {
          if (res.data) _displayName = res.data.display_name;
        }).catch(function() {});
    }
  }).catch(function() {
    _session = null;
  });
})();

// Listen for auth state changes (e.g. after OAuth redirect)
(function() {
  if (_mockMode) return;
  getSupabase().auth.onAuthStateChange(function(event, session) {
    _session = session;
  });
})();

function isLoggedIn() {
  return _mockMode || _session !== null;
}

function isSubscriber() {
  return isLoggedIn();
}

function getUser() {
  if (_mockMode) return { id: 'mock-user-id', user_metadata: { full_name: 'Debug User' } };
  return _session ? _session.user : null;
}

function getUserId() {
  var u = getUser();
  return u ? u.id : null;
}

var _displayName = null;

function getDisplayName() {
  if (_mockMode) return 'Debug User';
  return _displayName || (getUser() && getUser().user_metadata && getUser().user_metadata.full_name) || 'Player';
}

async function loginWithPatreon() {
  var redirectTo = window.location.origin + '/mobile/index.html';
  return getSupabase().auth.signInWithOAuth({
    provider: 'patreon',
    options: { redirectTo: redirectTo }
  });
}

async function logout() {
  await getSupabase().auth.signOut();
  _session = null;
}

// ===== SETTINGS SYNC =====

async function syncSettings(settings) {
  if (!isSubscriber()) return;
  try {
    await getSupabase().from('user_settings').upsert({
      user_id: getUserId(),
      language: settings.language,
      theme: settings.theme,
      bg_mode: settings.bg_mode,
      bg_index: settings.bg_index,
      last_game: settings.last_game || null
    });
  } catch(e) { console.warn('syncSettings failed:', e); }
}

async function loadSettings() {
  if (!isSubscriber()) return null;
  try {
    var result = await getSupabase().from('user_settings')
      .select('*').eq('user_id', getUserId()).single();
    if (result.data) {
      // Apply to localStorage
      if (result.data.language) setActiveLanguage(result.data.language);
      if (result.data.theme) hjlrSetTheme(result.data.theme);
      if (result.data.bg_mode) hjlrSetBgMode(result.data.bg_mode);
      if (typeof result.data.bg_index === 'number') {
        try { localStorage.setItem('hjlr_bgidx', String(result.data.bg_index)); } catch(e) {}
      }
      if (result.data.last_game) {
        try { localStorage.setItem('hjlr_last_game', result.data.last_game); } catch(e) {}
      }
    }
    return result.data;
  } catch(e) { console.warn('loadSettings failed:', e); return null; }
}

function getCurrentSettings() {
  return {
    language: getActiveLanguage(),
    theme: hjlrGetTheme(),
    bg_mode: hjlrGetBgMode(),
    bg_index: parseInt(localStorage.getItem('hjlr_bgidx') || '0', 10),
    last_game: localStorage.getItem('hjlr_last_game') || null
  };
}

// ===== DAILY GAME STATE SYNC =====

async function syncDailyState(game, language, date, stateObj, phase) {
  if (!isSubscriber()) return;
  try {
    await getSupabase().from('daily_game_state').upsert({
      user_id: getUserId(),
      game: game,
      language: language,
      game_date: date,
      state_json: stateObj,
      phase: phase || 'playing'
    });
  } catch(e) { console.warn('syncDailyState failed:', e); }
}

async function loadDailyState(game, language, date) {
  if (!isSubscriber()) return null;
  try {
    var result = await getSupabase().from('daily_game_state')
      .select('state_json, phase')
      .eq('user_id', getUserId())
      .eq('game', game)
      .eq('language', language)
      .eq('game_date', date)
      .single();
    if (!result.data) return null;
    return { state: result.data.state_json, phase: result.data.phase };
  } catch(e) { console.warn('loadDailyState failed:', e); return null; }
}

// ===== SCORE SUBMISSION =====

async function submitScore(game, language, scoreData) {
  if (!isSubscriber()) return;
  try {
    await getSupabase().from('session_scores').insert({
      user_id: getUserId(),
      game: game,
      language: language,
      difficulty: scoreData.difficulty || null,
      score: scoreData.score,
      words_completed: scoreData.words_completed || 0,
      duration_secs: scoreData.duration_secs || null,
      seed: scoreData.seed || null,
      details_json: scoreData.details || null
    });
  } catch(e) { console.warn('submitScore failed:', e); }
}

// ===== LEADERBOARD =====

async function getLeaderboard(game, language, difficulty, limit) {
  limit = limit || 20;
  try {
    var query = getSupabase().from('session_scores')
      .select('score, played_at, user_id, difficulty')
      .eq('game', game)
      .eq('language', language)
      .order('score', { ascending: false })
      .limit(limit);
    if (difficulty) query = query.eq('difficulty', difficulty);
    var result = await query;
    if (!result.data || result.data.length === 0) return [];

    // Fetch display names for all user_ids
    var userIds = [];
    result.data.forEach(function(r) {
      if (userIds.indexOf(r.user_id) === -1) userIds.push(r.user_id);
    });
    var profiles = await getSupabase().from('profiles')
      .select('user_id, display_name')
      .in('user_id', userIds);
    var nameMap = {};
    if (profiles.data) {
      profiles.data.forEach(function(p) { nameMap[p.user_id] = p.display_name; });
    }

    return result.data.map(function(r, i) {
      return {
        rank: i + 1,
        display_name: nameMap[r.user_id] || 'Player',
        score: r.score,
        played_at: r.played_at,
        is_me: r.user_id === getUserId()
      };
    });
  } catch(e) { console.warn('getLeaderboard failed:', e); return []; }
}

// ===== USER STATS =====

async function getMyStats(game, language) {
  if (!isSubscriber()) return null;
  try {
    var result = await getSupabase().from('user_game_stats')
      .select('*')
      .eq('user_id', getUserId())
      .eq('game', game)
      .eq('language', language)
      .single();
    return result.data || null;
  } catch(e) { console.warn('getMyStats failed:', e); return null; }
}

async function getAllMyStats() {
  if (!isSubscriber()) return [];
  try {
    var result = await getSupabase().from('user_game_stats')
      .select('*')
      .eq('user_id', getUserId());
    return result.data || [];
  } catch(e) { console.warn('getAllMyStats failed:', e); return []; }
}
```

- [ ] **Step 2: Commit**

```bash
git add web/shared/auth.js
git commit -m "feat: add auth.js — Supabase session, sync helpers, mock mode"
```

---

## Chunk 2: Home Screen + Settings Integration

### Task 4: Add Auth Scripts + Login Button to index.html

**Files:**
- Modify: `web/mobile/index.html`

- [ ] **Step 1: Add script tags after engine.js**

Find `<script src="../shared/engine.js"></script>` and add immediately after it:

```html
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.min.js"></script>
<script src="../shared/supabase-config.js"></script>
<script src="../shared/auth.js"></script>
```

- [ ] **Step 2: Add login/logout button to the hamburger menu**

Find `<nav id="hamburger-menu" role="menu">` and add as its first child:

```html
<a href="#" role="menuitem" id="menu-auth" style="display:none">
  <svg viewBox="0 0 24 24"><path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z"/></svg>
  <span id="menu-auth-label">Login with Patreon</span>
</a>
```

Also find `<nav id="hamburger-menu-game" role="menu">` and add as its first child:

```html
<a href="#" role="menuitem" id="menu-auth-game" style="display:none">
  <svg viewBox="0 0 24 24"><path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z"/></svg>
  <span id="menu-auth-game-label">Login with Patreon</span>
</a>
```

- [ ] **Step 3: Add auth initialization to the init flow**

At the end of the `<script>` block (before the closing `</script>` tag), add:

```javascript
// Auth: show login/logout in menus, sync settings on load
authReady.then(function() {
  var authBtn = document.getElementById('menu-auth');
  var authLabel = document.getElementById('menu-auth-label');
  var authBtnGame = document.getElementById('menu-auth-game');
  var authLabelGame = document.getElementById('menu-auth-game-label');

  function updateAuthUI() {
    if (isSubscriber()) {
      var name = getDisplayName() || 'Player';
      authLabel.textContent = name + ' (Logout)';
      authLabelGame.textContent = name + ' (Logout)';
    } else {
      authLabel.textContent = 'Login with Patreon';
      authLabelGame.textContent = 'Login with Patreon';
    }
    authBtn.style.display = '';
    authBtnGame.style.display = '';
  }

  updateAuthUI();

  authBtn.addEventListener('click', function(e) {
    e.preventDefault();
    closePickerMenu();
    if (isSubscriber()) { logout().then(function() { updateAuthUI(); }); }
    else { loginWithPatreon(); }
  });
  authBtnGame.addEventListener('click', function(e) {
    e.preventDefault();
    closeGameMenu();
    if (isSubscriber()) { logout().then(function() { updateAuthUI(); }); }
    else { loginWithPatreon(); }
  });

  // Sync settings from server on login
  if (isSubscriber()) {
    loadSettings().then(function() {
      updateLangFlags();
      // Re-init with synced language if it changed
      var syncedLang = getActiveLanguage();
      var lc = getLanguageConfig(syncedLang);
      if (lc) {
        filteredGames = GAMES.filter(function(g) { return lc.games.indexOf(g.id) !== -1; }).map(function(g) {
          var override = resolveGameName(syncedLang, g.id);
          if (override) return Object.assign({}, g, { name: override.name || g.name, desc: override.desc || g.desc });
          return g;
        });
        N = filteredGames.length;
        currentIndex = 0;
        var lastId = getLastPlayed();
        if (lastId) {
          for (var i = 0; i < filteredGames.length; i++) {
            if (filteredGames[i].id === lastId) { currentIndex = i; break; }
          }
        }
        buildCards();
        setCarouselTransition(true);
        updateCarousel();
      }
    });
  }
});
```

- [ ] **Step 4: Test locally**

Run: `npm run serve`
Open: `http://localhost:3124/mobile/index.html`
Verify: hamburger menu shows "Login with Patreon" item.
Open: `http://localhost:3124/mobile/index.html?mock_subscriber=true`
Verify: hamburger menu shows "Debug User (Logout)".

- [ ] **Step 5: Commit**

```bash
git add web/mobile/index.html
git commit -m "feat: add auth scripts and login/logout to index.html menus"
```

---

### Task 5: Add Account Section to settings.html

**Files:**
- Modify: `web/mobile/settings.html`

- [ ] **Step 1: Add script tags after engine.js**

Find `<script src="../shared/engine.js"></script>` and add immediately after it:

```html
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.min.js"></script>
<script src="../shared/supabase-config.js"></script>
<script src="../shared/auth.js"></script>
```

- [ ] **Step 2: Add Account section HTML**

Find `<h1>Settings</h1>` and add immediately after it:

```html
<div id="account-section" style="display:none;margin-bottom:24px;padding:16px;border-radius:12px;background:var(--bg-card);border:1px solid var(--border-subtle);">
  <div class="section-label">Account</div>
  <div id="account-logged-out" style="display:none">
    <button id="btn-login" style="width:100%;padding:12px;font-family:'Roboto Condensed',sans-serif;font-weight:700;font-size:14px;background:var(--accent);color:var(--bg-primary);border:none;border-radius:8px;cursor:pointer;">Login with Patreon</button>
    <div style="margin-top:8px;font-size:12px;color:var(--text-secondary);text-align:center;">Sync settings, save scores, and view leaderboards</div>
  </div>
  <div id="account-logged-in" style="display:none">
    <div style="display:flex;align-items:center;gap:10px;margin-bottom:12px;">
      <svg viewBox="0 0 24 24" style="width:24px;height:24px;fill:var(--accent);flex-shrink:0"><path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z"/></svg>
      <span id="account-name" style="font-size:16px;font-weight:700;color:var(--text-primary)"></span>
    </div>
    <div style="display:flex;gap:8px;">
      <a href="./profile.html" id="btn-profile" style="flex:1;padding:10px;text-align:center;font-family:'Roboto Condensed',sans-serif;font-weight:700;font-size:13px;background:var(--bg-primary);color:var(--accent);border:1px solid var(--accent);border-radius:8px;text-decoration:none;cursor:pointer;">View Profile</a>
      <button id="btn-logout" style="flex:1;padding:10px;font-family:'Roboto Condensed',sans-serif;font-weight:700;font-size:13px;background:transparent;color:var(--text-secondary);border:1px solid var(--border-subtle);border-radius:8px;cursor:pointer;">Logout</button>
    </div>
  </div>
</div>
```

- [ ] **Step 3: Add auth logic at the end of the script block**

Before the closing `</script>` tag, add:

```javascript
// Auth: show account section, sync settings on change
authReady.then(function() {
  var section = document.getElementById('account-section');
  var loggedOut = document.getElementById('account-logged-out');
  var loggedIn = document.getElementById('account-logged-in');

  section.style.display = '';

  if (isSubscriber()) {
    loggedOut.style.display = 'none';
    loggedIn.style.display = '';
    document.getElementById('account-name').textContent = getDisplayName() || 'Player';
    document.getElementById('btn-logout').addEventListener('click', function() {
      logout().then(function() { window.location.reload(); });
    });
  } else {
    loggedOut.style.display = '';
    loggedIn.style.display = 'none';
    document.getElementById('btn-login').addEventListener('click', function() {
      loginWithPatreon();
    });
  }
});

// Sync settings to Supabase on any change.
// Uses the existing postMessage events (themeChange, bgModeChange, languageChange)
// that settings.html already fires to the parent window.
// We hook them here to also sync to Supabase.
function trySyncSettings() {
  authReady.then(function() {
    if (isSubscriber()) syncSettings(getCurrentSettings());
  });
}

// Hook theme card clicks — the existing buildThemeGrid click handlers call hjlrSetTheme
// and postMessage. We listen for postMessage from self (same window) as the sync trigger.
window.addEventListener('message', function(e) {
  if (e.data && (e.data.type === 'themeChange' || e.data.type === 'bgModeChange' || e.data.type === 'languageChange')) {
    trySyncSettings();
  }
});
// Settings page sends postMessage to parent, but is also the sender — listen on self.
// Additionally, for direct settings changes within the page (not via postMessage),
// hook the theme card and bg button click handlers by calling trySyncSettings after a short delay:
document.addEventListener('click', function(e) {
  if (e.target.closest('.theme-card') || e.target.closest('.bg-btn') || e.target.closest('.lang-card')) {
    setTimeout(trySyncSettings, 100);
  }
});
```

- [ ] **Step 4: Test locally**

Run: `npm run serve`
Open: `http://localhost:3124/mobile/settings.html?mock_subscriber=true`
Verify: Account section shows "Debug User" with Profile and Logout buttons.
Open without mock: verify "Login with Patreon" button appears.

- [ ] **Step 5: Commit**

```bash
git add web/mobile/settings.html
git commit -m "feat: add account section and settings sync to settings.html"
```

---

## Chunk 3: Session Game Integration (Score Submission)

### Task 6: Add Score Submission to Bogglesky

**Files:**
- Modify: `web/mobile/bogglesky.html`

- [ ] **Step 1: Add auth script tags**

Find `<script src="../shared/engine.js"></script>` and add immediately after it:

```html
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.min.js"></script>
<script src="../shared/supabase-config.js"></script>
<script src="../shared/auth.js"></script>
```

- [ ] **Step 2: Add submitScore call inside endGame()**

Find the `endGame()` function. After the `showEndModal()` call inside it, add:

```javascript
// Submit score for subscribers
authReady.then(function() {
  if (isSubscriber()) {
    submitScore('bogglesky', getActiveLanguage(), {
      score: game.score,
      difficulty: game.difficulty,
      words_completed: game.wordsFound.length,
      duration_secs: game.difficulty === 'easy' || game.difficulty === 'medium' ? 120 : 120,
      details: { wordsFound: game.wordsFound.map(function(w) { return w.word; }) }
    });
  }
});
```

- [ ] **Step 3: Commit**

```bash
git add web/mobile/bogglesky.html
git commit -m "feat: add score submission to bogglesky"
```

---

### Task 7: Add Score Submission to Scramblisky

**Files:**
- Modify: `web/mobile/scramblisky.html`

- [ ] **Step 1: Add auth script tags** (same 3 lines as Task 6, after engine.js)

- [ ] **Step 2: Add submitScore call inside endGame()**

Find the `endGame()` function. After the `showEndModal()` call inside it, add:

```javascript
authReady.then(function() {
  if (isSubscriber()) {
    submitScore('scramblisky', getActiveLanguage(), {
      score: game.score,
      difficulty: game.difficulty,
      words_completed: game.wordsCompleted,
      duration_secs: 90,
      details: { wordsSkipped: game.wordsSkipped, wrongAttempts: game.wrongAttempts }
    });
  }
});
```

- [ ] **Step 3: Commit**

```bash
git add web/mobile/scramblisky.html
git commit -m "feat: add score submission to scramblisky"
```

---

### Task 8: Add Score Submission to Snakesky

**Files:**
- Modify: `web/mobile/snakesky.html`

- [ ] **Step 1: Add auth script tags** (same 3 lines)

- [ ] **Step 2: Add submitScore call inside gameOver()**

Find the `gameOver()` function. After the `showDeathModal()` call inside it, add:

```javascript
authReady.then(function() {
  if (isSubscriber()) {
    submitScore('snakesky', getActiveLanguage(), {
      score: state.score,
      difficulty: state.difficulty,
      words_completed: state.wordsCompleted,
      duration_secs: Math.round((Date.now() - state.startTime) / 1000),
      seed: state.seed,
      details: { completedWords: state.completedWords.map(function(w) { return w.word; }) }
    });
  }
});
```

- [ ] **Step 3: Commit**

```bash
git add web/mobile/snakesky.html
git commit -m "feat: add score submission to snakesky"
```

---

### Task 9: Add Score Submission to Fruitsky

**Files:**
- Modify: `web/mobile/fruitsky.html`

- [ ] **Step 1: Add auth script tags** (same 3 lines)

- [ ] **Step 2: Add submitScore call inside showGameOver()**

Find the `showGameOver()` function. At the end of the function body (before its closing `}`), add:

```javascript
authReady.then(function() {
  if (isSubscriber()) {
    submitScore('fruitsky', getActiveLanguage(), {
      score: gameState.score,
      words_completed: gameState.wordsCompleted,
      duration_secs: 60,
      details: { totalSynonymsSlashed: gameState.totalSynonymsSlashed }
    });
  }
});
```

- [ ] **Step 3: Commit**

```bash
git add web/mobile/fruitsky.html
git commit -m "feat: add score submission to fruitsky"
```

---

### Task 10: Add Score Submission to Tetrisky

**Files:**
- Modify: `web/mobile/tetrisky.html`

- [ ] **Step 1: Add auth script tags** (same 3 lines)

- [ ] **Step 2: Add submitScore call inside gameOver()**

Find the `gameOver()` function. After the `showDeathModal()` call inside it, add:

```javascript
authReady.then(function() {
  if (isSubscriber()) {
    submitScore('tetrisky', getActiveLanguage(), {
      score: state.score,
      difficulty: state.difficulty || 'medium',
      words_completed: state.wordsCompleted,
      duration_secs: Math.round((Date.now() - state.startTime) / 1000),
      details: { completedWords: state.completedWords.map(function(w) { return w.word; }) }
    });
  }
});
```

- [ ] **Step 3: Commit**

```bash
git add web/mobile/tetrisky.html
git commit -m "feat: add score submission to tetrisky"
```

---

## Chunk 4: Daily Game Integration (State Sync + Score Submission)

### Task 11: Add State Sync + Score Submission to Wordsky

**Files:**
- Modify: `web/mobile/wordsky.html`

- [ ] **Step 1: Add auth script tags** (same 3 lines after engine.js)

- [ ] **Step 2: Add daily state loading on game init**

Find where the game loads saved state from localStorage (look for the `saveGameState` function and its callers). After the existing localStorage load on game init, add a Supabase fallback:

```javascript
// After existing localStorage state load, before game starts rendering:
// If no local state for today, try loading from server
authReady.then(function() {
  if (isSubscriber()) {
    var todayStr = gameState.date; // YYYYMMDD format
    var isoDate = todayStr.substring(0, 4) + '-' + todayStr.substring(4, 6) + '-' + todayStr.substring(6, 8);
    var localKey = 'wordsky_state_' + todayStr;
    var hasLocal = false;
    try { hasLocal = !!localStorage.getItem(localKey); } catch(e) {}
    if (!hasLocal) {
      loadDailyState('wordsky', getActiveLanguage(), isoDate).then(function(result) {
        if (result && result.state) {
          // Apply server state — save to localStorage and reload
          try { localStorage.setItem(localKey, JSON.stringify(result.state)); } catch(e) {}
          window.location.reload();
        }
      });
    }
  }
});
```

- [ ] **Step 3: Add state sync on save**

Find the existing `saveGameState()` function. After the `localStorage.setItem` call inside it, add:

```javascript
// Sync to Supabase
if (typeof isSubscriber === 'function' && isSubscriber()) {
  var isoDate = state.date.substring(0, 4) + '-' + state.date.substring(4, 6) + '-' + state.date.substring(6, 8);
  var phase = state.completed ? 'finished' : 'playing';
  syncDailyState('wordsky', getActiveLanguage(), isoDate, state, phase);
}
```

- [ ] **Step 4: Add score submission on game complete**

Find where `saveToHistory()` is called on game completion. After that call, add:

```javascript
if (typeof isSubscriber === 'function' && isSubscriber()) {
  var totalScore = getTotalScore(gameState.wordScores);
  submitScore('wordsky', getActiveLanguage(), {
    score: totalScore,
    words_completed: gameState.wordScores.length,
    duration_secs: Math.round(gameState.elapsedMs / 1000),
    details: { wordScores: gameState.wordScores }
  });
}
```

- [ ] **Step 5: Commit**

```bash
git add web/mobile/wordsky.html
git commit -m "feat: add daily state sync and score submission to wordsky"
```

---

### Task 12: Add State Sync + Score Submission to Rootsky

**Files:**
- Modify: `web/mobile/rootsky.html`

Same pattern as Task 11, but for rootsky:

- [ ] **Step 1: Add auth script tags**
- [ ] **Step 2: Add daily state loading** (same pattern as wordsky Task 11 Step 2, replace `'wordsky'` with `'rootsky'`, localStorage key `'rootsky_state_' + todayStr`. Use `result.state` from the returned `{state, phase}` object)
- [ ] **Step 3: Add state sync in `saveGameState()`** (same pattern, replace game name)
- [ ] **Step 4: Add score submission on complete** (same pattern, replace game name; find where `saveToHistory` is called)
- [ ] **Step 5: Commit**

```bash
git add web/mobile/rootsky.html
git commit -m "feat: add daily state sync and score submission to rootsky"
```

---

### Task 13: Add State Sync + Score Submission to Triviatsky

**Files:**
- Modify: `web/mobile/triviatsky.html`

Same pattern as Task 11, but triviatsky uses language-aware localStorage keys:

- [ ] **Step 1: Add auth script tags**

- [ ] **Step 2: Add daily state loading**

Use localStorage key `'triviatsky_state_' + getActiveLanguage() + '_' + todayStr` for the local check.

- [ ] **Step 3: Add state sync in `saveGameState()`** (same pattern, game name = `'triviatsky'`)

- [ ] **Step 4: Add score submission on complete**

Find where `saveToHistory` is called on game completion. After it, add:

```javascript
if (typeof isSubscriber === 'function' && isSubscriber()) {
  submitScore('triviatsky', getActiveLanguage(), {
    score: gameState.score,
    words_completed: gameState.questionScores.length,
    details: { questionScores: gameState.questionScores }
  });
}
```

- [ ] **Step 5: Commit**

```bash
git add web/mobile/triviatsky.html
git commit -m "feat: add daily state sync and score submission to triviatsky"
```

---

## Chunk 5: Leaderboard + Profile Page

### Task 14: Add Leaderboard Modal to All Games

**Files:**
- Create: `web/shared/leaderboard.js`

A shared leaderboard modal that any game can invoke. It creates a full-screen overlay showing top 20 scores.

- [ ] **Step 1: Create leaderboard.js**

```javascript
/* ===== LEADERBOARD MODAL ===== */
/* Call showLeaderboard(game, language, difficulty) from any game page */

function showLeaderboard(game, language, difficulty) {
  // Remove existing modal if any
  var existing = document.getElementById('leaderboard-modal');
  if (existing) existing.remove();

  var modal = document.createElement('div');
  modal.id = 'leaderboard-modal';
  modal.style.cssText = 'position:fixed;top:0;left:0;right:0;bottom:0;z-index:10000;background:rgba(0,0,0,0.85);display:flex;align-items:center;justify-content:center;backdrop-filter:blur(4px);-webkit-backdrop-filter:blur(4px);';

  var inner = document.createElement('div');
  inner.style.cssText = 'background:var(--bg-card,#1e1e3a);border:1px solid var(--border-subtle,#333);border-radius:16px;width:90%;max-width:400px;max-height:80vh;overflow:hidden;display:flex;flex-direction:column;';

  // Header
  var header = document.createElement('div');
  header.style.cssText = 'padding:16px 20px;border-bottom:1px solid var(--border-subtle,#333);display:flex;align-items:center;justify-content:space-between;';
  header.innerHTML = '<span style="font-family:\'Press Start 2P\',monospace;font-size:11px;color:var(--accent,#c8a830);">Leaderboard</span>';
  var closeBtn = document.createElement('button');
  closeBtn.textContent = '\u2715';
  closeBtn.style.cssText = 'background:none;border:none;color:var(--text-secondary,#888);font-size:18px;cursor:pointer;padding:4px 8px;';
  closeBtn.addEventListener('click', function() { modal.remove(); });
  header.appendChild(closeBtn);
  inner.appendChild(header);

  // Body (scrollable)
  var body = document.createElement('div');
  body.style.cssText = 'padding:12px 20px;overflow-y:auto;flex:1;';
  body.innerHTML = '<div style="text-align:center;color:var(--text-secondary,#888);padding:20px;">Loading...</div>';
  inner.appendChild(body);

  modal.appendChild(inner);
  modal.addEventListener('click', function(e) { if (e.target === modal) modal.remove(); });
  document.body.appendChild(modal);

  // Fetch leaderboard
  getLeaderboard(game, language, difficulty, 20).then(function(entries) {
    if (entries.length === 0) {
      body.innerHTML = '<div style="text-align:center;color:var(--text-secondary,#888);padding:20px;">No scores yet. Be the first!</div>';
      if (!isSubscriber()) {
        body.innerHTML += '<div style="text-align:center;margin-top:12px;"><button onclick="loginWithPatreon()" style="padding:10px 20px;font-family:\'Roboto Condensed\',sans-serif;font-weight:700;font-size:13px;background:var(--accent,#c8a830);color:var(--bg-primary,#0e0e1a);border:none;border-radius:8px;cursor:pointer;">Login to submit scores</button></div>';
      }
      return;
    }
    var html = '<table style="width:100%;border-collapse:collapse;">';
    html += '<tr style="color:var(--text-secondary,#888);font-size:11px;text-transform:uppercase;"><td style="padding:4px 0;">#</td><td>Player</td><td style="text-align:right;">Score</td></tr>';
    entries.forEach(function(e) {
      var rowStyle = e.is_me ? 'background:var(--accent-subtle,rgba(200,168,48,0.15));border-radius:6px;' : '';
      var nameStyle = e.is_me ? 'font-weight:700;color:var(--accent,#c8a830);' : 'color:var(--text-primary,#eee);';
      html += '<tr style="' + rowStyle + '">';
      html += '<td style="padding:8px 4px;font-size:13px;color:var(--text-secondary,#888);">' + e.rank + '</td>';
      html += '<td style="padding:8px 4px;font-size:14px;' + nameStyle + '">' + e.display_name + '</td>';
      html += '<td style="padding:8px 4px;font-size:14px;text-align:right;color:var(--text-primary,#eee);font-weight:700;">' + e.score + '</td>';
      html += '</tr>';
    });
    html += '</table>';
    if (!isSubscriber()) {
      html += '<div style="text-align:center;margin-top:16px;padding-top:12px;border-top:1px solid var(--border-subtle,#333);"><button onclick="loginWithPatreon()" style="padding:10px 20px;font-family:\'Roboto Condensed\',sans-serif;font-weight:700;font-size:13px;background:var(--accent,#c8a830);color:var(--bg-primary,#0e0e1a);border:none;border-radius:8px;cursor:pointer;">Login to submit your scores</button></div>';
    }
    body.innerHTML = html;
  });
}
```

- [ ] **Step 2: Add leaderboard.js script tag to all game HTML files**

In each of the 8 game HTML files, after the `auth.js` script tag, add:

```html
<script src="../shared/leaderboard.js"></script>
```

- [ ] **Step 3: Add Leaderboard button to each game's end modal**

In each game's end/death modal, find the share button and add a leaderboard button next to it. The exact location varies per game, but the button HTML is the same:

```html
<button onclick="showLeaderboard('GAME_ID', getActiveLanguage(), DIFFICULTY_VAR)" style="margin-top:8px;width:100%;padding:10px;font-family:'Roboto Condensed',sans-serif;font-weight:700;font-size:14px;background:transparent;color:var(--accent);border:1px solid var(--accent);border-radius:8px;cursor:pointer;">Leaderboard</button>
```

Replace `GAME_ID` with the game's ID string and `DIFFICULTY_VAR` with the variable holding difficulty (e.g., `game.difficulty` for bogglesky, `state.difficulty` for snakesky, `null` for fruitsky/daily games).

- [ ] **Step 4: Commit**

```bash
git add web/shared/leaderboard.js web/mobile/bogglesky.html web/mobile/scramblisky.html web/mobile/snakesky.html web/mobile/fruitsky.html web/mobile/tetrisky.html web/mobile/wordsky.html web/mobile/rootsky.html web/mobile/triviatsky.html
git commit -m "feat: add leaderboard modal to all games"
```

---

### Task 15: Create Profile Page

**Files:**
- Create: `web/mobile/profile.html`

- [ ] **Step 1: Create profile.html**

```html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
<title>Profile</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Press+Start+2P&family=Roboto+Condensed:wght@400;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="../shared/theme.css">
<script src="../shared/theme.js"></script>
<script src="../shared/engine.js"></script>
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.min.js"></script>
<script src="../shared/supabase-config.js"></script>
<script src="../shared/auth.js"></script>
<script src="../shared/leaderboard.js"></script>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{
  background:var(--bg-primary);color:var(--text-primary);
  font-family:'Roboto Condensed',sans-serif;
  display:flex;flex-direction:column;align-items:center;
  height:100vh;height:100dvh;
  overflow-y:auto;-webkit-overflow-scrolling:touch;
  user-select:none;-webkit-user-select:none;
}
.profile-wrap{width:100%;max-width:500px;padding:24px 20px;}
h1{font-family:'Press Start 2P',monospace;font-size:14px;color:var(--accent);text-shadow:0 0 20px var(--accent-glow);margin-bottom:8px;text-align:center;}
.player-name{text-align:center;font-size:16px;color:var(--text-secondary);margin-bottom:24px;}
.section-label{font-size:12px;font-weight:700;color:var(--text-secondary);text-transform:uppercase;letter-spacing:1.5px;margin:20px 0 12px;}
.stat-card{background:var(--bg-card);border:1px solid var(--border-subtle);border-radius:12px;padding:14px;margin-bottom:10px;display:flex;align-items:center;justify-content:space-between;}
.stat-card .game-name{font-weight:700;font-size:15px;color:var(--accent);}
.stat-card .stat-row{display:flex;gap:16px;font-size:13px;color:var(--text-secondary);}
.stat-card .stat-val{font-weight:700;color:var(--text-primary);}
.streak-badges{display:flex;gap:8px;flex-wrap:wrap;margin-bottom:16px;}
.badge{padding:6px 12px;border-radius:20px;font-size:12px;font-weight:700;background:var(--bg-card);border:1px solid var(--border-subtle);color:var(--text-secondary);}
.badge.active{border-color:var(--accent);color:var(--accent);background:var(--accent-subtle,rgba(200,168,48,0.1));}
.not-logged-in{text-align:center;padding:60px 20px;color:var(--text-secondary);}
#loading{text-align:center;padding:40px;color:var(--text-secondary);}
</style>
</head>
<body>
<div class="profile-wrap">
  <h1>Profile</h1>
  <div id="loading">Loading...</div>
  <div id="profile-content" style="display:none">
    <div class="player-name" id="display-name"></div>
    <div class="section-label">Streaks</div>
    <div class="streak-badges" id="streak-badges"></div>
    <div class="section-label">Game Stats</div>
    <div id="stats-list"></div>
  </div>
  <div id="not-logged-in" class="not-logged-in" style="display:none">
    <div style="font-size:18px;margin-bottom:12px;">Not logged in</div>
    <button onclick="loginWithPatreon()" style="padding:12px 24px;font-family:'Roboto Condensed',sans-serif;font-weight:700;font-size:14px;background:var(--accent);color:var(--bg-primary);border:none;border-radius:8px;cursor:pointer;">Login with Patreon</button>
  </div>
</div>
<script>
var GAME_NAMES = {
  bogglesky: 'Bogglesky', scramblisky: 'Scramblisky', snakesky: 'Snakesky',
  fruitsky: 'Fruitsky', tetrisky: 'Tetrisky', wordsky: 'Wordsky',
  rootsky: 'Rootsky', triviatsky: 'Triviatsky'
};
var STREAK_MILESTONES = [7, 30, 100];

authReady.then(function() {
  document.getElementById('loading').style.display = 'none';

  if (!isSubscriber()) {
    document.getElementById('not-logged-in').style.display = '';
    return;
  }

  document.getElementById('profile-content').style.display = '';
  document.getElementById('display-name').textContent = getDisplayName() || 'Player';

  getAllMyStats().then(function(stats) {
    // Streak badges
    var bestStreak = 0;
    stats.forEach(function(s) { if (s.best_streak > bestStreak) bestStreak = s.best_streak; });
    var badgesEl = document.getElementById('streak-badges');
    STREAK_MILESTONES.forEach(function(m) {
      var badge = document.createElement('span');
      badge.className = 'badge' + (bestStreak >= m ? ' active' : '');
      badge.textContent = m + '-day streak';
      badgesEl.appendChild(badge);
    });

    // Per-game stats
    var listEl = document.getElementById('stats-list');
    if (stats.length === 0) {
      listEl.innerHTML = '<div style="text-align:center;color:var(--text-secondary);padding:20px;">No games played yet</div>';
      return;
    }
    stats.forEach(function(s) {
      var card = document.createElement('div');
      card.className = 'stat-card';
      var streakHtml = s.current_streak > 0
        ? '<span>Streak: <span class="stat-val">' + s.current_streak + '</span></span>' : '';
      card.innerHTML =
        '<div><div class="game-name">' + (GAME_NAMES[s.game] || s.game) + '</div>' +
        '<div style="font-size:11px;color:var(--text-secondary);margin-top:2px;">' + s.language.toUpperCase() + '</div></div>' +
        '<div class="stat-row">' +
        '<span>Played: <span class="stat-val">' + s.games_played + '</span></span>' +
        '<span>Best: <span class="stat-val">' + s.best_score + '</span></span>' +
        streakHtml +
        '</div>';
      card.style.cursor = 'pointer';
      card.addEventListener('click', function() {
        showLeaderboard(s.game, s.language, null);
      });
      listEl.appendChild(card);
    });
  });
});
</script>
</body>
</html>
```

- [ ] **Step 2: Test locally**

Open: `http://localhost:3124/mobile/profile.html?mock_subscriber=true`
Verify: Shows "Debug User", streak badges (all inactive), "No games played yet" or stats if mock data exists.

- [ ] **Step 3: Commit**

```bash
git add web/mobile/profile.html
git commit -m "feat: add profile page with stats and streak badges"
```

---

## Chunk 6: Final Verification + Cleanup

### Task 16: End-to-End Smoke Test

No file changes — this is a manual verification task.

- [ ] **Step 1: Test non-subscriber flow**

Open `http://localhost:3124/mobile/index.html`. Verify:
- All games are playable
- Hamburger menu shows "Login with Patreon"
- Playing a game and finishing it does NOT call Supabase (check Network tab)
- Leaderboard button appears on game end, shows empty state with "Login to submit" prompt

- [ ] **Step 2: Test mock subscriber flow**

Open `http://localhost:3124/mobile/index.html?mock_subscriber=true`. Verify:
- Hamburger shows "Debug User (Logout)"
- Playing and finishing a game sends a POST to Supabase `session_scores` (check Network tab)
- Leaderboard button shows submitted score
- Settings page shows account section with "Debug User"
- Profile page shows stats

- [ ] **Step 3: Test settings sync**

As mock subscriber:
- Change theme in settings
- Check Supabase dashboard > Table Editor > user_settings for the upserted row

- [ ] **Step 4: Test daily game sync (if wordsky/rootsky/triviatsky are in the active language)**

As mock subscriber:
- Start a daily game, answer one question
- Check Supabase dashboard > daily_game_state for the saved state

- [ ] **Step 5: Final commit with all remaining changes**

```bash
git add -A
git status  # verify no unexpected files
git commit -m "feat: complete Patreon + Supabase integration v1"
```
