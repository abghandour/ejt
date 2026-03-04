/**
 * Fruitsky Engine — testable game logic for the synonym slash game.
 *
 * This module is designed to be importable both from the HTML game file
 * (via inline copy) and from Vitest tests (via module.exports).
 */

/**
 * Validate a single word entry from the synonym dictionary.
 * Returns true only if the entry has:
 * - a non-empty `word` string
 * - a non-empty `translation` string
 * - a `synonyms` array with at least 3 entries, each having non-empty `word` and `translation`
 *
 * @param {object} entry - Raw dictionary entry
 * @returns {boolean}
 */
function validateWordEntry(entry) {
  if (!entry || typeof entry !== 'object') return false;
  if (typeof entry.word !== 'string' || entry.word.trim() === '') return false;
  if (typeof entry.translation !== 'string' || entry.translation.trim() === '') return false;
  if (!Array.isArray(entry.synonyms) || entry.synonyms.length < 3) return false;

  for (var i = 0; i < entry.synonyms.length; i++) {
    var syn = entry.synonyms[i];
    if (!syn || typeof syn !== 'object') return false;
    if (typeof syn.word !== 'string' || syn.word.trim() === '') return false;
    if (typeof syn.translation !== 'string' || syn.translation.trim() === '') return false;
  }

  return true;
}

/**
 * Load and validate the synonym dictionary.
 * Accepts either a direct URL string or a deps object for browser integration.
 *
 * When called with a URL string, fetches from that URL directly.
 * When called with a deps object, uses injected getActiveLanguage/resolveDictionaryUrl.
 * When called with no arguments in the browser, uses the shared GameEngine functions.
 *
 * Skips invalid word entries. Throws if no valid entries remain or distractors are missing.
 *
 * @param {string|object} [urlOrDeps] - URL string or dependency injection object
 * @param {function} [urlOrDeps.fetch] - Custom fetch function
 * @param {function} [urlOrDeps.getActiveLanguage] - Returns the active language ID
 * @param {function} [urlOrDeps.resolveDictionaryUrl] - Resolves dictionary URL for a language and game
 * @returns {Promise<{words: Array, distractors: Array}>}
 */
async function loadSynonymDictionary(urlOrDeps) {
  var url;
  var _fetch;

  if (typeof urlOrDeps === 'string') {
    // Direct URL mode
    url = urlOrDeps;
    _fetch = typeof fetch !== 'undefined' ? fetch : null;
  } else {
    // Deps / browser mode
    var deps = urlOrDeps || {};
    _fetch = deps.fetch || (typeof fetch !== 'undefined' ? fetch : null);
    var _getActiveLanguage = deps.getActiveLanguage ||
      (typeof getActiveLanguage !== 'undefined' ? getActiveLanguage : null);
    var _resolveDictionaryUrl = deps.resolveDictionaryUrl ||
      (typeof resolveDictionaryUrl !== 'undefined' ? resolveDictionaryUrl : null);

    if (!_getActiveLanguage) throw new Error('getActiveLanguage is not available');
    if (!_resolveDictionaryUrl) throw new Error('resolveDictionaryUrl is not available');

    var langId = _getActiveLanguage();
    url = _resolveDictionaryUrl(langId, 'fruitsky');
  }

  if (!_fetch) throw new Error('fetch is not available');

  var resp = await _fetch(url);
  if (!resp.ok) throw new Error('HTTP ' + resp.status);

  var data = await resp.json();

  if (!data || typeof data !== 'object') {
    throw new Error('Invalid dictionary format');
  }

  var words = Array.isArray(data.words) ? data.words.filter(validateWordEntry) : [];

  if (words.length === 0) {
    throw new Error('No valid word entries in dictionary');
  }

  var distractors = Array.isArray(data.distractors) ? data.distractors : [];
  if (distractors.length === 0) {
    throw new Error('Dictionary must contain at least one distractor');
  }

  return { words: words, distractors: distractors };
}

/**
 * Create the initial game state from a validated dictionary.
 * Selects a random main word from the dictionary's words array.
 *
 * @param {{words: Array, distractors: Array}} dictionary - Validated dictionary
 * @returns {GameState}
 */
