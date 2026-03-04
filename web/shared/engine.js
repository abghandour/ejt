/* ===== SHARED ENGINE ===== */
/* Audio, SeedEngine, dictionary helpers, share utility */

// ===== AUDIO ENGINE =====
var audioCtx = null;
var audioUnlocked = false;
var _audioDebug = [];

function _alog(msg) {
  _audioDebug.push(Date.now() + ': ' + msg);
  if (_audioDebug.length > 30) _audioDebug.shift();
}

function getAudioDebug() { return _audioDebug.join('\n'); }

function getAudioCtx() {
  if (!audioCtx) {
    audioCtx = new (window.AudioContext || window.webkitAudioContext)();
    _alog('getAudioCtx created, state=' + audioCtx.state);
  }
  return audioCtx;
}

function unlockAudio() {
  if (!audioCtx) {
    audioCtx = new (window.AudioContext || window.webkitAudioContext)();
    _alog('unlockAudio created, state=' + audioCtx.state);
  }
  var ctx = audioCtx;
  _alog('unlockAudio called, state=' + ctx.state + ', unlocked=' + audioUnlocked);
  if (ctx.state === 'suspended') {
    ctx.resume().then(function() {
      _alog('resume resolved, state=' + ctx.state);
      audioUnlocked = true;
    }).catch(function(e) {
      _alog('resume rejected: ' + e);
    });
  }
  if (!audioUnlocked) {
    try {
      var b = ctx.createBuffer(1, 1, 22050);
      var s = ctx.createBufferSource();
      s.buffer = b;
      s.connect(ctx.destination);
      s.start(0);
      _alog('silent buffer played');
    } catch(e) {
      _alog('silent buffer error: ' + e);
    }
  }
  if (ctx.state === 'running') audioUnlocked = true;
}

// iOS requires resume on every user gesture — don't use { once: true }
['touchstart', 'touchend', 'click', 'keydown'].forEach(function(evt) {
  document.addEventListener(evt, unlockAudio, true);
});

// Audio debug overlay — enabled via localStorage flag from Settings
(function() {
  var AUDIO_DBG_KEY = 'hjlr_audio_debug';
  if (typeof localStorage === 'undefined') return;
  try { if (localStorage.getItem(AUDIO_DBG_KEY) !== '1') return; } catch(e) { return; }
  document.addEventListener('DOMContentLoaded', function() {
    var el = document.createElement('div');
    el.id = 'audio-dbg';
    el.style.cssText = 'position:fixed;bottom:4px;left:4px;right:4px;max-height:35vh;overflow:auto;background:rgba(0,0,0,0.88);color:#0f0;font:10px monospace;padding:6px;border-radius:6px;z-index:9999;white-space:pre-wrap;-webkit-tap-highlight-color:transparent;';
    el.textContent = 'Tap to refresh audio debug log';
    el.addEventListener('click', function() { el.textContent = getAudioDebug(); });
    document.body.appendChild(el);
  });
})();

// iOS mute switch hint — show once per session if iOS detected
var _muteHintShown = false;
function showMuteHint() {
  if (_muteHintShown) return;
  // Only show on iOS (iPhone/iPad/iPod in Safari or WKWebView)
  var isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent) ||
    (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  if (!isIOS) return;
  try { if (sessionStorage.getItem('hjlr_mute_hint') === '1') return; } catch(e) {}
  _muteHintShown = true;
  try { sessionStorage.setItem('hjlr_mute_hint', '1'); } catch(e) {}
  var toast = document.createElement('div');
  toast.style.cssText = 'position:fixed;bottom:20px;left:50%;transform:translateX(-50%);background:rgba(0,0,0,0.88);color:#fff;font:14px "Roboto Condensed",sans-serif;padding:12px 20px;border-radius:10px;z-index:9999;text-align:center;max-width:90%;backdrop-filter:blur(8px);-webkit-backdrop-filter:blur(8px);opacity:0;transition:opacity 0.3s;';
  toast.textContent = '🔇 No sound? Turn off silent mode (switch on the side of your iPhone)';
  document.body.appendChild(toast);
  requestAnimationFrame(function() { toast.style.opacity = '1'; });
  setTimeout(function() {
    toast.style.opacity = '0';
    setTimeout(function() { toast.remove(); }, 400);
  }, 5000);
}

