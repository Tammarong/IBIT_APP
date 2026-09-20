import {createHash} from "node:crypto";
import {Database} from "firebase-admin/database";
import {
  AuthIdentity, BookingError, checkBookable, Interval, objectInput, overlaps,
  parseBooking, requireIdentity, Reservation, sameBooking, startsAt,
} from "./domain";

type Day = {roomId: string; date: string; intervals: Record<string, Interval>};
type AppData = {
  rooms?: Record<string, {bookingEnabled?: boolean}>;
  roomDays?: Record<string, Record<string, Day>>;
  reservations?: Record<string, Reservation>;
};

export class ReservationService {
  constructor(private readonly db: Database, private readonly now: () => number = Date.now) {}

  private async transact(work: (state: AppData) => Reservation): Promise<{reservation: Reservation}> {
    let failure: unknown;
    let reservation: Reservation | undefined;
    // Both the private record and public availability live under this root.
    const root = this.db.ref("appData");
    // The Admin SDK invokes the update callback with an uncached null first.
    // An existing root is required; the probe makes the server return its value
    // and retry the callback without erasing the real data.
    if (!(await root.get()).exists()) {
      throw new BookingError("not-found", "Rooms have not been set up yet.");
    }
    const result = await root.transaction((current: AppData | null) => {
      failure = undefined;
      reservation = undefined;
      if (current === null || "__transactionProbe" in current) {
        return {__transactionProbe: true};
      }
      const state = structuredClone(current ?? {}) as AppData;
      try {
        reservation = work(state);
        return state;
      } catch (error) {
        failure = error;
        return undefined;
      }
    }, undefined, false);
    if (!result.committed) {
      if (failure) throw failure;
      throw new BookingError("unavailable", "The booking changed while saving. Please retry.");
    }
    if (!reservation) throw new BookingError("internal", "The reservation was not saved.");
    return {reservation};
  }

  async create(raw: unknown, auth: AuthIdentity | undefined): Promise<{reservation: Reservation}> {
    const identity = requireIdentity(auth);
    if (!identity.emailVerified) {
      throw new BookingError("permission-denied", "Verify your email before reserving a room.");
    }
    const input = parseBooking(raw);
    const id = createHash("sha256").update(`${identity.uid}\0${input.requestId}`).digest("hex");
    return this.transact((state) => {
      const previous = state.reservations?.[id];
      if (previous) {
        if (!sameBooking(input, previous, identity.uid)) {
          throw new BookingError("already-exists", "This request ID was already used for different reservation details.");
        }
        return previous;
      }
      const room = state.rooms?.[input.roomId];
      if (!room) throw new BookingError("not-found", "This room is no longer available.");
      if (!input.roomId.startsWith("room-") && room.bookingEnabled !== true) {
        throw new BookingError("failed-precondition", "This room is not open for app reservations.");
      }
      const createdAt = this.now();
      checkBookable(input, createdAt);
      const day = state.roomDays?.[input.date]?.[input.roomId] ?? {
        roomId: input.roomId, date: input.date, intervals: {},
      };
      const intervals = day.intervals ?? {};
      if (Object.values(intervals).some((interval) => overlaps(input, interval))) {
        throw new BookingError("already-exists", "Someone has reserved this time. Choose another time or room.");
      }
      const {requestId: _requestId, ...details} = input;
      const reservation: Reservation = {...details, id, userId: identity.uid, status: "confirmed", createdAt};
      intervals[id] = {reservationId: id, startMinute: input.startMinute, endMinute: input.endMinute};
      day.intervals = intervals;
      state.roomDays ??= {};
      state.roomDays[input.date] ??= {};
      state.roomDays[input.date][input.roomId] = day;
      state.reservations ??= {};
      state.reservations[id] = reservation;
      return reservation;
    });
  }

  async cancel(raw: unknown, auth: AuthIdentity | undefined): Promise<{reservation: Reservation}> {
    const identity = requireIdentity(auth);
    const {reservationId} = objectInput(raw);
    if (typeof reservationId !== "string" || !/^[a-f0-9]{64}$/.test(reservationId)) {
      throw new BookingError("invalid-argument", "Choose a valid reservation.");
    }
    return this.transact((state) => {
      const previous = state.reservations?.[reservationId];
      if (!previous) throw new BookingError("not-found", "Reservation not found.");
      if (previous.userId !== identity.uid) {
        throw new BookingError("permission-denied", "You can only cancel your own reservations.");
      }
      if (previous.status === "cancelled") return previous;
      if (startsAt(previous.date, previous.startMinute) <= this.now()) {
        throw new BookingError("failed-precondition", "This reservation has already started and cannot be cancelled.");
      }
      const day = state.roomDays?.[previous.date]?.[previous.roomId];
      if (!day?.intervals?.[reservationId]) {
        throw new BookingError("internal", "Availability is out of sync with this reservation.");
      }
      delete day.intervals[reservationId];
      const reservation: Reservation = {...previous, status: "cancelled"};
      state.reservations![reservationId] = reservation;
      return reservation;
    });
  }
}
