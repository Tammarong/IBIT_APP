import {after, before, test} from "node:test";
import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import {resolve} from "node:path";
import {randomUUID} from "node:crypto";
import {initializeApp, deleteApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {getDatabase} from "firebase-admin/database";
import {initializeTestEnvironment, assertFails, assertSucceeds, RulesTestEnvironment} from "@firebase/rules-unit-testing";
import {BookingError, BookingInput, startsAt} from "../src/domain";
import {ReservationService} from "../src/reservations";

process.env.FIREBASE_DATABASE_EMULATOR_HOST ||= "127.0.0.1:9000";
process.env.FIREBASE_AUTH_EMULATOR_HOST ||= "127.0.0.1:9099";
const projectId = "demo-ibit-reservations";
const databaseURL = `https://${projectId}-default-rtdb.firebaseio.com`;
const app = initializeApp({projectId, databaseURL}, "integration");
const db = getDatabase(app);
const adminAuth = getAuth(app);
const service = new ReservationService(db);
const suffix = randomUUID().replaceAll("-", "");
const owner = {uid: `test-owner-${suffix}`, emailVerified: true};
const stranger = {uid: `test-stranger-${suffix}`, emailVerified: true};
const base: BookingInput = {requestId: randomUUID(), roomId: "room-01", date: "2099-03-02",
  startMinute: 490, endMinute: 575, purpose: "Integration test"};
const ownReservations = new Set<string>();
const createdRooms: string[] = [];
let rules: RulesTestEnvironment;
let ownerToken: string;
let unverifiedToken: string;

async function login(uid: string, verified: boolean): Promise<string> {
  const email = `${uid}@example.com`;
  await adminAuth.createUser({uid, email, password: "Local-test-pass-123", emailVerified: verified});
  const response = await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo-key`, {
    method: "POST", headers: {"Content-Type": "application/json"},
    body: JSON.stringify({email, password: "Local-test-pass-123", returnSecureToken: true}),
  });
  const body = await response.json() as {idToken: string};
  assert.equal(response.status, 200);
  return body.idToken;
}

async function callable(name: string, data: unknown, token?: string) {
  const response = await fetch(`http://127.0.0.1:5001/${projectId}/asia-southeast1/${name}`, {
    method: "POST", headers: {"Content-Type": "application/json", ...(token ? {Authorization: `Bearer ${token}`} : {})},
    body: JSON.stringify({data}),
  });
  const body = await response.json() as {result?: {reservation: {id: string; status: string}}; error?: {status: string}};
  if (body.result?.reservation.id) ownReservations.add(body.result.reservation.id);
  return {status: response.status, ...body};
}

async function create(overrides: Partial<BookingInput> = {}, identity = owner) {
  const input = {...base, ...overrides, requestId: overrides.requestId ?? randomUUID()};
  const result = await service.create(input, identity);
  ownReservations.add(result.reservation.id);
  return result.reservation;
}

before(async () => {
  for (const roomId of ["room-01", "room-02", "room-03", "room-04", "room-05", "room-06"]) {
    const ref = db.ref(`appData/rooms/${roomId}`);
    if (!(await ref.get()).exists()) {await ref.set({name: `IBIT ${roomId}`}); createdRooms.push(roomId);}
  }
  for (const [roomId, bookingEnabled] of [["5A09", true], ["4A07", false]] as const) {
    const ref = db.ref(`appData/rooms/${roomId}`);
    if (!(await ref.get()).exists()) {await ref.set({name: roomId, bookingEnabled}); createdRooms.push(roomId);}
  }
  ownerToken = await login(owner.uid, true);
  unverifiedToken = await login(stranger.uid, false);
  rules = await initializeTestEnvironment({projectId, database: {
    host: "127.0.0.1", port: 9000,
    rules: readFileSync(resolve(process.cwd(), "../database.rules.json"), "utf8"),
  }});
});

after(async () => {
  // A single cleanup transaction preserves unrelated reservations and intervals.
  await db.ref("appData").transaction(current => {
    if (!current) return current;
    for (const id of ownReservations) {
      const reservation = current.reservations?.[id];
      if (!reservation) continue;
      delete current.reservations[id];
      const intervals = current.roomDays?.[reservation.date]?.[reservation.roomId]?.intervals;
      if (intervals) delete intervals[id];
    }
    for (const id of createdRooms) delete current.rooms?.[id];
    return current;
  }, undefined, false);
  await Promise.all([owner.uid, stranger.uid].map(uid => adminAuth.deleteUser(uid).catch(() => {})));
  await rules?.cleanup();
  await db.goOffline();
  await deleteApp(app);
});

test("callable authentication, verification, booking envelope and cancellation", async () => {
  const input = {...base, roomId: "room-06", requestId: randomUUID()};
  assert.equal((await callable("createReservation", input)).error?.status, "UNAUTHENTICATED");
  assert.equal((await callable("createReservation", input, unverifiedToken)).error?.status, "PERMISSION_DENIED");
  const created = await callable("createReservation", input, ownerToken);
  assert.equal(created.status, 200);
  assert.equal(created.result?.reservation.status, "confirmed");
  const cancelled = await callable("cancelReservation", {reservationId: created.result?.reservation.id}, ownerToken);
  assert.equal(cancelled.result?.reservation.status, "cancelled");
});

