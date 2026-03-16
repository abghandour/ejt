/* ===== AUTH MODULE ===== */
/* Supabase session management, subscriber checks, sync helpers */
/* Load after: supabase CDN client, supabase-config.js, engine.js */

var _supabase = null;
var _session = null;
var _mockMode = false;
var _displayName = null;
var _patreonTier = null;
var _authError = null;

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

// Fetch profile data (display name + tier) for a logged-in user
function _fetchProfile(userId) {
  return getSupabase().from('profiles')
    .select('display_name, patreon_tier')
    .eq('user_id', userId)
    .single()
    .then(function(res) {
      if (res.data) {
        _displayName = res.data.display_name;
        _patreonTier = res.data.patreon_tier;
      }
    }).catch(function() {});
}

// Detect if running inside an iframe
var _isIframe = (function() {
  try { return window.self !== window.top; } catch(e) { return true; }
})();

// authReady resolves once the session check completes.
// All page-load logic must await this before calling isLoggedIn()/isSubscriber().
var authReady = (function() {
  if (_mockMode) {
    _session = { mock: true };
    _displayName = 'Debug User';
    _patreonTier = 'Mock Tier';
    return Promise.resolve();
  }

  // IFRAME MODE: request session from parent window via postMessage
  if (_isIframe) {
    return new Promise(function(resolve) {
      var timeout = setTimeout(function() {
        // Parent didn't respond — no session
        _session = null;
        resolve();
      }, 2000);

      window.addEventListener('message', function handler(e) {
        if (e.data && e.data.type === 'authSession') {
          clearTimeout(timeout);
          window.removeEventListener('message', handler);
          if (e.data.session) {
            // Set session in Supabase client so API calls work
            getSupabase().auth.setSession({
              access_token: e.data.session.access_token,
              refresh_token: e.data.session.refresh_token
            }).then(function(result) {
              _session = result.data.session;
              _displayName = e.data.displayName || null;
              _patreonTier = e.data.patreonTier || null;
              resolve();
            }).catch(function() {
              _session = null;
              resolve();
            });
          } else {
            _session = null;
            resolve();
          }
        }
      });

      // Ask parent for session
      window.parent.postMessage({ type: 'requestAuthSession' }, '*');
    });
  }

  // TOP-LEVEL MODE: handle Patreon OAuth code or check existing session

  // Check for Patreon OAuth code in URL (redirect from Patreon)
  var urlParams = new URLSearchParams(window.location.search);
  var patreonCode = urlParams.get('code');
  if (patreonCode) {
    // Clean the URL immediately
    if (window.history.replaceState) {
      window.history.replaceState({}, '', window.location.pathname);
    }
    // Exchange code for session via Edge Function
    return fetch(SUPABASE_URL + '/functions/v1/patreon-auth', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ' + SUPABASE_ANON_KEY,
        'apikey': SUPABASE_ANON_KEY
      },
      body: JSON.stringify({ code: patreonCode, redirect_uri: PATREON_REDIRECT_URI })
    })
    .then(function(res) { return res.json(); })
    .then(function(data) {
      if (data.error) {
        console.warn('Patreon auth error:', data.message);
        _authError = data.message || 'Login failed';
        _session = null;
        return;
      }
      _patreonTier = data.tier || null;
      // Set the session in Supabase client
      return getSupabase().auth.setSession({
        access_token: data.session.access_token,
        refresh_token: data.session.refresh_token
      }).then(function(result) {
        _session = result.data.session;
        if (_session && _session.user) {
          return _fetchProfile(_session.user.id);
        }
      });
    })
    .catch(function(err) {
      console.warn('Patreon auth failed:', err);
      _authError = 'Login failed. Please try again.';
      _session = null;
    });
  }

  // No code param — check for existing session
  return getSupabase().auth.getSession().then(function(result) {
    _session = result.data.session;
    if (_session && _session.user) {
      return _fetchProfile(_session.user.id);
    }
  }).catch(function() {
    _session = null;
  });
})();

// Listen for auth state changes (e.g. after OAuth redirect)
(function() {
  if (_mockMode || _isIframe) return;
  getSupabase().auth.onAuthStateChange(function(event, session) {
    _session = session;
  });
})();

// TOP-LEVEL: respond to iframe auth session requests
(function() {
  if (_isIframe || _mockMode) return;
  window.addEventListener('message', function(e) {
    if (e.data && e.data.type === 'requestAuthSession') {
      authReady.then(function() {
        var responseData = { type: 'authSession', session: null, displayName: null, patreonTier: null };
        if (_session && _session.access_token) {
          responseData.session = {
            access_token: _session.access_token,
            refresh_token: _session.refresh_token
          };
          responseData.displayName = _displayName;
          responseData.patreonTier = _patreonTier;
        }
        var frame = document.getElementById('game-frame');
        if (frame && frame.contentWindow) {
          frame.contentWindow.postMessage(responseData, '*');
        }
      });
    }
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

function getPatreonTier() {
  if (_mockMode) return 'Mock Tier';
  return _patreonTier;
}

function getAuthError() {
  return _authError;
}

async function loginWithPatreon() {
  var params = new URLSearchParams({
    response_type: 'code',
    client_id: PATREON_CLIENT_ID,
    redirect_uri: PATREON_REDIRECT_URI,
    scope: 'identity identity.memberships'
  });
  window.location.href = 'https://www.patreon.com/oauth2/authorize?' + params.toString();
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
