import {createHash} from "node:crypto";
import {Firestore} from "firebase-admin/firestore";
import {
  AuthIdentity, BookingError, checkBookable, Interval, objectInput, overlaps,
  parseBooking, requireIdentity, Reservation, sameBooking, startsAt,
} from "./domain";

export class ReservationService {
  constructor(private readonly db: Firestore, private readonly now: () => number = Date.now) {}

  async create(raw: unknown, auth: AuthIdentity | undefined): Promise<{reservation: Reservation}> {
    const identity = requireIdentity(auth);
    if (!identity.emailVerified) {
      throw new BookingError("permission-denied", "Verify your email before reserving a room.");
    }
    const input = parseBooking(raw);
    // Namespace request IDs by authenticated owner; avoid exposing UID in references.
    const id = createHash("sha256").update(`${identity.uid}\0${input.requestId}`).digest("hex");
    const reservationRef = this.db.collection("reservations").doc(id);
    const roomRef = this.db.collection("rooms").doc(input.roomId);
    const dayRef = this.db.collection("roomDays").doc(`${input.roomId}_${input.date}`);
    const reservation = await this.db.runTransaction(async (tx) => {
      const [existing, room, day] = await tx.getAll(reservationRef, roomRef, dayRef);
      if (existing.exists) {
        const previous = existing.data() as Reservation;
        if (!sameBooking(input, previous, identity.uid)) {
          throw new BookingError("already-exists", "This request ID was already used for different reservation details.");
        }
        return previous;
      }
      if (!room.exists) throw new BookingError("not-found", "This room is no longer available.");
      const createdAt = this.now();
      checkBookable(input, createdAt);
      const intervals = (day.data()?.intervals ?? []) as Interval[];
      if (intervals.some((interval) => overlaps(input, interval))) {
        throw new BookingError("already-exists", "Someone has reserved this time. Choose another time or room.");
      }
      const {requestId: _requestId, ...details} = input;
      const result: Reservation = {...details, id, userId: identity.uid, status: "confirmed", createdAt};
      intervals.push({reservationId: id, startMinute: input.startMinute, endMinute: input.endMinute});
      intervals.sort((a, b) => a.startMinute - b.startMinute);
      // Reading and writing the same deterministic day document serializes even its first booking.
      tx.set(dayRef, {roomId: input.roomId, date: input.date, intervals});
      tx.create(reservationRef, result);
      return result;
    }, {maxAttempts: 20});
    return {reservation};
  }

  async cancel(raw: unknown, auth: AuthIdentity | undefined): Promise<{reservation: Reservation}> {
    const identity = requireIdentity(auth);
    const {reservationId} = objectInput(raw);
    if (typeof reservationId !== "string" || !/^[a-f0-9]{64}$/.test(reservationId)) {
      throw new BookingError("invalid-argument", "Choose a valid reservation.");
    }
    const reservationRef = this.db.collection("reservations").doc(reservationId);
    const reservation = await this.db.runTransaction(async (tx) => {
      const doc = await tx.get(reservationRef);
      if (!doc.exists) throw new BookingError("not-found", "Reservation not found.");
      const previous = doc.data() as Reservation;
      if (previous.userId !== identity.uid) {
        throw new BookingError("permission-denied", "You can only cancel your own reservations.");
      }
      if (previous.status === "cancelled") return previous;
      if (startsAt(previous.date, previous.startMinute) <= this.now()) {
        throw new BookingError("failed-precondition", "This reservation has already started and cannot be cancelled.");
      }
      const dayRef = this.db.collection("roomDays").doc(`${previous.roomId}_${previous.date}`);
      const day = await tx.get(dayRef);
      const intervals = ((day.data()?.intervals ?? []) as Interval[])
        .filter((interval) => interval.reservationId !== reservationId);
      const result: Reservation = {...previous, status: "cancelled"};
      tx.set(dayRef, {roomId: previous.roomId, date: previous.date, intervals});
      tx.update(reservationRef, {status: "cancelled"});
      return result;
    }, {maxAttempts: 20});
    return {reservation};
  }
}