function createInitialState(dictionary) {
  var idx = Math.floor(Math.random() * dictionary.words.length);
  return {
    score: 0,
    lives: 3,
    timeRemaining: 60,
    elapsedTime: 0,
    currentMainWord: dictionary.words[idx],
    collectedSynonyms: new Set(),
    wordsCompleted: 0,
    totalSynonymsSlashed: 0,
    activeWords: [],
    phase: 'playing'
  };
}

/**
 * Process a slash event and return a new game state (immutable pattern).
 *
 * @param {GameState} state - Current game state
 * @param {string} wordType - 'synonym' | 'distractor' | 'powerup' | 'bomb'
 * @param {string} [synonymWord] - The synonym text being slashed (needed for collectedSynonyms)
 * @returns {GameState} - New state object
 */
function processSlash(state, wordType, synonymWord) {
  var newState = {
    score: state.score,
    lives: state.lives,
    timeRemaining: state.timeRemaining,
    elapsedTime: state.elapsedTime,
    currentMainWord: state.currentMainWord,
    collectedSynonyms: new Set(state.collectedSynonyms),
    wordsCompleted: state.wordsCompleted,
    totalSynonymsSlashed: state.totalSynonymsSlashed,
    activeWords: state.activeWords,
    phase: state.phase
  };

  if (wordType === 'synonym') {
    newState.score += 10;
    newState.totalSynonymsSlashed += 1;
    if (synonymWord) {
      newState.collectedSynonyms.add(synonymWord);
    }
  } else if (wordType === 'distractor') {
    newState.lives -= 1;
    if (newState.lives <= 0) {
      newState.lives = 0;
      newState.phase = 'gameover';
    }
  } else if (wordType === 'powerup') {
    newState.timeRemaining += 5;
  } else if (wordType === 'bomb') {
    newState.timeRemaining = Math.max(0, newState.timeRemaining - 5);
  }

  return newState;
}

/**
 * Check if all synonyms for the current main word have been collected.
 *
 * @param {GameState} state - Current game state
 * @returns {boolean}
 */
function allSynonymsCollected(state) {
  return state.collectedSynonyms.size === state.currentMainWord.synonyms.length;
}

/**
 * Rotate to a new main word, reset collectedSynonyms, add bonus points.
 * Selects a different word from current if possible.
 *
 * @param {GameState} state - Current game state
 * @param {{words: Array, distractors: Array}} dictionary - Validated dictionary
 * @returns {GameState} - New state object
 */
function rotateMainWord(state, dictionary) {
  var newState = {
    score: state.score + 25,
    lives: state.lives,
    timeRemaining: state.timeRemaining,
    elapsedTime: state.elapsedTime,
    currentMainWord: state.currentMainWord,
    collectedSynonyms: new Set(),
    wordsCompleted: state.wordsCompleted + 1,
    totalSynonymsSlashed: state.totalSynonymsSlashed,
    activeWords: state.activeWords,
    phase: state.phase
  };

  if (dictionary.words.length > 1) {
    var idx;
    do {
      idx = Math.floor(Math.random() * dictionary.words.length);
    } while (dictionary.words[idx].word === state.currentMainWord.word);
    newState.currentMainWord = dictionary.words[idx];
  } else {
    newState.currentMainWord = dictionary.words[0];
  }

  return newState;
}

// ===== Timer Manager =====

/**
 * Create a new timer state.
 * @param {number} [seconds=60] - Starting seconds
 * @returns {{timeRemaining: number}}
 */
function createTimer(seconds) {
  return { timeRemaining: seconds !== undefined ? seconds : 60 };
}

/**
 * Tick the timer by a delta. Reduces timeRemaining, clamped to 0 minimum.
 * @param {{timeRemaining: number}} timer - Current timer
 * @param {number} dt - Delta in seconds
 * @returns {{timeRemaining: number}} - New timer object
 */
function tickTimer(timer, dt) {
  return { timeRemaining: Math.max(0, timer.timeRemaining - dt) };
}

