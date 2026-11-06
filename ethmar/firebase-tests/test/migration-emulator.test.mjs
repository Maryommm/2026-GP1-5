import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';

import { deleteApp, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { initializeTestEnvironment } from '@firebase/rules-unit-testing';

import {
  applyUser,
  discoverUsers,
  inspectUser,
} from '../scripts/farm-spot-migration-firestore.mjs';

const projectId = 'ethmar-plant-records-test';
let app;
let db;
let environment;

before(async () => {
  environment = await initializeTestEnvironment({ projectId });
  await environment.clearFirestore();
  app = initializeApp({ projectId }, 'farm-spot-migration-test');
  db = getFirestore(app);
});

after(async () => {
  await deleteApp(app);
  await environment.cleanup();
});

test('migration discovers missing parent users and backfills without moving plants', async () => {
  const user = db.collection('users').doc('legacy-without-parent');
  await user.collection('plants').doc('p1').set({ land: 0, square: 0 });
  await user.collection('plants').doc('p2').set({ land: 0, square: 3 });
  await user.collection('plants').doc('p3').set({ land: 0, square: 3 });

  const users = await discoverUsers(db);
  assert.equal(users.some((candidate) => candidate.id === user.id), true);

  const beforeApply = await inspectUser(user);
  assert.equal(beforeApply.existing.size, 0);
  assert.equal(beforeApply.plan.conflicts.length, 1);
  await applyUser(db, user);

  const reservation = (await user.collection('farmSpots').doc('l0s0').get()).data();
  assert.equal(reservation.status, 'reserved');
  assert.equal(reservation.plantId, 'p1');
  const conflict = (await user.collection('farmSpots').doc('l0s3').get()).data();
  assert.equal(conflict.status, 'conflict');
  assert.deepEqual(conflict.plantIds, ['p2', 'p3']);
  assert.deepEqual(
    (await user.collection('plants').listDocuments())
      .map((ref) => ref.id)
      .sort(),
    ['p1', 'p2', 'p3'],
  );
});

test('migration refuses to overwrite a disagreeing reservation', async () => {
  const user = db.collection('users').doc('blocked');
  await user.collection('plants').doc('real').set({ land: 0, square: 0 });
  await user.collection('farmSpots').doc('l0s0').set({
    status: 'reserved',
    plantId: 'wrong',
    land: 0,
    square: 0,
  });

  const inspection = await inspectUser(user);
  assert.equal(inspection.blockers.length, 1);
  await assert.rejects(() => applyUser(db, user), /disagrees with existing plants/);
  assert.equal(
    (await user.collection('farmSpots').doc('l0s0').get()).data().plantId,
    'wrong',
  );
});

test('migration blocks invalid plants and orphan reservations without writing', async () => {
  const user = db.collection('users').doc('unsafe-legacy');
  await user.collection('plants').doc('invalid').set({ land: 9, square: 0 });
  await user.collection('farmSpots').doc('l0s4').set({
    status: 'reserved',
    plantId: 'missing',
    land: 0,
    square: 4,
  });

  const inspection = await inspectUser(user);
  assert.equal(inspection.blockers.length, 2);
  await assert.rejects(() => applyUser(db, user), /invalid plant positions/);
  assert.equal((await user.collection('farmSpots').doc('l0s4').get()).exists, true);
});
