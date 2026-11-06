import assert from 'node:assert/strict';
import test from 'node:test';

import {
  planFarmSpots,
  samePlacement,
  spotId,
} from '../scripts/farm-spot-migration-plan.mjs';

test('plans deterministic reservations for partially occupied farms', () => {
  const plan = planFarmSpots([
    { id: 'p1', data: { land: 0, square: 0 } },
    { id: 'p2', data: { land: 2, square: 24 } },
  ]);
  assert.deepEqual(plan.desired.get('l0s0'), {
    status: 'reserved',
    plantId: 'p1',
    land: 0,
    square: 0,
  });
  assert.equal(plan.desired.get('l2s24').plantId, 'p2');
  assert.deepEqual(plan.conflicts, []);
});

test('records legacy conflicts without deleting or moving either plant', () => {
  const plan = planFarmSpots([
    { id: 'p2', data: { land: 0, square: 3 } },
    { id: 'p1', data: { land: 0, square: 3 } },
  ]);
  assert.deepEqual(plan.desired.get('l0s3'), {
    status: 'conflict',
    plantIds: ['p1', 'p2'],
    land: 0,
    square: 3,
  });
  assert.equal(plan.conflicts.length, 1);
});

test('reports invalid positions and compares existing records safely', () => {
  const plan = planFarmSpots([
    { id: 'bad', data: { land: 9, square: 0 } },
    { id: 'valid', data: { land: 0, square: 1 } },
  ]);
  assert.deepEqual(plan.invalid, ['bad']);
  assert.equal(
    samePlacement(
      {
        status: 'reserved',
        plantId: 'valid',
        land: 0,
        square: 1,
        createdAt: { toMillis: () => 1 },
      },
      plan.desired.get('l0s1'),
    ),
    true,
  );
  assert.equal(
    samePlacement(
      {
        status: 'reserved',
        plantId: 'other',
        land: 0,
        square: 1,
        createdAt: { toMillis: () => 1 },
      },
      plan.desired.get('l0s1'),
    ),
    false,
  );
  assert.throws(() => spotId(9, 0), RangeError);
  assert.equal(
    samePlacement(
      { status: 'reserved', plantId: 'valid', land: 0, square: 1 },
      plan.desired.get('l0s1'),
    ),
    false,
  );
});
