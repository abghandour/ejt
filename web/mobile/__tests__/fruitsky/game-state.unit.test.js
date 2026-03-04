import { describe, it, expect } from 'vitest';
import { createRequire } from 'module';
const require = createRequire(import.meta.url);
const {
  createInitialState,
  processSlash,
  allSynonymsCollected,
  rotateMainWord
} = require('../../fruitsky-engine');

const makeDictionary = () => ({
  words: [
    {
      word: 'быстрый',
      translation: 'fast',
      synonyms: [
        { word: 'скорый', translation: 'quick' },
        { word: 'стремительный', translation: 'rapid' },
        { word: 'проворный', translation: 'agile' }
      ]
    },
    {
      word: 'большой',
      translation: 'big',
      synonyms: [
        { word: 'огромный', translation: 'huge' },
        { word: 'крупный', translation: 'large' },
        { word: 'великий', translation: 'great' }
      ]
    }
  ],
  distractors: [
    { word: 'медленный', translation: 'slow' },
    { word: 'тяжёлый', translation: 'heavy' }
  ]
});

describe('createInitialState', () => {
  it('produces correct starting state', () => {
    const dict = makeDictionary();
    const state = createInitialState(dict);

    expect(state.score).toBe(0);
    expect(state.lives).toBe(3);
    expect(state.timeRemaining).toBe(60);
    expect(state.elapsedTime).toBe(0);
    expect(state.collectedSynonyms).toBeInstanceOf(Set);
    expect(state.collectedSynonyms.size).toBe(0);
    expect(state.wordsCompleted).toBe(0);
    expect(state.totalSynonymsSlashed).toBe(0);
    expect(state.activeWords).toEqual([]);
    expect(state.phase).toBe('playing');
  });

  it('selects a main word from the dictionary', () => {
    const dict = makeDictionary();
    const state = createInitialState(dict);
    const wordTexts = dict.words.map(w => w.word);
    expect(wordTexts).toContain(state.currentMainWord.word);
  });
});

describe('processSlash', () => {
  const baseState = () => ({
    score: 50,
    lives: 3,
    timeRemaining: 30,
    elapsedTime: 10,
    currentMainWord: makeDictionary().words[0],
    collectedSynonyms: new Set(),
    wordsCompleted: 0,
    totalSynonymsSlashed: 2,
    activeWords: [],
    phase: 'playing'
  });

  it('synonym slash: +10 points, adds to collectedSynonyms, increments totalSynonymsSlashed', () => {
    const state = baseState();
    const result = processSlash(state, 'synonym', 'скорый');
    expect(result.score).toBe(60);
    expect(result.totalSynonymsSlashed).toBe(3);
    expect(result.collectedSynonyms.has('скорый')).toBe(true);
    expect(result.lives).toBe(3);
  });

  it('distractor slash: -1 life', () => {
    const state = baseState();
    const result = processSlash(state, 'distractor');
    expect(result.lives).toBe(2);
    expect(result.score).toBe(50);
    expect(result.phase).toBe('playing');
  });

  it('distractor slash: gameover when lives reach 0', () => {
    const state = baseState();
    state.lives = 1;
    const result = processSlash(state, 'distractor');
    expect(result.lives).toBe(0);
    expect(result.phase).toBe('gameover');
  });

  it('powerup slash: +5 seconds', () => {
    const state = baseState();
    const result = processSlash(state, 'powerup');
    expect(result.timeRemaining).toBe(35);
    expect(result.score).toBe(50);
  });

  it('bomb slash: -5 seconds', () => {
    const state = baseState();
    const result = processSlash(state, 'bomb');
    expect(result.timeRemaining).toBe(25);
    expect(result.score).toBe(50);
  });

  it('bomb slash: clamps time to 0', () => {
    const state = baseState();
    state.timeRemaining = 3;
    const result = processSlash(state, 'bomb');
    expect(result.timeRemaining).toBe(0);
  });

  it('returns a new state object (immutable)', () => {
    const state = baseState();
    const result = processSlash(state, 'synonym', 'скорый');
    expect(result).not.toBe(state);
    expect(state.score).toBe(50);
    expect(state.collectedSynonyms.size).toBe(0);
  });
});

describe('allSynonymsCollected', () => {
  it('returns false when not all synonyms collected', () => {
    const state = {
      collectedSynonyms: new Set(['скорый']),
      currentMainWord: makeDictionary().words[0]
    };
    expect(allSynonymsCollected(state)).toBe(false);
  });

  it('returns true when all synonyms collected', () => {
    const state = {
      collectedSynonyms: new Set(['скорый', 'стремительный', 'проворный']),
      currentMainWord: makeDictionary().words[0]
    };
    expect(allSynonymsCollected(state)).toBe(true);
  });
});

describe('rotateMainWord', () => {
  it('selects new word, resets collectedSynonyms, adds +25 bonus, increments wordsCompleted', () => {
    const dict = makeDictionary();
    const state = {
      score: 100, lives: 3, timeRemaining: 40, elapsedTime: 20,
      currentMainWord: dict.words[0],
      collectedSynonyms: new Set(['скорый', 'стремительный', 'проворный']),
      wordsCompleted: 1, totalSynonymsSlashed: 5, activeWords: [], phase: 'playing'
    };
    const result = rotateMainWord(state, dict);
    expect(result.score).toBe(125);
    expect(result.wordsCompleted).toBe(2);
    expect(result.collectedSynonyms.size).toBe(0);
    expect(result.currentMainWord.word).not.toBe(state.currentMainWord.word);
  });

  it('keeps same word when dictionary has only one entry', () => {
    const dict = { words: [makeDictionary().words[0]], distractors: [] };
    const state = {
      score: 50, lives: 3, timeRemaining: 40, elapsedTime: 20,
      currentMainWord: dict.words[0],
      collectedSynonyms: new Set(), wordsCompleted: 0,
      totalSynonymsSlashed: 0, activeWords: [], phase: 'playing'
    };
    const result = rotateMainWord(state, dict);
    expect(result.score).toBe(75);
    expect(result.wordsCompleted).toBe(1);
    expect(result.currentMainWord.word).toBe(dict.words[0].word);
  });

  it('returns a new state object (immutable)', () => {
    const dict = makeDictionary();
    const state = {
      score: 100, lives: 3, timeRemaining: 40, elapsedTime: 20,
      currentMainWord: dict.words[0],
      collectedSynonyms: new Set(['a', 'b', 'c']),
      wordsCompleted: 0, totalSynonymsSlashed: 3, activeWords: [], phase: 'playing'
    };
    const result = rotateMainWord(state, dict);
    expect(result).not.toBe(state);
    expect(state.score).toBe(100);
    expect(state.wordsCompleted).toBe(0);
  });
});
