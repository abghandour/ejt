/**
 * Preservation Property Tests — Desktop/Android playTone Behavior Unchanged
 *
 * **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5**
 *
 * Property 2 (Preservation): For all valid playTone parameter combinations with
 * AudioContext in 'running' state, oscillator is created with correct frequency and type,
 * gain envelope is applied, and oscillator is started and stopped.
 *
 * EXPECTED: These tests PASS on unfixed code — they capture baseline desktop behavior.
 */

import { describe, it, expect, beforeEach } from 'vitest';
import { test as fcTest } from '@fast-check/vitest';
import fc from 'fast-check';
import { readFileSync } from 'fs';
import { resolve } from 'path';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// --- Desktop AudioContext Mock (state starts as 'running') ---
let oscillatorsCreated = [];
let gainNodesCreated = [];
let resumeCalls = [];

function createDesktopMockAudioContext() {
  const ctx = {
    state: 'running',
    currentTime: 1.0,
    destination: { __dest: true },
    resume() {
      resumeCalls.push(true);
      return Promise.resolve();
    },
    createOscillator() {
      const osc = {
        type: 'sine',
        frequency: { value: 440 },
        connect(node) { return node; },
        start(time) { osc._startTime = time; osc._started = true; },
        stop(time) { osc._stopTime = time; osc._stopped = true; },
        _started: false,
        _stopped: false,
        _startTime: null,
        _stopTime: null,
      };
      oscillatorsCreated.push(osc);
      return osc;
    },
    createGain() {
      const gainNode = {
        gain: {
          value: 1,
          _setValueAtTimeCalls: [],
          _linearRampCalls: [],
          _exponentialRampCalls: [],
          setValueAtTime(val, time) {
            gainNode.gain._setValueAtTimeCalls.push({ val, time });
          },
          linearRampToValueAtTime(val, time) {
            gainNode.gain._linearRampCalls.push({ val, time });
          },
          exponentialRampToValueAtTime(val, time) {
            gainNode.gain._exponentialRampCalls.push({ val, time });
          },
        },
        connect(dest) { return dest; },
      };
      gainNodesCreated.push(gainNode);
      return gainNode;
    },
    createBuffer() { return {}; },
    createBufferSource() {
      return { buffer: null, connect() {}, start() {} };
    },
  };
  return ctx;
}

// --- Load engine.js as a script (global vars, not ES modules) ---
let engine;

function loadEngine() {
  globalThis.window = globalThis.window || globalThis;
  globalThis.window.addEventListener = globalThis.window.addEventListener || function() {};
  globalThis.document = globalThis.document || {
    addEventListener() {},
    createElement() {
      return { style: {}, innerHTML: '', appendChild() {}, querySelector() { return null; } };
    },
    body: { appendChild() {} },
    head: { appendChild() {} },
    querySelectorAll() { return []; },
  };
  globalThis.localStorage = globalThis.localStorage || (() => {
    const store = {};
    return {
      getItem(k) { return store[k] || null; },
      setItem(k, v) { store[k] = String(v); },
    };
  })();
  globalThis.navigator = globalThis.navigator || {};
  globalThis.alert = globalThis.alert || function() {};
  globalThis.prompt = globalThis.prompt || function() {};
  globalThis.fetch = globalThis.fetch || function() { return Promise.resolve({ ok: false }); };

  // Desktop AudioContext — starts in 'running' state
  globalThis.AudioContext = function() { return createDesktopMockAudioContext(); };
  globalThis.webkitAudioContext = globalThis.AudioContext;
  if (globalThis.window !== globalThis) {
    globalThis.window.AudioContext = globalThis.AudioContext;
    globalThis.window.webkitAudioContext = globalThis.AudioContext;
  }

  const enginePath = resolve(__dirname, '..', 'engine.js');
  const src = readFileSync(enginePath, 'utf-8');
  const cleanSrc = src.replace(/\/\/ ===== TEST EXPORTS =====[\s\S]*$/, '');

  const fn = new Function(
    'window', 'document', 'localStorage', 'navigator', 'alert', 'prompt', 'fetch', 'AudioContext', 'webkitAudioContext',
    cleanSrc + '\n' +
    'return { getAudioCtx, unlockAudio, playTone, SeedEngine, shuffleArray, isValidEntry, validateDictionary, shareText, setValidationRegex, ' +
    'get audioCtx() { return audioCtx; }, set audioCtx(v) { audioCtx = v; }, ' +
    'get audioUnlocked() { return audioUnlocked; }, set audioUnlocked(v) { audioUnlocked = v; } };'
  );
  return fn(
    globalThis.window, globalThis.document, globalThis.localStorage,
    globalThis.navigator, globalThis.alert, globalThis.prompt, globalThis.fetch,
    globalThis.AudioContext, globalThis.webkitAudioContext
  );
}

