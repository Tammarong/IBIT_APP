const {initializeApp} = require('firebase-admin/app');
const {getDatabase} = require('firebase-admin/database');

const expected = 'https://ibit-rooms-20260914-default-rtdb.asia-southeast1.firebasedatabase.app';
if (process.env.IBIT_DATABASE_URL !== expected ||
    process.env.FIREBASE_DATABASE_EMULATOR_HOST ||
    process.env.FIREBASE_AUTH_EMULATOR_HOST) {
  throw new Error('Hybrid mode needs the exact live IBIT database and no Auth or Database emulator.');
}
initializeApp({projectId: 'ibit-rooms-20260914', databaseURL: expected});
const timer = setTimeout(() => {
  console.error('Timed out checking live database access. Configure Application Default Credentials.');
  process.exit(1);
}, 15000);
getDatabase().ref('appData/rooms/3A02').get().then((snapshot) => {
  clearTimeout(timer);
  if (!snapshot.exists()) throw new Error('Live room catalog is missing.');
  console.log('Local booking server can read the live IBIT database.');
  process.exit(0);
}).catch((error) => {
  clearTimeout(timer);
  console.error(`Live database access failed: ${error.code || error.message}`);
  process.exit(1);
});
