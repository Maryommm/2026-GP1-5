# Plant Records atomic placement rollout

## What changes

New clients reserve each occupied farm square at
`users/{uid}/farmSpots/l{land}s{square}`. A normal reservation contains
`status: reserved`, the plant ID, its unchanged zero-based `land` and `square`,
and `createdAt`. The plant and reservation are created in one Firestore
transaction. The first missing reservation in the user's unlocked lands is
selected, so transaction retries prevent concurrent clients from sharing a
square.

Deletion first creates `users/{uid}/plantDeletions/{plantId}`. That marker
blocks new growth writes while growth documents are removed in retryable
chunks. The final batch removes the plant, its normal reservation, and the
marker together. Task logs and `stats/summary` are never deleted.

Legacy duplicate positions are represented by a migration-only `conflict`
reservation containing every plant ID at that position. The app treats the
square as occupied and cannot edit or delete that marker. It never silently
moves or deletes either plant. An administrator must resolve the underlying
records and then replace the marker deliberately.

## Why coordinated rollout is required

The current production rules do not allow the new reservation and deletion
marker collections, so the new client cannot safely create or delete against
the old rules. Conversely, the strict new rules intentionally reject creation
and deletion from old clients because those clients do not perform the paired
writes. Shipping only one side is therefore not safe.

Before release, prevent old clients from continuing Plant Records writes (for
example with a maintenance window and a minimum supported app version). This
repository does not implement remote minimum-version enforcement.

## Local emulator verification

Run these commands from `ethmar` after installing Node dependencies in
`firebase-tests`:

```powershell
cd firebase-tests
npm install
cd ..
npx --prefix firebase-tests firebase emulators:exec --only firestore --project ethmar-plant-records-test "npm --prefix firebase-tests test"
```

The project ID above is intentionally synthetic. Do not replace it with the
production project for destructive tests.

To inspect the migration using emulator data, keep the emulator running and
use:

```powershell
$env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080'
npm --prefix firebase-tests run migrate:dry -- --project=ethmar-plant-records-test
npm --prefix firebase-tests run migrate:dry -- --project=ethmar-plant-records-test --apply
```

The first command is read-only. The second writes only because the emulator
host is explicit.

## Production migration and release checklist

No command in this section should be run until the project owner approves the
maintenance window, production backup, credentials, and target project ID.

1. Export or otherwise back up the production Firestore database.
2. Stop Plant Records writes from all released clients.
3. Run the migration without `--apply`, passing the production project ID.
4. Review every reported invalid position, legacy conflict, orphan spot, and
   disagreement blocker. Invalid plants, orphans, malformed reservations, and
   disagreements block the entire apply before its first write. The tool never
   moves/deletes plants or overwrites a reservation.
5. Resolve every blocker manually and repeat the dry run until it reports none.
   A conflict marker is allowed only as a conservative occupied square;
   document its later repair owner.
6. With explicit service-account credentials and approval, run the same
   command with both `--apply` and `--confirm-project=THE_PROJECT_ID`.
7. Repeat the dry run. It must report zero reservations needed and zero
   disagreement blockers. Review orphan/conflict reports again.
8. Deploy the reviewed strict Firestore rules. Deployment is intentionally not
   performed by this implementation.
9. Release the new client and prevent older clients from writing Plant Records.
10. Monitor failed creates/deletes and rerun the dry-run report after release.

Example production commands (placeholders only):

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS = 'C:\secure\approved-service-account.json'
npm --prefix firebase-tests run migrate:dry -- --project=THE_PROJECT_ID
npm --prefix firebase-tests run migrate:dry -- --project=THE_PROJECT_ID --apply --confirm-project=THE_PROJECT_ID
```

The apply command only creates missing deterministic reservation documents. It
does not delete orphan documents, overwrite mismatches, repair invalid plants,
move duplicates, or deploy rules.

## Interrupted deletion and backend boundary

The client algorithm is retry-safe: until the final batch succeeds, the plant
and square remain present, and the marker prevents new growth. Retrying resumes
growth cleanup. This is the safest client-compatible approach, but it is not a
guaranteed unattended cascade if the client never runs again. A trusted backend
worker is required if the product must guarantee eventual cleanup without any
client retry. Stale conflict markers and administratively damaged records also
require an explicit admin repair; the client deliberately leaves them occupied.

## Real Android testing

Emulator rule tests and a local Android debug build are not the same as testing
the installed app against the live Firebase project. Live create/delete tests
must wait until migration and strict rules are coordinated. When approved,
connect a phone with USB debugging enabled, accept the RSA prompt, confirm it in
`flutter devices`, and run `flutter run -d DEVICE_ID` from `ethmar`.

Manually verify sign-in, add/persistence after restart, edit and schedules,
delete, disappearance from My Plants and Virtual Farm, reuse of the deleted
square, and updates to tasks/reminders. Confirm historical task logs and streak
statistics remain unchanged.