/**
 * Add or subtract time from the timer. Clamped to [0, +∞).
 * @param {{timeRemaining: number}} timer - Current timer
 * @param {number} delta - Seconds to add (positive) or subtract (negative)
 * @returns {{timeRemaining: number}} - New timer object
 */
function modifyTimer(timer, delta) {
  return { timeRemaining: Math.max(0, timer.timeRemaining + delta) };
}

// ===== Difficulty Controller =====

/**
 * @typedef {Object} DifficultyParams
 * @property {number} launchSpeed - Base launch speed multiplier (1.0 to 2.0)
 * @property {number} launchInterval - Milliseconds between launches (decreases over time)
 * @property {number} distractorRatio - Ratio of distractors to synonyms (0.3 to 0.7)
 * @property {number} maxSimultaneous - Max flying words at once (3 to 5)
 */

/**
 * Compute difficulty parameters based on elapsed game time.
 * Uses linear interpolation clamped to bounds, ramping over ~60 seconds.
 *
 * @param {number} elapsedSeconds - Time since game start
 * @returns {DifficultyParams}
 */
function computeDifficulty(elapsedSeconds) {
  // Clamp progress to [0, 1] over 60 seconds
  var t = Math.min(Math.max(elapsedSeconds / 60, 0), 1);

  return {
    launchSpeed: 1.0 + t * 1.0,           // 1.0 → 2.0
    launchInterval: 1500 - t * 900,        // 1500ms → 600ms
    distractorRatio: 0.3 + t * 0.4,        // 0.3 → 0.7
    maxSimultaneous: Math.round(3 + t * 2)  // 3 → 5
  };
}

// ===== Word Launcher =====

/** Auto-incrementing counter for unique flying word IDs. */
var _flyingWordIdCounter = 0;

/**
 * Create a new flying word with parabolic trajectory parameters.
 *
 * The word starts at a random horizontal position within the play area and
 * at (or slightly below) the bottom edge. It is given an upward velocity
 * (negative vy) with some randomness, a slight horizontal velocity for
 * varied trajectories, and a gravity constant that will pull it back down.
 *
 * @param {string} text - The word text to display
 * @param {string} type - 'synonym' | 'distractor' | 'powerup' | 'bomb'
 * @param {number} playAreaWidth - Current play area width in pixels
 * @param {number} playAreaHeight - Current play area height in pixels
 * @returns {FlyingWord}
 */
function createFlyingWord(text, type, playAreaWidth, playAreaHeight) {
  // Random horizontal position within the play area (with a small margin)
  var margin = playAreaWidth * 0.1;
  var x = margin + Math.random() * (playAreaWidth - 2 * margin);

  // Start at or slightly below the bottom edge
  var y = playAreaHeight + Math.random() * 20;

  // Upward velocity (negative = upward) with randomness for varied arcs
  var baseVy = -(playAreaHeight * 0.8);
  var vy = baseVy + (Math.random() - 0.5) * (playAreaHeight * 0.3);

  // Slight horizontal velocity for varied trajectories
  var vx = (Math.random() - 0.5) * (playAreaWidth * 0.3);

  // Gravity constant (positive, pulls word back down)
  var gravity = playAreaHeight * 0.8;

  _flyingWordIdCounter += 1;
  var id = 'fw-' + _flyingWordIdCounter + '-' + Date.now();

  return {
    id: id,
    text: text,
    type: type,
    x: x,
    y: y,
    vx: vx,
    vy: vy,
    gravity: gravity,
    launchTime: Date.now(),
    el: null,
    slashed: false
  };
}

/**
 * Update the position of a flying word using parabolic motion.
 * Mutates the word object in place (updates vy, x, y).
 *
 * @param {FlyingWord} word - The flying word to update
 * @param {number} dt - Delta time in seconds
 * @param {number} playAreaHeight - Height of the play area in pixels
 * @returns {boolean} - True if word is still in play, false if it fell below the bottom edge
 */