engine = loadEngine();

// --- Arbitraries for playTone parameters ---
const freqArb = fc.integer({ min: 20, max: 20000 });
const durArb = fc.double({ min: 0.01, max: 5, noNaN: true });
const typeArb = fc.constantFrom('sine', 'square', 'sawtooth', 'triangle');
const volArb = fc.double({ min: 0.001, max: 1, noNaN: true });
const delayArb = fc.double({ min: 0, max: 2, noNaN: true });

// --- Reset engine state between tests ---
function resetEngine() {
  engine.audioCtx = null;
  engine.audioUnlocked = false;
  oscillatorsCreated = [];
  gainNodesCreated = [];
  resumeCalls = [];
}

// ============================================================
// Preservation Property Tests
// ============================================================

describe('Preservation — Desktop playTone Behavior', () => {
  beforeEach(() => {
    resetEngine();
  });

  // --- Property 2a: playTone creates oscillator with correct frequency and type ---
  describe('Property 2a: playTone creates oscillator with correct frequency and type', () => {
    /**
     * **Validates: Requirements 3.1, 3.2, 3.4**
     */
    fcTest.prop([freqArb, durArb, typeArb, volArb, delayArb])(
      'for all valid params, oscillator has correct frequency and type',
      (freq, dur, type, vol, delay) => {
        resetEngine();
        engine.playTone(freq, dur, type, vol, delay);

        expect(oscillatorsCreated.length).toBe(1);
        const osc = oscillatorsCreated[0];
        expect(osc.frequency.value).toBe(freq);
        expect(osc.type).toBe(type);
      }
    );
  });

  // --- Property 2b: playTone applies gain envelope with correct timing ---
  describe('Property 2b: playTone applies gain envelope correctly', () => {
    /**
     * **Validates: Requirements 3.1, 3.2, 3.4**
     */
    fcTest.prop([freqArb, durArb, typeArb, volArb, delayArb])(
      'for all valid params, gain envelope is applied with correct values and timing',
      (freq, dur, type, vol, delay) => {
        resetEngine();
        engine.playTone(freq, dur, type, vol, delay);

        expect(gainNodesCreated.length).toBe(1);
        const gain = gainNodesCreated[0];
        const ctxTime = engine.audioCtx.currentTime;

        // setValueAtTime(0.001, currentTime + delay)
        expect(gain.gain._setValueAtTimeCalls.length).toBe(1);
        expect(gain.gain._setValueAtTimeCalls[0].val).toBe(0.001);
        expect(gain.gain._setValueAtTimeCalls[0].time).toBeCloseTo(ctxTime + delay, 5);

        // linearRampToValueAtTime(vol, currentTime + delay + 0.02)
        expect(gain.gain._linearRampCalls.length).toBe(1);
        expect(gain.gain._linearRampCalls[0].val).toBe(vol);
        expect(gain.gain._linearRampCalls[0].time).toBeCloseTo(ctxTime + delay + 0.02, 5);

        // exponentialRampToValueAtTime(0.001, currentTime + delay + dur)
        expect(gain.gain._exponentialRampCalls.length).toBe(1);
        expect(gain.gain._exponentialRampCalls[0].val).toBe(0.001);
        expect(gain.gain._exponentialRampCalls[0].time).toBeCloseTo(ctxTime + delay + dur, 5);
      }
    );
  });

  // --- Property 2c: playTone starts and stops oscillator at correct times ---
  describe('Property 2c: playTone starts and stops oscillator at correct times', () => {
    /**
     * **Validates: Requirements 3.1, 3.2, 3.4**
     */
    fcTest.prop([freqArb, durArb, typeArb, volArb, delayArb])(
      'for all valid params, oscillator is started and stopped at correct times',
      (freq, dur, type, vol, delay) => {
        resetEngine();
        engine.playTone(freq, dur, type, vol, delay);

        expect(oscillatorsCreated.length).toBe(1);
        const osc = oscillatorsCreated[0];
        const ctxTime = engine.audioCtx.currentTime;

        expect(osc._started).toBe(true);
        expect(osc._stopped).toBe(true);
        expect(osc._startTime).toBeCloseTo(ctxTime + delay, 5);
        expect(osc._stopTime).toBeCloseTo(ctxTime + delay + dur, 5);
      }
    );
  });

  // --- Property 2d: No resume() call when AudioContext is already 'running' ---
  describe('Property 2d: No resume() when AudioContext is already running', () => {
    /**
     * **Validates: Requirements 3.1, 3.2**
     */
    fcTest.prop([freqArb, durArb, typeArb, volArb, delayArb])(
      'for all valid params with running context, resume() is not called',
      (freq, dur, type, vol, delay) => {
        resetEngine();
        engine.playTone(freq, dur, type, vol, delay);

        // On desktop, AudioContext starts as 'running', so resume() should not be called
        expect(resumeCalls.length).toBe(0);
      }
    );
  });

  // --- Edge cases: playTone with boundary parameters ---
  describe('Edge cases: playTone with boundary parameters', () => {
    it('handles very high frequency (20000 Hz)', () => {
      engine.playTone(20000, 0.1, 'sine', 0.1, 0);
      expect(oscillatorsCreated.length).toBe(1);
      expect(oscillatorsCreated[0].frequency.value).toBe(20000);
      expect(oscillatorsCreated[0]._started).toBe(true);
    });

    it('handles 0 delay', () => {
      engine.playTone(440, 0.3, 'sine', 0.1, 0);
      expect(oscillatorsCreated.length).toBe(1);
      const osc = oscillatorsCreated[0];
      const ctxTime = engine.audioCtx.currentTime;
      expect(osc._startTime).toBeCloseTo(ctxTime, 5);
    });

    it('handles missing optional args (type, vol, delay default)', () => {
      engine.playTone(440, 0.3);
      expect(oscillatorsCreated.length).toBe(1);
      const osc = oscillatorsCreated[0];
      // Defaults: type='sine', vol=0.1, delay=0
      expect(osc.type).toBe('sine');
      expect(osc._started).toBe(true);
      expect(osc._stopped).toBe(true);

      const gain = gainNodesCreated[0];
      expect(gain.gain._linearRampCalls[0].val).toBe(0.1);
    });

    it('handles very short duration', () => {
      engine.playTone(440, 0.01, 'triangle', 0.5, 0);
      expect(oscillatorsCreated.length).toBe(1);
      expect(oscillatorsCreated[0]._started).toBe(true);
      expect(oscillatorsCreated[0]._stopped).toBe(true);
    });

    it('handles all oscillator types', () => {
      const types = ['sine', 'square', 'sawtooth', 'triangle'];
      types.forEach((type, i) => {
        resetEngine();
        engine.playTone(440, 0.3, type, 0.1, 0);
        expect(oscillatorsCreated[0].type).toBe(type);
      });
    });
  });
});

