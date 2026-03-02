/* ===== SHARED ENGINE ===== */
/* Audio, SeedEngine, dictionary helpers, share utility */

// ===== AUDIO ENGINE =====
var audioCtx = null;
var audioUnlocked = false;

function getAudioCtx() {
  if (!audioCtx) audioCtx = new (window.AudioContext || window.webkitAudioContext)();
  return audioCtx;
}

function ensureAudio() {
  var ctx = getAudioCtx();
  if (ctx.state === 'suspended') ctx.resume();
}

function unlockAudio() {
  if (audioUnlocked) return;
  var ctx = getAudioCtx();
  if (ctx.state === 'suspended') ctx.resume();
  var b = ctx.createBuffer(1, 1, 22050);
  var s = ctx.createBufferSource();
  s.buffer = b;
  s.connect(ctx.destination);
  s.start(0);
  audioUnlocked = true;
}

document.addEventListener('touchstart', ensureAudio, true);
document.addEventListener('touchend', ensureAudio, true);
document.addEventListener('click', ensureAudio, true);
document.addEventListener('touchstart', unlockAudio, { once: true });
document.addEventListener('touchend', unlockAudio, { once: true });
document.addEventListener('click', unlockAudio, { once: true });

function playTone(freq, dur, type, vol, delay) {
  var ctx = getAudioCtx();
  if (ctx.state === 'suspended') ctx.resume();
  type = type || 'sine';
  vol = vol || 0.1;
  delay = delay || 0;
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
function isValidEntry(e) {
  if (!e || typeof e !== 'object') return false;
  if (typeof e.word !== 'string' || typeof e.translation !== 'string') return false;
  if (e.translation.trim() === '') return false;
  var w = e.word.trim().toLowerCase();
  if (w.length < 3 || w.length > 8) return false;
  return /^[а-яёА-ЯЁ]+$/.test(w);
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
