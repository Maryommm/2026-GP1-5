import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Timestamp,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  runTransaction,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

const projectId = 'ethmar-plant-records-test';
const rules = readFileSync(
  new URL('../../firestore.rules', import.meta.url),
  'utf8',
);
let environment;

before(async () => {
  environment = await initializeTestEnvironment({
    projectId,
    firestore: { rules },
  });
});

beforeEach(async () => environment.clearFirestore());
after(async () => environment.cleanup());

function dbFor(uid, verified = true) {
  return environment
    .authenticatedContext(uid, {
      email: `${uid}@example.test`,
      email_verified: verified,
    })
    .firestore();
}

function plantData(land = 0, square = 0, overrides = {}) {
  const now = Timestamp.now();
  return {
    cropId: 'tomato',
    name: 'Emulator Tomato',
    category: 'vegetable',
    land,
    square,
    irrigation: { everyDays: 1, time: '07:00' },
    fertilization: null,
    plantedAt: now,
    createdAt: now,
    updatedAt: now,
    ...overrides,
  };
}

function spotId(land, square) {
  return `l${land}s${square}`;
}

async function createAt(db, uid, plantId, land, square, data = plantData(land, square)) {
  const plant = doc(db, `users/${uid}/plants/${plantId}`);
  const spot = doc(db, `users/${uid}/farmSpots/${spotId(land, square)}`);
  return runTransaction(db, async (transaction) => {
    if ((await transaction.get(spot)).exists()) throw new Error('occupied');
    transaction.set(plant, data);
    transaction.set(spot, {
      status: 'reserved',
      plantId,
      land,
      square,
      createdAt: serverTimestamp(),
    });
  });
}

async function allocateFirst(db, uid, plantId, lands = 1) {
  return runTransaction(db, async (transaction) => {
    let selected;
    for (let land = 0; land < lands && !selected; land++) {
      for (let square = 0; square < 25; square++) {
        const spot = doc(db, `users/${uid}/farmSpots/${spotId(land, square)}`);
        if (!(await transaction.get(spot)).exists()) {
          selected = { land, square, spot };
          break;
        }
      }
    }
    if (!selected) throw new Error('farm-full');
    const plant = doc(db, `users/${uid}/plants/${plantId}`);
    transaction.set(plant, plantData(selected.land, selected.square));
    transaction.set(selected.spot, {
      status: 'reserved',
      plantId,
      land: selected.land,
      square: selected.square,
      createdAt: serverTimestamp(),
    });
    return { land: selected.land, square: selected.square };
  });
}

async function seed(path, data) {
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), path), data);
  });
}

async function beginDeletion(db, uid, plantId, land, square) {
  await setDoc(doc(db, `users/${uid}/plantDeletions/${plantId}`), {
    plantId,
    land,
    square,
    startedAt: serverTimestamp(),
  });
}