test("general ITD rooms can be booked; specialized and disabled rooms cannot", async () => {
  const booking = await create({roomId: "5A09"});
  assert.equal(booking.roomId, "5A09");
  await assert.rejects(create({roomId: "5A01"}), {code: "invalid-argument"});
  if (createdRooms.includes("4A07")) {
    await assert.rejects(create({roomId: "4A07"}), {code: "failed-precondition"});
  }
});

test("concurrent overlapping first bookings produce exactly one reservation", async () => {
  const outcomes = await Promise.allSettled(Array.from({length: 8}, () => create()));
  assert.equal(outcomes.filter(result => result.status === "fulfilled").length, 1);
  for (const outcome of outcomes) if (outcome.status === "rejected") {
    assert.equal((outcome.reason as BookingError).code, "already-exists");
  }
});

test("concurrent idempotent retries return one reservation; changed payload is rejected", async () => {
  const requestId = randomUUID();
  const attempts = await Promise.all(Array.from({length: 5}, () => create({roomId: "room-02", requestId})));
  assert.equal(new Set(attempts.map(x => x.id)).size, 1);
  await assert.rejects(create({roomId: "room-02", requestId, purpose: "Changed"}), {code: "already-exists"});
});

test("adjacent times and different rooms are independently reservable", async () => {
  await create({startMinute: 575, endMinute: 600});
  await create({roomId: "room-03"});
  const day = (await db.ref(`appData/roomDays/${base.date}/${base.roomId}`).get()).val();
  assert.equal(Object.keys(day.intervals).length, 2);
  for (const interval of Object.values(day.intervals) as Record<string, unknown>[]) {
    assert.deepEqual(Object.keys(interval).sort(), ["endMinute", "reservationId", "startMinute"]);
  }
});

test("only owner may cancel; cancellation is idempotent and releases availability", async () => {
  const reservation = await create({roomId: "room-04"});
  await assert.rejects(service.cancel({reservationId: reservation.id}, stranger), {code: "permission-denied"});
  const cancelled = await service.cancel({reservationId: reservation.id}, owner);
  assert.equal(cancelled.reservation.status, "cancelled");
  assert.deepEqual(await service.cancel({reservationId: reservation.id}, owner), cancelled);
  await create({roomId: "room-04"});
});

test("cannot cancel after start; retry of existing booking succeeds after start", async () => {
  const requestId = randomUUID();
  const reservation = await create({roomId: "room-05", requestId});
  const later = new ReservationService(db, () => startsAt(base.date, base.startMinute));
  await assert.rejects(later.cancel({reservationId: reservation.id}, owner), {code: "failed-precondition"});
  assert.equal((await later.create({...base, roomId: "room-05", requestId}, owner)).reservation.id, reservation.id);
});

test("server rejects past, weekends, lunch overlaps and unverified users", async () => {
  await assert.rejects(create({date: "2020-01-06"}), {code: "failed-precondition"});
  await assert.rejects(create({date: "2099-03-07"}), {code: "failed-precondition"});
  await assert.rejects(create({startMinute: 700, endMinute: 800}), {code: "invalid-argument"});
  await assert.rejects(create({}, {...owner, emailVerified: false}), {code: "permission-denied"});
});

test("Realtime Database rules enforce private ownership and deny direct writes", async () => {
  const reservation = await create({roomId: "room-06", startMinute: 800, endMinute: 850});
  const ownerDb = rules.authenticatedContext(owner.uid).database(databaseURL);
  const otherDb = rules.authenticatedContext(stranger.uid).database(databaseURL);
  const guestDb = rules.unauthenticatedContext().database(databaseURL);
  const reservationPath = `appData/reservations/${reservation.id}`;
  await assertSucceeds(ownerDb.ref(reservationPath).once("value"));
  await assertFails(otherDb.ref(reservationPath).once("value"));
  await assertFails(guestDb.ref(reservationPath).once("value"));
  await assertSucceeds(ownerDb.ref("appData/reservations").orderByChild("userId").equalTo(owner.uid).once("value"));
  await assertFails(ownerDb.ref("appData/reservations").once("value"));
  await assertFails(otherDb.ref("appData/reservations").orderByChild("userId").equalTo(owner.uid).once("value"));
  await assertSucceeds(otherDb.ref(`appData/roomDays/${base.date}/room-06`).once("value"));
  await assertSucceeds(ownerDb.ref("appData/rooms/room-01").once("value"));
  await assertFails(guestDb.ref("appData/rooms/room-01").once("value"));
  await assertFails(guestDb.ref(`appData/roomDays/${base.date}/room-06`).once("value"));
  await assertFails(ownerDb.ref("appData").once("value"));
  for (const path of [reservationPath, "appData/rooms/room-01", `appData/roomDays/${base.date}/room-06`]) {
    await assertFails(ownerDb.ref(path).set({userId: owner.uid}));
    await assertFails(ownerDb.ref(path).update({userId: owner.uid}));
    await assertFails(ownerDb.ref(path).remove());
  }
});
