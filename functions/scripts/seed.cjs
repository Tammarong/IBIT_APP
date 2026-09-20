/* Seed only the local Realtime Database emulator; preserve edits and bookings. */
const {initializeApp} = require('firebase-admin/app');
const {getDatabase} = require('firebase-admin/database');
const {readFileSync} = require('node:fs');
const {resolve} = require('node:path');

process.env.FIREBASE_DATABASE_EMULATOR_HOST ||= '127.0.0.1:9000';
if (!/^(localhost|127\.0\.0\.1):\d+$/.test(process.env.FIREBASE_DATABASE_EMULATOR_HOST)) {
  throw new Error('This seed script only supports a local Realtime Database emulator.');
}
initializeApp({
  projectId: 'demo-ibit-reservations',
  databaseURL: 'https://demo-ibit-reservations-default-rtdb.firebaseio.com',
});
const db = getDatabase();
const subtitles = ['Find your focus', 'Space for fresh ideas', 'Make room for teamwork',
  'A place to prepare', 'Bring your ideas together', 'Your next great session'];
const catalog = JSON.parse(readFileSync(resolve(__dirname, '../../assets/rooms/itd_catalog.json'), 'utf8'));

async function main() {
  let created = 0;
  await db.ref('appData').transaction(current => {
    const state = current || {};
    state.rooms ||= {};
    created = 0;
    for (let i = 1; i <= 6; i++) {
      const number = String(i).padStart(2, '0');
      const id = `room-${number}`;
      if (state.rooms[id]) continue;
      state.rooms[id] = {
        name: `IBIT Room ${number}`,
        subtitle: subtitles[i - 1],
        description: 'A reservable space at the IBIT faculty for study, meetings, and academic activities. Choose the time that works for your session.',
        assetPath: `assets/rooms/${id}.png`,
        facilities: [],
      };
      created++;
    }
    for (const room of catalog) {
      if (state.rooms[room.id]) continue;
      const {id, ...metadata} = room;
      state.rooms[id] = {
        ...metadata,
        subtitle: `Floor ${room.floor} · ITD, KMUTNB`,
        description: '',
        assetPath: 'assets/rooms/room-01.png',
        facilities: [],
      };
      created++;
    }
    return state;
  }, undefined, false);
  console.log(`Seed complete: ${created} rooms created; existing metadata and reservations preserved.`);
  await db.goOffline();
}
main().catch(error => {console.error(error); process.exitCode = 1;});
