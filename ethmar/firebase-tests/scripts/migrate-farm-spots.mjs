import { applicationDefault, getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

import {
  applyUser,
  discoverUsers,
  inspectUser,
} from './farm-spot-migration-firestore.mjs';

const args = new Map(
  process.argv.slice(2).map((arg) => {
    const [key, ...value] = arg.replace(/^--/, '').split('=');
    return [key, value.length === 0 ? true : value.join('=')];
  }),
);
const apply = args.has('apply');
const emulator = process.env.FIRESTORE_EMULATOR_HOST;
const projectId = String(args.get('project') || process.env.GCLOUD_PROJECT || '');
const confirmedProject = String(args.get('confirm-project') || '');

if (!projectId) {
  throw new Error('Pass --project=PROJECT_ID (dry-run and apply).');
}
if (apply && !emulator && confirmedProject !== projectId) {
  throw new Error(
    'Production apply requires --confirm-project=PROJECT_ID and explicit credentials.',
  );
}
if (apply && !emulator && !process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  throw new Error('Production apply requires GOOGLE_APPLICATION_CREDENTIALS.');
}

const app =
  getApps()[0] ??
  initializeApp({
    projectId,
    ...(emulator ? {} : { credential: applicationDefault() }),
  });
const db = getFirestore(app);

function reportUser(uid, plan, existing, blockers) {
  const missing = [...plan.desired.keys()].filter((id) => !existing.has(id));
  const orphan = [...existing.keys()].filter((id) => !plan.desired.has(id));
  console.log(
    JSON.stringify({
      uid,
      reservationsNeeded: missing.length,
      legacyConflicts: plan.conflicts,
      invalidPlantPositions: plan.invalid,
      orphanSpotDocuments: orphan,
      blockers,
    }),
  );
}

const users = await discoverUsers(db);
const inspections = [];
for (const userRef of users) {
  const inspection = await inspectUser(userRef);
  reportUser(userRef.id, inspection.plan, inspection.existing, inspection.blockers);
  inspections.push({ userRef, inspection });
}

const blockingUsers = inspections.filter(
  ({ inspection }) => inspection.blockers.length > 0,
).length;
if (blockingUsers > 0) {
  throw new Error(`${blockingUsers} user(s) require manual repair; nothing was overwritten.`);
}
if (apply) {
  for (const { userRef } of inspections) {
    await applyUser(db, userRef);
  }
}
console.log(apply ? 'Migration apply completed.' : 'Dry run completed; no writes performed.');