// ============================================================
// Non-Audio Engine Functions — Smoke Tests
// ============================================================

describe('Preservation — Non-audio engine functions unaffected', () => {
  it('SeedEngine produces deterministic results', () => {
    const rng1 = new engine.SeedEngine(42);
    const rng2 = new engine.SeedEngine(42);
    const results1 = [];
    const results2 = [];
    for (let i = 0; i < 10; i++) {
      results1.push(rng1.next());
      results2.push(rng2.next());
    }
    expect(results1).toEqual(results2);
    // Values should be in [0, 1)
    results1.forEach(v => {
      expect(v).toBeGreaterThanOrEqual(0);
      expect(v).toBeLessThan(1);
    });
  });

  it('SeedEngine.shuffle returns a permutation of the input', () => {
    const rng = new engine.SeedEngine(123);
    const arr = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    const shuffled = rng.shuffle(arr);
    expect(shuffled).toHaveLength(arr.length);
    expect(shuffled.sort((a, b) => a - b)).toEqual(arr);
  });

  it('shuffleArray returns a permutation of the input', () => {
    const arr = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    const shuffled = engine.shuffleArray(arr);
    expect(shuffled).toHaveLength(arr.length);
    expect(shuffled.sort((a, b) => a - b)).toEqual(arr);
    // Original array is not mutated
    expect(arr).toEqual([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
  });

  it('isValidEntry validates correctly', () => {
    expect(engine.isValidEntry({ word: 'кошка', translation: 'cat' })).toBe(true);
    expect(engine.isValidEntry({ word: 'ab', translation: 'short' })).toBe(false); // too short
    expect(engine.isValidEntry({ word: '', translation: '' })).toBe(false);
    expect(engine.isValidEntry(null)).toBe(false);
  });

  it('validateDictionary filters and validates entries', () => {
    const words = [
      'кошка', 'собака', 'молоко', 'дерево', 'книга', 'школа', 'город',
      'улица', 'работа', 'музыка', 'погода', 'машина', 'письмо', 'сердце',
      'солнце', 'ветер', 'облако', 'берег', 'камень', 'песок', 'озеро',
      'птица', 'рыбка', 'цветок', 'листок',
    ];
    const entries = words.map((w, i) => ({ word: w, translation: 'word' + i }));
    // Should not throw — enough valid entries
    const result = engine.validateDictionary(entries);
    expect(result.length).toBeGreaterThanOrEqual(20);
  });

  it('validateDictionary throws on too few valid entries', () => {
    expect(() => engine.validateDictionary([
      { word: 'кот', translation: 'cat' },
    ])).toThrow('Dictionary too small');
  });
});
