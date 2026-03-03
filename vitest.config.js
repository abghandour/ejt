import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    include: ['web/**/__tests__/**/*.test.js'],
  },
});