function updateWordPosition(word, dt, playAreaHeight) {
  word.vy += word.gravity * dt;
  word.x += word.vx * dt;
  word.y += word.vy * dt;

  // Word has fallen below the bottom edge and is on its way down
  if (word.y > playAreaHeight && word.vy > 0) {
    return false;
  }

  return true;
}



// ===== Word Selection =====

/**
 * Select the next word to launch based on game state, dictionary, and difficulty.
 *
 * Logic:
 * 1. ~10% chance to return a power-up
 * 2. ~8% chance to return a bomb
 * 3. Otherwise, use distractorRatio to decide between synonym and distractor
 * 4. If picking a synonym, choose randomly from unslashed synonyms; fall back to distractor if none remain
 * 5. If picking a distractor, choose randomly from dictionary.distractors
 *
 * @param {GameState} state - Current game state (needs currentMainWord, collectedSynonyms)
 * @param {{words: Array, distractors: Array}} dictionary - Validated dictionary
 * @param {DifficultyParams} difficulty - Current difficulty (needs distractorRatio)
 * @returns {{text: string, translation: string, type: string}}
 */
function selectNextWord(state, dictionary, difficulty) {
  var roll = Math.random();

  // ~10% chance for a power-up
  if (roll < 0.10) {
    return { text: '⏰', translation: '+5s', type: 'powerup' };
  }

  // ~8% chance for a bomb (0.10 to 0.18)
  if (roll < 0.18) {
    return { text: '💣', translation: '-5s', type: 'bomb' };
  }

  // Get unslashed synonyms
  var unslashed = state.currentMainWord.synonyms.filter(function (syn) {
    return !state.collectedSynonyms.has(syn.word);
  });

  // Decide between distractor and synonym based on distractorRatio
  var pickDistractor = Math.random() < difficulty.distractorRatio || unslashed.length === 0;

  if (pickDistractor) {
    var d = dictionary.distractors[Math.floor(Math.random() * dictionary.distractors.length)];
    return { text: d.word, translation: d.translation, type: 'distractor' };
  }

  // Pick a random unslashed synonym
  var syn = unslashed[Math.floor(Math.random() * unslashed.length)];
  return { text: syn.word, translation: syn.translation, type: 'synonym' };
}

/**
 * Check if a line segment intersects an axis-aligned bounding box.
 * Uses the Liang-Barsky line clipping algorithm.
 *
 * @param {{x1: number, y1: number, x2: number, y2: number}} segment - Line segment endpoints
 * @param {{x: number, y: number, width: number, height: number}} rect - Axis-aligned bounding box
 * @returns {boolean} True if the segment intersects or is inside the rectangle
 */
function segmentIntersectsRect(segment, rect) {
  var dx = segment.x2 - segment.x1;
  var dy = segment.y2 - segment.y1;

  var xmin = rect.x;
  var xmax = rect.x + rect.width;
  var ymin = rect.y;
  var ymax = rect.y + rect.height;

  // p, q arrays for Liang-Barsky: edges left, right, top, bottom
  var p = [-dx, dx, -dy, dy];
  var q = [
    segment.x1 - xmin,
    xmax - segment.x1,
    segment.y1 - ymin,
    ymax - segment.y1
  ];

  var tMin = 0;
  var tMax = 1;

  for (var i = 0; i < 4; i++) {
    if (p[i] === 0) {
      // Segment is parallel to this edge
      if (q[i] < 0) {
        // Segment is outside this edge
        return false;
      }
      // Otherwise parallel and inside this slab, continue
    } else {
      var t = q[i] / p[i];
      if (p[i] < 0) {
        // Entry edge
        if (t > tMin) tMin = t;
      } else {
        // Exit edge
        if (t < tMax) tMax = t;
      }
      if (tMin > tMax) {
        return false;
      }
    }
  }

  return true;
}

/**
 * Initialize swipe detection on the play area element.
 * Listens for touch events (primary) and pointer events (desktop fallback).
 * Only registers slashes when the cumulative swipe path length >= 20px.
 * @param {HTMLElement} playArea - The play area DOM element
 * @param {function} getActiveWords - Returns array of FlyingWord objects with .el, .id, .slashed
 * @param {function} onSlash - Callback when a word is slashed: (wordId) => void
 */