describe('Plant Records ownership and validation', () => {
  test('verified owner creates plant and reservation atomically', async () => {
    const db = dbFor('owner');
    await assertSucceeds(createAt(db, 'owner', 'p1', 0, 0));
    await assertSucceeds(getDoc(doc(db, 'users/owner/plants/p1')));
    await assertSucceeds(getDoc(doc(db, 'users/owner/farmSpots/l0s0')));
  });

  test('unauthenticated, unverified and cross-user access is rejected', async () => {
    await seed('users/owner/plants/p1', plantData());
    const anonymous = environment.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(anonymous, 'users/owner/plants/p1')));
    await assertFails(getDoc(doc(dbFor('owner', false), 'users/owner/plants/p1')));
    await assertFails(getDoc(doc(dbFor('other'), 'users/owner/plants/p1')));
    await assertFails(deleteDoc(doc(dbFor('other'), 'users/owner/plants/p1')));
  });

  test('a plant or reservation cannot be created without its atomic pair', async () => {
    const db = dbFor('owner');
    await assertFails(setDoc(doc(db, 'users/owner/plants/p1'), plantData()));
    await assertFails(
      setDoc(doc(db, 'users/owner/farmSpots/l0s0'), {
        status: 'reserved',
        plantId: 'p1',
        land: 0,
        square: 0,
        createdAt: serverTimestamp(),
      }),
    );
  });

  test('malformed plants, schedules, positions and future dates are rejected', async () => {
    const db = dbFor('owner');
    const badPlants = [
      plantData(0, 0, { cropId: 'not_in_catalog' }),
      plantData(0, 0, { name: ' padded ' }),
      plantData(0, 0, { irrigation: { everyDays: 5, time: '07:00' } }),
      plantData(0, 25),
      plantData(0, 0, {
        plantedAt: Timestamp.fromMillis(Date.now() + 60 * 60 * 1000),
      }),
    ];
    for (let index = 0; index < badPlants.length; index++) {
      await assertFails(createAt(db, 'owner', `bad${index}`, 0, 0, badPlants[index]));
      assert.equal(
        (await getDoc(doc(db, 'users/owner/farmSpots/l0s0'))).exists(),
        false,
      );
    }
  });

  test('plants cannot be placed outside unlocked lands', async () => {
    const db = dbFor('owner');
    await assertFails(createAt(db, 'owner', 'p1', 1, 0));
    await seed('users/owner/stats/summary', {
      currentStreak: 0,
      lastCompletedDate: null,
      lands: 2,
    });
    await assertSucceeds(createAt(db, 'owner', 'p1', 1, 0));
  });

  test('editable fields can change but identity and placement cannot', async () => {
    const db = dbFor('owner');
    await createAt(db, 'owner', 'p1', 0, 0);
    const plant = doc(db, 'users/owner/plants/p1');
    await assertSucceeds(
      updateDoc(plant, { name: 'Renamed', updatedAt: Timestamp.now() }),
    );
    await assertFails(updateDoc(plant, { square: 1, updatedAt: Timestamp.now() }));
    await assertFails(updateDoc(plant, { cropId: 'mint', updatedAt: Timestamp.now() }));
    await assertFails(updateDoc(doc(db, 'users/owner/plants/missing'), { name: 'x' }));
  });
});

describe('Atomic placement', () => {
  test('two concurrent creates cannot reserve the same square', async () => {
    const db = dbFor('owner');
    const results = await Promise.allSettled([
      createAt(db, 'owner', 'p1', 0, 0),
      createAt(db, 'owner', 'p2', 0, 0),
    ]);
    assert.equal(results.filter((result) => result.status === 'fulfilled').length, 1);
    assert.equal(results.filter((result) => result.status === 'rejected').length, 1);
    const plants = await getDocs(collection(db, 'users/owner/plants'));
    assert.equal(plants.size, 1);
  });

  test('allocator fills the first gap and reports a full land', async () => {
    const db = dbFor('owner');
    await seed('users/owner/plants/existing', plantData(0, 0));
    await seed('users/owner/farmSpots/l0s0', {
      status: 'reserved',
      plantId: 'existing',
      land: 0,
      square: 0,
      createdAt: Timestamp.now(),
    });
    assert.deepEqual(await allocateFirst(db, 'owner', 'next'), { land: 0, square: 1 });

    await environment.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      for (let square = 2; square < 25; square++) {
        await setDoc(doc(adminDb, `users/owner/plants/fill${square}`), plantData(0, square));
        await setDoc(doc(adminDb, `users/owner/farmSpots/l0s${square}`), {
          status: 'reserved',
          plantId: `fill${square}`,
          land: 0,
          square,
          createdAt: Timestamp.now(),
        });
      }
    });
    await assert.rejects(() => allocateFirst(db, 'owner', 'overflow'), /farm-full/);
  });

  test('admin-backfilled legacy reservations make partially occupied farms safe', async () => {
    await seed('users/owner/plants/legacy', plantData(0, 0));
    await seed('users/owner/farmSpots/l0s0', {
      status: 'reserved',
      plantId: 'legacy',
      land: 0,
      square: 0,
      createdAt: Timestamp.now(),
    });

    const db = dbFor('owner');
    assert.deepEqual(await allocateFirst(db, 'owner', 'new'), { land: 0, square: 1 });
  });

  test('legacy conflicts remain occupied and are never overwritten by allocation', async () => {
    await seed('users/owner/plants/legacy1', plantData(0, 0));
    await seed('users/owner/plants/legacy2', plantData(0, 0));
    await seed('users/owner/farmSpots/l0s0', {
      status: 'conflict',
      plantIds: ['legacy1', 'legacy2'],
      land: 0,
      square: 0,
      createdAt: Timestamp.now(),
    });

    const db = dbFor('owner');
    assert.deepEqual(await allocateFirst(db, 'owner', 'new'), { land: 0, square: 1 });
    assert.equal(
      (await getDoc(doc(db, 'users/owner/farmSpots/l0s0'))).data().status,
      'conflict',
    );
  });

  test('clients cannot list, overwrite or forge conflict reservations', async () => {
    await seed('users/owner/farmSpots/l0s3', {
      status: 'conflict',
      plantIds: ['legacy1', 'legacy2'],
      land: 0,
      square: 3,
      createdAt: Timestamp.now(),
    });
    const db = dbFor('owner');
    await assertSucceeds(getDoc(doc(db, 'users/owner/farmSpots/l0s3')));
    await assertFails(getDocs(collection(db, 'users/owner/farmSpots')));
    await assertFails(updateDoc(doc(db, 'users/owner/farmSpots/l0s3'), { plantIds: [] }));
    await assertFails(deleteDoc(doc(db, 'users/owner/farmSpots/l0s3')));
  });
});

