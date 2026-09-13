/* Seed only the local demo project. Existing metadata and bookings are preserved. */
const {initializeApp} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');

process.env.FIRESTORE_EMULATOR_HOST ||= '127.0.0.1:8080';
if (!/^(localhost|127\.0\.0\.1):\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST)) {
  throw new Error('This seed script only supports a local Firestore emulator.');
}
initializeApp({projectId: 'demo-ibit-reservations'});
const db = getFirestore();
const subtitles = ['Find your focus', 'Space for fresh ideas', 'Make room for teamwork',
  'A place to prepare', 'Bring your ideas together', 'Your next great session'];
async function main() {
  let created = 0;
  for (let i = 1; i <= 6; i++) {
    const number = String(i).padStart(2, '0');
    const ref = db.collection('rooms').doc(`room-${number}`);
    await db.runTransaction(async tx => {
      const existing = await tx.get(ref);
      if (!existing.exists) {
        tx.create(ref, {
          name: `IBIT Room ${number}`,
          subtitle: subtitles[i - 1],
          description: 'A reservable space at the IBIT faculty for study, meetings, and academic activities. Choose the time that works for your session.',
          assetPath: `assets/rooms/room-${number}.png`,
          imageUrl: null,
          facilities: [],
        });
        created++;
      }
    });
  }
  console.log(`Seed complete: ${created} rooms created; existing rooms and reservations preserved.`);
  await db.terminate();
}
main().catch(error => {console.error(error); process.exitCode = 1;});
