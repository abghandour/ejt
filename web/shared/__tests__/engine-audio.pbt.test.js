/**
 * Bug Condition Exploration Test — iPhone AudioContext Suspended in Non-Gesture Context
 *
 * **Validates: Requirements 1.1, 1.2, 1.3, 1.4**
 *
 * Property 1 (Fault Condition): For all valid playTone parameters (freq, dur, type, vol, delay),
 * when at least one user gesture has triggered unlockAudio(), the AudioContext SHALL be in
 * 'running' state and an oscillator SHALL be scheduled.
 *
 * EXPECTED: These tests FAIL on unfixed code — failure confirms the bug exists.
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

// --- iOS AudioContext Mock ---
let inGestureContext = false;
let oscillatorsCreated = [];
let resumeCalls = [];

function setGestureContext(val) {
  inGestureContext = val;
}

function createMockAudioContext() {
  const ctx = {
    state: 'suspended',
    currentTime: 0,
    destination: {},
    resume() {
      resumeCalls.push({ inGesture: inGestureContext });
      if (inGestureContext) {
        ctx.state = 'running';
      }
      return Promise.resolve();
    },
    createOscillator() {
      const osc = {
        type: 'sine',
        frequency: { value: 440 },
        connect(node) { return node; },
        start() { osc._started = true; },
        stop() { osc._stopped = true; },
        _started: false,
        _stopped: false,
      };
      oscillatorsCreated.push(osc);
      return osc;
    },
    createGain() {
      return {
        gain: {
          value: 1,
          setValueAtTime() {},
          linearRampToValueAtTime() {},
          exponentialRampToValueAtTime() {},
        },
        connect(dest) { return dest; },
      };
    },
    createBuffer() { return {}; },
    createBufferSource() {
      return { buffer: null, connect() {}, start() {} };
    },
  };
  return ctx;
}

// --- Load engine.js as a script (it uses global vars, not modules) ---
// We eval it in a controlled scope that captures the globals it defines.

let engine;

function loadEngine() {
  // Set up minimal browser globals
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

  // Mock AudioContext constructor
  globalThis.AudioContext = function() { return createMockAudioContext(); };
  globalThis.webkitAudioContext = globalThis.AudioContext;
  if (globalThis.window !== globalThis) {
    globalThis.window.AudioContext = globalThis.AudioContext;
    globalThis.window.webkitAudioContext = globalThis.AudioContext;
  }

  const enginePath = resolve(__dirname, '..', 'engine.js');
  const src = readFileSync(enginePath, 'utf-8');

  // Strip the conditional module.exports at the bottom (we use the globals directly)
  const cleanSrc = src.replace(/\/\/ ===== TEST EXPORTS =====[\s\S]*$/, '');

  // Eval engine.js in a function scope, injecting browser globals as parameters
  // so that var declarations (window, document, etc.) are accessible inside.
  const fn = new Function(
    'window', 'document', 'localStorage', 'navigator', 'alert', 'prompt', 'fetch', 'AudioContext', 'webkitAudioContext',
    cleanSrc + '\n' +
    'return { getAudioCtx, unlockAudio, playTone, ' +
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
  resumeCalls = [];
  inGestureContext = false;
}

// ============================================================
// Test Cases
// ============================================================

describe('Bug Condition Exploration — iOS AudioContext', () => {
  beforeEach(() => {
    resetEngine();
  });

  // ---- Test Case 1 ----
  describe('Case 1: Lazy creation from setTimeout without prior gesture', () => {
    it('AudioContext starts suspended and playTone from non-gesture context produces no useful oscillator', () => {
      setGestureContext(false);
      engine.playTone(440, 0.3, 'sine', 0.1, 0);

      const ctx = engine.audioCtx;
      expect(ctx.state).toBe('suspended');
    });
  });

  // ---- Test Case 2 ----
  describe('Case 2: Resume from setInterval when context is suspended', () => {
    it('playTone returns early on suspended context without calling resume', () => {
      setGestureContext(false);
      engine.playTone(440, 0.3, 'sine', 0.1, 0);

      oscillatorsCreated = [];
      resumeCalls = [];
      engine.playTone(880, 0.2, 'square', 0.1, 0);

      const ctx = engine.audioCtx;
      expect(ctx.state).toBe('suspended');
      // Fix: playTone no longer calls resume from non-gesture context
      const nonGestureResumes = resumeCalls.filter(r => !r.inGesture);
      expect(nonGestureResumes.length).toBe(0);
    });
  });

  // ---- Test Case 3 ----
  describe('Case 3: unlockAudio sets audioUnlocked before ctx.state is running', () => {
    it('audioUnlocked flag is true but context is still suspended', () => {
      // Create context outside gesture first (starts suspended)
      setGestureContext(false);
      engine.getAudioCtx();
      const ctx = engine.audioCtx;
      expect(ctx.state).toBe('suspended');

      // Override resume to simulate iOS async behavior where resume()
      // doesn't synchronously transition state even in gesture context
      ctx.resume = function () {
        resumeCalls.push({ inGesture: inGestureContext });
        // Simulate: promise resolves but state doesn't change synchronously
        return Promise.resolve();
      };

      setGestureContext(true);
      engine.unlockAudio();

      // Bug: audioUnlocked is set to true even though ctx.state is still 'suspended'
      expect(engine.audioUnlocked).toBe(true);
      expect(ctx.state).toBe('suspended');
    });
  });

  // ---- Test Case 4 ----
  describe('Case 4: Re-suspension after inactivity prevents retry', () => {
    it('audioUnlocked flag prevents full re-unlock on subsequent gestures', () => {
      // Initial successful unlock
      setGestureContext(true);
      engine.unlockAudio();
      const ctx = engine.audioCtx;
      expect(ctx.state).toBe('running');
      expect(engine.audioUnlocked).toBe(true);

      // Simulate iOS re-suspending after inactivity
      ctx.state = 'suspended';

      // Override resume to NOT change state (simulating iOS failure on re-suspend)
      ctx.resume = function () {
        resumeCalls.push({ inGesture: inGestureContext });
        return Promise.resolve();
      };

      // Another gesture fires unlockAudio
      oscillatorsCreated = [];
      resumeCalls = [];
      engine.unlockAudio();

      // Fix: unlockAudio recreates AudioContext when resume doesn't work,
      // so engine.audioCtx is a NEW object in 'running' state
      expect(engine.audioCtx.state).toBe('running');
    });
  });

  // ---- Property-Based Test ----
  describe('Property 1: playTone after gesture SHALL have running context and scheduled oscillator', () => {
    fcTest.prop([freqArb, durArb, typeArb, volArb, delayArb])(
      'for all valid playTone params, after unlockAudio gesture, ctx is running and oscillator is scheduled',
      (freq, dur, type, vol, delay) => {
        resetEngine();

        // Simulate user gesture triggering unlockAudio
        setGestureContext(true);
        engine.unlockAudio();

        // Now call playTone from a non-gesture context (setTimeout/setInterval)
        setGestureContext(false);
        oscillatorsCreated = [];
        engine.playTone(freq, dur, type, vol, delay);

        const ctx = engine.audioCtx;
        expect(ctx.state).toBe('running');
        expect(oscillatorsCreated.length).toBeGreaterThanOrEqual(1);
        const osc = oscillatorsCreated[oscillatorsCreated.length - 1];
        expect(osc._started).toBe(true);
      }
    );
  });

  // ---- Property-Based Test: Gesture with async resume failure ----
  describe('Property 1b: unlockAudio SHALL ensure running state even with prior lazy creation', () => {
    fcTest.prop([freqArb, durArb, typeArb, volArb, delayArb])(
      'for all valid playTone params, after lazy creation + gesture unlock, ctx SHALL be running',
      (freq, dur, type, vol, delay) => {
        resetEngine();

        // Lazy creation outside gesture (iOS starts suspended)
        setGestureContext(false);
        engine.getAudioCtx();
        expect(engine.audioCtx.state).toBe('suspended');

        // Override resume to simulate iOS async behavior
        const ctx = engine.audioCtx;
        ctx.resume = function () {
          resumeCalls.push({ inGesture: inGestureContext });
          return Promise.resolve();
        };

        // User gesture triggers unlockAudio
        setGestureContext(true);
        engine.unlockAudio();

        // Fix: unlockAudio recreates AudioContext when resume doesn't work,
        // so engine.audioCtx is a NEW object in 'running' state
        expect(engine.audioUnlocked).toBe(true);
        expect(engine.audioCtx.state).toBe('running');
      }
    );
  });
});