function playTone(freq, dur, type, vol, delay) {
  var ctx = getAudioCtx();
  _alog('playTone f=' + freq + ' state=' + ctx.state);
  if (ctx.state === 'suspended') {
    ctx.resume().catch(function() {});
  }
  showMuteHint();
  type = type || 'sine';
  vol = vol || 0.1;
  delay = delay || 0;
  try {
    var o = ctx.createOscillator();
    var g = ctx.createGain();
    o.type = type;
    o.frequency.value = freq;
    g.gain.setValueAtTime(0.001, ctx.currentTime + delay);
    g.gain.linearRampToValueAtTime(vol, ctx.currentTime + delay + 0.02);
    g.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + delay + dur);
    o.connect(g).connect(ctx.destination);
    o.start(ctx.currentTime + delay);
    o.stop(ctx.currentTime + delay + dur);
  } catch(e) {}
}

// ===== SEED ENGINE (mulberry32) =====
function SeedEngine(seed) { this._state = seed | 0; }
SeedEngine.prototype.next = function() {
  this._state |= 0;
  this._state = this._state + 0x6D2B79F5 | 0;
  var t = Math.imul(this._state ^ this._state >>> 15, 1 | this._state);
  t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
  return ((t ^ t >>> 14) >>> 0) / 4294967296;
};
SeedEngine.prototype.nextInt = function(max) { return Math.floor(this.next() * max); };
SeedEngine.prototype.shuffle = function(arr) {
  var a = arr.slice();
  for (var i = a.length - 1; i > 0; i--) {
    var j = this.nextInt(i + 1);
    var tmp = a[i]; a[i] = a[j]; a[j] = tmp;
  }
  return a;
};

// ===== DICTIONARY HELPERS =====
var _activeValidationRegex = /^[а-яёА-ЯЁ]+$/;

function setValidationRegex(pattern) {
  try {
    _activeValidationRegex = new RegExp(pattern);
  } catch (e) {
    _activeValidationRegex = /^[а-яёА-ЯЁ]+$/;
  }
}

function isValidEntry(e) {
  if (!e || typeof e !== 'object') return false;
  if (typeof e.word !== 'string' || typeof e.translation !== 'string') return false;
  if (e.translation.trim() === '') return false;
  var w = e.word.trim().toLowerCase();
  if (w.length < 3 || w.length > 8) return false;
  return _activeValidationRegex.test(w);
}

function validateDictionary(entries) {
  if (!Array.isArray(entries)) throw new Error('Invalid dictionary format');
  var valid = entries.filter(isValidEntry);
  if (valid.length < 20) throw new Error('Dictionary too small (' + valid.length + ' entries)');
  return valid;
}

function shuffleArray(arr) {
  var a = arr.slice();
  for (var i = a.length - 1; i > 0; i--) {
    var j = Math.floor(Math.random() * (i + 1));
    var tmp = a[i]; a[i] = a[j]; a[j] = tmp;
  }
  return a;
}

async function loadDictionary(url) {
  var resp = await fetch(url);
  if (!resp.ok) throw new Error('HTTP ' + resp.status);
  var data = await resp.json();
  return validateDictionary(data);
}

// ===== SHARE UTILITY =====
function shareText(text) {
  if (navigator.share) {
    navigator.share({ text: text }).catch(function(){});
  } else if (navigator.clipboard) {
    navigator.clipboard.writeText(text).then(function() { alert('Copied!'); });
  } else {
    prompt('Copy:', text);
  }
}

// ===== SHARE WITH SCREENSHOT =====
function shareWithScreenshot(text, overlaySelector) {
  var overlay = document.querySelector(overlaySelector || '#death-overlay');
  if (!overlay) { shareText(text); return; }

  // Use html2canvas if available, otherwise try canvas capture
  _captureElement(overlay).then(function(blob) {
    if (blob && navigator.share && navigator.canShare) {
      var file = new File([blob], 'result.png', { type: 'image/png' });
      var shareData = { text: text, files: [file] };
      if (navigator.canShare(shareData)) {
        navigator.share(shareData).catch(function(){});
        return;
      }
    }
    // Fallback to text-only share
    shareText(text);
  }).catch(function() {
    shareText(text);
  });
}