function initSwipeDetector(playArea, getActiveWords, onSlash) {
  var swipePoints = [];
  var cumulativeLength = 0;
  var isSwiping = false;
  var usedTouch = false; // track if touch events fired to suppress pointer duplicates

  function getPlayAreaRelativePoint(clientX, clientY) {
    var rect = playArea.getBoundingClientRect();
    return { x: clientX - rect.left, y: clientY - rect.top };
  }

  function distance(p1, p2) {
    var dx = p2.x - p1.x;
    var dy = p2.y - p1.y;
    return Math.sqrt(dx * dx + dy * dy);
  }

  function checkIntersections(p1, p2) {
    var segment = { x1: p1.x, y1: p1.y, x2: p2.x, y2: p2.y };
    var areaRect = playArea.getBoundingClientRect();
    var words = getActiveWords();
    for (var i = 0; i < words.length; i++) {
      var word = words[i];
      if (word.slashed || !word.el) continue;
      var wr = word.el.getBoundingClientRect();
      // Convert to play area-relative coordinates
      var relRect = {
        x: wr.left - areaRect.left,
        y: wr.top - areaRect.top,
        width: wr.width,
        height: wr.height
      };
      if (segmentIntersectsRect(segment, relRect)) {
        word.slashed = true;
        onSlash(word.id);
      }
    }
  }

  function startSwipe(x, y) {
    var pt = getPlayAreaRelativePoint(x, y);
    swipePoints = [pt];
    cumulativeLength = 0;
    isSwiping = true;
  }

  function moveSwipe(x, y) {
    if (!isSwiping) return;
    var pt = getPlayAreaRelativePoint(x, y);
    var prev = swipePoints[swipePoints.length - 1];
    var segLen = distance(prev, pt);
    cumulativeLength += segLen;
    swipePoints.push(pt);

    // Only check intersections once cumulative path length exceeds 20px
    if (cumulativeLength >= 20) {
      checkIntersections(prev, pt);
    }
  }

  function endSwipe() {
    isSwiping = false;
    swipePoints = [];
    cumulativeLength = 0;
  }

  // --- Touch events (primary, for mobile) ---
  playArea.addEventListener('touchstart', function(e) {
    e.preventDefault();
    usedTouch = true;
    var touch = e.touches[0];
    startSwipe(touch.clientX, touch.clientY);
  }, { passive: false });

  playArea.addEventListener('touchmove', function(e) {
    e.preventDefault();
    var touch = e.touches[0];
    moveSwipe(touch.clientX, touch.clientY);
  }, { passive: false });

  playArea.addEventListener('touchend', function(e) {
    e.preventDefault();
    endSwipe();
  }, { passive: false });

  // --- Pointer events (fallback for desktop) ---
  playArea.addEventListener('pointerdown', function(e) {
    if (usedTouch) return; // skip if touch events are active
    startSwipe(e.clientX, e.clientY);
  });

  playArea.addEventListener('pointermove', function(e) {
    if (usedTouch) return;
    moveSwipe(e.clientX, e.clientY);
  });

  playArea.addEventListener('pointerup', function(e) {
    if (usedTouch) return;
    endSwipe();
  });
}


// ===== TEST EXPORTS =====
if (typeof module !== 'undefined') {
  module.exports = {
    validateWordEntry: validateWordEntry,
    loadSynonymDictionary: loadSynonymDictionary,
    createInitialState: createInitialState,
    processSlash: processSlash,
    allSynonymsCollected: allSynonymsCollected,
    rotateMainWord: rotateMainWord,
    createTimer: createTimer,
    tickTimer: tickTimer,
    modifyTimer: modifyTimer,
    computeDifficulty: computeDifficulty,
    createFlyingWord: createFlyingWord,
    updateWordPosition: updateWordPosition,
    selectNextWord: selectNextWord,
    segmentIntersectsRect: segmentIntersectsRect,
    initSwipeDetector: initSwipeDetector
  };
}