describe('Growth and retryable deletion', () => {
  test('growth requires a live parent and is blocked by a deletion marker', async () => {
    const db = dbFor('owner');
    const growth = {
      date: Timestamp.now(),
      notes: null,
      photo: null,
    };
    await assertFails(setDoc(doc(db, 'users/owner/plants/missing/growth/g1'), growth));
    await createAt(db, 'owner', 'p1', 0, 0);
    await assertSucceeds(setDoc(doc(db, 'users/owner/plants/p1/growth/g1'), growth));
    await beginDeletion(db, 'owner', 'p1', 0, 0);
    await assertFails(setDoc(doc(db, 'users/owner/plants/p1/growth/g2'), growth));
    await assertFails(updateDoc(doc(db, 'users/owner/plants/p1/growth/g1'), { notes: 'late' }));
    await assertSucceeds(deleteDoc(doc(db, 'users/owner/plants/p1/growth/g1')));
  });

  test('plant, reservation and marker must be released together', async () => {
    const db = dbFor('owner');
    await createAt(db, 'owner', 'p1', 0, 0);
    await beginDeletion(db, 'owner', 'p1', 0, 0);

    await assertFails(deleteDoc(doc(db, 'users/owner/plants/p1')));
    assert.equal((await getDoc(doc(db, 'users/owner/farmSpots/l0s0'))).exists(), true);

    const batch = writeBatch(db);
    batch.delete(doc(db, 'users/owner/plants/p1'));
    batch.delete(doc(db, 'users/owner/farmSpots/l0s0'));
    batch.delete(doc(db, 'users/owner/plantDeletions/p1'));
    await assertSucceeds(batch.commit());

    assert.equal((await getDoc(doc(db, 'users/owner/plants/p1'))).exists(), false);
    assert.equal((await getDoc(doc(db, 'users/owner/farmSpots/l0s0'))).exists(), false);
    await assertSucceeds(createAt(db, 'owner', 'replacement', 0, 0));
  });

  test('legacy plant without reservation remains editable and safely deletable', async () => {
    await seed('users/owner/plants/legacy', plantData(0, 4));
    const db = dbFor('owner');
    await assertSucceeds(
      updateDoc(doc(db, 'users/owner/plants/legacy'), {
        name: 'Legacy edited',
        updatedAt: Timestamp.now(),
      }),
    );
    await beginDeletion(db, 'owner', 'legacy', 0, 4);
    const batch = writeBatch(db);
    batch.delete(doc(db, 'users/owner/plants/legacy'));
    batch.delete(doc(db, 'users/owner/plantDeletions/legacy'));
    await assertSucceeds(batch.commit());
  });
});
