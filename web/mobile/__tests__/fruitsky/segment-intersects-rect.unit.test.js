import { describe, it, expect } from 'vitest';
import { createRequire } from 'module';
const require = createRequire(import.meta.url);
const { segmentIntersectsRect } = require('../../fruitsky-engine');

const rect = { x: 100, y: 100, width: 50, height: 30 };

describe('segmentIntersectsRect', () => {
  it('returns true when segment is fully inside the rect', () => {
    const seg = { x1: 110, y1: 110, x2: 140, y2: 120 };
    expect(segmentIntersectsRect(seg, rect)).toBe(true);
  });

  it('returns true when segment crosses the left edge', () => {
    const seg = { x1: 80, y1: 115, x2: 120, y2: 115 };
    expect(segmentIntersectsRect(seg, rect)).toBe(true);
  });

  it('returns true when segment crosses the right edge', () => {
    const seg = { x1: 130, y1: 115, x2: 170, y2: 115 };
    expect(segmentIntersectsRect(seg, rect)).toBe(true);
  });

  it('returns true when segment crosses the top edge', () => {
    const seg = { x1: 125, y1: 80, x2: 125, y2: 115 };
    expect(segmentIntersectsRect(seg, rect)).toBe(true);
  });

  it('returns true when segment crosses the bottom edge', () => {
    const seg = { x1: 125, y1: 120, x2: 125, y2: 150 };
    expect(segmentIntersectsRect(seg, rect)).toBe(true);
  });

  it('returns true when segment crosses two opposite edges (through rect)', () => {
    const seg = { x1: 80, y1: 115, x2: 170, y2: 115 };
    expect(segmentIntersectsRect(seg, rect)).toBe(true);
  });

  it('returns true for diagonal segment crossing the rect', () => {
    const seg = { x1: 90, y1: 90, x2: 160, y2: 140 };
    expect(segmentIntersectsRect(seg, rect)).toBe(true);
  });

  it('returns false when segment is fully to the left', () => {
    const seg = { x1: 10, y1: 115, x2: 90, y2: 115 };
    expect(segmentIntersectsRect(seg, rect)).toBe(false);
  });

  it('returns false when segment is fully to the right', () => {
    const seg = { x1: 160, y1: 115, x2: 250, y2: 115 };
    expect(segmentIntersectsRect(seg, rect)).toBe(false);
  });

  it('returns false when segment is fully above', () => {
    const seg = { x1: 125, y1: 10, x2: 125, y2: 90 };
    expect(segmentIntersectsRect(seg, rect)).toBe(false);
  });

  it('returns false when segment is fully below', () => {
    const seg = { x1: 125, y1: 140, x2: 125, y2: 200 };
    expect(segmentIntersectsRect(seg, rect)).toBe(false);
  });

  it('returns false for diagonal segment missing the rect', () => {
    const seg = { x1: 10, y1: 10, x2: 90, y2: 90 };
    expect(segmentIntersectsRect(seg, rect)).toBe(false);
  });

  it('handles zero-length segment (point) inside rect', () => {
    const seg = { x1: 125, y1: 115, x2: 125, y2: 115 };
    expect(segmentIntersectsRect(seg, rect)).toBe(true);
  });

  it('handles zero-length segment (point) outside rect', () => {
    const seg = { x1: 10, y1: 10, x2: 10, y2: 10 };
    expect(segmentIntersectsRect(seg, rect)).toBe(false);
  });

  it('returns true when segment touches the rect edge exactly', () => {
    // Segment endpoint lands exactly on the left edge
    const seg = { x1: 80, y1: 115, x2: 100, y2: 115 };
    expect(segmentIntersectsRect(seg, rect)).toBe(true);
  });
});
