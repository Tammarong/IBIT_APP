import {initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {getDatabase} from "firebase-admin/database";
import {logger} from "firebase-functions";
import {onCall, HttpsError, CallableRequest} from "firebase-functions/v2/https";
import {AuthIdentity, BookingError} from "./domain";
import {ReservationService} from "./reservations";

if (process.env.IBIT_HYBRID_MODE === "1" &&
    (process.env.IBIT_DATABASE_URL !==
      "https://ibit-rooms-20260914-default-rtdb.asia-southeast1.firebasedatabase.app" ||
      process.env.FIREBASE_AUTH_EMULATOR_HOST ||
      process.env.FIREBASE_DATABASE_EMULATOR_HOST)) {
  throw new Error("Hybrid booking must use live IBIT Auth and Realtime Database.");
}
initializeApp({projectId: process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT ||
  (process.env.IBIT_HYBRID_MODE === "1" ? "ibit-rooms-20260914" : "demo-ibit-reservations"),
databaseURL: process.env.IBIT_DATABASE_URL || process.env.FIREBASE_DATABASE_URL ||
  (process.env.FIREBASE_DATABASE_EMULATOR_HOST ?
    "https://demo-ibit-reservations-default-rtdb.firebaseio.com" : undefined)});
// Discovery runs before project-specific dotenv values are loaded. Defer
// database access until the callable executes in the emulator runtime.
const service = () => new ReservationService(getDatabase());
const options = {region: "asia-southeast1", maxInstances: 10, timeoutSeconds: 60};

async function identity(request: CallableRequest): Promise<AuthIdentity | undefined> {
  if (process.env.IBIT_HYBRID_MODE !== "1") {
    return request.auth ? {uid: request.auth.uid, emailVerified: request.auth.token.email_verified === true} : undefined;
  }
  // The Functions emulator can skip its normal token verification. Never trust
  // its decoded request.auth when this local process writes to the live DB.
  const match = /^Bearer (.+)$/i.exec(request.rawRequest.get("Authorization") ?? "");
  if (!match) return undefined;
  try {
    // Signature, issuer, audience, expiry and project are checked locally
    // using Google's public signing certificates. Revocation checking would
    // call Firebase Auth Admin APIs, which reject gcloud user ADC locally.
    const token = await getAuth().verifyIdToken(match[1]);
    return {uid: token.uid, emailVerified: token.email_verified === true};
  } catch {
    throw new BookingError("unauthenticated", "Sign in again before reserving a room.");
  }
}

async function handle<T>(work: () => Promise<T>): Promise<T> {
  try {
    return await work();
  } catch (error) {
    if (error instanceof BookingError) throw new HttpsError(error.code, error.message);
    logger.error("Reservation operation failed", error);
    throw new HttpsError("internal", "We could not save your reservation. Please retry.");
  }
}

export const createReservation = onCall(options, (request) =>
  handle(async () => service().create(request.data, await identity(request))));

export const cancelReservation = onCall(options, (request) =>
  handle(async () => service().cancel(request.data, await identity(request))));

export const bookingServiceStatus = onCall(options, () => handle(async () => {
  const room = await getDatabase().ref("appData/rooms").limitToFirst(1).get();
  return {ready: room.exists()};
}));
