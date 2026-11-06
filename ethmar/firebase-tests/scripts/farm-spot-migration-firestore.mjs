import { FieldValue } from 'firebase-admin/firestore';

import {
  planFarmSpots,
  samePlacement,
} from './farm-spot-migration-plan.mjs';

function userRefForNestedDocument(documentRef, collectionId) {
  const collection = documentRef.parent;
  const userRef = collection.parent;
  if (
    collection.id !== collectionId ||
    !userRef ||
    userRef.parent.id !== 'users'
  ) {
    return null;
  }
  return userRef;
}

// Firestore permits subcollections below a missing parent document. Include
// users discovered through plants and farmSpots so a legacy account cannot be
// silently omitted just because users/{uid} itself does not exist.
export async function discoverUsers(db) {
  const [users, plants, spots] = await Promise.all([
    db.collection('users').get(),
    db.collectionGroup('plants').get(),
    db.collectionGroup('farmSpots').get(),
  ]);
  const refs = new Map(users.docs.map((document) => [document.id, document.ref]));
  for (const document of plants.docs) {
    const userRef = userRefForNestedDocument(document.ref, 'plants');
    if (userRef) refs.set(userRef.id, userRef);
  }
  for (const document of spots.docs) {
    const userRef = userRefForNestedDocument(document.ref, 'farmSpots');
    if (userRef) refs.set(userRef.id, userRef);
  }
  return [...refs.values()].sort((a, b) => a.id.localeCompare(b.id));
}

export async function inspectUser(userRef) {
  const [plantsSnapshot, spotsSnapshot] = await Promise.all([
    userRef.collection('plants').get(),
    userRef.collection('farmSpots').get(),
  ]);
  const plants = plantsSnapshot.docs.map((document) => ({
    id: document.id,
    data: document.data(),
  }));
  const existing = new Map(
    spotsSnapshot.docs.map((document) => [document.id, document.data()]),
  );
  const plan = planFarmSpots(plants);
  const blockers = [];
  for (const plantId of plan.invalid) {
    blockers.push({ plantId, reason: 'plant has an invalid farm position' });
  }
  for (const [id, desired] of plan.desired) {
    const current = existing.get(id);
    if (current && !samePlacement(current, desired)) {
      blockers.push({ spotId: id, reason: 'existing document disagrees with plants' });
    }
  }
  for (const id of existing.keys()) {
    if (!plan.desired.has(id)) {
      blockers.push({ spotId: id, reason: 'reservation points to no current plant position' });
    }
  }
  return { plan, existing, blockers };
}

export async function applyUser(db, userRef) {
  await db.runTransaction(async (transaction) => {
    const plantsSnapshot = await transaction.get(userRef.collection('plants'));
    const spotsSnapshot = await transaction.get(userRef.collection('farmSpots'));
    const plants = plantsSnapshot.docs.map((document) => ({
      id: document.id,
      data: document.data(),
    }));
    const existing = new Map(
      spotsSnapshot.docs.map((document) => [document.id, document.data()]),
    );
    const plan = planFarmSpots(plants);

    if (plan.invalid.length > 0) {
      throw new Error(`${userRef.id} has invalid plant positions`);
    }

    for (const id of existing.keys()) {
      if (!plan.desired.has(id)) {
        throw new Error(`${userRef.id}/${id} points to no current plant position`);
      }
    }

    for (const [id, desired] of plan.desired) {
      const current = existing.get(id);
      if (current && !samePlacement(current, desired)) {
        throw new Error(`${userRef.id}/${id} disagrees with existing plants`);
      }
      if (!current) {
        transaction.create(userRef.collection('farmSpots').doc(id), {
          ...desired,
          createdAt: FieldValue.serverTimestamp(),
        });
      }
    }
  });
}