function _captureElement(el) {
  // Try html2canvas first (loaded dynamically)
  if (window.html2canvas) {
    return window.html2canvas(el, {
      backgroundColor: '#0a0a14',
      scale: 2,
      useCORS: true
    }).then(function(canvas) {
      return new Promise(function(resolve) {
        canvas.toBlob(function(b) { resolve(b); }, 'image/png');
      });
    });
  }

  // Dynamically load html2canvas
  return new Promise(function(resolve, reject) {
    var script = document.createElement('script');
    script.src = 'https://cdnjs.cloudflare.com/ajax/libs/html2canvas/1.4.1/html2canvas.min.js';
    script.onload = function() {
      window.html2canvas(el, {
        backgroundColor: '#0a0a14',
        scale: 2,
        useCORS: true
      }).then(function(canvas) {
        canvas.toBlob(function(b) { resolve(b); }, 'image/png');
      }).catch(reject);
    };
    script.onerror = function() { resolve(null); };
    document.head.appendChild(script);
  });
}

// ===== DIFFICULTY TOGGLE SETUP =====
function setupDifficultyToggle(callback) {
  var diffBtns = document.querySelectorAll('.diff-btn');
  diffBtns.forEach(function(btn) {
    btn.addEventListener('click', function() {
      diffBtns.forEach(function(b) { b.classList.remove('active'); });
      btn.classList.add('active');
      if (callback) callback(btn.getAttribute('data-diff'));
    });
  });
}

// ===== PAUSE / RESUME SUPPORT =====
// Parent (index.html) sends {type:'pause'} via postMessage when banner is clicked.
// Games can register callbacks via onGamePause / onGameResume for custom logic (e.g. stop timers).

var _pauseCallbacks = [];
var _resumeCallbacks = [];
function onGamePause(fn) { _pauseCallbacks.push(fn); }
function onGameResume(fn) { _resumeCallbacks.push(fn); }

var _pauseOverlay = null;
function _createPauseOverlay() {
  if (_pauseOverlay) return _pauseOverlay;
  var ov = document.createElement('div');
  ov.id = 'pause-overlay';
  ov.style.cssText = 'position:fixed;top:0;left:0;right:0;bottom:0;background:var(--bg-overlay);display:flex;align-items:center;justify-content:center;z-index:200;backdrop-filter:blur(8px);-webkit-backdrop-filter:blur(8px);';
  ov.innerHTML = '<div style="display:flex;flex-direction:column;align-items:center;gap:16px;">' +
    '<div style="font-family:\'Press Start 2P\',monospace;font-size:20px;color:var(--accent);text-shadow:0 0 20px var(--accent-glow);">PAUSED</div>' +
    '<button id="resume-btn" style="font-family:\'Roboto Condensed\',sans-serif;font-weight:700;font-size:18px;padding:14px 40px;background:var(--btn-play-bg);border:2px solid var(--btn-play-border);border-radius:12px;color:var(--text-primary);cursor:pointer;box-shadow:0 4px 16px var(--btn-play-shadow);-webkit-tap-highlight-color:transparent;">Resume</button>' +
    '</div>';
  ov.style.display = 'none';
  document.body.appendChild(ov);
  ov.querySelector('#resume-btn').addEventListener('click', function() {
    _hidePause();
  });
  _pauseOverlay = ov;
  return ov;
}

function _showPause() {
  var ov = _createPauseOverlay();
  ov.style.display = 'flex';
  _pauseCallbacks.forEach(function(fn) { try { fn(); } catch(e){} });
}

function _hidePause() {
  if (_pauseOverlay) _pauseOverlay.style.display = 'none';
  _resumeCallbacks.forEach(function(fn) { try { fn(); } catch(e){} });
}

window.addEventListener('message', function(e) {
  if (e.data && e.data.type === 'pause') {
    _showPause();
  }
});

// ===== LANGUAGE MANAGEMENT =====
var LANG_KEY = 'hjlr_language';
var DEFAULT_LANG = 'ru';
var _langConfig = null;

