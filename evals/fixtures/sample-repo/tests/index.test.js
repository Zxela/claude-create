import { describe, it } from 'node:test';
import assert from 'node:assert';
import { greet, validateUser, calculateTotal } from '../src/index.js';

describe('greet', () => {
  it('returns greeting with name', () => {
    assert.strictEqual(greet('World'), 'Hello, World!');
  });
});

describe('validateUser', () => {
  it('returns true for valid email', () => {
    assert.strictEqual(validateUser({ email: 'test@example.com' }), true);
  });

  it('returns false for invalid email', () => {
    assert.strictEqual(validateUser({ email: 'invalid' }), false);
  });

  // Missing test for null input - this is the bug we want to fix
});

describe('calculateTotal', () => {
  it('sums item prices', () => {
    const items = [{ price: 10 }, { price: 20 }];
    assert.strictEqual(calculateTotal(items), 30);
  });
});
