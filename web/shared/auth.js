/* ===== AUTH MODULE ===== */
/* Supabase session management, subscriber checks, sync helpers */
/* Load after: supabase CDN client, supabase-config.js, engine.js */

var _supabase = null;
var _session = null;
var _mockMode = false;
var _displayName = null;

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