var _FALLBACK_CONFIG = {
  "ru": {
    "displayName": "Russian",
    "games": ["rootsky", "scramblisky", "bogglesky", "snakesky"],
    "themes": ["soviet", "dark", "light", "bw", "festivus"],
    "dictionaryBasePath": "../shared/dictionaries/ru",
    "letterPool": "оооооооеееееееаааааааиииииинннннттттссссррррввввллллккккммммддддппппууууяяяббггззччхжшюцщэфъьёй",
    "validationRegex": "^[а-яёА-ЯЁ]+$",
    "gameNames": {
      "rootsky":     { "name": "Rootsky",     "desc": "Match Russian words to their roots" },
      "scramblisky": { "name": "Scramblisky", "desc": "Unscramble Russian words before time runs out" },
      "bogglesky":   { "name": "Bogglesky",   "desc": "Swipe to find Russian words in a letter grid" },
      "snakesky":    { "name": "Snakesky",    "desc": "Guide the snake to eat the right Russian words" }
    }
  },
  "pt-br": {
    "displayName": "Português (Brasil)",
    "games": ["scramblisky", "bogglesky", "snakesky"],
    "themes": ["brazil", "dark", "light", "bw", "festivus"],
    "dictionaryBasePath": "../shared/dictionaries/pt-br",
    "letterPool": "aaaaaaaaaaeeeeeeeeeoooooooossssssrrrrrrnnnnnnttttttllllddddmmmmccccppppuuuiiibbbggffvvhhjjqqxxzzçãõéêíóôúâà",
    "validationRegex": "^[a-záàâãéêíóôõúüç]+$",
    "gameNames": {
      "scramblisky": { "name": "Scramblisky", "desc": "Unscramble Portuguese words before time runs out" },
      "bogglesky":   { "name": "Bogglesky",   "desc": "Swipe to find Portuguese words in a letter grid" },
      "snakesky":    { "name": "Snakesky",    "desc": "Guide the snake to eat the right Portuguese words" }
    }
  }
};

async function loadLanguageConfig() {
  if (_langConfig) return _langConfig;
  try {
    var resp = await fetch('../shared/languages.json');
    if (!resp.ok) throw new Error('HTTP ' + resp.status);
    _langConfig = await resp.json();
  } catch (e) {
    console.warn('Failed to load languages.json, using fallback Russian config:', e);
    _langConfig = JSON.parse(JSON.stringify(_FALLBACK_CONFIG));
  }
  return _langConfig;
}

function getActiveLanguage() {
  var stored = localStorage.getItem(LANG_KEY);
  if (!stored) {
    localStorage.setItem(LANG_KEY, DEFAULT_LANG);
    return DEFAULT_LANG;
  }
  if (_langConfig && !_langConfig[stored]) {
    localStorage.setItem(LANG_KEY, DEFAULT_LANG);
    return DEFAULT_LANG;
  }
  return stored;
}

function setActiveLanguage(langId) {
  localStorage.setItem(LANG_KEY, langId);
}

function getLanguageConfig(langId) {
  if (!_langConfig || !_langConfig[langId]) return null;
  return _langConfig[langId];
}

function resolveValidationRegex(langId) {
  var config = getLanguageConfig(langId);
  if (config && config.validationRegex) {
    try {
      return new RegExp(config.validationRegex);
    } catch (e) {
      console.warn('Invalid validationRegex for language "' + langId + '", falling back to Russian:', e);
    }
  }
  return /^[а-яёА-ЯЁ]+$/;
}

function resolveDictionaryUrl(langId, gameId) {
  var config = getLanguageConfig(langId);
  if (config && config.dictionaryBasePath) {
    return config.dictionaryBasePath + '/' + gameId + '.json';
  }
  return '../shared/dictionaries/ru/' + gameId + '.json';
}

function resolveLetterPool(langId) {
  var config = getLanguageConfig(langId);
  if (config && config.letterPool) {
    return config.letterPool;
  }
  return 'оооооооеееееееаааааааиииииинннннттттссссррррввввллллккккммммддддппппууууяяяббггззччхжшюцщэфъьёй';
}

function resolveGameName(langId, gameId) {
  var config = getLanguageConfig(langId);
  if (config && config.gameNames && config.gameNames[gameId]) {
    return config.gameNames[gameId];
  }
  return null;
}


// ===== TEST EXPORTS =====
if (typeof module !== 'undefined') {
  module.exports = {
    getAudioCtx: getAudioCtx,
    unlockAudio: unlockAudio,
    playTone: playTone,
    get audioCtx() { return audioCtx; },
    set audioCtx(v) { audioCtx = v; },
    get audioUnlocked() { return audioUnlocked; },
    set audioUnlocked(v) { audioUnlocked = v; }
  };
}
