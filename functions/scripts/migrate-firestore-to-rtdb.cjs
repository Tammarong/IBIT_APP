/* One-time local migration. Requires both Firestore and Realtime Database emulators. */
const {initializeApp} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');
const {getDatabase} = require('firebase-admin/database');

const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST;
const databaseHost = process.env.FIREBASE_DATABASE_EMULATOR_HOST;
const local = /^(localhost|127\.0\.0\.1):\d+$/;
if (!local.test(firestoreHost || '') || !local.test(databaseHost || '')) {
  throw new Error('Migration requires local Firestore and Realtime Database emulators.');
}
initializeApp({
  projectId: 'demo-ibit-reservations',
  databaseURL: 'https://demo-ibit-reservations-default-rtdb.firebaseio.com',
});
const firestore = getFirestore();
const database = getDatabase();

async function main() {
  const [rooms, reservations, days] = await Promise.all([
    firestore.collection('rooms').get(),
    firestore.collection('reservations').get(),
    firestore.collection('roomDays').get(),
  ]);
  const next = {rooms: {}, reservations: {}, roomDays: {}};
  for (const doc of rooms.docs) next.rooms[doc.id] = doc.data();
  for (const doc of reservations.docs) next.reservations[doc.id] = doc.data();
  for (const doc of days.docs) {
    const day = doc.data();
    const date = day.date;
    const roomId = day.roomId;
    if (!date || !roomId) throw new Error(`Invalid room day: ${doc.id}`);
    next.roomDays[date] ||= {};
    next.roomDays[date][roomId] = {
      roomId, date,
      intervals: Object.fromEntries((day.intervals || []).map(interval => [interval.reservationId, interval])),
    };
  }
  let blocked = false;
  const result = await database.ref('appData').transaction(current => {
    if (current?.reservations && Object.keys(current.reservations).length) {
      blocked = true;
      return undefined;
    }
    return {
      ...(current || {}),
      rooms: {...(current?.rooms || {}), ...next.rooms},
      reservations: next.reservations,
      roomDays: next.roomDays,
    };
  }, undefined, false);
  if (!result.committed) throw new Error(blocked ?
    'Realtime Database already has reservations; migration refused to overwrite them.' :
    'Migration did not commit.');
  console.log(`Migrated ${rooms.size} rooms, ${reservations.size} reservations, and ${days.size} room days.`);
  await Promise.all([firestore.terminate(), database.goOffline()]);
}
main().catch(error => {console.error(error); process.exitCode = 1;});
