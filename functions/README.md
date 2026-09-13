# IBIT reservation backend

Node.js 22, TypeScript, Firebase Auth, Firestore, and second-generation callable Cloud Functions. All booking times are calendar dates plus minute-of-day in Asia/Bangkok (UTC+07:00). The server clock decides whether a booking has started.

## Local use

From the repository root, with Node.js 22, Firebase CLI, and Java 21 or newer installed:

```powershell
npm --prefix functions ci
.\scripts\start-emulators.ps1
```

In another terminal:

```powershell
.\scripts\seed-emulators.ps1
.\scripts\test-backend.ps1 -UseRunningEmulators
```

The scripts find Android Studio's bundled Java on Windows when it is absent from PATH. Other systems can run `npm --prefix functions run build`, `firebase emulators:start --project demo-ibit-reservations --only auth,firestore,functions`, and `npm --prefix functions run seed` directly. To run the tests with temporary emulators, use `scripts/test-backend.ps1` without the switch. The startup script exports data to `.emulator-data` on graceful shutdown and restores it on the next run. Stop it with Ctrl+C to retain local accounts and reservations.

Ports: Auth 9099, Firestore 8080, Functions 5001, UI 4000, all bound to `127.0.0.1`. Android's emulator reaches the host through `10.0.2.2`. The development project ID is `demo-ibit-reservations` and the callable region is `asia-southeast1`.

The seed creates missing `room-01` through `room-06` documents. Repeating it preserves edited metadata and all reservations. Images are Flutter assets by default; administrators can set `imageUrl` in room metadata to use their own room photography. Auth accounts are created through the app. The emulator console prints local verification and password-reset links.

## Callable contract

`createReservation` accepts `{ requestId, roomId, date, startMinute, endMinute, purpose }`. Use a fresh UUID per booking attempt and retain it across network retries. Allowed request IDs contain 8–128 ASCII letters, digits, `_` or `-`; the purpose is trimmed and must have 1–500 characters. The server derives user identity from Firebase Authentication and requires a verified email. Ownership fields supplied by the client are ignored.

`cancelReservation` accepts `{ reservationId }`. Only the owner can cancel, and only before the starting instant. Repeating a successful cancellation is harmless.

Both return `{ reservation }`, where the reservation contains `id`, `roomId`, `userId`, `date` (`YYYY-MM-DD`), `startMinute`, `endMinute`, `purpose`, `status` (`confirmed` or `cancelled`), and `createdAt` (Unix milliseconds). Completion is derived by the client from end time; it is not stored as another status.

The server accepts any whole-minute duration entirely within 08:00–12:00 or 13:00–16:00, Monday–Friday. Adjacent reservations are allowed. It rejects past starts and overlapping bookings. Normal validation errors are returned as Firebase callable `invalid-argument`, `failed-precondition`, `permission-denied`, `not-found`, or `already-exists` errors, with readable messages.

A reservation ID is SHA-256 of the authenticated UID plus request ID. A reused request ID with different normalized details is rejected. Retrying existing details returns the original record, including after cancellation or the start time; it never recreates a cancelled booking. Use a new request ID to make a new booking.

## Data and concurrency

- `rooms/{roomId}` stores editable `name`, `subtitle`, `description`, `assetPath`, nullable `imageUrl`, and `facilities` strings. Capacity is intentionally omitted until supplied by the faculty.
- `reservations/{id}` stores private reservation details; reads and queries are limited to the owner.
- `roomDays/{roomId}_{date}` stores `roomId`, `date`, and `intervals: [{ reservationId, startMinute, endMinute }]`. It contains no identity or booking purpose.

Every successful create transaction reads and updates the deterministic room/day document and creates its private reservation together. Simultaneous requests for a previously empty day therefore contend on the same document; exactly one overlapping request can commit. Cancellation changes the reservation and removes its interval in a single transaction. Client writes to all three collections are denied. Seed scripts and backend functions use the Admin SDK.

## Verification

`npm --prefix functions test` builds and runs the domain tests without emulators. `npm --prefix functions run test:integration` requires all three emulators and tests callable auth/verification, concurrent conflicts, concurrent idempotency, adjacent bookings, different rooms, cancellation, privacy and direct-write denial. Integration tests create temporary users and records in March 2099 and clean those records after completion. They preserve other user reservations and room metadata.

Cloud deployment is intentionally deferred. Use the root setup instructions for a real Firebase project, FlutterFire configuration, providers and Android signing fingerprints. Deployed Cloud Functions require the Firebase Blaze plan. Do not use this emulator-only seed script to populate a production database.
