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
