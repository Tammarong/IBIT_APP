import {initializeApp} from "firebase-admin/app";
import {getDatabase} from "firebase-admin/database";
import {logger} from "firebase-functions";
import {onCall, HttpsError, CallableRequest} from "firebase-functions/v2/https";
import {BookingError} from "./domain";
import {ReservationService} from "./reservations";

initializeApp({databaseURL: process.env.FIREBASE_DATABASE_URL ||
  (process.env.FIREBASE_DATABASE_EMULATOR_HOST ?
    "https://demo-ibit-reservations-default-rtdb.firebaseio.com" : undefined)});
const service = new ReservationService(getDatabase());
const options = {region: "asia-southeast1", maxInstances: 10, timeoutSeconds: 60};

function identity(request: CallableRequest) {
  return request.auth ? {uid: request.auth.uid, emailVerified: request.auth.token.email_verified === true} : undefined;
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
  handle(() => service.create(request.data, identity(request))));

export const cancelReservation = onCall(options, (request) =>
  handle(() => service.cancel(request.data, identity(request))));
